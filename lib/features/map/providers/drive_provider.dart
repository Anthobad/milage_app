import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/destination.dart';
import '../models/drive_state.dart';
import '../services/drive_controller.dart';
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
/// - Forward each GPS point to [mapProvider] so the current-location marker
///   always reflects the latest position (Bug 3 fix).
/// - Pause the idle location stream while a drive is active to avoid running
///   two parallel GPS streams; resume it after the drive ends.
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

    final result = await _controller.startDrive(destination: destination);

    switch (result) {
      case DriveStarted(:final mode):
        state = DriveState(
          status: DriveStatus.active,
          mode: mode,
          startedAt: DateTime.now().toUtc(),
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
        // Keep the active state. Pause the idle stream just like normal start.
        state = DriveState(
          status: DriveStatus.active,
          mode: DriveMode.destination,
          startedAt: DateTime.now().toUtc(),
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
  /// Stops the foreground service, saves the final track points for trip
  /// creation (Phase 5), then resets all active-drive statistics so the map
  /// info bar immediately shows idle placeholders.
  ///
  /// The reset happens at the state layer — not in the UI — so every widget
  /// that reads [driveProvider] sees zeroed values without any widget-level
  /// hacks.
  ///
  /// After resetting, the idle location stream is resumed so the
  /// current-location marker keeps moving without an app restart.
  Future<void> finishDrive() async {
    if (!state.isActive) return;

    state = state.copyWith(status: DriveStatus.finishing);

    final points = await _controller.stopDrive();

    // TODO (Phase 5): pass [points] to the trip repository to create a Trip record.
    // ignore: unused_local_variable
    final completedPoints = points;

    // Reset to idle immediately — active-drive stats (distance, path, speed,
    // altitude) must not persist to the next drive or continue to be shown in
    // the info bar after the drive ends.
    state = const DriveState();

    // Resume passive location updates so the current-location marker continues
    // to follow the user after the drive ends (Bug 3 fix).
    ref.read(mapProvider.notifier).resumeIdleLocationUpdates();
  }

  /// Explicitly reset to idle.
  ///
  /// Called after a Reckless drive is ended via the confirmation dialog so
  /// the UI can immediately allow destination selection without waiting for
  /// the async [finishDrive] chain.
  void resetDrive() {
    state = const DriveState();
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

        // ── Forward position to the authoritative current-location source ──
        // This is the fix for Bug 3: the location marker reads
        // mapProvider.currentLocation, which was previously only set once at
        // startup.  By pushing every drive GPS point here, the marker moves
        // in real-time with the user — using the same position data that
        // already drives the path polyline and distance counter.
        ref.read(mapProvider.notifier).updateCurrentLocation(point.latLng);

      case DriveUpdateError(:final message):
        // Log the error but keep the drive active — GPS errors can be transient.
        // The user must explicitly press FINISH to stop.
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

    // Re-subscribe to task data in case the service is still running.
    _controller.onUpdate = _onDriveUpdate;

    // Restore state from persisted data.
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
    );
  }

  // ---------------------------------------------------------------------------
  // Distance computation for recovery
  // ---------------------------------------------------------------------------

  /// Recomputes total driven distance in km from a list of track points.
  ///
  /// Uses the haversine formula for accuracy.
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
