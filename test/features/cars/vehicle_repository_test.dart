// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:triprank_project/core/database/database_config.dart';
import 'package:triprank_project/features/cars/data/vehicle_repository.dart';
import 'package:triprank_project/features/cars/models/vehicle.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Creates a fresh in-memory database with the full v2 schema.
///
/// Each test gets its own independent database — no singleton bleed.
Future<Database> _openTestDb() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kDatabaseVersion,
      singleInstance: false,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kMetadataTable (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kVehiclesTable (
            id          TEXT    PRIMARY KEY,
            brand       TEXT    NOT NULL,
            model       TEXT    NOT NULL,
            year        INTEGER NOT NULL,
            type        TEXT    NOT NULL,
            created_at  TEXT    NOT NULL,
            updated_at  TEXT    NOT NULL
          )
        ''');
      },
    ),
  );
}

/// Builds a [VehicleRepository] backed by a fresh in-memory database.
Future<({VehicleRepository repo, Database db})> _openRepo() async {
  final db = await _openTestDb();
  return (repo: VehicleRepository(db), db: db);
}

/// Builds a test [Vehicle] with sensible defaults.
Vehicle _makeVehicle({
  String id = 'v1',
  String brand = 'Toyota',
  String model = 'Corolla',
  int year = 2020,
  VehicleType type = VehicleType.sedan,
}) {
  return Vehicle(
    id: id,
    brand: brand,
    model: model,
    year: year,
    type: type,
    createdAt: DateTime(2024, 1, 1),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_initFfi);

  // ── Test 1: Create vehicle ─────────────────────────────────────────────────

  test('1. Create vehicle inserts a row', () async {
    final (:repo, :db) = await _openRepo();

    final vehicle = _makeVehicle();
    await repo.create(vehicle);

    final rows = await db.query(kVehiclesTable);
    expect(rows.length, 1);
    expect(rows.first['id'], vehicle.id);
    expect(rows.first['brand'], vehicle.brand);
    expect(rows.first['model'], vehicle.model);
    expect(rows.first['year'], vehicle.year);
    expect(rows.first['type'], vehicle.type.value);

    await db.close();
  });

  // ── Test 2: Retrieve vehicle by ID ─────────────────────────────────────────

  test('2. getById returns the correct vehicle', () async {
    final (:repo, :db) = await _openRepo();

    final vehicle = _makeVehicle(id: 'abc', brand: 'Honda', model: 'Civic');
    await repo.create(vehicle);

    final found = await repo.getById('abc');
    expect(found, isNotNull);
    expect(found!.id, 'abc');
    expect(found.brand, 'Honda');
    expect(found.model, 'Civic');

    await db.close();
  });

  // ── Test 3: Retrieve all vehicles ──────────────────────────────────────────

  test('3. getAll returns all vehicles ordered by created_at', () async {
    final (:repo, :db) = await _openRepo();

    final v1 = Vehicle(
      id: 'v1',
      brand: 'Toyota',
      model: 'Corolla',
      year: 2020,
      type: VehicleType.sedan,
      createdAt: DateTime(2024, 1, 1),
    );
    final v2 = Vehicle(
      id: 'v2',
      brand: 'Honda',
      model: 'Civic',
      year: 2021,
      type: VehicleType.hatchback,
      createdAt: DateTime(2024, 2, 1),
    );

    await repo.create(v1);
    await repo.create(v2);

    final all = await repo.getAll();
    expect(all.length, 2);
    // Ordered by created_at ASC — v1 first.
    expect(all.first.id, 'v1');
    expect(all.last.id, 'v2');

    await db.close();
  });

  // ── Test 4: Update vehicle ─────────────────────────────────────────────────

  test('4. update modifies an existing vehicle row', () async {
    final (:repo, :db) = await _openRepo();

    final original = _makeVehicle(brand: 'Toyota', model: 'Corolla');
    await repo.create(original);

    final updated = original.copyWith(brand: 'Ford', model: 'Focus');
    await repo.update(updated);

    final found = await repo.getById(original.id);
    expect(found, isNotNull);
    expect(found!.brand, 'Ford');
    expect(found.model, 'Focus');
    // Other fields unchanged.
    expect(found.year, original.year);
    expect(found.type, original.type);

    await db.close();
  });

  // ── Test 5: Delete vehicle ─────────────────────────────────────────────────

  test('5. delete removes the vehicle row', () async {
    final (:repo, :db) = await _openRepo();

    await repo.create(_makeVehicle(id: 'del1'));
    await repo.create(
        _makeVehicle(id: 'del2', brand: 'BMW', model: '3 Series'));

    await repo.delete('del1');

    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.first.id, 'del2');

    final gone = await repo.getById('del1');
    expect(gone, isNull);

    await db.close();
  });

  // ── Test 6: Selected vehicle persistence ──────────────────────────────────

  test('6. setSelectedVehicleId persists and getSelectedVehicleId retrieves',
      () async {
    final (:repo, :db) = await _openRepo();

    // Nothing selected initially.
    expect(await repo.getSelectedVehicleId(), isNull);

    await repo.create(_makeVehicle(id: 'sel1'));
    await repo.setSelectedVehicleId('sel1');

    expect(await repo.getSelectedVehicleId(), 'sel1');

    await db.close();
  });

  // ── Test 7: Clear selected vehicle ────────────────────────────────────────

  test('7. clearSelectedVehicle removes the selection', () async {
    final (:repo, :db) = await _openRepo();

    await repo.create(_makeVehicle(id: 'clear1'));
    await repo.setSelectedVehicleId('clear1');
    expect(await repo.getSelectedVehicleId(), 'clear1');

    await repo.clearSelectedVehicle();
    expect(await repo.getSelectedVehicleId(), isNull);

    await db.close();
  });

  // ── Test 8: Delete selected vehicle clears selection ──────────────────────

  test('8. deleting the selected vehicle automatically clears the selection',
      () async {
    final (:repo, :db) = await _openRepo();

    await repo.create(_makeVehicle(id: 'autosel'));
    await repo.setSelectedVehicleId('autosel');
    expect(await repo.getSelectedVehicleId(), 'autosel');

    // Delete the selected vehicle.
    await repo.delete('autosel');

    // Selection must be cleared.
    expect(await repo.getSelectedVehicleId(), isNull);

    await db.close();
  });

  // ── Test 9: Multiple vehicles can coexist ─────────────────────────────────

  test('9. multiple vehicles coexist without collisions', () async {
    final (:repo, :db) = await _openRepo();

    final types = VehicleType.values;
    for (var i = 0; i < types.length; i++) {
      await repo.create(Vehicle(
        id: 'multi$i',
        brand: 'Brand$i',
        model: 'Model$i',
        year: 2000 + i,
        type: types[i],
        createdAt: DateTime(2024, 1, i + 1),
      ));
    }

    final all = await repo.getAll();
    expect(all.length, types.length);

    // Spot-check round-trip fidelity.
    expect(all.last.type, types.last);
    expect(all.last.brand, 'Brand${types.length - 1}');

    await db.close();
  });

  // ── Test 10: Vehicles survive DB close/reopen ──────────────────────────────
  //
  // Uses a named file path in the sqflite_common_ffi databases directory so
  // data survives a close + reopen cycle within the same test.

  test('10. vehicles survive database close and reopen', () async {
    // Use a distinct name so it never collides with the singleton's triprank.db.
    final baseDir = await databaseFactoryFfi.getDatabasesPath();
    final namedPath = p.join(baseDir, 'persist_test.db');

    // Ensure clean state.
    await databaseFactoryFfi.deleteDatabase(namedPath);

    Future<Database> open() => databaseFactoryFfi.openDatabase(
          namedPath,
          options: OpenDatabaseOptions(
            version: kDatabaseVersion,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE IF NOT EXISTS $kMetadataTable (
                  key   TEXT PRIMARY KEY,
                  value TEXT NOT NULL
                )
              ''');
              await db.execute('''
                CREATE TABLE IF NOT EXISTS $kVehiclesTable (
                  id          TEXT    PRIMARY KEY,
                  brand       TEXT    NOT NULL,
                  model       TEXT    NOT NULL,
                  year        INTEGER NOT NULL,
                  type        TEXT    NOT NULL,
                  created_at  TEXT    NOT NULL,
                  updated_at  TEXT    NOT NULL
                )
              ''');
            },
          ),
        );

    // Open, insert, close.
    final db1 = await open();
    final repo1 = VehicleRepository(db1);
    await repo1.create(_makeVehicle(id: 'persist1', brand: 'Persist'));
    await repo1.setSelectedVehicleId('persist1');
    await db1.close();

    // Reopen on the same named path, verify data is still there.
    final db2 = await open();
    final repo2 = VehicleRepository(db2);
    final all = await repo2.getAll();
    expect(all.length, 1);
    expect(all.first.id, 'persist1');
    expect(all.first.brand, 'Persist');

    final selectedId = await repo2.getSelectedVehicleId();
    expect(selectedId, 'persist1');

    await db2.close();
    await databaseFactoryFfi.deleteDatabase(namedPath);
  });

  // ── Test 11: Migration v1 → v2 creates the vehicles table ─────────────────

  test('11. migration from version 1 to version 2 creates vehicles table',
      () async {
    // Step A: Open a v1 database (only db_metadata, no vehicles table).
    final v1Db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $kMetadataTable (
              key   TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await db.insert(kMetadataTable, {
            'key': kMetaKeySchemaVersion,
            'value': '1',
          });
        },
      ),
    );

    final v1Tables = await v1Db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$kVehiclesTable'",
    );
    expect(v1Tables, isEmpty, reason: 'v1 must not have vehicles table');
    await v1Db.close();

    // Step B: Simulate migration to v2 via onUpgrade.
    final v2Db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          // Fresh install — create both tables.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $kMetadataTable (
              key   TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $kVehiclesTable (
              id          TEXT    PRIMARY KEY,
              brand       TEXT    NOT NULL,
              model       TEXT    NOT NULL,
              year        INTEGER NOT NULL,
              type        TEXT    NOT NULL,
              created_at  TEXT    NOT NULL,
              updated_at  TEXT    NOT NULL
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (var v = oldVersion + 1; v <= newVersion; v++) {
            if (v == 2) {
              // The migration that AppDatabase._migrate runs for case 2.
              await db.execute('''
                CREATE TABLE IF NOT EXISTS $kVehiclesTable (
                  id          TEXT    PRIMARY KEY,
                  brand       TEXT    NOT NULL,
                  model       TEXT    NOT NULL,
                  year        INTEGER NOT NULL,
                  type        TEXT    NOT NULL,
                  created_at  TEXT    NOT NULL,
                  updated_at  TEXT    NOT NULL
                )
              ''');
            }
          }
        },
      ),
    );

    // vehicles table must exist.
    final v2Tables = await v2Db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$kVehiclesTable'",
    );
    expect(v2Tables.length, 1);
    expect(v2Tables.first['name'], kVehiclesTable);

    // Verify the column schema.
    final columns = await v2Db.rawQuery('PRAGMA table_info($kVehiclesTable)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();
    expect(
      columnNames,
      containsAll([
        'id',
        'brand',
        'model',
        'year',
        'type',
        'created_at',
        'updated_at',
      ]),
    );

    // The repository must be usable against the migrated schema.
    final repo = VehicleRepository(v2Db);
    await repo.create(_makeVehicle(id: 'migrated'));
    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.first.id, 'migrated');

    await v2Db.close();
  });
}
