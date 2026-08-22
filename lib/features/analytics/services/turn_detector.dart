// ---------------------------------------------------------------------------
// TurnDetector — Phase 6.2 Turn Analysis
// ---------------------------------------------------------------------------
//
// ## Algorithm overview
//
// The detector slides a fixed-size window across the chronologically-sorted
// GPS track.  For each window position it:
//
//   1. Checks that the window has enough physical movement (minMovementM).
//      Stationary or near-stationary GPS noise is ignored.
//
//   2. Splits the window in half:
//        - Entry half  → compute average bearing across the first half
//        - Exit half   → compute average bearing across the second half
//
//   3. Computes the signed heading change between entry and exit bearings
//      using GpsMathUtils.headingChangeDegrees (normalised to (−180, +180]).
//      Positive = right (clockwise), negative = left (counter-clockwise).
//
//   4. If |angle| < minTurnAngleDeg  → skip (gentle curve / noise).
//      If |angle| ≥ uTurnThresholdDeg → classify as U-turn.
//      Otherwise → classify as left or right.
//
//   5. Debounce: after a turn is recorded, the detector will not emit
//      another turn until the vehicle has traveled at least
//      [debounceDistanceM] metres from the turn midpoint.  This prevents
//      one physical turn from generating many events while its GPS points
//      are still within overlapping windows.
//
//   6. The turn event's location is the midpoint of the current window.
//      The turn event's timestamp is the midpoint point's timestamp.
//
// ## Design notes
//
// * Pure Dart — no Flutter, no Riverpod, no database.
// * All thresholds are centralised in [TurnDetectorConfig].
// * The algorithm is O(n × windowSize) ≈ O(n) because windowSize is a
//   small bounded constant.
// * Reuses GpsMathUtils — no duplicate GPS math.
//
// ## Sign convention (matches GpsMathUtils.headingChangeDegrees)
//
//   positive → clockwise  → RIGHT
//   negative → counter-clockwise → LEFT

import 'dart:math' as math;

import '../models/turn_analysis.dart';
import '../models/turn_event.dart';
import 'gps_math_utils.dart';
import '../../trips/models/track_point_record.dart';

// ---------------------------------------------------------------------------
// TurnDetectorConfig
// ---------------------------------------------------------------------------

/// Configuration constants for [TurnDetector].
///
/// All thresholds are named constants — no magic numbers in the algorithm.
class TurnDetectorConfig {
  const TurnDetectorConfig({
    this.windowSize = kDefaultWindowSize,
    this.minTurnAngleDeg = kDefaultMinTurnAngleDeg,
    this.uTurnThresholdDeg = kDefaultUTurnThresholdDeg,
    this.minMovementM = kDefaultMinMovementM,
    this.debounceDistanceM = kDefaultDebounceDistanceM,
  });

  /// Number of consecutive GPS points examined in each sliding window.
  ///
  /// Must be ≥ 3.  The window is split into entry half and exit half;
  /// a larger window is more robust to noise but may merge nearby turns.
  ///
  /// Default: 5 (entry = pairs 0→1,1→2; exit = pair 3→4; midpoint = point 2).
  final int windowSize;

  /// Minimum signed |angle| in degrees required to classify a turn.
  ///
  /// Changes below this threshold are treated as gentle curves, small
  /// steering corrections, or GPS noise.
  ///
  /// Default: 35°.  Real road turns are typically ≥ 45°; 35° provides a
  /// small safety margin for roads with slightly angled intersections while
  /// still filtering gradual highway curves (typically < 20°).
  final double minTurnAngleDeg;

  /// Minimum |angle| in degrees to classify a turn as a U-turn.
  ///
  /// U-turns are not counted as left or right turns.
  ///
  /// Default: 150°.  True U-turns are typically 160–180°; 150° leaves a
  /// margin for imprecise GPS traces.
  final double uTurnThresholdDeg;

  /// Minimum total haversine distance (metres) across all segments of a
  /// window for the window to be considered for turn detection.
  ///
  /// Prevents stationary GPS noise from triggering false turns.
  ///
  /// Default: 10 m.  Typical GPS fix interval at 30 km/h ≈ 8 m per second;
  /// 10 m filters out essentially-stationary clusters without discarding
  /// slow-traffic turns.
  final double minMovementM;

  /// Minimum distance (metres) the vehicle must travel after a detected turn
  /// before another turn can be registered.
  ///
  /// Prevents a single physical turn from generating multiple events because
  /// its GPS points overlap several window positions.
  ///
  /// Default: 50 m.  At urban speeds (30–50 km/h) a typical turn intersection
  /// spans ~10–20 m; 50 m ensures clean separation without merging two
  /// legitimate close turns (e.g. a quick left–right spaced by a short
  /// straight segment).
  final double debounceDistanceM;

  // ── Defaults ───────────────────────────────────────────────────────────────
  static const int kDefaultWindowSize = 5;
  static const double kDefaultMinTurnAngleDeg = 35.0;
  static const double kDefaultUTurnThresholdDeg = 150.0;
  static const double kDefaultMinMovementM = 10.0;
  static const double kDefaultDebounceDistanceM = 50.0;
}

// ---------------------------------------------------------------------------
// TurnDetector
// ---------------------------------------------------------------------------

/// Detects left, right, and U-turn events from a sorted GPS track.
///
/// ## Usage
///
/// ```dart
/// const detector = TurnDetector();
/// final analysis = detector.detectTurns(points);
/// ```
///
/// The input list must be **already sorted chronologically** (as produced by
/// [DrivingAnalyticsService]).  The detector does not re-sort.
class TurnDetector {
  const TurnDetector({this.config = const TurnDetectorConfig()});

