// ---------------------------------------------------------------------------
// DrivingAnalytics — Phase 6.1 Foundation
// ---------------------------------------------------------------------------
//
// Top-level analytics result model.
//
// This model is designed to grow with each Phase 6 subphase:
//   6.1 — Foundation: speed analysis, altitude analysis, track summary
//   6.2 — Turn analysis (TurnAnalysis)
//   6.3 — Braking / sudden-stop detection (BrakingAnalysis)
//   6.4 — Overall driving statistics (DrivingScore)
//   6.5 — Analytics UI integration
//
// All sub-models are nullable so that Phase 6.1 can leave future fields empty
// without producing invalid data, and future phases can populate them
// incrementally.
//
// ## Design principles
//
// * Immutable: all models use final fields.
// * No Flutter dependency: plain Dart only — usable in unit tests and
//   background isolates.
// * No Riverpod dependency: the model knows nothing about state management.
// * Extensible: new fields can be added in future phases without breaking
//   existing consumers.

import 'analyzed_track_point.dart';
import 'speed_analysis.dart';
import 'altitude_analysis.dart';

/// The complete analytics result for one trip.
///
/// Produced by [DrivingAnalyticsService.analyze] from a list of
/// [TrackPointRecord]s.  Future phases will populate [turnAnalysis],
/// [brakingAnalysis], and [overallStatistics].
class DrivingAnalytics {
  const DrivingAnalytics({
    required this.tripId,
    required this.analyzedPoints,
    required this.speedAnalysis,
    required this.altitudeAnalysis,
    this.turnAnalysis,
    this.brakingAnalysis,
    this.overallStatistics,
  });

  // ── Identity ───────────────────────────────────────────────────────────────

  /// The trip this analytics result belongs to.
  final String tripId;

  // ── Derived track ──────────────────────────────────────────────────────────

  /// Ordered list of analyzed track points with derived per-segment values
  /// (distance, time delta, derived speed, acceleration, heading change).
  ///
  /// Always sorted chronologically.  Empty when the trip has no track points.
  final List<AnalyzedTrackPoint> analyzedPoints;

  // ── Sub-analyses ───────────────────────────────────────────────────────────

  /// Speed-related analysis derived from the GPS track.
  final SpeedAnalysis speedAnalysis;

  /// Altitude-related analysis derived from the GPS track.
  final AltitudeAnalysis altitudeAnalysis;

  /// Turn analysis — populated in Phase 6.2.  Null until implemented.
  final dynamic turnAnalysis;

  /// Braking / sudden-stop analysis — populated in Phase 6.3.  Null until
  /// implemented.
  final dynamic brakingAnalysis;

  /// Overall driving statistics / score — populated in Phase 6.4.  Null until
  /// implemented.
  final dynamic overallStatistics;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// True when the trip has no recorded GPS track.
  bool get isEmpty => analyzedPoints.isEmpty;

  /// Number of analyzed track points.
  int get pointCount => analyzedPoints.length;

  // ── Factory — empty result ─────────────────────────────────────────────────

  /// Returns a valid empty [DrivingAnalytics] result for a trip with no
  /// recorded GPS track.
  factory DrivingAnalytics.empty(String tripId) {
    return DrivingAnalytics(
      tripId: tripId,
      analyzedPoints: const [],
      speedAnalysis: SpeedAnalysis.empty(),
      altitudeAnalysis: AltitudeAnalysis.empty(),
    );
  }

  // ── copyWith ───────────────────────────────────────────────────────────────

  DrivingAnalytics copyWith({
    String? tripId,
    List<AnalyzedTrackPoint>? analyzedPoints,
    SpeedAnalysis? speedAnalysis,
    AltitudeAnalysis? altitudeAnalysis,
    dynamic turnAnalysis,
    dynamic brakingAnalysis,
    dynamic overallStatistics,
  }) {
    return DrivingAnalytics(
      tripId: tripId ?? this.tripId,
      analyzedPoints: analyzedPoints ?? this.analyzedPoints,
      speedAnalysis: speedAnalysis ?? this.speedAnalysis,
      altitudeAnalysis: altitudeAnalysis ?? this.altitudeAnalysis,
      turnAnalysis: turnAnalysis ?? this.turnAnalysis,
      brakingAnalysis: brakingAnalysis ?? this.brakingAnalysis,
      overallStatistics: overallStatistics ?? this.overallStatistics,
    );
  }

  @override
  String toString() =>
      'DrivingAnalytics(tripId: $tripId, points: $pointCount, '
      'speed: $speedAnalysis, altitude: $altitudeAnalysis)';
}
