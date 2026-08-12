// ---------------------------------------------------------------------------
// AnalyzedTrackPoint — Phase 6.1 Foundation
// ---------------------------------------------------------------------------
//
// A single GPS track point enriched with per-segment derived values.
//
// Raw GPS data from [TrackPointRecord] is preserved unchanged.
// Derived values (distance, time delta, derived speed, acceleration,
// heading change) are computed by [GpsMathUtils] and stored separately
// so future analytics phases can use both without confusion.
//
// ## Units
//
// All internal numeric values use SI units:
//   distance       → metres (m)
//   time           → seconds (s)
//   speed          → metres per second (m/s)   internal
//   speedKmh       → kilometres per hour       display convenience
//   acceleration   → metres per second squared (m/s²)
//   heading        → degrees clockwise from true north (0–360)
//   altitude       → metres (m)
//
// Conversion to display units (km/h, km) is done at the UI layer only.

/// A GPS track point annotated with segment-level derived values.
///
/// ## Segment semantics
///
/// Segment values relate to the interval **between the previous point and
/// this point**.  For the first point in a track, all segment values are
/// null because there is no preceding point.
///
/// ## Null safety
///
/// All derived fields are nullable to prevent fabricating values when the
/// input data is insufficient (e.g. zero time delta, single-point track).
class AnalyzedTrackPoint {
  const AnalyzedTrackPoint({
    // Raw GPS fields (preserved as-is)
    required this.id,
    required this.tripId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.rawSpeedKmh,
    this.accuracyM,
    this.headingDegrees,
    // Derived segment values (null for first point or invalid intervals)
    this.segmentDistanceM,
    this.segmentDurationS,
    this.derivedSpeedMs,
    this.derivedSpeedKmh,
    this.speedChangeMps,
    this.accelerationMps2,
    this.headingChangeDeg,
    this.altitudeChangeMetre,
  });

  // ── Raw GPS fields ─────────────────────────────────────────────────────────

  /// Database ID of the originating [TrackPointRecord].
  final String id;

  /// Trip this point belongs to.
  final String tripId;

  /// UTC timestamp of this GPS fix.
  final DateTime timestamp;

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Altitude in metres above the WGS 84 ellipsoid, or null if unavailable.
  final double? altitude;

  /// Raw GPS-reported speed in km/h, or null if not reported.
  ///
  /// This is the value from the GPS sensor / location provider.
  /// Not overwritten by derived calculations.
  final double? rawSpeedKmh;

  /// GPS accuracy estimate in metres, or null if not reported.
  final double? accuracyM;

  /// GPS-reported heading in degrees clockwise from north (0–360), or null.
  final double? headingDegrees;

  // ── Derived segment values ─────────────────────────────────────────────────

  /// Haversine distance from the **previous** point to this point, in metres.
  ///
  /// Null for the first point.
  final double? segmentDistanceM;

  /// Elapsed seconds from the **previous** point to this point.
  ///
  /// Null for the first point or when the interval is zero/negative.
  final double? segmentDurationS;

  /// Speed derived from [segmentDistanceM] / [segmentDurationS], in m/s.
  ///
  /// Null when distance or duration are unavailable or duration is zero.
  final double? derivedSpeedMs;

  /// [derivedSpeedMs] converted to km/h for convenience.
  ///
  /// Null when [derivedSpeedMs] is null.
  final double? derivedSpeedKmh;

  /// Change in speed (m/s) between the previous segment and this segment.
  ///
  /// Positive = acceleration, negative = deceleration.
  /// Null for the first two points or when speed is unavailable.
  final double? speedChangeMps;

  /// Acceleration in m/s² — [speedChangeMps] / [segmentDurationS].
  ///
  /// Null when either value is unavailable or [segmentDurationS] is zero.
  final double? accelerationMps2;

  /// Bearing change from the previous point's heading to this point's
  /// heading, in degrees.  Positive = clockwise (right), negative = left.
  ///
  /// Null when heading information is unavailable for either point.
  final double? headingChangeDeg;

  /// Altitude change from the previous point to this point, in metres.
  ///
  /// Positive = climbing, negative = descending.
  /// Null when altitude is unavailable for either point.
  final double? altitudeChangeMetre;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// The best available speed for this point in km/h.
  ///
  /// Prefers the raw GPS speed when available.  Falls back to the derived
  /// speed.  Returns null if neither is available.
  double? get bestSpeedKmh => rawSpeedKmh ?? derivedSpeedKmh;

  @override
  String toString() =>
      'AnalyzedTrackPoint(id: $id, lat: $latitude, lng: $longitude, '
      'ts: $timestamp, segDist: ${segmentDistanceM?.toStringAsFixed(1)} m, '
      'segDur: ${segmentDurationS?.toStringAsFixed(1)} s, '
      'derivedSpd: ${derivedSpeedKmh?.toStringAsFixed(1)} km/h)';
}
