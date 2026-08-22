// ---------------------------------------------------------------------------
// OverallDrivingAnalytics — Phase 6.6 Overall Dashboard
// ---------------------------------------------------------------------------
//
// Aggregated analytics for ALL trips belonging to ONE selected vehicle.
//
// ## Design principles
//
// * Immutable: all fields are final.
// * No Flutter dependency: plain Dart only.
// * No Riverpod dependency.
// * All nullable fields represent genuinely unavailable data — never fake zeros.
//
// ## Weighted average speed
//
// The overall average speed is calculated as:
//
//   averageSpeedKmh = totalDistanceKm / (totalMovingDurationSeconds / 3600)
//
// This is the correct time-weighted average — not the arithmetic mean of per-trip
// averages. For example:
//   Trip A: 10 km at 100 km/h (6 min moving time)
//   Trip B:  1 km at  20 km/h (3 min moving time)
//   Naive:  (100 + 20) / 2 = 60 km/h  ← WRONG
//   Weighted: 11 km / (9 min / 60) = ~73.3 km/h  ← CORRECT
//
// Source of totalDistanceKm: sum of trip.distanceKm (persisted at drive completion).
// Source of movingDurationSeconds: sum of SpeedAnalysis.movingDurationS from
//   per-trip analytics (loaded from GPS track points via DrivingAnalyticsService).
//
// When movingDurationSeconds is unavailable (no track points for any trip),
// averageSpeedKmh is null rather than an approximation.
//
// ## Elevation
//
// totalElevationGainM and totalElevationLossM are summed from per-trip
// AltitudeAnalysis.totalElevationGainM / totalElevationLossM.
//
// These values represent cumulative positive/negative elevation changes as
// computed by DrivingAnalyticsService — NOT max_altitude - min_altitude.
//
// ## Event counts
//
// totalLeftTurns, totalRightTurns, totalUTurns, totalHardBraking, totalSuddenStops
// are summed from per-trip analytics (TurnAnalysis, BrakingAnalysis).
//
// ## Stops
//
// totalStops is summed from trip.stops (persisted INTEGER column).
// Trips where trip.stops is null do not contribute to the total.
//
// ## Movement time
//
// movingDurationSeconds: sum of SpeedAnalysis.movingDurationS across trips.
// stoppedDurationSeconds: null — cannot be reliably derived from persisted data
//   without reloading all GPS track points per trip. Not faked.

import 'trip_data_point.dart';

/// Overall analytics aggregated across all trips for one vehicle.
class OverallDrivingAnalytics {
  const OverallDrivingAnalytics({
    required this.vehicleId,
    required this.tripCount,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
    required this.tripDataPoints,
    this.averageSpeedKmh,
    this.minimumSpeedKmh,
    this.maximumSpeedKmh,
    this.totalStops,
    this.totalLeftTurns,
    this.totalRightTurns,
    this.totalUTurns,
    this.totalHardBraking,
    this.totalSuddenStops,
    this.minimumAltitudeM,
    this.maximumAltitudeM,
    this.totalElevationGainM,
    this.totalElevationLossM,
    this.movingDurationSeconds,
    this.stoppedDurationSeconds,
  });

  /// The vehicle these analytics belong to.
  final String vehicleId;

  // ── Usage ──────────────────────────────────────────────────────────────────

  /// Total number of completed trips for this vehicle.
  final int tripCount;

  /// Sum of all trip distances in kilometres.
  final double totalDistanceKm;

  /// Sum of all trip durations in seconds.
  final int totalDurationSeconds;

  /// Per-trip data points used to draw trend graphs.
  ///
  /// Ordered chronologically (oldest → newest).
  final List<TripDataPoint> tripDataPoints;

  // ── Speed ──────────────────────────────────────────────────────────────────

  /// Weighted average speed: totalDistanceKm / (movingDurationSeconds / 3600).
  ///
  /// Null when no moving-duration data is available (e.g. no GPS track points
  /// for any trip).  Never an arithmetic mean of per-trip averages.
  final double? averageSpeedKmh;

  /// Minimum of trip.minimumSpeedKmh across all trips.
  ///
  /// Null when no trip has a recorded minimum speed.
  final double? minimumSpeedKmh;

  /// Maximum of trip.maximumSpeedKmh across all trips.
  ///
  /// Null when no trip has a recorded maximum speed.
  final double? maximumSpeedKmh;

  // ── Stops ──────────────────────────────────────────────────────────────────

  /// Sum of trip.stops across all trips with a non-null stops value.
  ///
  /// Null when no trip has a persisted stop count.
  final int? totalStops;

  // ── Turns ──────────────────────────────────────────────────────────────────

  /// Sum of TurnAnalysis.leftTurns across all trips.
  final int? totalLeftTurns;

  /// Sum of TurnAnalysis.rightTurns across all trips.
  final int? totalRightTurns;

  /// Sum of TurnAnalysis.uTurns across all trips.
  final int? totalUTurns;

  // ── Safety ─────────────────────────────────────────────────────────────────

  /// Sum of BrakingAnalysis.hardBrakingCount across all trips.
  final int? totalHardBraking;

  /// Sum of BrakingAnalysis.suddenStopCount across all trips.
  final int? totalSuddenStops;

  // ── Altitude ───────────────────────────────────────────────────────────────

  /// Minimum of trip.minimumAltitudeM across all trips.
  final double? minimumAltitudeM;

  /// Maximum of trip.maximumAltitudeM across all trips.
  final double? maximumAltitudeM;

  /// Sum of AltitudeAnalysis.totalElevationGainM across all trips.
  ///
  /// Cumulative climbing distance — NOT max_altitude - min_altitude.
  final double? totalElevationGainM;

  /// Sum of AltitudeAnalysis.totalElevationLossM across all trips.
  ///
  /// Cumulative descending distance — NOT max_altitude - min_altitude.
  final double? totalElevationLossM;

  // ── Movement ───────────────────────────────────────────────────────────────

  /// Sum of SpeedAnalysis.movingDurationS across all trips (in seconds).
  ///
  /// Null when no trip has moving-duration data.
  final double? movingDurationSeconds;

  /// Stopped duration in seconds.
  ///
  /// Always null — cannot be derived reliably from persisted data without
  /// reloading all GPS track points per trip.
  final double? stoppedDurationSeconds;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// True when no trips are recorded for this vehicle.
  bool get isEmpty => tripCount == 0;

  /// Formatted total distance.
  String get totalDistanceLabel {
    if (totalDistanceKm < 1.0) {
      return '${(totalDistanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${totalDistanceKm.toStringAsFixed(1)} km';
  }

  /// Formatted total duration.
  String get totalDurationLabel {
    final h = totalDurationSeconds ~/ 3600;
    final m = (totalDurationSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${totalDurationSeconds}s';
  }

  @override
  String toString() =>
      'OverallDrivingAnalytics(vehicle: $vehicleId, trips: $tripCount, '
      'dist: ${totalDistanceKm.toStringAsFixed(1)} km, '
      'avgSpeed: ${averageSpeedKmh?.toStringAsFixed(1)} km/h)';
}
