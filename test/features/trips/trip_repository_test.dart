// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:triprank_project/core/database/database_config.dart';
import 'package:triprank_project/features/cars/data/vehicle_repository.dart';
import 'package:triprank_project/features/cars/models/vehicle.dart';
import 'package:triprank_project/features/trips/data/trip_repository.dart';
import 'package:triprank_project/features/trips/models/trip.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Creates a fresh in-memory database with the full v3 schema (all 3 tables).
Future<Database> _openTestDb() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kDatabaseVersion,
      singleInstance: false,
      onConfigure: (db) async {
        // Enable foreign key enforcement so ON DELETE SET NULL works.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // db_metadata
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kMetadataTable (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        // vehicles
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
        // trips
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kTripsTable (
            id                      TEXT    PRIMARY KEY,
            vehicle_id              TEXT    REFERENCES $kVehiclesTable(id) ON DELETE SET NULL,
            mode                    TEXT    NOT NULL,
            start_time              TEXT    NOT NULL,
            end_time                TEXT    NOT NULL,
            duration_seconds        INTEGER NOT NULL,
            distance_km             REAL    NOT NULL,
            start_latitude          REAL    NOT NULL,
            start_longitude         REAL    NOT NULL,
            start_name              TEXT,
            destination_latitude    REAL,
            destination_longitude   REAL,
            destination_name        TEXT,
            average_speed_kmh       REAL,
            minimum_speed_kmh       REAL,
            maximum_speed_kmh       REAL,
            minimum_altitude_m      REAL,
            maximum_altitude_m      REAL,
            stops                   INTEGER,
            created_at              TEXT    NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_trips_vehicle_id ON $kTripsTable (vehicle_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_trips_start_time ON $kTripsTable (start_time DESC)');
      },
    ),
  );
}

Future<({TripRepository repo, Database db})> _openRepo() async {
  final db = await _openTestDb();
  return (repo: TripRepository(db), db: db);
}

final _t0 = DateTime.utc(2024, 6, 1, 8, 0);
final _t1 = DateTime.utc(2024, 6, 1, 8, 30);

/// Returns a minimal valid [Trip].
Trip _makeTrip({
  String id = 't1',
  String? vehicleId,          // null by default — no FK required
  TripMode mode = TripMode.reckless,
  DateTime? startTime,
  DateTime? endTime,
  int durationSeconds = 1800,
  double distanceKm = 12.5,
  double startLat = 33.888,
  double startLng = 35.495,
  String? startName,
  double? destLat,
  double? destLng,
  String? destName,
  double? avgSpeed,
  double? minSpeed,
  double? maxSpeed,
  double? minAlt,
  double? maxAlt,
  int? stops,
}) {
  return Trip(
    id: id,
    vehicleId: vehicleId,
    mode: mode,
    startTime: startTime ?? _t0,
    endTime: endTime ?? _t1,
    durationSeconds: durationSeconds,
    distanceKm: distanceKm,
    startLatitude: startLat,
    startLongitude: startLng,
    startName: startName,
    destinationLatitude: destLat,
    destinationLongitude: destLng,
    destinationName: destName,
    averageSpeedKmh: avgSpeed,
    minimumSpeedKmh: minSpeed,
    maximumSpeedKmh: maxSpeed,
    minimumAltitudeM: minAlt,
    maximumAltitudeM: maxAlt,
    stops: stops,
    createdAt: DateTime.utc(2024, 6, 1),
  );
}

