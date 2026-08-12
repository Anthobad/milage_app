// ---------------------------------------------------------------------------
// SpeedAnalysis — Phase 6.1 Foundation
// ---------------------------------------------------------------------------
//
// Speed-related analytics derived from the GPS track.
//
// ## Relationship to existing Trip summary statistics
//
// The [Trip] model already persists:
//   - averageSpeedKmh
//   - minimumSpeedKmh
//   - maximumSpeedKmh
//
// These are computed by [TripBuilder] at drive completion and remain
// authoritative for those three values.
//
// [SpeedAnalysis] provides additional track-based speed context for future
// analytics phases (e.g. speed distribution, time spent at various speed
// bands, speed-change events for braking detection).
//
// Do NOT use [SpeedAnalysis] to replace or contradict the persisted Trip
// summary statistics.

/// Speed-related analysis derived from the GPS track.
///
/// All speed values are in km/h for readability.
/// All speed values in m/s are stored internally and exposed via [*Ms] getters
/// for use by future acceleration-based analyses.
class SpeedAnalysis {
  const SpeedAnalysis({
    required this.pointCount,
    required this.pointsWithSpeed,
    this.maxDerivedSpeedKmh,
    this.minDerivedSpeedKmh,
    this.avgDerivedSpeedKmh,
    this.maxSpeedChangeMps,
    this.totalDistanceM,
    this.movingDurationS,
  });

  // ── Coverage ───────────────────────────────────────────────────────────────

  /// Total number of track points analyzed.
  final int pointCount;

  /// Number of points that had a valid GPS-reported or derived speed.
  final int pointsWithSpeed;

  // ── Derived speed extremes ─────────────────────────────────────────────────

  /// Maximum derived speed (distance/time between points) in km/h.
  ///
  /// Null when no valid segments exist.
  final double? maxDerivedSpeedKmh;

  /// Minimum derived speed (distance/time between points) in km/h,
  /// excluding stationary segments (0 km/h).
  ///
  /// Null when no valid moving segments exist.
  final double? minDerivedSpeedKmh;

  /// Average derived speed across all valid moving segments, in km/h.
  ///
  /// Null when no valid moving segments exist.
  final double? avgDerivedSpeedKmh;

  // ── Speed changes ──────────────────────────────────────────────────────────

  /// Maximum absolute speed change (m/s) between consecutive segments.
  ///
  /// This is the magnitude of the largest single-segment acceleration or
  /// deceleration event.  Null when fewer than two segments exist.
  final double? maxSpeedChangeMps;

  // ── Distance / duration ────────────────────────────────────────────────────

  /// Total track distance in metres, computed from segment haversine sums.
  ///
  /// Null when no valid segments exist.
  final double? totalDistanceM;

  /// Total time in seconds during which the vehicle was moving
  /// (derived speed > 0).
  ///
  /// Null when no valid moving segments exist.
  final double? movingDurationS;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// True when there is no speed data available.
  bool get isEmpty => pointsWithSpeed == 0;

  /// Total track distance in kilometres.  Null when [totalDistanceM] is null.
  double? get totalDistanceKm =>
      totalDistanceM != null ? totalDistanceM! / 1000.0 : null;

  // ── Factory — empty ────────────────────────────────────────────────────────

  factory SpeedAnalysis.empty() {
    return const SpeedAnalysis(
      pointCount: 0,
      pointsWithSpeed: 0,
    );
  }

  @override
  String toString() =>
      'SpeedAnalysis(points: $pointCount/$pointsWithSpeed, '
      'maxKmh: ${maxDerivedSpeedKmh?.toStringAsFixed(1)}, '
      'avgKmh: ${avgDerivedSpeedKmh?.toStringAsFixed(1)})';
}
