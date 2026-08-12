// ---------------------------------------------------------------------------
// GpsMathUtils — Phase 6.1 Foundation
// ---------------------------------------------------------------------------
//
// Reusable GPS mathematics for the analytics layer.
//
// ## Design principles
//
// * Pure Dart — no Flutter, no Riverpod, no database.
// * Defensive — never produces NaN or Infinity.
// * Zero-crash — handles all degenerate inputs (null, zero, negative).
// * SI units internally: metres, seconds, m/s, m/s².
// * No state — all methods are static.
//
// ## Dependency
//
// Uses [latlong2] Distance class (already in pubspec.yaml) for the haversine
// great-circle distance calculation.  No new packages required.
//
// ## Units reference
//
//   distance       → metres (m)
//   time           → seconds (s)
//   speed          → metres per second (m/s) internally
//   acceleration   → metres per second squared (m/s²)
//   heading        → degrees clockwise from true north (0–360)
//   altitude       → metres (m)

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Reusable GPS math utilities for the analytics engine.
///
/// All methods are null-safe and guard against:
/// - Division by zero
/// - NaN / Infinity in results
/// - Invalid or out-of-order timestamps
/// - Missing / null GPS fields
abstract final class GpsMathUtils {
  // `abstract final` class cannot be instantiated — all members are static.

  // ── Distance ──────────────────────────────────────────────────────────────

  /// Calculates the haversine (great-circle) distance between two coordinate
  /// pairs in **metres**.
  ///
  /// Uses the [latlong2] `Distance` class which applies the WGS 84 Earth
  /// radius.  Accurate to within ~0.5% for typical driving distances.
  ///
  /// Returns 0.0 for identical coordinates.
  /// Never returns NaN or a negative value.
  ///
  /// ```dart
  /// final dist = GpsMathUtils.distanceMetres(51.5, -0.1, 51.6, -0.1);
  /// ```
  static double distanceMetres(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const haversine = Distance();
    final result = haversine.as(
      LengthUnit.Meter,
      LatLng(lat1, lng1),
      LatLng(lat2, lng2),
    );
    if (result.isNaN || result.isInfinite || result < 0) return 0.0;
    return result;
  }

  // ── Time delta ────────────────────────────────────────────────────────────

  /// Calculates the elapsed seconds between [from] and [to].
  ///
  /// Returns **null** when:
  /// - The delta is zero (same timestamp — avoids division by zero).
  /// - The delta is negative (out-of-order or duplicate timestamps).
  ///
  /// Callers must null-check before dividing.
  ///
  /// ```dart
  /// final dt = GpsMathUtils.timeDeltaSeconds(prev.timestamp, cur.timestamp);
  /// if (dt != null && dt > 0) { /* safe to divide */ }
  /// ```
  static double? timeDeltaSeconds(DateTime from, DateTime to) {
    final deltaMicros = to.difference(from).inMicroseconds;
    if (deltaMicros <= 0) return null; // zero or negative — unusable
    return deltaMicros / 1000000.0; // microseconds → seconds
  }

  // ── Speed ─────────────────────────────────────────────────────────────────

  /// Derives speed in **m/s** from distance (metres) and duration (seconds).
  ///
  /// Returns null when [distanceM] or [durationS] are null, or [durationS] ≤ 0.
  ///
  /// ```dart
  /// final spd = GpsMathUtils.derivedSpeedMs(50.0, 10.0); // 5.0 m/s
  /// ```
  static double? derivedSpeedMs(double? distanceM, double? durationS) {
    if (distanceM == null || durationS == null || durationS <= 0) return null;
    final result = distanceM / durationS;
    if (result.isNaN || result.isInfinite) return null;
    return result;
  }

  /// Converts **m/s** to **km/h**.  Returns null when [speedMs] is null.
  static double? speedMsToKmh(double? speedMs) {
    if (speedMs == null) return null;
    return speedMs * 3.6;
  }

  /// Converts **km/h** to **m/s**.  Returns null when [speedKmh] is null.
  static double? speedKmhToMs(double? speedKmh) {
    if (speedKmh == null) return null;
    return speedKmh / 3.6;
  }

  // ── Acceleration ──────────────────────────────────────────────────────────

  /// Calculates acceleration in **m/s²**.
  ///
  /// [speedChangeMps] — speed change in m/s (positive = acceleration,
  ///                    negative = deceleration).
  /// [durationS]      — elapsed time in seconds.
  ///
  /// Returns null when either argument is null or [durationS] ≤ 0.
  ///
  /// ```dart
  /// // 4 m/s speed gain over 2 s → 2 m/s²
  /// final a = GpsMathUtils.accelerationMps2(4.0, 2.0);
  /// ```
  static double? accelerationMps2(double? speedChangeMps, double? durationS) {
    if (speedChangeMps == null || durationS == null || durationS <= 0) {
      return null;
    }
    final result = speedChangeMps / durationS;
    if (result.isNaN || result.isInfinite) return null;
    return result;
  }

  // ── Bearing / heading ─────────────────────────────────────────────────────

  /// Calculates the forward bearing from point A to point B in degrees
  /// clockwise from true north (0–360).
  ///
  /// Returns null when both coordinates are identical (no direction defined).
  ///
  /// ```dart
  /// // ~0° heading north
  /// final b = GpsMathUtils.bearingDegrees(51.5, -0.1, 51.6, -0.1);
  /// ```
  static double? bearingDegrees(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    if (lat1 == lat2 && lng1 == lng2) return null;

    final dLng = _rad(lng2 - lng1);
    final lat1R = _rad(lat1);
    final lat2R = _rad(lat2);

    final y = math.sin(dLng) * math.cos(lat2R);
    final x = math.cos(lat1R) * math.sin(lat2R) -
        math.sin(lat1R) * math.cos(lat2R) * math.cos(dLng);

    final bearing = _deg(math.atan2(y, x));
    final result = (bearing + 360) % 360; // normalise to [0, 360)

    if (result.isNaN || result.isInfinite) return null;
    return result;
  }

  /// Calculates the signed heading change from [fromDeg] to [toDeg],
  /// normalised to (−180, +180].
  ///
  /// Positive = clockwise (right), negative = counter-clockwise (left).
  /// Returns null when either argument is null.
  ///
  /// ```dart
  /// GpsMathUtils.headingChangeDegrees(350, 10);  // +20° (right)
  /// GpsMathUtils.headingChangeDegrees(10, 350);  // −20° (left)
  /// ```
  static double? headingChangeDegrees(double? fromDeg, double? toDeg) {
    if (fromDeg == null || toDeg == null) return null;
    var delta = toDeg - fromDeg;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta <= -180) {
      delta += 360;
    }
    if (delta.isNaN || delta.isInfinite) return null;
    return delta;
  }

  // ── Altitude ──────────────────────────────────────────────────────────────

  /// Calculates the altitude change from [fromM] to [toM] in metres.
  ///
  /// Positive = climbing, negative = descending.
  /// Returns null when either value is null.
  ///
  /// **Never** substitutes 0 for a null altitude.
  static double? altitudeChangeMetre(double? fromM, double? toM) {
    if (fromM == null || toM == null) return null;
    return toM - fromM;
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Returns true when [value] is a non-null, finite number (not NaN, not ±∞).
  static bool isValid(double? value) {
    if (value == null) return false;
    return value.isFinite;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static double _rad(double degrees) => degrees * math.pi / 180;
  static double _deg(double radians) => radians * 180 / math.pi;
}
