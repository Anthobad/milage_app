import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_config.dart';
import '../models/vehicle.dart';

// ---------------------------------------------------------------------------
// VehicleRepository
// ---------------------------------------------------------------------------

/// Data-access layer for the [kVehiclesTable] table and the selected-vehicle
/// entry in [kMetadataTable].
///
/// All SQL is encapsulated here.  No widget or Riverpod provider executes
/// raw SQL directly.
///
/// ## Selected vehicle persistence
///
/// The selected vehicle ID is stored as a row in [kMetadataTable] under the
/// key [kMetaKeySelectedVehicleId].  Using the metadata table keeps the
/// selection decoupled from the vehicles rows — there is always exactly one
/// authoritative source and no flag needs to be updated across multiple rows.
///
/// ## Testability
///
/// The constructor accepts a raw [Database] connection so that unit tests can
/// inject an in-memory database without going through the [AppDatabase]
/// singleton.  In production the [vehicleRepositoryProvider] supplies the
/// connection from [AppDatabase.instance.database].
///
/// ## Thread safety
///
/// sqflite serialises writes on its internal queue so concurrent calls are
/// safe without additional locking.
class VehicleRepository {
  const VehicleRepository(this._db);

  final Database _db;

  // ── Vehicle CRUD ────────────────────────────────────────────────────────────

  /// Returns all vehicles ordered by [created_at] ascending (oldest first).
  Future<List<Vehicle>> getAll() async {
    final rows = await _db.query(
      kVehiclesTable,
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToVehicle).toList();
  }

  /// Returns the vehicle with [id], or `null` if not found.
  Future<Vehicle?> getById(String id) async {
    final rows = await _db.query(
      kVehiclesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToVehicle(rows.first);
  }

  /// Inserts [vehicle] into the database.
  ///
  /// Throws if a vehicle with the same ID already exists.
  Future<void> create(Vehicle vehicle) async {
    await _db.insert(
      kVehiclesTable,
      _vehicleToRow(vehicle),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Updates the row for [vehicle] in place.
  ///
  /// Sets [updated_at] to the current time.
  /// Does nothing if no row with that ID exists.
  Future<void> update(Vehicle vehicle) async {
    final row = _vehicleToRow(vehicle);
    // Always refresh updated_at on edit.
    row['updated_at'] = DateTime.now().toIso8601String();

    await _db.update(
      kVehiclesTable,
      row,
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  /// Deletes the vehicle with [id].
  ///
  /// Also clears the selected vehicle if it matches [id] so no dangling
  /// reference remains in the metadata table.
  Future<void> delete(String id) async {
    await _db.delete(
      kVehiclesTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    // Clear selection if the deleted vehicle was selected.
    final selectedId = await getSelectedVehicleId();
    if (selectedId == id) {
      await clearSelectedVehicle();
    }
  }

  // ── Selected vehicle persistence ───────────────────────────────────────────

  /// Returns the ID of the selected vehicle, or `null` if none is stored.
  Future<String?> getSelectedVehicleId() async {
    final rows = await _db.query(
      kMetadataTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [kMetaKeySelectedVehicleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    // Treat empty string as "no selection" (defensive).
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Persists [vehicleId] as the selected vehicle.
  ///
  /// Uses REPLACE so the row is created on first call and updated thereafter.
  Future<void> setSelectedVehicleId(String vehicleId) async {
    await _db.insert(
      kMetadataTable,
      {
        'key': kMetaKeySelectedVehicleId,
        'value': vehicleId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes the selected vehicle entry from the metadata table.
  Future<void> clearSelectedVehicle() async {
    await _db.delete(
      kMetadataTable,
      where: 'key = ?',
      whereArgs: [kMetaKeySelectedVehicleId],
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Converts a database row (snake_case keys) to a [Vehicle].
  Vehicle _rowToVehicle(Map<String, dynamic> row) {
    return Vehicle(
      id: row['id'] as String,
      brand: row['brand'] as String,
      model: row['model'] as String,
      year: row['year'] as int,
      type: VehicleType.fromValue(row['type'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Converts a [Vehicle] to a database row map (snake_case keys).
  Map<String, dynamic> _vehicleToRow(Vehicle vehicle) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': vehicle.id,
      'brand': vehicle.brand,
      'model': vehicle.model,
      'year': vehicle.year,
      'type': vehicle.type.value,
      'created_at': vehicle.createdAt.toIso8601String(),
      'updated_at': now,
    };
  }
}
