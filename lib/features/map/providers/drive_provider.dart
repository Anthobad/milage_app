import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/destination.dart';
import '../models/drive_state.dart';
import '../services/drive_controller.dart';
import '../../analytics/services/stop_detector.dart';
import '../../cars/providers/vehicle_provider.dart';
import '../../trips/models/track_point_record.dart';
import '../../trips/models/trip.dart';
import '../../trips/providers/track_point_repository_provider.dart';
import '../../trips/providers/trip_repository_provider.dart';
import '../../trips/providers/trips_filter_provider.dart';
import 'map_provider.dart';

// ---------------------------------------------------------------------------
// DriveNotifier
// ---------------------------------------------------------------------------

/// Manages [DriveState] via Riverpod.
///
/// Bridges the UI layer to [DriveController].
///
/// Responsibilities:
/// - Expose [DriveState] to all widgets that need it.
/// - Delegate start/stop logic to [DriveController].
/// - Apply live GPS updates from the controller to the state.
/// - Assign a stable [activeTripId] (UUID v4) at drive start — used as the
///   FK for incremental GPS point persistence.
/// - Persist each GPS point immediately via [TrackPointRepository].
/// - Capture [vehicleId] and [destination] at drive start so they are
///   available for trip persistence at drive end.
/// - Persist a completed [Trip] via [TripRepository] when FINISH is pressed.
/// - Return the completed [Trip.id] from [finishDrive] so the UI can navigate
///   directly to Trip Stats.
/// - Forward each GPS point to [mapProvider] for the current-location marker.
/// - Pause/resume the idle location stream around active drives.
/// - Attempt drive recovery on first build (process restart while drive was active).
class DriveNotifier extends Notifier<DriveState> {
  late final DriveController _controller;

  @override
  DriveState build() {
    _controller = DriveController();

    // Wire the controller callback so every GPS point arrives here.
    _controller.onUpdate = _onDriveUpdate;

    // Dispose the controller when this provider is destroyed.
    ref.onDispose(_controller.dispose);

    // Attempt to recover a drive interrupted by process death.
    Future.microtask(_recoverIfNeeded);

    return const DriveState();
  }

  // ---------------------------------------------------------------------------
  // Public API — called by UI
  // ---------------------------------------------------------------------------

  /// Start a drive.
  ///
  /// [destination] null → Reckless Mode.
  /// [destination] non-null → Destination Mode (Google Maps check + launch).
  ///
  /// Returns a human-readable error string if the drive could not start,
  /// or null on success.
  Future<String?> startDrive({Destination? destination}) async {
    if (state.isActive || state.isStarting) return null;

    state = state.copyWith(status: DriveStatus.starting);

    // Capture the selected vehicle ID now so it is available at trip
    // completion even if the user changes vehicles mid-drive.
    final vehicleId = ref.read(vehicleProvider).value?.selectedVehicleId;

    // Generate the stable trip ID for this drive session now.
    // GPS points will be persisted with this ID as their FK immediately,
    // before the completed trip summary row is created.
    final tripId = const Uuid().v4();

    final result = await _controller.startDrive(destination: destination);

    switch (result) {
      case DriveStarted(:final mode):
        state = DriveState(
          status: DriveStatus.active,
          mode: mode,
          startedAt: DateTime.now().toUtc(),
          vehicleId: vehicleId,
          destination: destination,
          activeTripId: tripId,
        );
        // Pause the idle location stream — the foreground service GPS will
        // drive mapProvider.updateCurrentLocation() from here on.
        ref.read(mapProvider.notifier).pauseIdleLocationUpdates();
        return null; // success

      case DriveGoogleMapsNotInstalled():
        state = const DriveState(); // back to idle
        return 'Google Maps not found. Please install Google Maps to start a route.';

      case DriveLaunchFailed():
        // Drive IS active — tracking is running — but Google Maps didn't open.
        state = DriveState(
          status: DriveStatus.active,
          mode: DriveMode.destination,
          startedAt: DateTime.now().toUtc(),
          vehicleId: vehicleId,
          destination: destination,
          activeTripId: tripId,
        );
        ref.read(mapProvider.notifier).pauseIdleLocationUpdates();
        return 'Drive tracking started but Google Maps could not be launched.';

      case DriveStartFailed(:final message):
        state = const DriveState(); // back to idle
        return message;
    }
  }

