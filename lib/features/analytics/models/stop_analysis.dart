// ---------------------------------------------------------------------------
// StopAnalysis — Phase 6.4.1 Stop Detection
// ---------------------------------------------------------------------------
//
// Aggregated result of stop detection for one trip.
//
// ## Single authoritative source
//
// [stopCount] is derived from [events] at construction time.  The event list
// is the single source of truth — there is no separate counter that can drift
// out of sync.
//
// ## Immutability
//
// All fields are final.

import 'stop_event.dart';

/// Aggregated stop analysis for one trip.
///
/// Produced by [StopDetector.detect] and stored in
/// [DrivingAnalytics.stopAnalysis].
class StopAnalysis {
  StopAnalysis({required this.events})
      : stopCount = events.length;

  /// All detected stop events in chronological order.
  ///
  /// Each physical stop appears exactly once.
  final List<StopEvent> events;

  /// Number of stops detected.
  ///
  /// Derived from [events] at construction — single authoritative source.
  final int stopCount;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// True when no stops were detected.
  bool get isEmpty => events.isEmpty;

  // ── Factory — empty result ─────────────────────────────────────────────────

  /// Returns a valid empty [StopAnalysis] with no events.
  factory StopAnalysis.empty() => StopAnalysis(events: const []);

  @override
  String toString() =>
      'StopAnalysis(stopCount: $stopCount)';
}
