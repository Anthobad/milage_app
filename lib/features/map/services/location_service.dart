import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Result of a location permission / service check.
enum LocationStatus {
  /// Services enabled and permission granted — ready to use.
  ready,
  /// Location services disabled on device.
  serviceDisabled,
  /// Permission denied — can request again.
  permissionDenied,
  /// Permission permanently denied — must open settings.
  permissionDeniedForever,
}

/// Provides location data for the map feature.
///
/// Stateless service — business logic lives in the provider.
/// Ready for future stream-based trip recording.
class LocationService {
  const LocationService();

  // Default location shown before permission is granted (London).
  static const LatLng defaultLocation = LatLng(51.5074, -0.1278);

  // ---------------------------------------------------------------------------
  // Permission & service checks
  // ---------------------------------------------------------------------------

  /// Check service status and permission, requesting if needed.
  /// Returns [LocationStatus] so the caller can react without catching errors.
  Future<LocationStatus> checkAndRequest() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.denied => LocationStatus.permissionDenied,
      LocationPermission.deniedForever => LocationStatus.permissionDeniedForever,
      _ => LocationStatus.ready,
    };
  }

  // ---------------------------------------------------------------------------
  // One-shot position
  // ---------------------------------------------------------------------------

  /// Returns the current [LatLng], or null on error.
  Future<LatLng?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Continuous stream — ready for trip recording (Phase 5)
  // ---------------------------------------------------------------------------

  /// Emits [Position] updates. Used during active trip recording.
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // metres
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings helpers
  // ---------------------------------------------------------------------------

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
