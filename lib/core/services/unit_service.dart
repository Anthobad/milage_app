import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/providers/unit_preference_provider.dart';

// ---------------------------------------------------------------------------
// UnitService — Phase 7.4
// ---------------------------------------------------------------------------
//
// Centralized unit conversion and formatting service.
//
// IMPORTANT:
//   Do NOT perform conversions or formatting inside widgets directly.
//   Call the methods on this service (or use the Riverpod provider) instead.
//
// CANONICAL INTERNAL UNITS:
//   Distance:  kilometres (km)
//   Speed:     kilometres per hour (km/h)
//   Altitude:  metres (m)
//
// All inputs to this service are expected in canonical units.
// This service converts first, then formats for display.
//
// CONVERSIONS (standard):
//   1 km       = 0.621371 mi
//   1 km/h     = 0.621371 mph
//   1 m        = 3.28084  ft
//
// No rounding is applied internally. Convert first, then format.
//
// FORMATTING EXAMPLES:
//
//   Metric:
//     12.4 km  |  84 km/h  |  412 m
//
//   Imperial:
//     7.7 mi   |  52.2 mph |  1352 ft
//
// USAGE:
//
//   // Via provider (reads UnitSystem from Riverpod):
//   final service = ref.watch(unitServiceProvider);
//   final label   = service.formatDistance(trip.distanceKm);
//
//   // Directly with a known system:
//   final label = UnitService(UnitSystem.imperial).formatSpeed(speedKmh);
//
// DURATION is NOT affected by this service.
// Duration remains time-based (seconds/minutes/hours) as before.

// ---------------------------------------------------------------------------
// Conversion constants
// ---------------------------------------------------------------------------

/// Kilometres to miles conversion factor.
const double kKmToMiles = 0.621371;

/// Metres to feet conversion factor.
const double kMetresToFeet = 3.28084;

// ---------------------------------------------------------------------------
// UnitService
// ---------------------------------------------------------------------------

/// Formats and converts measurement values for display using the specified
/// [UnitSystem].
///
/// All inputs are expected in canonical internal units:
///   distance → km, speed → km/h, altitude → m
///
/// Never throws.  Handles NaN and Infinity safely (returns placeholder).
class UnitService {
  const UnitService(this.system);

  /// The unit system to format values in.
  final UnitSystem system;

  // ---------------------------------------------------------------------------
  // Distance
  // ---------------------------------------------------------------------------

  /// Format [distanceKm] (in kilometres) for display using the current system.
  ///
  /// Metric:   "12.4 km" or "850 m" for sub-1 km values
  /// Imperial: "7.7 mi"
  ///
  /// Never displays NaN or Infinity — falls back to "—".
  String formatDistance(double distanceKm) {
    if (distanceKm.isNaN || distanceKm.isInfinite) return '—';

    switch (system) {
      case UnitSystem.metric:
        if (distanceKm < 1.0) {
          final metres = distanceKm * 1000;
          return '${metres.toStringAsFixed(0)} m';
        }
        return '${distanceKm.toStringAsFixed(1)} km';

      case UnitSystem.imperial:
        final miles = distanceKm * kKmToMiles;
        return '${miles.toStringAsFixed(1)} mi';
    }
  }

  /// Returns the unit label for distance without a value.
  ///
  /// Metric:   "km"
  /// Imperial: "mi"
  String get distanceUnit {
    return switch (system) {
      UnitSystem.metric => 'km',
      UnitSystem.imperial => 'mi',
    };
  }

  /// Converts [distanceKm] to the display unit (no formatting).
  ///
  /// Metric:   returns [distanceKm] unchanged
  /// Imperial: returns miles
  double convertDistance(double distanceKm) {
    if (distanceKm.isNaN || distanceKm.isInfinite) return distanceKm;
    return switch (system) {
      UnitSystem.metric => distanceKm,
      UnitSystem.imperial => distanceKm * kKmToMiles,
    };
  }

  // ---------------------------------------------------------------------------
  // Speed
  // ---------------------------------------------------------------------------

