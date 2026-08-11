import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Map theme setting — independent from app theme per spec.
enum MapTheme {
  /// OpenStreetMap standard tiles (light).
  standard,

  /// Future: dark/custom tile server.
  dark,
}

/// Immutable state for the map feature.
class MapState {
  const MapState({
    this.currentLocation,
    this.locationStatus = LocationStatus.permissionDenied,
    this.mapTheme = MapTheme.standard,
    this.isLoadingLocation = false,
  });

  /// User's current location, null until resolved.
  final LatLng? currentLocation;

  /// Last known location permission / service status.
  final LocationStatus locationStatus;

  /// Map tile theme — independent from app theme.
  final MapTheme mapTheme;

  /// True while fetching initial location.
  final bool isLoadingLocation;

  bool get isReady => locationStatus == LocationStatus.ready;

  MapState copyWith({
    LatLng? currentLocation,
    LocationStatus? locationStatus,
    MapTheme? mapTheme,
    bool? isLoadingLocation,
  }) {
    return MapState(
      currentLocation: currentLocation ?? this.currentLocation,
      locationStatus: locationStatus ?? this.locationStatus,
      mapTheme: mapTheme ?? this.mapTheme,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages map state: location permission, current position, map theme,
/// and camera control via [MapController].
///
/// ## Single authoritative location source
///
/// [state.currentLocation] is the one and only source of truth for the
/// user's current position.  It is updated by two complementary paths:
///
/// 1. **Idle passive stream** — when no drive is active, [initLocation]
///    subscribes to [LocationService.positionStream] with a light filter.
///    Every position update flows into [updateCurrentLocation] so the marker
///    stays fresh even without a drive.
///
/// 2. **Active drive forwarding** — while a drive is running the foreground
///    service produces high-frequency GPS points.  [DriveNotifier._onDriveUpdate]
///    calls [updateCurrentLocation] for each point so the marker follows the
///    user in real-time.  The idle stream is **paused** while a drive is
///    active to avoid redundant position requests.
///
/// The idle stream is resumed automatically by [resumeIdleLocationUpdates]
/// after a drive ends, so the marker keeps moving without an app restart.
class MapNotifier extends Notifier<MapState> {
  late final LocationService _locationService;

  /// The flutter_map [MapController] is owned here so both the map widget and
  /// other parts of the UI (e.g. re-center button) can share the same instance.
  ///
  /// Created eagerly — the widget attaches it via [FlutterMap.mapController].
  final MapController mapController = MapController();

  /// Passive background position stream used when no drive is active.
  StreamSubscription<dynamic>? _idlePositionSub;

  /// True after [_cancelIdleStream] has been called, so [resumeIdleLocationUpdates]
  /// knows to restart rather than resume a dead subscription.
  bool _idleStreamCancelled = false;

  @override
  MapState build() {
    _locationService = const LocationService();

    // Cancel the idle stream when this provider is destroyed.
    ref.onDispose(_cancelIdleStream);

    // Request location on first build.
    Future.microtask(initLocation);
    return const MapState();
  }

  // ---------------------------------------------------------------------------
  // Public API — location
  // ---------------------------------------------------------------------------

  /// Check permission, then start a continuous idle position stream that keeps
  /// [state.currentLocation] fresh whenever no drive is active.
  ///
  /// Safe to call multiple times — any existing idle stream is cancelled first.
  Future<void> initLocation() async {
    state = state.copyWith(isLoadingLocation: true);

    final status = await _locationService.checkAndRequest();
    state = state.copyWith(locationStatus: status);

    if (status == LocationStatus.ready) {
      // ── Seed with a quick one-shot fix so the marker appears immediately ──
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        state = state.copyWith(
          currentLocation: location,
          isLoadingLocation: false,
        );
      } else {
        state = state.copyWith(isLoadingLocation: false);
      }

      // ── Then subscribe to the continuous stream for ongoing updates ────────
      _startIdleStream();
    } else {
      state = state.copyWith(isLoadingLocation: false);
    }
  }

  /// Re-request permission (called from the UI permission prompt).
  Future<void> requestPermission() => initLocation();

  /// Push a new GPS position into [state.currentLocation].
  ///
  /// Called by:
  /// - The idle position stream (passive updates when not driving).
  /// - [DriveNotifier._onDriveUpdate] on every GPS point during a drive.
  ///
  /// This is the **single write path** for the current-location marker,
  /// ensuring the pointer always reflects the latest known position regardless
  /// of whether a drive is active.
  void updateCurrentLocation(LatLng position) {
    state = state.copyWith(currentLocation: position);
  }

  /// Pause the idle position stream.
  ///
  /// Called by [DriveNotifier] when a drive starts so we are not running two
  /// parallel GPS streams simultaneously.
  void pauseIdleLocationUpdates() {
    _idlePositionSub?.pause();
  }

  /// Resume (or restart) the idle position stream after a drive ends.
  ///
  /// Called by [DriveNotifier] after [finishDrive] so the marker keeps moving
  /// without requiring an app restart.
  void resumeIdleLocationUpdates() {
    if (_idlePositionSub == null || _idleStreamCancelled) {
      // Stream was never started or was cancelled — restart it.
      _startIdleStream();
    } else {
      _idlePositionSub!.resume();
    }
  }

  // ---------------------------------------------------------------------------
  // Camera control
  // ---------------------------------------------------------------------------

  /// Animate the map camera to [point] at [zoom].
  ///
  /// Safe to call even before the map is attached — the controller will
  /// silently no-op if it has no map yet.
  void moveCamera(LatLng point, {double zoom = 15}) {
    try {
      mapController.move(point, zoom);
    } catch (_) {
      // Controller not yet attached to a map widget — safe to ignore.
    }
  }

  /// Re-center map on the user's current location.
  void recenterOnUser() {
    final loc = state.currentLocation;
    if (loc != null) {
      moveCamera(loc);
    }
  }

  /// Fit the camera to show all provided [points] with optional [padding].
  ///
  /// Called when a route is ready so that the entire polyline (including
  /// the current location and destination) is visible.
  ///
  /// Safe to call even before the map is attached — silently ignored.
  void fitRoute(
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(60),
  }) {
    if (points.isEmpty) return;
    try {
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final bounds = LatLngBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
      );

      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: padding,
        ),
      );
    } catch (_) {
      // MapController not yet attached to a live map — safe to ignore.
    }
  }

  /// Switch map tile theme — independent from app theme.
  void setMapTheme(MapTheme theme) {
    state = state.copyWith(mapTheme: theme);
  }

  // ---------------------------------------------------------------------------
  // Internal — idle position stream
  // ---------------------------------------------------------------------------

  /// Start a low-frequency position stream used when no drive is active.
  ///
  /// A 10-metre filter keeps the idle stream from firing constantly while the
  /// user is stationary, while still catching meaningful position changes.
  void _startIdleStream() {
    _cancelIdleStream();
    _idleStreamCancelled = false;
    _idlePositionSub = _locationService.positionStream().listen(
      (position) {
        updateCurrentLocation(LatLng(position.latitude, position.longitude));
      },
      onError: (_) {
        // Idle stream errors are non-fatal — the last known position is kept.
      },
      cancelOnError: false,
    );
  }

  void _cancelIdleStream() {
    _idlePositionSub?.cancel();
    _idlePositionSub = null;
    _idleStreamCancelled = true;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final NotifierProvider<MapNotifier, MapState> mapProvider =
    NotifierProvider<MapNotifier, MapState>(MapNotifier.new);
