import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_config.dart';
import '../models/trip.dart';

// ---------------------------------------------------------------------------
// TripRepository
// ---------------------------------------------------------------------------

/// Data-access layer for the [kTripsTable] table.
///
/// All SQL is encapsulated here. No widget or Riverpod provider executes
/// raw SQL directly.
///
/// ## Testability
///
/// Accepts a raw [Database] connection so that unit tests can inject an
/// in-memory database without going through the [AppDatabase] singleton.
///
/// ## Ordering
///
/// All multi-row query methods return trips ordered by [start_time] DESC
/// (newest first) so the Trip History screen shows the most recent trip
/// at the top without additional sorting.
class TripRepository {
  const TripRepository(this._db);

  final Database _db;

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Persists a completed [trip] record.
  ///
  /// Called once at the end of [DriveNotifier.finishDrive()].
  /// Throws if a row with the same [trip.id] already exists.
  Future<void> createTrip(Trip trip) async {
    await _db.insert(
      kTripsTable,
      _tripToRow(trip),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns the trip with [id], or `null` if not found.
  Future<Trip?> getTripById(String id) async {
    final rows = await _db.query(
      kTripsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToTrip(rows.first);
  }

  /// Returns all trips ordered by [start_time] DESC (newest first).
  Future<List<Trip>> getAllTrips() async {
    final rows = await _db.query(
      kTripsTable,
      orderBy: 'start_time DESC',
    );
    return rows.map(_rowToTrip).toList();
  }

  /// Returns all trips for [vehicleId] ordered by [start_time] DESC.
  ///
  /// Returns an empty list if no trips exist for that vehicle.
  Future<List<Trip>> getTripsForVehicle(String vehicleId) async {
    final rows = await _db.query(
      kTripsTable,
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'start_time DESC',
    );
    return rows.map(_rowToTrip).toList();
  }

  /// Returns the [limit] most recent trips ordered by [start_time] DESC.
  ///
  /// Defaults to 20.
  Future<List<Trip>> getRecentTrips({int limit = 20}) async {
    final rows = await _db.query(
      kTripsTable,
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return rows.map(_rowToTrip).toList();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Deletes the trip with [id].
  ///
  /// Does nothing if no row with that ID exists.
  Future<void> deleteTrip(String id) async {
    await _db.delete(
      kTripsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Converts a database row (snake_case keys) to a [Trip].
  Trip _rowToTrip(Map<String, dynamic> row) {
    return Trip(
      id: row['id'] as String,
      vehicleId: row['vehicle_id'] as String?,
      mode: TripMode.fromValue(row['mode'] as String),
      startTime: DateTime.parse(row['start_time'] as String),
      endTime: DateTime.parse(row['end_time'] as String),
      durationSeconds: row['duration_seconds'] as int,
      distanceKm: (row['distance_km'] as num).toDouble(),
      startLatitude: (row['start_latitude'] as num).toDouble(),
      startLongitude: (row['start_longitude'] as num).toDouble(),
      startName: row['start_name'] as String?,
      destinationLatitude: row['destination_latitude'] != null
          ? (row['destination_latitude'] as num).toDouble()
          : null,
      destinationLongitude: row['destination_longitude'] != null
          ? (row['destination_longitude'] as num).toDouble()
          : null,
      destinationName: row['destination_name'] as String?,
      averageSpeedKmh: row['average_speed_kmh'] != null
          ? (row['average_speed_kmh'] as num).toDouble()
          : null,
      minimumSpeedKmh: row['minimum_speed_kmh'] != null
          ? (row['minimum_speed_kmh'] as num).toDouble()
          : null,
      maximumSpeedKmh: row['maximum_speed_kmh'] != null
          ? (row['maximum_speed_kmh'] as num).toDouble()
          : null,
      minimumAltitudeM: row['minimum_altitude_m'] != null
          ? (row['minimum_altitude_m'] as num).toDouble()
          : null,
      maximumAltitudeM: row['maximum_altitude_m'] != null
          ? (row['maximum_altitude_m'] as num).toDouble()
          : null,
      stops: row['stops'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Converts a [Trip] to a database row map (snake_case keys).
  Map<String, dynamic> _tripToRow(Trip trip) {
    return {
      'id': trip.id,
      'vehicle_id': trip.vehicleId,
      'mode': trip.mode.value,
      'start_time': trip.startTime.toUtc().toIso8601String(),
      'end_time': trip.endTime.toUtc().toIso8601String(),
      'duration_seconds': trip.durationSeconds,
      'distance_km': trip.distanceKm,
      'start_latitude': trip.startLatitude,
      'start_longitude': trip.startLongitude,
      'start_name': trip.startName,
      'destination_latitude': trip.destinationLatitude,
      'destination_longitude': trip.destinationLongitude,
      'destination_name': trip.destinationName,
      'average_speed_kmh': trip.averageSpeedKmh,
      'minimum_speed_kmh': trip.minimumSpeedKmh,
      'maximum_speed_kmh': trip.maximumSpeedKmh,
      'minimum_altitude_m': trip.minimumAltitudeM,
      'maximum_altitude_m': trip.maximumAltitudeM,
      'stops': trip.stops,
      'created_at': trip.createdAt.toUtc().toIso8601String(),
    };
  }
}