  /// Format [speedKmh] (in km/h) for display using the current system.
  ///
  /// Metric:   "84 km/h"
  /// Imperial: "52.2 mph"
  ///
  /// Never displays NaN or Infinity — falls back to "—".
  String formatSpeed(double speedKmh) {
    if (speedKmh.isNaN || speedKmh.isInfinite) return '—';

    switch (system) {
      case UnitSystem.metric:
        return '${speedKmh.toStringAsFixed(0)} km/h';

      case UnitSystem.imperial:
        final mph = speedKmh * kKmToMiles;
        return '${mph.toStringAsFixed(1)} mph';
    }
  }

  /// Format an optional speed value.  Returns "—" when null.
  String formatSpeedOrDash(double? speedKmh) {
    if (speedKmh == null) return '—';
    return formatSpeed(speedKmh);
  }

  /// Returns the unit label for speed without a value.
  ///
  /// Metric:   "km/h"
  /// Imperial: "mph"
  String get speedUnit {
    return switch (system) {
      UnitSystem.metric => 'km/h',
      UnitSystem.imperial => 'mph',
    };
  }

  /// Converts [speedKmh] to the display unit (no formatting).
  ///
  /// Metric:   returns [speedKmh] unchanged
  /// Imperial: returns mph
  double convertSpeed(double speedKmh) {
    if (speedKmh.isNaN || speedKmh.isInfinite) return speedKmh;
    return switch (system) {
      UnitSystem.metric => speedKmh,
      UnitSystem.imperial => speedKmh * kKmToMiles,
    };
  }

  // ---------------------------------------------------------------------------
  // Altitude
  // ---------------------------------------------------------------------------

  /// Format [altitudeM] (in metres) for display using the current system.
  ///
  /// Metric:   "412 m"
  /// Imperial: "1352 ft"
  ///
  /// Never displays NaN or Infinity — falls back to "—".
  String formatAltitude(double altitudeM) {
    if (altitudeM.isNaN || altitudeM.isInfinite) return '—';

    switch (system) {
      case UnitSystem.metric:
        return '${altitudeM.toStringAsFixed(0)} m';

      case UnitSystem.imperial:
        final feet = altitudeM * kMetresToFeet;
        return '${feet.toStringAsFixed(0)} ft';
    }
  }

  /// Format an optional altitude value.  Returns "—" when null.
  String formatAltitudeOrDash(double? altitudeM) {
    if (altitudeM == null) return '—';
    return formatAltitude(altitudeM);
  }

  /// Returns the unit label for altitude without a value.
  ///
  /// Metric:   "m"
  /// Imperial: "ft"
  String get altitudeUnit {
    return switch (system) {
      UnitSystem.metric => 'm',
      UnitSystem.imperial => 'ft',
    };
  }

  /// Converts [altitudeM] to the display unit (no formatting).
  ///
  /// Metric:   returns [altitudeM] unchanged
  /// Imperial: returns feet
  double convertAltitude(double altitudeM) {
    if (altitudeM.isNaN || altitudeM.isInfinite) return altitudeM;
    return switch (system) {
      UnitSystem.metric => altitudeM,
      UnitSystem.imperial => altitudeM * kMetresToFeet,
    };
  }

  // ---------------------------------------------------------------------------
  // Elevation (gain / loss — also in metres internally)
  // ---------------------------------------------------------------------------

  /// Format an elevation value (in metres).  Same conversion as altitude.
  String formatElevation(double elevationM) => formatAltitude(elevationM);

  /// Format an optional elevation value.  Returns "—" when null.
  String formatElevationOrDash(double? elevationM) {
    if (elevationM == null) return '—';
    return formatElevation(elevationM);
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides a [UnitService] configured with the currently selected [UnitSystem].
///
/// Rebuilds automatically when the user changes the unit preference.
///
/// Usage:
/// ```dart
/// final unitService = ref.watch(unitServiceProvider);
/// final label = unitService.formatDistance(trip.distanceKm);
/// ```
final Provider<UnitService> unitServiceProvider = Provider<UnitService>((ref) {
  final system = ref.watch(unitPreferenceProvider).value ?? UnitSystem.metric;
  return UnitService(system);
});
