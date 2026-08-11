import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/destination.dart';
import '../models/drive_state.dart';
import '../services/drive_controller.dart';
import '../../cars/providers/vehicle_provider.dart';
import '../../trips/models/trip.dart';
import '../../trips/providers/trip_repository_provider.dart';
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
/// - Capture [vehicleId] and [destination] at drive start so they are
///   available for trip persistence at drive end.
/// - Persist a completed [Trip] via [TripRepository] when FINISH is pressed.
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
    final vehicleId =
        ref.read(vehicleProvider).value?.selectedVehicleId;

    final result = await _controller.startDrive(destination: destination);

    switch (result) {
      case DriveStarted(:final mode):
        state = DriveState(
          status: DriveStatus.active,
          mode: mode,
          startedAt: DateTime.now().toUtc(),
          vehicleId: vehicleId,
          destination: destination,
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
  /// 1. Stops the foreground service and collects all track points.
  /// 2. Builds a [Trip] from the completed [DriveState] via [TripBuilder].
  /// 3. Persists it via [TripRepository].
  /// 4. Resets state to idle so the info bar shows placeholders.
  /// 5. Resumes the idle location stream.
  Future<void> finishDrive() async {
    if (!state.isActive) return;

    // Capture snapshot before state changes.
    final driveSnapshot = state.copyWith(
      status: DriveStatus.finishing,
      finishedAt: DateTime.now().toUtc(),
    );

    state = driveSnapshot;

    final points = await _controller.stopDrive();

    // Build the final DriveState with all track points and finishedAt.
    final finishedDrive = driveSnapshot.copyWith(
      trackPoints: points,
      finishedAt: driveSnapshot.finishedAt ?? DateTime.now().toUtc(),
    );

    // ── Persist the completed trip ──────────────────────────────────────────
    await _persistTrip(finishedDrive);

    // Reset to idle — active-drive stats must not persist to the next drive.
    state = const DriveState();

    // Resume passive location updates (Bug 3 fix).
    ref.read(mapProvider.notifier).resumeIdleLocationUpdates();
  }

  /// Explicitly reset to idle.
  ///
  /// Called after a Reckless drive is ended via the confirmation dialog.
  void resetDrive() {
    state = const DriveState();
  }

  // ---------------------------------------------------------------------------
  // Trip persistence
  // ---------------------------------------------------------------------------

  Future<void> _persistTrip(DriveState drive) async {
    try {
      final dest = drive.destination;
      final trip = TripBuilder.build(
        tripId: const Uuid().v4(),
        vehicleId: drive.vehicleId,
        drive: drive,
        startName: null, // reverse-geocoding at drive start not yet wired
        destinationLatitude: dest?.latitude,
        destinationLongitude: dest?.longitude,
        destinationName: dest?.name,
      );

      final repo = ref.read(tripRepositoryProvider);
      await repo.createTrip(trip);
    } catch (error, stackTrace) {
      // Do not crash the app on persistence failure.
      // ignore: avoid_print
      print('[DriveNotifier] Trip persistence failed: $error\n$stackTrace');
    }
  }

  // ---------------------------------------------------------------------------
  // Live GPS update handler — called from DriveController callback
  // ---------------------------------------------------------------------------

  void _onDriveUpdate(DriveUpdate update) {
    switch (update) {
      case DriveUpdatePoint(:final point, :final distanceKm):
        if (!state.isActive) return;
        state = state.copyWith(
          trackPoints: [...state.trackPoints, point],
          currentSpeedKmh: point.speedKmh,
          currentAltitudeM: point.altitude,
          distanceKm: distanceKm,
        );

        // Forward position to the authoritative current-location source (Bug 3 fix).
        ref.read(mapProvider.notifier).updateCurrentLocation(point.latLng);

      case DriveUpdateError(:final message):
        // Log but keep drive active — GPS errors can be transient.
        // ignore: avoid_print
        print('[DriveNotifier] GPS error: $message');
    }
  }

  // ---------------------------------------------------------------------------
  // Recovery — resumed after process death
  // ---------------------------------------------------------------------------

  Future<void> _recoverIfNeeded() async {
    final persisted = await _controller.recoverDrive();
    if (persisted == null) return;

    _controller.onUpdate = _onDriveUpdate;

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
      // vehicleId and destination are not persisted in SharedPreferences — they
      // will be null after recovery. The trip will still be created with a null
      // vehicleId, which is valid per the schema (ON DELETE SET NULL).
    );
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
