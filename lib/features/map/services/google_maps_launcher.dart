import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// GoogleMapsLauncher
// ---------------------------------------------------------------------------

/// Handles checking for Google Maps and launching it with a destination.
///
/// Uses platform channels to query the Android package manager and to launch
/// the Google Maps navigation intent.
///
/// Only targets Google Maps (package: com.google.android.apps.maps).
/// Does NOT fall back to other map apps or show an app chooser.
class GoogleMapsLauncher {
  static const _platform = MethodChannel('com.triprank.app/google_maps');

  // ---------------------------------------------------------------------------
  // Check install
  // ---------------------------------------------------------------------------

  /// Returns true if Google Maps is installed on the device.
  ///
  /// Falls back to false on any platform error.
  static Future<bool> isInstalled() async {
    try {
      final result = await _platform.invokeMethod<bool>('isGoogleMapsInstalled');
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Launch navigation
  // ---------------------------------------------------------------------------

  /// Launches Google Maps with turn-by-turn navigation to [latitude],[longitude].
  ///
  /// Uses the `google.navigation` intent URI which explicitly opens Google Maps.
  /// Returns true on success, false if the launch failed.
  static Future<bool> launchNavigation({
    required double latitude,
    required double longitude,
    String? destinationName,
  }) async {
    try {
      final result = await _platform.invokeMethod<bool>(
        'launchGoogleMapsNavigation',
        {
          'latitude': latitude,
          'longitude': longitude,
          'name': destinationName,
        },
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