  /// Finish the active drive.
  ///
  /// 1. Stops the foreground service and collects remaining track points.
  /// 2. Ensures all GPS points are flushed to SQLite.
  /// 3. Builds a [Trip] from the completed [DriveState] via [TripBuilder].
  /// 4. Persists the [Trip] via [TripRepository].
  /// 5. Resets state to idle so the info bar shows placeholders.
  /// 6. Resumes the idle location stream.
  ///
  /// Returns the completed [Trip.id] on success, or null if persistence failed.
  /// The UI uses this to navigate to Trip Stats immediately.
  Future<String?> finishDrive() async {
    if (!state.isActive) return null;

    // Capture the full in-memory drive snapshot BEFORE any state changes.
    // state.trackPoints is the authoritative source — every GPS point that
    // arrived via _onDriveUpdate is already in here.
    final driveSnapshot = state.copyWith(
      status: DriveStatus.finishing,
      finishedAt: DateTime.now().toUtc(),
    );

    state = driveSnapshot;

    // Stop the foreground service.  The returned list comes from
    // SharedPreferences (task-isolate writes) which can be incomplete or
    // empty when the isolate hasn't flushed yet.  We intentionally ignore
    // that return value and use the in-memory snapshot instead.
    await _controller.stopDrive();

    // ── Persist completed trip and track points ─────────────────────────────
    // driveSnapshot.trackPoints is the complete in-memory set accumulated by
    // _onDriveUpdate on every GPS fix — it is the most reliable source.
    final completedTripId = await _persistTripAndPoints(driveSnapshot);

    // Invalidate the trips list so the Trips page always shows the new trip
    // regardless of which UI path triggered the finish (FINISH button,
    // "End Drive" dialog, map top bar, etc.) and regardless of whether the
    // app was in the background or the main isolate was restarted.
    ref.invalidate(vehicleTripsProvider);

    // Reset to idle — active-drive stats must not persist to the next drive.
    state = const DriveState();

    // Resume passive location updates (Bug 3 fix).
    ref.read(mapProvider.notifier).resumeIdleLocationUpdates();

    return completedTripId;
  }

  /// Explicitly reset to idle.
  ///
  /// Called after a Reckless drive is ended via the confirmation dialog.
  Future<void> resetDrive() async {
    if (state.isActive) {
      // Persist the trip even when ending via the dialog.
      // Use the in-memory snapshot — same reason as finishDrive().
      final driveSnapshot = state.copyWith(
        status: DriveStatus.finishing,
        finishedAt: DateTime.now().toUtc(),
      );
      await _controller.stopDrive(); // stop service; ignore SharedPrefs result
      await _persistTripAndPoints(driveSnapshot);

      // Invalidate so the Trips page reflects the saved trip immediately.
      ref.invalidate(vehicleTripsProvider);
    }
    state = const DriveState();
  }

  // ---------------------------------------------------------------------------
  // Trip + track-point persistence
  // ---------------------------------------------------------------------------

