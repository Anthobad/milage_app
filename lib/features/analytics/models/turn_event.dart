// ---------------------------------------------------------------------------
// TurnEvent — Phase 6.2 Turn Analysis
// ---------------------------------------------------------------------------
//
// ## Sign convention (documented here, tested explicitly)
//
//   headingChangeDegrees() from GpsMathUtils returns a value normalised to
//   (−180, +180]:
//
//     positive → clockwise change → RIGHT turn
//     negative → counter-clockwise change → LEFT turn
//
//   This is the project-wide convention used by GpsMathUtils and carried
//   forward here.
//
// ## U-turns
//
//   A directional change near ±180° is classified as [TurnDirection.uTurn].
//   U-turns are NOT counted in [leftTurns] or [rightTurns].
//   The U-turn threshold is defined in [TurnDetectorConfig.uTurnThresholdDeg].
//
// ## Immutability
//
//   All fields are final.  No setters.

/// The direction of a detected turn.
///
/// ## Sign convention
///
/// Based on the signed heading-change normalised to (−180, +180]:
///   - Negative change → [left]  (counter-clockwise)
///   - Positive change → [right] (clockwise)
///   - |angle| ≥ [TurnDetectorConfig.uTurnThresholdDeg] → [uTurn]
enum TurnDirection {
  /// Counter-clockwise (negative heading change).
  left,

  /// Clockwise (positive heading change).
  right,

  /// Near-180° reversal — not counted in left/right totals.
  uTurn,
}

// ---------------------------------------------------------------------------
// TurnEvent
// ---------------------------------------------------------------------------

/// A single detected turn event.
///
/// Each event represents one meaningful change in driving direction that
/// passed the angle threshold, movement threshold, and debounce conditions
/// defined in [TurnDetectorConfig].
///
/// ## Location semantics
///
/// [latitude] and [longitude] are the coordinates of the GPS point closest
/// to the midpoint of the turning window — the best available approximation
/// of where the turn occurred.
///
/// ## Timestamp semantics
///
/// [timestamp] is the UTC timestamp of the midpoint GPS point.
class TurnEvent {
  const TurnEvent({
    required this.direction,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.angleDeg,
    required this.entryBearingDeg,
    required this.exitBearingDeg,
    this.speedKmh,
  });

  // ── Core classification ────────────────────────────────────────────────────

  /// Whether this is a left, right, or U-turn.
  final TurnDirection direction;

  // ── Location in space and time ─────────────────────────────────────────────

  /// UTC timestamp at the approximate midpoint of the turning movement.
  final DateTime timestamp;

  /// Latitude of the representative turn location.
  final double latitude;

  /// Longitude of the representative turn location.
  final double longitude;

  // ── Angle ──────────────────────────────────────────────────────────────────

  /// The signed heading change in degrees, normalised to (−180, +180].
  ///
  /// Negative = left, positive = right.
  /// The absolute value is the turn magnitude.
  final double angleDeg;

  /// Entry bearing into the turn in degrees (0–360).
  final double entryBearingDeg;

  /// Exit bearing out of the turn in degrees (0–360).
  final double exitBearingDeg;

  // ── Speed (optional) ──────────────────────────────────────────────────────

  /// Vehicle speed at the turn midpoint in km/h, or null if unavailable.
  final double? speedKmh;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// Absolute turn angle in degrees (always positive).
  double get absAngleDeg => angleDeg.abs();

  /// True when this is a left turn.
  bool get isLeft => direction == TurnDirection.left;

  /// True when this is a right turn.
  bool get isRight => direction == TurnDirection.right;

  /// True when this is a U-turn.
  bool get isUTurn => direction == TurnDirection.uTurn;

  @override
  String toString() =>
      'TurnEvent(dir: $direction, angle: ${angleDeg.toStringAsFixed(1)}°, '
      'lat: ${latitude.toStringAsFixed(5)}, lng: ${longitude.toStringAsFixed(5)}, '
      'ts: $timestamp)';
}
