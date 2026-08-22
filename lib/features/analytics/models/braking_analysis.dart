// ---------------------------------------------------------------------------
// BrakingAnalysis — Phase 6.3 Hard Braking & Sudden Stop Detection
// ---------------------------------------------------------------------------
//
// Aggregated result of braking detection for one trip.
//
// ## Single authoritative source
//
// Counts ([hardBrakingCount], [suddenStopCount], [severeCount]) are derived
// from [events] at construction time.  The event list is the single source
// of truth.  There is no separate counter state that can drift out of sync.
//
// ## Event deduplication
//
// [BrakingDetector] never emits both a hardBraking event AND a suddenStop
// event for the same physical braking maneuver.  When braking ends at near-
// zero speed, only a [BrakingEventType.suddenStop] event is emitted.
// Therefore [hardBrakingCount] + [suddenStopCount] = total events.
//
// ## Immutability
//
// All fields are final or late-final (set once at construction).
// The event list is stored as-is from the detector — callers should not
// mutate it after construction.

import 'braking_event.dart';

/// Aggregated braking analysis for one trip.
///
/// Produced by [BrakingDetector.detect] and stored in
/// [DrivingAnalytics.brakingAnalysis].
class BrakingAnalysis {
  BrakingAnalysis({required this.events}) {
    // Derive counts from the event list — single authoritative source.
    var hardBraking = 0;
    var suddenStop = 0;
    var severe = 0;

    for (final e in events) {
      switch (e.type) {
        case BrakingEventType.hardBraking:
          hardBraking++;
        case BrakingEventType.suddenStop:
          suddenStop++;
      }
      if (e.severity == BrakingEventSeverity.severe) severe++;
    }

    hardBrakingCount = hardBraking;
    suddenStopCount = suddenStop;
    severeCount = severe;
  }

  /// All detected braking events in chronological order.
  ///
  /// Each physical braking maneuver appears exactly once.
  /// Hard braking that ends at near-zero speed is classified as
  /// [BrakingEventType.suddenStop] — not as two separate events.
  final List<BrakingEvent> events;

  /// Number of [BrakingEventType.hardBraking] events.
  ///
  /// Derived from [events] — not a separate counter.
  late final int hardBrakingCount;

  /// Number of [BrakingEventType.suddenStop] events.
  ///
  /// Derived from [events] — not a separate counter.
  late final int suddenStopCount;

  /// Number of events with [BrakingEventSeverity.severe] severity,
  /// across all event types.
  ///
  /// Derived from [events] — not a separate counter.
  late final int severeCount;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// Total number of braking events detected.
  int get totalEvents => events.length;

  /// True when no braking events were detected.
  bool get isEmpty => events.isEmpty;

  // ── Factory — empty result ─────────────────────────────────────────────────

  /// Returns a valid empty [BrakingAnalysis] with no events.
  factory BrakingAnalysis.empty() => BrakingAnalysis(events: const []);

  @override
  String toString() =>
      'BrakingAnalysis(hardBraking: $hardBrakingCount, '
      'suddenStops: $suddenStopCount, severe: $severeCount, '
      'total: $totalEvents)';
}