  /// Persists the completed trip summary and ensures all track points are in
  /// the database.
  ///
  /// Returns the trip ID on success, null on failure.
  ///
  /// ## Order of operations — IMPORTANT
  ///
  /// The trips row MUST be created BEFORE track points are inserted.
  /// `trip_track_points.trip_id` has a FK `REFERENCES trips(id)` and
  /// `PRAGMA foreign_keys = ON` is enabled, so any track-point insert that
  /// references a non-existent trip ID will fail with a constraint violation.
  ///
  /// 1. Build & insert the trip summary row first (including stop count).
  /// 2. Then flush all track points (the parent row now exists).
  Future<String?> _persistTripAndPoints(DriveState drive) async {
    try {
      final tripId = drive.activeTripId ?? const Uuid().v4();
      final dest = drive.destination;

      // ignore: avoid_print
      print('[DriveNotifier] Persisting trip $tripId with ${drive.trackPoints.length} track points');

      // ── Compute stop count from in-memory track points ──────────────────
      // Convert in-memory TrackPoint list to TrackPointRecord list so the
      // StopDetector (which consumes the same model as the rest of the
      // analytics pipeline) can process them without a database round-trip.
      final stopCount = _computeStopCount(drive.trackPoints, tripId);

      // Build the trip summary.
      final trip = TripBuilder.build(
        tripId: tripId,
        vehicleId: drive.vehicleId,
        drive: drive,
        startName: null,
        destinationLatitude: dest?.latitude,
        destinationLongitude: dest?.longitude,
        destinationName: dest?.name,
        stops: stopCount,
      );

      // Step 1: Persist the trip summary row FIRST.
      final tripRepo = ref.read(tripRepositoryProvider);
      await tripRepo.createTrip(trip);
      // ignore: avoid_print
      print('[DriveNotifier] Trip row created OK (stops: $stopCount)');

      // Step 2: Flush all track points now that the parent row exists.
      await _flushTrackPoints(drive.trackPoints, tripId);
      // ignore: avoid_print
      print('[DriveNotifier] Track points flushed OK');

      return tripId;
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print('[DriveNotifier] Trip persistence FAILED: $error\n$stackTrace');
      return null;
    }
  }

  /// Runs [StopDetector] on the in-memory [TrackPoint] list and returns the
  /// number of detected stops, or null if the list is empty.
  ///
  /// The detector is given the same default configuration as the analytics
  /// pipeline.  The computation is synchronous and O(n) so it completes in
  /// milliseconds for typical trip lengths.
  int? _computeStopCount(List<TrackPoint> points, String tripId) {
    if (points.isEmpty) return null;
    try {
      // Convert in-memory TrackPoint → TrackPointRecord without database.
      // The id and tripId fields are not used by the StopDetector.
      const uuidGen = Uuid();
      final records = points.map((p) => TrackPointRecord.fromTrackPoint(
            id: uuidGen.v4(),
            tripId: tripId,
            point: p,
          )).toList();

      const detector = StopDetector();
      final analysis = detector.detect(records);
      return analysis.stopCount;
    } catch (error, stack) {
      // ignore: avoid_print
      print('[DriveNotifier] Stop count computation failed: $error\n$stack');
      return null;
    }
  }

  /// Inserts all [points] into the track-point table under [tripId].
  ///
  /// Uses [addTrackPoints] for a single transaction so the flush is atomic.
  Future<void> _flushTrackPoints(
    List<TrackPoint> points,
    String tripId,
  ) async {
    if (points.isEmpty) {
      // ignore: avoid_print
      print('[DriveNotifier] _flushTrackPoints: nothing to flush (0 points)');
      return;
    }
    try {
      final trackRepo = ref.read(trackPointRepositoryProvider);
      final records = points.map((p) {
        return TrackPointRecord.fromTrackPoint(
          id: const Uuid().v4(),
          tripId: tripId,
          point: p,
        );
      }).toList();
      // ignore: avoid_print
      print('[DriveNotifier] Flushing ${records.length} track points for trip $tripId');
      await trackRepo.addTrackPoints(records);
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print('[DriveNotifier] Track-point flush FAILED: $error\n$stackTrace');
    }
  }

  // ---------------------------------------------------------------------------
  // Live GPS update handler — called from DriveController callback
  // ---------------------------------------------------------------------------

