// ---------------------------------------------------------------------------
// StopEvent — Phase 6.4.1 Stop Detection
// ---------------------------------------------------------------------------
//
// Represents a single detected stop event.
//
// ## What is a stop
//
// A stop is a meaningful period where the vehicle has halted or nearly halted
// during a trip.  A single GPS point with speed == 0 is NOT sufficient — GPS
// data contains noise and occasional inaccurate speed readings.  The detector
// requires the near-zero-speed condition to persist for a configurable minimum
// duration.
//
// ## Location semantics
//
// [latitude] and [longitude] are the coordinates of the GPS point at which
// the stop began (the first point that entered the near-zero-speed window).
// This is the most actionable location for future UI display.
//
// ## Duration semantics
//
// [durationS] is the elapsed time between the first and last GPS point that
// were inside the stop window.  It does NOT include any inter-fix gaps beyond
// the last qualifying point.
//
// ## Index semantics
//
// [startIndex] and [endIndex] are the indices into the SORTED track-point
// list passed to [StopDetector.detect].  They are useful for future UI
// features (e.g. highlighting the stop segment on the map) and for debugging.
//
// ## Immutability
//
// All fields are final.  No mutable state.

/// A single detected stop event from a GPS track.
///
/// Produced by [StopDetector] and stored in [StopAnalysis.events].
class StopEvent {
  const StopEvent({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.durationS,
    required this.startIndex,
    required this.endIndex,
  });

  // ── Location in space and time ─────────────────────────────────────────────

  /// UTC timestamp of the first GPS point that entered the stop window.
  ///
  /// This is the earliest moment the vehicle was detected as stopped or
  /// nearly stopped.
  final DateTime timestamp;

  /// Latitude of the first GPS point inside the stop window.
  ///
  /// Represents the approximate location where the stop began.
  /// Not reverse-geocoded — no internet required.
  final double latitude;

  /// Longitude of the first GPS point inside the stop window.
  final double longitude;

  // ── Duration ───────────────────────────────────────────────────────────────

  /// Total duration of the stop in seconds (always > 0).
  ///
  /// Elapsed time from [timestamp] (first point in the window) to the
  /// last GPS point still inside the stop window.
  ///
  /// This is GPS-fix-rate dependent: if GPS fixes are infrequent, the
  /// measured duration may underestimate the true stop duration.
  final double durationS;

  // ── Track indices ──────────────────────────────────────────────────────────

  /// Index of the first qualifying track point (within the sorted list
  /// passed to [StopDetector.detect]).
  ///
  /// Useful for highlighting the stopped segment on a route map.
  final int startIndex;

  /// Index of the last qualifying track point in the stop window.
  ///
  /// Always ≥ [startIndex].
  final int endIndex;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// Duration formatted for display (e.g. "1m 30s", "45s").
  String get durationLabel {
    final totalSeconds = durationS.round();
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  String toString() =>
      'StopEvent(ts: $timestamp, lat: ${latitude.toStringAsFixed(5)}, '
      'lng: ${longitude.toStringAsFixed(5)}, dur: ${durationS.toStringAsFixed(1)} s, '
      'idx: $startIndex–$endIndex)';
}
