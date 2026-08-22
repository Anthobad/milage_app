// ---------------------------------------------------------------------------
// DrivingAnalytics — Phase 6.1–6.4.1
// ---------------------------------------------------------------------------
//
// Top-level analytics result model.
//
// This model is designed to grow with each Phase 6 subphase:
//   6.1 — Foundation: speed analysis, altitude analysis, track summary
//   6.2 — Turn analysis (TurnAnalysis) ← populated
//   6.3 — Braking / sudden-stop detection (BrakingAnalysis) ← populated
//   6.4.1 — Stop detection (StopAnalysis) ← populated
//   6.5 — Analytics UI integration
//
// All sub-models are nullable so that future phases can be added
// incrementally without breaking existing consumers.
//
// ## Design principles
//
// * Immutable: all fields are final.
// * No Flutter dependency: plain Dart only.
// * No Riverpod dependency.
// * Extensible: new fields can be added in future phases.

import 'analyzed_track_point.dart';
import 'altitude_analysis.dart';
import 'braking_analysis.dart';
import 'speed_analysis.dart';
import 'stop_analysis.dart';
import 'turn_analysis.dart';

/// The complete analytics result for one trip.
///
/// Produced by [DrivingAnalyticsService.analyze] from a list of
/// [TrackPointRecord]s.
class DrivingAnalytics {
  const DrivingAnalytics({
    required this.tripId,
    required this.analyzedPoints,
    required this.speedAnalysis,
    required this.altitudeAnalysis,
    this.turnAnalysis,
    this.brakingAnalysis,
    this.stopAnalysis,
    this.overallStatistics,
  });

  // ── Identity ───────────────────────────────────────────────────────────────

  /// The trip this analytics result belongs to.
  final String tripId;

  // ── Derived track ──────────────────────────────────────────────────────────

  /// Ordered list of analyzed track points with derived per-segment values.
  ///
  /// Always sorted chronologically.  Empty when the trip has no track points.
  final List<AnalyzedTrackPoint> analyzedPoints;

  // ── Sub-analyses ───────────────────────────────────────────────────────────

  /// Speed-related analysis derived from the GPS track.
  final SpeedAnalysis speedAnalysis;

  /// Altitude-related analysis derived from the GPS track.
  final AltitudeAnalysis altitudeAnalysis;

  /// Turn analysis — populated from Phase 6.2.
  final TurnAnalysis? turnAnalysis;

  /// Braking / sudden-stop analysis — populated from Phase 6.3.
  ///
  /// Null before Phase 6.3 implementation; non-null (possibly empty) from
  /// Phase 6.3 onward.
  final BrakingAnalysis? brakingAnalysis;

  /// Stop analysis — populated from Phase 6.4.1.
  ///
  /// Non-null from Phase 6.4.1 onward.  [StopAnalysis.stopCount] is the
  /// number of meaningful stops detected during the trip.
  final StopAnalysis? stopAnalysis;

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
      turnAnalysis: TurnAnalysis.empty(),
      brakingAnalysis: BrakingAnalysis.empty(),
      stopAnalysis: StopAnalysis.empty(),
    );
  }

  // ── copyWith ───────────────────────────────────────────────────────────────

  DrivingAnalytics copyWith({
    String? tripId,
    List<AnalyzedTrackPoint>? analyzedPoints,
    SpeedAnalysis? speedAnalysis,
    AltitudeAnalysis? altitudeAnalysis,
    TurnAnalysis? turnAnalysis,
    BrakingAnalysis? brakingAnalysis,
    StopAnalysis? stopAnalysis,
    dynamic overallStatistics,
  }) {
    return DrivingAnalytics(
      tripId: tripId ?? this.tripId,
      analyzedPoints: analyzedPoints ?? this.analyzedPoints,
      speedAnalysis: speedAnalysis ?? this.speedAnalysis,
      altitudeAnalysis: altitudeAnalysis ?? this.altitudeAnalysis,
      turnAnalysis: turnAnalysis ?? this.turnAnalysis,
      brakingAnalysis: brakingAnalysis ?? this.brakingAnalysis,
      stopAnalysis: stopAnalysis ?? this.stopAnalysis,
      overallStatistics: overallStatistics ?? this.overallStatistics,
    );
  }

  @override
  String toString() =>
      'DrivingAnalytics(tripId: $tripId, points: $pointCount, '
      'speed: $speedAnalysis, altitude: $altitudeAnalysis, '
      'turns: $turnAnalysis, braking: $brakingAnalysis, '
      'stops: $stopAnalysis)';
}