  void _onDriveUpdate(DriveUpdate update) {
    switch (update) {
      case DriveUpdatePoint(:final point, :final distanceKm):
        // ignore: avoid_print
        print('[DriveNotifier] GPS point received — isActive:${state.isActive} '
            'lat:${point.latitude.toStringAsFixed(5)} '
            'lng:${point.longitude.toStringAsFixed(5)} '
            'spd:${point.speedKmh.toStringAsFixed(1)} km/h '
            'tripId:${state.activeTripId}');
        if (!state.isActive) return;
        state = state.copyWith(
          trackPoints: [...state.trackPoints, point],
          currentSpeedKmh: point.speedKmh,
          currentAltitudeM: point.altitude,
          distanceKm: distanceKm,
        );
        // ignore: avoid_print
        print('[DriveNotifier] trackPoints now: ${state.trackPoints.length}');

        _persistTrackPoint(point);
        ref.read(mapProvider.notifier).updateCurrentLocation(point.latLng);

      case DriveUpdateError(:final message):
        // ignore: avoid_print
        print('[DriveNotifier] GPS error: $message');
    }
  }

  /// Persists a single [TrackPoint] to SQLite incrementally.
  ///
  /// Errors are caught and logged — a single failed write must never crash
  /// or interrupt the active drive.
  void _persistTrackPoint(TrackPoint point) {
    final tripId = state.activeTripId;
    if (tripId == null) return; // no active trip ID yet — skip

    final record = TrackPointRecord.fromTrackPoint(
      id: const Uuid().v4(),
      tripId: tripId,
      point: point,
    );

    // Fire-and-forget — intentionally not awaited so the GPS stream is never
    // blocked by a database write.
    ref.read(trackPointRepositoryProvider).addTrackPoint(record).catchError(
      (Object error, StackTrace stack) {
        // ignore: avoid_print
        print('[DriveNotifier] Track-point write failed: $error');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Recovery — resumed after process death
  // ---------------------------------------------------------------------------

  Future<void> _recoverIfNeeded() async {
    final persisted = await _controller.recoverDrive();
    if (persisted == null) return;

    _controller.onUpdate = _onDriveUpdate;

    // We cannot recover the activeTripId after a process death (it was not
    // persisted to SharedPreferences).  Generate a new one so GPS points
    // arriving after recovery are linked to a valid trip.
    final recoveredTripId = const Uuid().v4();

    state = DriveState(
      status: DriveStatus.active,
      mode: persisted.mode,
      trackPoints: persisted.trackPoints,
      startedAt: persisted.startedAt,
      distanceKm: _computeDistanceKm(persisted.trackPoints),
      currentSpeedKmh: persisted.trackPoints.isNotEmpty
          ? persisted.trackPoints.last.speedKmh
          : 0.0,
      currentAltitudeM: persisted.trackPoints.isNotEmpty
          ? persisted.trackPoints.last.altitude
          : 0.0,
      activeTripId: recoveredTripId,
      // vehicleId and destination are not persisted in SharedPreferences — they
      // will be null after recovery. The trip will still be created with a null
      // vehicleId, which is valid per the schema (ON DELETE SET NULL).
    );

    // Invalidate the trips list so the Trips page reflects any trips that
    // were persisted to SQLite before the process was killed.  This covers
    // the case where the user navigates to Trips before pressing FINISH on
    // the recovered drive.
    ref.invalidate(vehicleTripsProvider);
  }

  // ---------------------------------------------------------------------------
  // Distance computation for recovery
  // ---------------------------------------------------------------------------

  double _computeDistanceKm(List<TrackPoint> points) {
    if (points.length < 2) return 0.0;
    double totalKm = 0.0;
    for (var i = 1; i < points.length; i++) {
      totalKm += _haversineKm(points[i - 1], points[i]);
    }
    return totalKm;
  }

  double _haversineKm(TrackPoint a, TrackPoint b) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinHalfLat = math.sin(dLat / 2);
    final sinHalfLon = math.sin(dLon / 2);
    final h = sinHalfLat * sinHalfLat +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            sinHalfLon *
            sinHalfLon;
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }

  double _toRad(double degrees) => degrees * math.pi / 180.0;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Single source of truth for the active drive state.
///
/// Widgets read:  `ref.watch(driveProvider)`
/// Notifier:      `ref.read(driveProvider.notifier).startDrive(...)`
final NotifierProvider<DriveNotifier, DriveState> driveProvider =
    NotifierProvider<DriveNotifier, DriveState>(DriveNotifier.new);