  final TurnDetectorConfig config;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Detects turns in [sortedPoints] and returns a [TurnAnalysis].
  ///
  /// [sortedPoints] must be chronologically sorted (ascending timestamp).
  /// Returns [TurnAnalysis.empty] for tracks with fewer points than the
  /// window size.
  ///
  /// Never throws.
  TurnAnalysis detectTurns(List<TrackPointRecord> sortedPoints) {
    final n = sortedPoints.length;
    final ws = config.windowSize;

    if (n < ws) return TurnAnalysis.empty();

    final events = <TurnEvent>[];

    // Distance accumulated since the last registered turn — used for debounce.
    // Initialised to infinity so the first candidate is never suppressed.
    double distanceSinceLastTurnM = double.infinity;

    for (var i = 0; i <= n - ws; i++) {
      // ── Accumulate post-turn distance for debounce ─────────────────────
      // Add the distance of the step entering this window position.
      if (i > 0) {
        distanceSinceLastTurnM += GpsMathUtils.distanceMetres(
          sortedPoints[i - 1].latitude, sortedPoints[i - 1].longitude,
          sortedPoints[i].latitude, sortedPoints[i].longitude,
        );
      }

      // ── Debounce gate ──────────────────────────────────────────────────
      if (distanceSinceLastTurnM < config.debounceDistanceM) continue;

      final window = sortedPoints.sublist(i, i + ws);

      // ── 1. Movement gate ───────────────────────────────────────────────
      final totalMovement = _windowMovement(window);
      if (totalMovement < config.minMovementM) continue;

      // ── 2. Entry bearing (first half of window) ────────────────────────
      // Uses pairs strictly before the midpoint: indices [0, halfSize).
      // For ws=5, halfSize=2 → pairs (0→1) — fully before the pivot.
      // Stopping before halfSize ensures the transition pair that straddles
      // the midpoint is excluded from the entry bearing.
      final halfSize = ws ~/ 2;
      final entry = _averageBearing(window, 0, halfSize);
      // ── 3. Exit bearing (second half of window) ────────────────────────
      // Uses pairs strictly after the midpoint: indices [halfSize+1, ws).
      // For ws=5, halfSize=2 → pairs (3→4) — fully past the pivot.
      // Starting at halfSize+1 ensures the transition pair is excluded from
      // the exit bearing, preventing 0°/180° circular-mean cancellation that
      // would otherwise misclassify a U-turn as a 90° turn.
      final exit = _averageBearing(window, halfSize + 1, ws);
      if (entry == null || exit == null) continue;

      // ── 4. Signed angle change ─────────────────────────────────────────
      final angle = GpsMathUtils.headingChangeDegrees(entry, exit);
      if (angle == null) continue;

      final absAngle = angle.abs();
      if (absAngle < config.minTurnAngleDeg) continue;

      // ── 5. Classify ────────────────────────────────────────────────────
      final direction = _classify(angle, absAngle);

      // ── 6. Build event at window midpoint ──────────────────────────────
      final midIdx = ws ~/ 2;
      final mid = window[midIdx];

      events.add(TurnEvent(
        direction: direction,
        timestamp: mid.timestamp,
        latitude: mid.latitude,
        longitude: mid.longitude,
        angleDeg: angle,
        entryBearingDeg: entry,
        exitBearingDeg: exit,
        speedKmh: mid.speedKmh,
      ));

      // Reset debounce distance
      distanceSinceLastTurnM = 0;
    }

    return TurnAnalysis(turns: events);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Total haversine distance across all consecutive pairs in [window].
  double _windowMovement(List<TrackPointRecord> window) {
    var total = 0.0;
    for (var i = 1; i < window.length; i++) {
      total += GpsMathUtils.distanceMetres(
        window[i - 1].latitude, window[i - 1].longitude,
        window[i].latitude, window[i].longitude,
      );
    }
    return total;
  }

  /// Computes the circular mean bearing across consecutive point pairs in
  /// [window] from [startIdx] (inclusive) to [endIdx] (exclusive).
  ///
  /// Uses sin/cos circular mean to correctly handle the 0°/360° wraparound.
  /// Returns null when no valid bearing can be computed.
  double? _averageBearing(
    List<TrackPointRecord> window,
    int startIdx,
    int endIdx,
  ) {
    if (endIdx - startIdx < 2) return null;

    double sinSum = 0;
    double cosSum = 0;
    int count = 0;

    for (var i = startIdx; i < endIdx - 1; i++) {
      final bearing = GpsMathUtils.bearingDegrees(
        window[i].latitude, window[i].longitude,
        window[i + 1].latitude, window[i + 1].longitude,
      );
      if (bearing == null) continue;
      final rad = bearing * math.pi / 180;
      sinSum += math.sin(rad);
      cosSum += math.cos(rad);
      count++;
    }

    if (count == 0) return null;

    final meanRad = math.atan2(sinSum / count, cosSum / count);
    final meanDeg = meanRad * 180 / math.pi;
    return (meanDeg + 360) % 360;
  }

  /// Classifies [angle] (signed, normalised (−180, +180]) into a
  /// [TurnDirection].
  TurnDirection _classify(double angle, double absAngle) {
    if (absAngle >= config.uTurnThresholdDeg) return TurnDirection.uTurn;
    return angle < 0 ? TurnDirection.left : TurnDirection.right;
  }
}
