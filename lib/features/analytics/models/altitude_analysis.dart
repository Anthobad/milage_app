// ---------------------------------------------------------------------------
// AltitudeAnalysis — Phase 6.1 Foundation
// ---------------------------------------------------------------------------
//
// Altitude-related analytics derived from the GPS track.
//
// ## Design notes
//
// - Altitude is nullable in [TrackPointRecord].  This model never invents
//   altitude values — all fields are null when altitude data is absent.
// - Missing altitude is NOT treated as 0 m.
// - Elevation gain and loss use only the subset of points that have altitude.

/// Altitude-related analysis derived from the GPS track.
///
/// All altitude values are in metres (m).
class AltitudeAnalysis {
  const AltitudeAnalysis({
    required this.pointCount,
    required this.pointsWithAltitude,
    this.minAltitudeM,
    this.maxAltitudeM,
    this.totalElevationGainM,
    this.totalElevationLossM,
    this.altitudeRangeM,
  });

  // ── Coverage ───────────────────────────────────────────────────────────────

  /// Total track points analyzed.
  final int pointCount;

  /// Points that had a non-null altitude value.
  final int pointsWithAltitude;

  // ── Altitude extremes ──────────────────────────────────────────────────────

  /// Minimum altitude recorded in metres.  Null when no altitude data.
  final double? minAltitudeM;

  /// Maximum altitude recorded in metres.  Null when no altitude data.
  final double? maxAltitudeM;

  // ── Elevation change ───────────────────────────────────────────────────────

  /// Sum of all positive altitude changes (climbing), in metres.
  ///
  /// Null when no altitude data.
  final double? totalElevationGainM;

  /// Sum of all negative altitude changes (descending), as a positive value
  /// in metres.
  ///
  /// Null when no altitude data.
  final double? totalElevationLossM;

  // ── Range ──────────────────────────────────────────────────────────────────

  /// Difference between [maxAltitudeM] and [minAltitudeM].
  ///
  /// Null when no altitude data.
  final double? altitudeRangeM;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// True when no altitude data is available.
  bool get isEmpty => pointsWithAltitude == 0;

  // ── Factory — empty ────────────────────────────────────────────────────────

  factory AltitudeAnalysis.empty() {
    return const AltitudeAnalysis(
      pointCount: 0,
      pointsWithAltitude: 0,
    );
  }

  @override
  String toString() =>
      'AltitudeAnalysis(points: $pointCount/$pointsWithAltitude, '
      'min: ${minAltitudeM?.toStringAsFixed(0)} m, '
      'max: ${maxAltitudeM?.toStringAsFixed(0)} m, '
      'gain: ${totalElevationGainM?.toStringAsFixed(0)} m, '
      'loss: ${totalElevationLossM?.toStringAsFixed(0)} m)';
}
