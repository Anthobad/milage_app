// ---------------------------------------------------------------------------
// BrakingEvent — Phase 6.3 Hard Braking & Sudden Stop Detection
// ---------------------------------------------------------------------------
//
// Represents a single detected hard-braking or sudden-stop event.
//
// ## Event types
//
//   [BrakingEventType.hardBraking]  — strong deceleration that does NOT end
//       at near-zero speed.  The vehicle was moving, decelerated hard, but
//       remained in motion.
//
//   [BrakingEventType.suddenStop]   — strong deceleration that terminates at
//       approximately stationary speed.  A sudden stop may also involve
//       hard braking, but it is represented as a single event with the
//       [isSuddenStop] classification rather than two separate events.
//
// ## Deduplication
//
// A single physical braking maneuver is always represented as ONE event.
// When strong braking ends at near-zero speed, the event type is
// [BrakingEventType.suddenStop] — not both a hard-braking event AND a
// sudden-stop event.  This prevents double-counting.
//
// ## Speed units
//
// [startSpeedKmh] and [endSpeedKmh] are stored in km/h for display convenience.
// [decelerationMps2] uses SI units (m/s²) — always a positive value
// representing the magnitude of deceleration.
//
// ## Severity
//
// [BrakingEventSeverity] is a simple three-level classification:
//
//   mild    — deceleration ≥ hard-braking threshold but < hard threshold
//   hard    — deceleration ≥ hard threshold but < severe threshold
//   severe  — deceleration ≥ severe threshold
//
// Severity thresholds are centralised in [BrakingDetectorConfig].  The
// initial implementation prioritises reliable detection over fine-grained
// scoring; severity is a lightweight extra signal, not the primary output.
//
// ## Immutability
//
// All fields are final.  No mutable state.
//
// ## GPS limitations
//
// This event is GPS-derived.  Deceleration values are calculated from
// sequential speed and time data, not from a vehicle brake sensor or
// accelerometer.  GPS noise, fix rate, and multi-path reflections can
// affect accuracy.  Treat individual event magnitudes as approximate.

// ---------------------------------------------------------------------------
// BrakingEventType
// ---------------------------------------------------------------------------

/// The type of a [BrakingEvent].
enum BrakingEventType {
  /// Strong deceleration without reaching near-zero speed.
  hardBraking,

  /// Strong deceleration that terminates at approximately stationary speed.
  ///
  /// A sudden stop implies hard braking occurred, but the two are NOT
  /// represented as separate events — only [suddenStop] is emitted.
  suddenStop,
}

// ---------------------------------------------------------------------------
// BrakingEventSeverity
// ---------------------------------------------------------------------------

/// Simple severity classification for a [BrakingEvent].
///
/// Severity is derived from [BrakingEvent.decelerationMps2] at construction
/// time using the thresholds in [BrakingDetectorConfig].
///
/// ## Approximate GPS-derived deceleration ranges
///
/// These ranges are conservative estimates suitable for GPS-only data.
/// Accelerometer-based thresholds from published literature (e.g. 0.3–0.5 g
/// for "harsh braking") should NOT be used directly — GPS-derived values
/// carry significantly more noise and are rate-limited by fix frequency.
///
///   mild   — ~0.4–0.6 m/s² (noticeable but not aggressive)
///   hard   — ~0.6–1.0 m/s² (firm braking at traffic lights, hazards)
///   severe — > 1.0 m/s²    (emergency braking, very hard stop)
enum BrakingEventSeverity {
  /// Noticeable braking, meets the detection threshold but not aggressive.
  mild,

  /// Firm braking — clearly intentional, harder than typical traffic stops.
  hard,

  /// Very hard or emergency-level braking.
  severe,
}

// ---------------------------------------------------------------------------
// BrakingEvent
// ---------------------------------------------------------------------------

/// A single hard-braking or sudden-stop event detected from a GPS track.
///
/// Produced by [BrakingDetector] and stored in [BrakingAnalysis.events].
class BrakingEvent {
  const BrakingEvent({
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.startSpeedKmh,
    required this.endSpeedKmh,
    required this.decelerationMps2,
    required this.severity,
    this.durationS,
  });

  // ── Classification ─────────────────────────────────────────────────────────

  /// Whether this is a hard-braking or sudden-stop event.
  final BrakingEventType type;

  // ── Location & time ────────────────────────────────────────────────────────

  /// UTC timestamp of the strongest deceleration point in the event.
  ///
  /// Corresponds to the GPS fix at the peak deceleration — NOT the trip
  /// start/end timestamp.
  final DateTime timestamp;

  /// Latitude of the representative event location.
  ///
  /// Set to the coordinates of the strongest deceleration point.
  /// Not reverse-geocoded — no internet required.
  final double latitude;

  /// Longitude of the representative event location.
  final double longitude;

  // ── Speed ──────────────────────────────────────────────────────────────────

  /// Speed in km/h at the start of the detected braking sequence.
  ///
  /// This is the speed at the beginning of the contiguous deceleration
  /// window that produced this event.
  final double startSpeedKmh;

  /// Speed in km/h at the end of the detected braking sequence.
  ///
  /// Near-zero for [BrakingEventType.suddenStop] events.
  final double endSpeedKmh;

  // ── Deceleration ───────────────────────────────────────────────────────────

  /// Peak deceleration magnitude in m/s² (always positive).
  ///
  /// This is the strongest individual segment deceleration observed within
  /// the braking window.  GPS-derived — treat as approximate.
  ///
  /// A value of 1.0 m/s² means the vehicle slowed by ~1 m/s per second
  /// (~3.6 km/h per second) at the strongest point.
  final double decelerationMps2;

  // ── Duration ───────────────────────────────────────────────────────────────

  /// Approximate duration of the braking sequence in seconds.
  ///
  /// Null when insufficient timing data is available (e.g. only one GPS fix
  /// spans the braking window, or time deltas are not reliable).
  final double? durationS;

  // ── Severity ───────────────────────────────────────────────────────────────

  /// Simple severity classification derived from [decelerationMps2].
  final BrakingEventSeverity severity;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// True when this event is a sudden stop.
  bool get isSuddenStop => type == BrakingEventType.suddenStop;

  /// True when this event is hard braking (not a sudden stop).
  bool get isHardBraking => type == BrakingEventType.hardBraking;

  /// Speed reduction across the event in km/h (always non-negative).
  double get speedReductionKmh => (startSpeedKmh - endSpeedKmh).clamp(0.0, double.infinity);

  @override
  String toString() =>
      'BrakingEvent(type: ${type.name}, severity: ${severity.name}, '
      'ts: $timestamp, lat: $latitude, lng: $longitude, '
      'startSpeed: ${startSpeedKmh.toStringAsFixed(1)} km/h, '
      'endSpeed: ${endSpeedKmh.toStringAsFixed(1)} km/h, '
      'decel: ${decelerationMps2.toStringAsFixed(2)} m/s², '
      'dur: ${durationS?.toStringAsFixed(1)} s)';
}
