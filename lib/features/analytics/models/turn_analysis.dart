// ---------------------------------------------------------------------------
// TurnAnalysis — Phase 6.2 Turn Analysis
// ---------------------------------------------------------------------------
//
// Aggregated result of turn detection for one trip.
//
// ## Counts
//
// [leftTurns] and [rightTurns] count only [TurnDirection.left] and
// [TurnDirection.right] events respectively.  U-turns are excluded from
// both counts — they appear in [turns] but do not inflate the left/right
// totals.
//
// ## Single authoritative source
//
// [leftTurns] and [rightTurns] are derived from [turns] at construction time.
// There is no duplication — the event list is the single source of truth.
//
// ## Immutability
//
// All fields are final.

import 'turn_event.dart';

/// Aggregated turn analysis for one trip.
///
/// Produced by [TurnDetector.detectTurns] and stored in
/// [DrivingAnalytics.turnAnalysis].
class TurnAnalysis {
  TurnAnalysis({required this.turns}) {
    // Derive counts from the event list — single authoritative source.
    var left = 0;
    var right = 0;
    var uTurn = 0;
    for (final t in turns) {
      switch (t.direction) {
        case TurnDirection.left:
          left++;
        case TurnDirection.right:
          right++;
        case TurnDirection.uTurn:
          uTurn++;
      }
    }
    leftTurns = left;
    rightTurns = right;
    uTurns = uTurn;
  }

  /// All detected turn events in chronological order.
  final List<TurnEvent> turns;

  /// Number of left turns detected.  U-turns are NOT included.
  late final int leftTurns;

  /// Number of right turns detected.  U-turns are NOT included.
  late final int rightTurns;

  /// Number of U-turns detected.  Not counted in [leftTurns]/[rightTurns].
  late final int uTurns;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// Total turns including U-turns.
  int get totalTurns => turns.length;

  /// True when no turns were detected.
  bool get isEmpty => turns.isEmpty;

  // ── Factory — empty result ─────────────────────────────────────────────────

  factory TurnAnalysis.empty() => TurnAnalysis(turns: const []);

  @override
  String toString() =>
      'TurnAnalysis(left: $leftTurns, right: $rightTurns, '
      'uTurns: $uTurns, total: $totalTurns)';
}
