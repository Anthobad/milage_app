import 'package:latlong2/latlong.dart';

import '../../map/models/drive_state.dart';

// ---------------------------------------------------------------------------
// TrackPointRecord
// ---------------------------------------------------------------------------

/// A single GPS track point as stored in the [kTrackPointsTable] SQLite table.
///
/// ## Relationship to [TrackPoint]
///
/// [TrackPoint] is the in-memory, in-transit model used by the foreground
/// service and Riverpod state during an active drive.
///
/// [TrackPointRecord] is the durable database record that survives process
/// death, app restarts, and device reboots.  It carries all the same GPS
/// fields plus:
/// - [id]     — a stable UUID primary key for the database row.
/// - [tripId] — the foreign key linking this point to its parent [Trip].
///
/// ## Field precision
///
/// [latitude] and [longitude] are stored as 64-bit IEEE 754 doubles (SQLite
/// REAL) — no rounding is applied before persistence.
///
/// ## Nullable fields
///
/// [altitude], [speedKmh], [accuracyM], and [headingDegrees] are nullable
/// because the platform location provider does not guarantee their presence
/// on every GPS fix.  A nullable REAL column is more honest than a sentinel
/// value like -1 or 0.
class TrackPointRecord {
  const TrackPointRecord({
    required this.id,
    required this.tripId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speedKmh,
    this.accuracyM,
    this.headingDegrees,
  });

  // ── Primary key ───────────────────────────────────────────────────────────

  /// Stable UUID v4 for this database row.
  final String id;

  // ── Foreign key ───────────────────────────────────────────────────────────

  /// ID of the [Trip] this point belongs to.
  ///
  /// NOT NULL.  ON DELETE CASCADE — removing the parent trip removes all its
  /// track points automatically.
  final String tripId;

  // ── GPS fields ────────────────────────────────────────────────────────────

  /// UTC timestamp when this GPS fix was recorded.
  final DateTime timestamp;

  /// Latitude in decimal degrees.  Full IEEE 754 double precision.
  final double latitude;

  /// Longitude in decimal degrees.  Full IEEE 754 double precision.
  final double longitude;

  /// Altitude in metres above the WGS 84 ellipsoid, or null if unavailable.
  final double? altitude;

  /// Speed in km/h (converted from m/s by the location service), or null.
  final double? speedKmh;

  /// Estimated GPS accuracy in metres, or null if not reported.
  final double? accuracyM;

  /// Heading in degrees clockwise from true north (0–360), or null.
  final double? headingDegrees;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// [LatLng] representation for map / polyline rendering.
  LatLng get latLng => LatLng(latitude, longitude);

  // ---------------------------------------------------------------------------
  // Factory — build from an in-memory [TrackPoint]
  // ---------------------------------------------------------------------------

  /// Creates a [TrackPointRecord] from a live [TrackPoint].
  ///
  /// [id] must be a pre-generated UUID v4.
  /// [tripId] must be the stable ID assigned at drive start.
  factory TrackPointRecord.fromTrackPoint({
    required String id,
    required String tripId,
    required TrackPoint point,
  }) {
    return TrackPointRecord(
      id: id,
      tripId: tripId,
      timestamp: point.timestamp,
      latitude: point.latitude,
      longitude: point.longitude,
      altitude: point.altitude,
      speedKmh: point.speedKmh,
      accuracyM: point.accuracyMeters,
      // TrackPoint does not carry heading — left null.
      headingDegrees: null,
    );
  }

  // ---------------------------------------------------------------------------
  // SQLite serialisation
  // ---------------------------------------------------------------------------

  /// Converts to a database row map (snake_case keys).
  Map<String, dynamic> toRow() => {
        'id': id,
        'trip_id': tripId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'speed_kmh': speedKmh,
        'accuracy_m': accuracyM,
        'heading_degrees': headingDegrees,
      };

  /// Constructs a [TrackPointRecord] from a database row map.
  factory TrackPointRecord.fromRow(Map<String, dynamic> row) {
    return TrackPointRecord(
      id: row['id'] as String,
      tripId: row['trip_id'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      altitude:
          row['altitude'] != null ? (row['altitude'] as num).toDouble() : null,
      speedKmh:
          row['speed_kmh'] != null ? (row['speed_kmh'] as num).toDouble() : null,
      accuracyM: row['accuracy_m'] != null
          ? (row['accuracy_m'] as num).toDouble()
          : null,
      headingDegrees: row['heading_degrees'] != null
          ? (row['heading_degrees'] as num).toDouble()
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & debug
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackPointRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TrackPointRecord(id: $id, tripId: $tripId, '
      'lat: $latitude, lng: $longitude, ts: $timestamp)';
}