Vehicle _makeVehicle(String id) => Vehicle(
      id: id,
      brand: 'Toyota',
      model: 'Corolla',
      year: 2020,
      type: VehicleType.sedan,
      createdAt: DateTime.utc(2024, 1, 1),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_initFfi);

  // ── Test 1: Create a trip ──────────────────────────────────────────────────

  test('1. createTrip inserts a row', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip());

    final rows = await db.query(kTripsTable);
    expect(rows.length, 1);
    expect(rows.first['id'], 't1');

    await db.close();
  });

  // ── Test 2: Retrieve a trip by ID ─────────────────────────────────────────

  test('2. getTripById returns the correct trip', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(id: 'abc'));

    final found = await repo.getTripById('abc');
    expect(found, isNotNull);
    expect(found!.id, 'abc');

    await db.close();
  });

  // ── Test 3: Retrieve all trips ─────────────────────────────────────────────

  test('3. getAllTrips returns all trips', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(id: 't1'));
    await repo.createTrip(_makeTrip(
      id: 't2',
      startTime: _t0.add(const Duration(hours: 1)),
      endTime: _t0.add(const Duration(hours: 2)),
    ));

    final all = await repo.getAllTrips();
    expect(all.length, 2);

    await db.close();
  });

  // ── Test 4: Retrieve trips for a vehicle ──────────────────────────────────

  test('4. getTripsForVehicle returns only that vehicle\'s trips', () async {
    final (:repo, :db) = await _openRepo();
    final vehicleRepo = VehicleRepository(db);

    // Must insert vehicles first — FK enforcement is on.
    await vehicleRepo.create(_makeVehicle('v1'));
    await vehicleRepo.create(_makeVehicle('v2'));

    await repo.createTrip(_makeTrip(id: 't1', vehicleId: 'v1'));
    await repo.createTrip(_makeTrip(
      id: 't2',
      vehicleId: 'v2',
      startTime: _t0.add(const Duration(hours: 1)),
      endTime: _t0.add(const Duration(hours: 2)),
    ));
    await repo.createTrip(_makeTrip(
      id: 't3',
      vehicleId: 'v1',
      startTime: _t0.add(const Duration(hours: 2)),
      endTime: _t0.add(const Duration(hours: 3)),
    ));

    final v1trips = await repo.getTripsForVehicle('v1');
    expect(v1trips.length, 2);
    expect(v1trips.every((t) => t.vehicleId == 'v1'), isTrue);

    await db.close();
  });

  // ── Test 5: Newest trips appear first ─────────────────────────────────────

  test('5. getAllTrips returns trips newest first', () async {
    final (:repo, :db) = await _openRepo();

    final older = _makeTrip(
      id: 'older',
      startTime: _t0,
      endTime: _t0.add(const Duration(hours: 1)),
    );
    final newer = _makeTrip(
      id: 'newer',
      startTime: _t0.add(const Duration(hours: 2)),
      endTime: _t0.add(const Duration(hours: 3)),
    );

    // Insert older first, then newer.
    await repo.createTrip(older);
    await repo.createTrip(newer);

    final all = await repo.getAllTrips();
    expect(all.first.id, 'newer');
    expect(all.last.id, 'older');

    await db.close();
  });

  // ── Test 6: Trip mode persists correctly ──────────────────────────────────

  test('6. trip mode (reckless / destination) round-trips correctly', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(id: 'r', mode: TripMode.reckless));
    await repo.createTrip(_makeTrip(
      id: 'd',
      mode: TripMode.destination,
      startTime: _t0.add(const Duration(hours: 1)),
      endTime: _t0.add(const Duration(hours: 2)),
    ));

    final r = await repo.getTripById('r');
    final d = await repo.getTripById('d');

    expect(r!.mode, TripMode.reckless);
    expect(d!.mode, TripMode.destination);

    await db.close();
  });

  // ── Test 7: Start/end timestamps persist correctly ────────────────────────

  test('7. start and end timestamps round-trip as UTC', () async {
    final (:repo, :db) = await _openRepo();

    final start = DateTime.utc(2024, 3, 15, 9, 30);
    final end = DateTime.utc(2024, 3, 15, 10, 15);

    await repo.createTrip(
        _makeTrip(startTime: start, endTime: end));

    final found = await repo.getTripById('t1');
    expect(found!.startTime.toUtc(), equals(start));
    expect(found.endTime.toUtc(), equals(end));

    await db.close();
  });

  // ── Test 8: Duration persists correctly ───────────────────────────────────

  test('8. durationSeconds round-trips correctly', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(durationSeconds: 3661));

    final found = await repo.getTripById('t1');
    expect(found!.durationSeconds, 3661);

    await db.close();
  });

  // ── Test 9: Distance persists correctly ───────────────────────────────────

  test('9. distanceKm round-trips correctly', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(distanceKm: 47.321));

    final found = await repo.getTripById('t1');
    expect(found!.distanceKm, closeTo(47.321, 0.001));

    await db.close();
  });

  // ── Test 10: Start coordinates persist correctly ──────────────────────────

  test('10. start coordinates round-trip correctly', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(
        _makeTrip(startLat: 33.8882, startLng: 35.4955));

    final found = await repo.getTripById('t1');
    expect(found!.startLatitude, closeTo(33.8882, 0.0001));
    expect(found.startLongitude, closeTo(35.4955, 0.0001));

    await db.close();
  });

  // ── Test 11: Start name persists correctly ────────────────────────────────

  test('11. startName (nullable) round-trips correctly', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(id: 'with_name', startName: 'Beirut'));
    await repo.createTrip(_makeTrip(
      id: 'no_name',
      startTime: _t0.add(const Duration(hours: 1)),
      endTime: _t0.add(const Duration(hours: 2)),
    ));

    final withName = await repo.getTripById('with_name');
    final noName = await repo.getTripById('no_name');

    expect(withName!.startName, 'Beirut');
    expect(noName!.startName, isNull);

    await db.close();
  });

  // ── Test 12: Destination coordinates persist correctly ────────────────────

  test('12. destination coordinates round-trip correctly', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(
      destLat: 34.0,
      destLng: 35.65,
    ));

    final found = await repo.getTripById('t1');
    expect(found!.destinationLatitude, closeTo(34.0, 0.0001));
    expect(found.destinationLongitude, closeTo(35.65, 0.0001));

    await db.close();
  });

  // ── Test 13: Destination name persists correctly ──────────────────────────

  test('13. destinationName round-trips correctly', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(destName: 'Jounieh'));

    final found = await repo.getTripById('t1');
    expect(found!.destinationName, 'Jounieh');

    await db.close();
  });

  // ── Test 14: Reckless trips can have null destination fields ──────────────

  test('14. reckless trip stores null destination fields', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(mode: TripMode.reckless));

    final found = await repo.getTripById('t1');
    expect(found!.destinationLatitude, isNull);
    expect(found.destinationLongitude, isNull);
    expect(found.destinationName, isNull);

    await db.close();
  });

  // ── Test 15: Summary statistics persist correctly ─────────────────────────

  test('15. summary statistics round-trip correctly', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(
      avgSpeed: 65.4,
      minSpeed: 0.0,
      maxSpeed: 120.5,
      minAlt: 50.0,
      maxAlt: 320.0,
    ));

    final found = await repo.getTripById('t1');
    expect(found!.averageSpeedKmh, closeTo(65.4, 0.01));
    expect(found.minimumSpeedKmh, closeTo(0.0, 0.01));
    expect(found.maximumSpeedKmh, closeTo(120.5, 0.01));
    expect(found.minimumAltitudeM, closeTo(50.0, 0.01));
    expect(found.maximumAltitudeM, closeTo(320.0, 0.01));

    await db.close();
  });

  // ── Test 16: Multiple trips can reference the same vehicle ────────────────

  test('16. multiple trips can reference the same vehicle', () async {
    final (:repo, :db) = await _openRepo();
    final vehicleRepo = VehicleRepository(db);

    // Must insert vehicle first — FK enforcement is on.
    await vehicleRepo.create(_makeVehicle('shared_vehicle'));

    for (var i = 0; i < 5; i++) {
      await repo.createTrip(_makeTrip(
        id: 'trip$i',
        vehicleId: 'shared_vehicle',
        startTime: _t0.add(Duration(hours: i)),
        endTime: _t0.add(Duration(hours: i, minutes: 30)),
      ));
    }

    final trips = await repo.getTripsForVehicle('shared_vehicle');
    expect(trips.length, 5);
    expect(trips.every((t) => t.vehicleId == 'shared_vehicle'), isTrue);

    await db.close();
  });

  // ── Test 17: Trips survive database close/reopen ──────────────────────────

  test('17. trips survive database close and reopen', () async {
    final baseDir = await databaseFactoryFfi.getDatabasesPath();
    final namedPath = p.join(baseDir, 'trip_persist_test.db');
    await databaseFactoryFfi.deleteDatabase(namedPath);

    Future<Database> open() => databaseFactoryFfi.openDatabase(
          namedPath,
          options: OpenDatabaseOptions(
            version: kDatabaseVersion,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE IF NOT EXISTS $kMetadataTable (
                  key TEXT PRIMARY KEY, value TEXT NOT NULL
                )
              ''');
              await db.execute('''
                CREATE TABLE IF NOT EXISTS $kVehiclesTable (
                  id TEXT PRIMARY KEY, brand TEXT NOT NULL,
                  model TEXT NOT NULL, year INTEGER NOT NULL,
                  type TEXT NOT NULL, created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                )
              ''');
              await db.execute('''
                CREATE TABLE IF NOT EXISTS $kTripsTable (
                  id TEXT PRIMARY KEY,
                  vehicle_id TEXT REFERENCES $kVehiclesTable(id) ON DELETE SET NULL,
                  mode TEXT NOT NULL, start_time TEXT NOT NULL,
                  end_time TEXT NOT NULL, duration_seconds INTEGER NOT NULL,
                  distance_km REAL NOT NULL, start_latitude REAL NOT NULL,
                  start_longitude REAL NOT NULL, start_name TEXT,
                  destination_latitude REAL, destination_longitude REAL,
                  destination_name TEXT, average_speed_kmh REAL,
                  minimum_speed_kmh REAL, maximum_speed_kmh REAL,
                  minimum_altitude_m REAL, maximum_altitude_m REAL,
                  stops INTEGER, created_at TEXT NOT NULL
                )
              ''');
            },
          ),
        );

    // Insert, close.
    final db1 = await open();
    await TripRepository(db1).createTrip(_makeTrip(id: 'persist1'));
    await db1.close();

    // Reopen, verify.
    final db2 = await open();
    final found = await TripRepository(db2).getTripById('persist1');
    expect(found, isNotNull);
    expect(found!.id, 'persist1');
    await db2.close();

    await databaseFactoryFfi.deleteDatabase(namedPath);
  });

  // ── Test 18: v2 → v3 migration preserves existing vehicles ───────────────

  test('18. v2→v3 migration creates trips table without touching vehicles',
      () async {
    // Simulate a v2 database with a vehicle row.
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $kMetadataTable (
              key TEXT PRIMARY KEY, value TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $kVehiclesTable (
              id TEXT PRIMARY KEY, brand TEXT NOT NULL,
              model TEXT NOT NULL, year INTEGER NOT NULL,
              type TEXT NOT NULL, created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          // Seed a vehicle.
          await db.insert(kVehiclesTable, {
            'id': 'existing_v',
            'brand': 'Honda',
            'model': 'Civic',
            'year': 2021,
            'type': 'sedan',
            'created_at': '2024-01-01T00:00:00.000Z',
            'updated_at': '2024-01-01T00:00:00.000Z',
          });
        },
      ),
    );

    // Manually apply the v3 migration (what _migrate case 3 does).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kTripsTable (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT REFERENCES $kVehiclesTable(id) ON DELETE SET NULL,
        mode TEXT NOT NULL, start_time TEXT NOT NULL,
        end_time TEXT NOT NULL, duration_seconds INTEGER NOT NULL,
        distance_km REAL NOT NULL, start_latitude REAL NOT NULL,
        start_longitude REAL NOT NULL, start_name TEXT,
        destination_latitude REAL, destination_longitude REAL,
        destination_name TEXT, average_speed_kmh REAL,
        minimum_speed_kmh REAL, maximum_speed_kmh REAL,
        minimum_altitude_m REAL, maximum_altitude_m REAL,
        stops INTEGER, created_at TEXT NOT NULL
      )
    ''');

    // Vehicles must still exist.
    final vehicles = await VehicleRepository(db).getAll();
    expect(vehicles.length, 1);
    expect(vehicles.first.id, 'existing_v');

    // Trips table must now exist.
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$kTripsTable'",
    );
    expect(tables.length, 1);

    await db.close();
  });

  // ── Test 19: Deleting a vehicle does NOT delete its historical trips ───────

  test('19. deleting a vehicle does NOT delete its historical trips', () async {
    final (:repo, :db) = await _openRepo();
    final vehicleRepo = VehicleRepository(db);

    // Create a vehicle.
    final v = _makeVehicle('del_v');
    await vehicleRepo.create(v);

    // Create a trip linked to it.
    await repo.createTrip(_makeTrip(id: 'linked_trip', vehicleId: 'del_v'));

    // Verify trip is linked.
    final before = await repo.getTripById('linked_trip');
    expect(before!.vehicleId, 'del_v');

    // Delete the vehicle.
    await vehicleRepo.delete('del_v');

    // Trip must still exist.
    final after = await repo.getTripById('linked_trip');
    expect(after, isNotNull, reason: 'Trip must survive vehicle deletion');

    await db.close();
  });

  // ── Test 20: Historical trip accessible after vehicle deletion ────────────

  test('20. vehicle_id is NULL on trip after vehicle is deleted', () async {
    final (:repo, :db) = await _openRepo();
    final vehicleRepo = VehicleRepository(db);

    await vehicleRepo.create(_makeVehicle('v_del'));
    await repo.createTrip(_makeTrip(id: 'orphan', vehicleId: 'v_del'));

    await vehicleRepo.delete('v_del');

    final trip = await repo.getTripById('orphan');
    expect(trip, isNotNull);
    // ON DELETE SET NULL — vehicleId becomes null after vehicle is deleted.
    expect(trip!.vehicleId, isNull);

    await db.close();
  });

  // ── Test 21: Deleting a trip removes only that trip ───────────────────────

  test('21. deleteTrip removes only the specified trip', () async {
    final (:repo, :db) = await _openRepo();

    await repo.createTrip(_makeTrip(id: 'keep'));
    await repo.createTrip(_makeTrip(
      id: 'remove',
      startTime: _t0.add(const Duration(hours: 1)),
      endTime: _t0.add(const Duration(hours: 2)),
    ));

    await repo.deleteTrip('remove');

    final all = await repo.getAllTrips();
    expect(all.length, 1);
    expect(all.first.id, 'keep');

    final gone = await repo.getTripById('remove');
    expect(gone, isNull);

    await db.close();
  });
}
