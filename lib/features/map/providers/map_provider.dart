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
/// Architecture is prepared for:
/// - Destination selection (Phase 4.2) ✅
/// - Route preview (Phase 4.3)
/// - Trip recording (Phase 5)
class MapNotifier extends Notifier<MapState> {
  late final LocationService _locationService;

  /// The flutter_map [MapController] is owned here so both the map widget and
  /// other parts of the UI (e.g. re-center button) can share the same instance.
  ///
  /// Created eagerly — the widget attaches it via [FlutterMap.mapController].
  final MapController mapController = MapController();

  @override
  MapState build() {
    _locationService = const LocationService();
    // Request location on first build.
    Future.microtask(initLocation);
    return const MapState();
  }

  /// Check permission and fetch current location.
  Future<void> initLocation() async {
    state = state.copyWith(isLoadingLocation: true);

    final status = await _locationService.checkAndRequest();
    state = state.copyWith(locationStatus: status);

    if (status == LocationStatus.ready) {
      final location = await _locationService.getCurrentLocation();
      state = state.copyWith(
        currentLocation: location,
        isLoadingLocation: false,
      );
    } else {
      state = state.copyWith(isLoadingLocation: false);
    }
  }

  /// Re-request permission (called from the UI permission prompt).
  Future<void> requestPermission() => initLocation();

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

  /// Switch map tile theme — independent from app theme.
  void setMapTheme(MapTheme theme) {
    state = state.copyWith(mapTheme: theme);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final NotifierProvider<MapNotifier, MapState> mapProvider =
    NotifierProvider<MapNotifier, MapState>(MapNotifier.new);
