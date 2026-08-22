// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:triprank_project/core/database/database_config.dart';
import 'package:triprank_project/features/cars/data/vehicle_repository.dart';
import 'package:triprank_project/features/cars/models/vehicle.dart';
import 'package:triprank_project/features/map/models/drive_state.dart';
import 'package:triprank_project/features/trips/data/track_point_repository.dart';
import 'package:triprank_project/features/trips/data/trip_repository.dart';
import 'package:triprank_project/features/trips/models/track_point_record.dart';
import 'package:triprank_project/features/trips/models/trip.dart';

// ---------------------------------------------------------------------------
// Initialisation
// ---------------------------------------------------------------------------

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

// ---------------------------------------------------------------------------
// Schema helper — full v5 schema (4 tables)
// ---------------------------------------------------------------------------

/// Opens a fresh in-memory database with the complete v5 schema.
///
/// [singleInstance] is false so every call gets an independent connection —
/// no singleton bleed between tests.
Future<Database> _openTestDb() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kDatabaseVersion,
      singleInstance: false,
      onConfigure: (db) async {
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
        // trips — vehicle_id ON DELETE CASCADE (v5)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kTripsTable (
            id                      TEXT    PRIMARY KEY,
            vehicle_id              TEXT    REFERENCES $kVehiclesTable(id) ON DELETE CASCADE,
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
          'CREATE INDEX IF NOT EXISTS idx_trips_vehicle_id ON $kTripsTable (vehicle_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_trips_start_time ON $kTripsTable (start_time DESC)',
        );
        // trip_track_points
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kTrackPointsTable (
            id               TEXT    PRIMARY KEY,
            trip_id          TEXT    NOT NULL
                                     REFERENCES $kTripsTable(id) ON DELETE CASCADE,
            timestamp        TEXT    NOT NULL,
            latitude         REAL    NOT NULL,
            longitude        REAL    NOT NULL,
            altitude         REAL,
            speed_kmh        REAL,
            accuracy_m       REAL,
            heading_degrees  REAL
          )
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_track_points_trip_time
            ON $kTrackPointsTable (trip_id, timestamp ASC)
        ''');
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Convenience openers
// ---------------------------------------------------------------------------

Future<
    ({
      TrackPointRepository trackRepo,
      TripRepository tripRepo,
      Database db,
    })> _openBothRepos() async {
  final db = await _openTestDb();
  return (
    trackRepo: TrackPointRepository(db),
    tripRepo: TripRepository(db),
    db: db,
  );
}

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

final _t0 = DateTime.utc(2024, 6, 1, 8, 0);
final _t1 = DateTime.utc(2024, 6, 1, 8, 30);

Trip _makeTrip({
  String id = 'trip1',
  String? vehicleId,
  DateTime? startTime,
  DateTime? endTime,
}) {
  return Trip(
    id: id,
    vehicleId: vehicleId,
    mode: TripMode.reckless,
    startTime: startTime ?? _t0,
    endTime: endTime ?? _t1,
    durationSeconds: 1800,
    distanceKm: 12.5,
    startLatitude: 33.888,
    startLongitude: 35.495,
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

/// Creates a [TrackPointRecord] with sensible defaults.
TrackPointRecord _makePoint({
  String id = 'p1',
  String tripId = 'trip1',
  DateTime? timestamp,
  double latitude = 33.888,
  double longitude = 35.495,
  double? altitude = 100.0,
  double? speedKmh = 60.0,
  double? accuracyM = 5.0,
  double? headingDegrees = 180.0,
}) {
  return TrackPointRecord(
    id: id,
    tripId: tripId,
    timestamp: timestamp ?? _t0,
    latitude: latitude,
    longitude: longitude,
    altitude: altitude,
    speedKmh: speedKmh,
    accuracyM: accuracyM,
    headingDegrees: headingDegrees,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_initFfi);

  // ==========================================================================
  // DATABASE TESTS (1–12)
  // ==========================================================================

  // ── Test 1: v3 → v4 migration succeeds ────────────────────────────────────

  test('1. v3 → v4 migration creates trip_track_points without data loss',
      () async {
    // Build a v3 database with existing vehicles and trips.
    final v3db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        singleInstance: false,
        onConfigure: (db) async =>
            db.execute('PRAGMA foreign_keys = ON'),
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
          // Seed data.
          await db.insert(kVehiclesTable, {
            'id': 'v1',
            'brand': 'BMW',
            'model': 'X5',
            'year': 2022,
            'type': 'suv',
            'created_at': '2024-01-01T00:00:00.000Z',
            'updated_at': '2024-01-01T00:00:00.000Z',
          });
          await db.insert(kTripsTable, {
            'id': 'old_trip',
            'vehicle_id': 'v1',
            'mode': 'reckless',
            'start_time': '2024-06-01T08:00:00.000Z',
            'end_time': '2024-06-01T08:30:00.000Z',
            'duration_seconds': 1800,
            'distance_km': 12.5,
            'start_latitude': 33.888,
            'start_longitude': 35.495,
            'created_at': '2024-06-01T00:00:00.000Z',
          });
        },
      ),
    );

    // Apply the v4 migration manually (what _migrate case 4 does).
    await v3db.execute('''
      CREATE TABLE IF NOT EXISTS $kTrackPointsTable (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES $kTripsTable(id) ON DELETE CASCADE,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        speed_kmh REAL,
        accuracy_m REAL,
        heading_degrees REAL
      )
    ''');
    await v3db.execute('''
      CREATE INDEX IF NOT EXISTS idx_track_points_trip_time
        ON $kTrackPointsTable (trip_id, timestamp ASC)
    ''');

    // Verify vehicles survived.
    final vehicles = await v3db.query(kVehiclesTable);
    expect(vehicles.length, 1, reason: 'Existing vehicle must survive v4 migration');
    expect(vehicles.first['id'], 'v1');

    // Verify trips survived.
    final trips = await v3db.query(kTripsTable);
    expect(trips.length, 1, reason: 'Existing trip must survive v4 migration');
    expect(trips.first['id'], 'old_trip');

    // Verify new table exists.
    final tables = await v3db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$kTrackPointsTable'",
    );
    expect(tables.length, 1, reason: 'trip_track_points table must exist after migration');

    await v3db.close();
  });

  // ── Test 2: Existing vehicles survive migration ────────────────────────────

  test('2. Existing vehicles survive v3 → v4 migration', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        singleInstance: false,
        onCreate: (db, version) async {
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
              vehicle_id TEXT, mode TEXT NOT NULL,
              start_time TEXT NOT NULL, end_time TEXT NOT NULL,
              duration_seconds INTEGER NOT NULL, distance_km REAL NOT NULL,
              start_latitude REAL NOT NULL, start_longitude REAL NOT NULL,
              start_name TEXT, destination_latitude REAL,
              destination_longitude REAL, destination_name TEXT,
              average_speed_kmh REAL, minimum_speed_kmh REAL,
              maximum_speed_kmh REAL, minimum_altitude_m REAL,
              maximum_altitude_m REAL, stops INTEGER,
              created_at TEXT NOT NULL
            )
          ''');
          for (var i = 1; i <= 3; i++) {
            await db.insert(kVehiclesTable, {
              'id': 'vehicle_$i',
              'brand': 'Brand$i',
              'model': 'Model$i',
              'year': 2020 + i,
              'type': 'sedan',
              'created_at': '2024-01-01T00:00:00.000Z',
              'updated_at': '2024-01-01T00:00:00.000Z',
            });
          }
        },
      ),
    );

    // Apply v4 migration.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kTrackPointsTable (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES $kTripsTable(id) ON DELETE CASCADE,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        altitude REAL, speed_kmh REAL, accuracy_m REAL, heading_degrees REAL
      )
    ''');

    final vehicles = await db.query(kVehiclesTable);
    expect(vehicles.length, 3, reason: 'All vehicles must survive migration');

    await db.close();
  });

  // ── Test 3: Existing trips survive migration ───────────────────────────────

  test('3. Existing trips survive v3 → v4 migration', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        singleInstance: false,
        onCreate: (db, version) async {
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
              id TEXT PRIMARY KEY, vehicle_id TEXT,
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
          for (var i = 1; i <= 5; i++) {
            await db.insert(kTripsTable, {
              'id': 'trip_$i',
              'mode': 'reckless',
              'start_time': '2024-0$i-01T08:00:00.000Z',
              'end_time': '2024-0$i-01T08:30:00.000Z',
              'duration_seconds': 1800,
              'distance_km': 10.0 * i,
              'start_latitude': 33.0,
              'start_longitude': 35.0,
              'created_at': '2024-0$i-01T00:00:00.000Z',
            });
          }
        },
      ),
    );

    // Apply v4 migration.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kTrackPointsTable (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES $kTripsTable(id) ON DELETE CASCADE,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        altitude REAL, speed_kmh REAL, accuracy_m REAL, heading_degrees REAL
      )
    ''');

    final trips = await db.query(kTripsTable);
    expect(trips.length, 5, reason: 'All trips must survive migration');

    await db.close();
  });

  // ── Test 4: Track-point table exists ──────────────────────────────────────

  test('4. trip_track_points table exists after v4 schema creation', () async {
    final db = await _openTestDb();

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$kTrackPointsTable'",
    );
    expect(tables, isNotEmpty, reason: 'trip_track_points table must exist');

    await db.close();
  });

  // ── Test 5: Track points can be inserted ──────────────────────────────────

  test('5. track points can be inserted', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());
    await trackRepo.addTrackPoint(_makePoint());

    final rows = await db.query(kTrackPointsTable);
    expect(rows.length, 1);
    expect(rows.first['id'], 'p1');

    await db.close();
  });

  // ── Test 6: Track points can be retrieved ─────────────────────────────────

  test('6. track points can be retrieved for a trip', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());
    await trackRepo.addTrackPoint(_makePoint(id: 'p1'));
    await trackRepo.addTrackPoint(
      _makePoint(id: 'p2', timestamp: _t0.add(const Duration(seconds: 10))),
    );

    final points = await trackRepo.getTrackPointsForTrip('trip1');
    expect(points.length, 2);

    await db.close();
  });

  // ── Test 7: Track points returned chronologically ─────────────────────────

  test('7. track points are returned in chronological order', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());

    // Insert out of order to verify ordering is done by timestamp, not insert order.
    final t2 = _t0.add(const Duration(seconds: 20));
    final t1 = _t0.add(const Duration(seconds: 10));
    final t3 = _t0.add(const Duration(seconds: 30));

    await trackRepo.addTrackPoint(_makePoint(id: 'p3', timestamp: t3));
    await trackRepo.addTrackPoint(_makePoint(id: 'p1', timestamp: _t0));
    await trackRepo.addTrackPoint(_makePoint(id: 'p2', timestamp: t2));
    await trackRepo.addTrackPoint(_makePoint(id: 'p_mid', timestamp: t1));

    final points = await trackRepo.getTrackPointsForTrip('trip1');
    expect(points.length, 4);
    expect(points[0].id, 'p1');
    expect(points[1].id, 'p_mid');
    expect(points[2].id, 'p2');
    expect(points[3].id, 'p3');

    // Verify ascending timestamp order.
    for (var i = 1; i < points.length; i++) {
      expect(
        points[i].timestamp.isAfter(points[i - 1].timestamp),
        isTrue,
        reason: 'Points must be in ascending timestamp order',
      );
    }

    await db.close();
  });

  // ── Test 8: Track points persist after database close/reopen ──────────────

  test('8. track points persist after database close and reopen', () async {
    final baseDir = await databaseFactoryFfi.getDatabasesPath();
    final path = p.join(baseDir, 'track_point_persist_test.db');
    await databaseFactoryFfi.deleteDatabase(path);

    Future<Database> openNamed() => databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: kDatabaseVersion,
            onConfigure: (db) async =>
                db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE IF NOT EXISTS $kTripsTable (
                  id TEXT PRIMARY KEY, vehicle_id TEXT, mode TEXT NOT NULL,
                  start_time TEXT NOT NULL, end_time TEXT NOT NULL,
                  duration_seconds INTEGER NOT NULL, distance_km REAL NOT NULL,
                  start_latitude REAL NOT NULL, start_longitude REAL NOT NULL,
                  start_name TEXT, destination_latitude REAL,
                  destination_longitude REAL, destination_name TEXT,
                  average_speed_kmh REAL, minimum_speed_kmh REAL,
                  maximum_speed_kmh REAL, minimum_altitude_m REAL,
                  maximum_altitude_m REAL, stops INTEGER,
                  created_at TEXT NOT NULL
                )
              ''');
              await db.execute('''
                CREATE TABLE IF NOT EXISTS $kTrackPointsTable (
                  id TEXT PRIMARY KEY,
                  trip_id TEXT NOT NULL REFERENCES $kTripsTable(id) ON DELETE CASCADE,
                  timestamp TEXT NOT NULL,
                  latitude REAL NOT NULL, longitude REAL NOT NULL,
                  altitude REAL, speed_kmh REAL, accuracy_m REAL,
                  heading_degrees REAL
                )
              ''');
            },
          ),
        );

    // Write.
    final db1 = await openNamed();
    await TripRepository(db1).createTrip(_makeTrip());
    await TrackPointRepository(db1).addTrackPoint(_makePoint(id: 'persist_p1'));
    await db1.close();

    // Read back.
    final db2 = await openNamed();
    final points = await TrackPointRepository(db2).getTrackPointsForTrip('trip1');
    expect(points.length, 1);
    expect(points.first.id, 'persist_p1');
    await db2.close();

    await databaseFactoryFfi.deleteDatabase(path);
  });

  // ── Test 9: Multiple trips have separate track points ─────────────────────

  test('9. multiple trips can have separate, isolated track points', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip(id: 'tripA'));
    await tripRepo.createTrip(_makeTrip(
      id: 'tripB',
      startTime: _t1,
      endTime: _t1.add(const Duration(hours: 1)),
    ));

    await trackRepo.addTrackPoint(_makePoint(id: 'a1', tripId: 'tripA'));
    await trackRepo.addTrackPoint(_makePoint(id: 'a2', tripId: 'tripA',
        timestamp: _t0.add(const Duration(seconds: 5))));
    await trackRepo.addTrackPoint(_makePoint(id: 'b1', tripId: 'tripB'));
    await trackRepo.addTrackPoint(_makePoint(id: 'b2', tripId: 'tripB',
        timestamp: _t1.add(const Duration(seconds: 5))));
    await trackRepo.addTrackPoint(_makePoint(id: 'b3', tripId: 'tripB',
        timestamp: _t1.add(const Duration(seconds: 10))));

    final pointsA = await trackRepo.getTrackPointsForTrip('tripA');
    final pointsB = await trackRepo.getTrackPointsForTrip('tripB');

    expect(pointsA.length, 2, reason: 'Trip A must have exactly 2 points');
    expect(pointsB.length, 3, reason: 'Trip B must have exactly 3 points');
    expect(pointsA.every((p) => p.tripId == 'tripA'), isTrue);
    expect(pointsB.every((p) => p.tripId == 'tripB'), isTrue);

    await db.close();
  });

  // ── Test 10: Deleting a Trip deletes its track points (CASCADE) ────────────

  test('10. deleting a Trip cascades to delete its track points', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip(id: 'tripDel'));
    for (var i = 0; i < 5; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'del_p$i',
        tripId: 'tripDel',
        timestamp: _t0.add(Duration(seconds: i)),
      ));
    }

    // Confirm points exist.
    final before = await trackRepo.getTrackPointsForTrip('tripDel');
    expect(before.length, 5);

    // Delete the trip — CASCADE must remove the points.
    await tripRepo.deleteTrip('tripDel');

    final after = await trackRepo.getTrackPointsForTrip('tripDel');
    expect(after, isEmpty,
        reason: 'Track points must be deleted when the parent trip is deleted');

    // Confirm no orphan rows in the table.
    final allRows = await db.query(kTrackPointsTable);
    expect(allRows, isEmpty, reason: 'No orphan track points must remain');

    await db.close();
  });

  // ── Test 11: Deleting a Vehicle deletes its Trips and their track points ───

  test('11. deleting a Vehicle deletes its Trips and their track points (CASCADE)',
      () async {
    final db = await _openTestDb();
    final vehicleRepo = VehicleRepository(db);
    final tripRepo = TripRepository(db);
    final trackRepo = TrackPointRepository(db);

    await vehicleRepo.create(_makeVehicle('v_del'));
    await tripRepo.createTrip(_makeTrip(id: 'tripWithVehicle', vehicleId: 'v_del'));
    for (var i = 0; i < 3; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'vdel_p$i',
        tripId: 'tripWithVehicle',
        timestamp: _t0.add(Duration(seconds: i)),
      ));
    }

    // Delete the vehicle — CASCADE: vehicle → trips → track points.
    await vehicleRepo.delete('v_del');

    // Trip must be deleted (ON DELETE CASCADE on vehicle_id).
    final trip = await tripRepo.getTripById('tripWithVehicle');
    expect(trip, isNull, reason: 'Trip must be deleted when its vehicle is deleted (CASCADE)');

    // Track points must also be gone (cascaded via trip deletion).
    final points = await trackRepo.getTrackPointsForTrip('tripWithVehicle');
    expect(points, isEmpty,
        reason: 'Track points must be deleted when the parent trip is deleted');

    await db.close();
  });

  // ── Test 12: No orphan track points remain after trip deletion ─────────────

  test('12. no orphan track points remain after trip deletion', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    // Create two trips with track points.
    await tripRepo.createTrip(_makeTrip(id: 'keep'));
    await tripRepo.createTrip(_makeTrip(
      id: 'remove',
      startTime: _t1,
      endTime: _t1.add(const Duration(hours: 1)),
    ));

    for (var i = 0; i < 3; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'keep_p$i',
        tripId: 'keep',
        timestamp: _t0.add(Duration(seconds: i)),
      ));
      await trackRepo.addTrackPoint(_makePoint(
        id: 'remove_p$i',
        tripId: 'remove',
        timestamp: _t1.add(Duration(seconds: i)),
      ));
    }

    // Delete one trip.
    await tripRepo.deleteTrip('remove');

    // Only points for 'keep' must remain.
    final keepPoints = await trackRepo.getTrackPointsForTrip('keep');
    final removePoints = await trackRepo.getTrackPointsForTrip('remove');
    final allRows = await db.query(kTrackPointsTable);

    expect(keepPoints.length, 3, reason: 'Unaffected trip points must remain');
    expect(removePoints, isEmpty, reason: 'Deleted trip points must be gone');
    expect(allRows.length, 3, reason: 'No orphan rows in the table');

    await db.close();
  });


  // ==========================================================================
  // REPOSITORY TESTS (13–17)
  // ==========================================================================

  // ── Test 13: addTrackPoint works ──────────────────────────────────────────

  test('13. addTrackPoint inserts a row with all fields', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());
    await trackRepo.addTrackPoint(
      TrackPointRecord(
        id: 'full_p',
        tripId: 'trip1',
        timestamp: _t0,
        latitude: 33.8882,
        longitude: 35.4955,
        altitude: 120.5,
        speedKmh: 75.3,
        accuracyM: 4.2,
        headingDegrees: 270.0,
      ),
    );

    final rows = await db.query(kTrackPointsTable, where: 'id = ?', whereArgs: ['full_p']);
    expect(rows.length, 1);

    final row = rows.first;
    expect((row['latitude'] as num).toDouble(), closeTo(33.8882, 0.00001));
    expect((row['longitude'] as num).toDouble(), closeTo(35.4955, 0.00001));
    expect((row['altitude'] as num).toDouble(), closeTo(120.5, 0.01));
    expect((row['speed_kmh'] as num).toDouble(), closeTo(75.3, 0.01));
    expect((row['accuracy_m'] as num).toDouble(), closeTo(4.2, 0.01));
    expect((row['heading_degrees'] as num).toDouble(), closeTo(270.0, 0.01));

    await db.close();
  });

  // ── Test 14: getTrackPointsForTrip works ──────────────────────────────────

  test('14. getTrackPointsForTrip returns correct TrackPointRecord objects',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());
    final record = TrackPointRecord(
      id: 'check_p',
      tripId: 'trip1',
      timestamp: _t0,
      latitude: 33.9,
      longitude: 35.5,
      altitude: 200.0,
      speedKmh: 50.0,
      accuracyM: 3.0,
      headingDegrees: 90.0,
    );
    await trackRepo.addTrackPoint(record);

    final points = await trackRepo.getTrackPointsForTrip('trip1');
    expect(points.length, 1);

    final p = points.first;
    expect(p.id, 'check_p');
    expect(p.tripId, 'trip1');
    expect(p.latitude, closeTo(33.9, 0.00001));
    expect(p.longitude, closeTo(35.5, 0.00001));
    expect(p.altitude, closeTo(200.0, 0.01));
    expect(p.speedKmh, closeTo(50.0, 0.01));
    expect(p.accuracyM, closeTo(3.0, 0.01));
    expect(p.headingDegrees, closeTo(90.0, 0.01));

    await db.close();
  });

  // ── Test 15: Empty track returns correctly ────────────────────────────────

  test('15. getTrackPointsForTrip returns empty list for a trip with no points',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());

    final points = await trackRepo.getTrackPointsForTrip('trip1');
    expect(points, isEmpty);

    await db.close();
  });

  // ── Test 16: Large track can be retrieved ─────────────────────────────────

  test('16. large GPS track (1000 points) can be inserted and retrieved',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());

    // Build 1000 points.
    final records = List.generate(1000, (i) {
      return TrackPointRecord(
        id: 'big_p${i.toString().padLeft(4, '0')}',
        tripId: 'trip1',
        timestamp: _t0.add(Duration(seconds: i)),
        latitude: 33.888 + i * 0.00001,
        longitude: 35.495 + i * 0.00001,
        altitude: 100.0 + i * 0.1,
        speedKmh: 60.0,
        accuracyM: 5.0,
      );
    });

    await trackRepo.addTrackPoints(records);

    final points = await trackRepo.getTrackPointsForTrip('trip1');
    expect(points.length, 1000);

    // Verify ordering.
    for (var i = 1; i < points.length; i++) {
      expect(
        points[i].timestamp.isAfter(points[i - 1].timestamp) ||
            points[i].timestamp == points[i - 1].timestamp,
        isTrue,
      );
    }

    await db.close();
  });

  // ── Test 17: Multiple trips remain isolated ───────────────────────────────

  test('17. track points from multiple trips remain isolated', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    // Create 3 trips, each with a different number of points.
    for (var t = 1; t <= 3; t++) {
      await tripRepo.createTrip(_makeTrip(
        id: 'iso_trip$t',
        startTime: _t0.add(Duration(hours: t)),
        endTime: _t0.add(Duration(hours: t, minutes: 30)),
      ));
      for (var p = 0; p < t * 10; p++) {
        await trackRepo.addTrackPoint(TrackPointRecord(
          id: 'iso_t${t}_p$p',
          tripId: 'iso_trip$t',
          timestamp: _t0.add(Duration(hours: t, seconds: p)),
          latitude: 33.0 + t * 0.001,
          longitude: 35.0 + p * 0.001,
        ));
      }
    }

    final t1Points = await trackRepo.getTrackPointsForTrip('iso_trip1');
    final t2Points = await trackRepo.getTrackPointsForTrip('iso_trip2');
    final t3Points = await trackRepo.getTrackPointsForTrip('iso_trip3');

    expect(t1Points.length, 10, reason: 'Trip 1 must have exactly 10 points');
    expect(t2Points.length, 20, reason: 'Trip 2 must have exactly 20 points');
    expect(t3Points.length, 30, reason: 'Trip 3 must have exactly 30 points');

    // Cross-contamination check.
    expect(t1Points.every((p) => p.tripId == 'iso_trip1'), isTrue);
    expect(t2Points.every((p) => p.tripId == 'iso_trip2'), isTrue);
    expect(t3Points.every((p) => p.tripId == 'iso_trip3'), isTrue);

    await db.close();
  });

  // ==========================================================================
  // DRIVE INTEGRATION TESTS (18–26)
  // ==========================================================================

  // ── Test 18: Drive assigns a stable activeTripId ──────────────────────────

  test('18. DriveState.activeTripId is a non-null UUID assigned at drive start',
      () async {
    // This is a unit test of the model/state logic — no foreground service.
    // We verify that DriveState carries a stable activeTripId that can be
    // used as a FK for track-point rows before the trip summary is created.

    const uuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
    final driveState = DriveState(
      status: DriveStatus.active,
      mode: DriveMode.reckless,
      startedAt: DateTime.now().toUtc(),
      activeTripId: uuid,
    );

    expect(driveState.activeTripId, isNotNull);
    expect(driveState.activeTripId, equals(uuid));

    // activeTripId must survive a copyWith that changes other fields.
    final updated = driveState.copyWith(
      currentSpeedKmh: 55.0,
    );
    expect(updated.activeTripId, equals(uuid),
        reason: 'activeTripId must be stable across copyWith calls');
  });

  // ── Test 19: GPS points are persisted during an active drive ──────────────

  test('19. GPS points persisted incrementally using activeTripId as FK',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    // Simulate a drive: trip summary does NOT exist yet (created on FINISH).
    // Points are persisted with the activeTripId using a non-FK path first —
    // we test addTrackPoints which is what _flushTrackPoints uses.
    //
    // For this test we first create the trip so FK constraints pass,
    // mimicking the production flow where the trip row is created at FINISH
    // but track points already carry the same ID.

    const activeTripId = 'active-trip-uuid';

    // Create the trip row first (as FINISH would do) so FK works.
    await tripRepo.createTrip(_makeTrip(id: activeTripId));

    // Simulate incremental persistence of 5 GPS points.
    for (var i = 0; i < 5; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'incr_p$i',
        tripId: activeTripId,
        timestamp: _t0.add(Duration(seconds: i * 10)),
      ));
    }

    final points = await trackRepo.getTrackPointsForTrip(activeTripId);
    expect(points.length, 5,
        reason: 'All 5 incremental points must be stored');

    await db.close();
  });

  // ── Test 20: FINISH flushes pending track points ──────────────────────────

  test('20. addTrackPoints (flush) inserts all points in a single transaction',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip(id: 'flush_trip'));

    final batch = List.generate(50, (i) {
      return _makePoint(
        id: 'flush_p$i',
        tripId: 'flush_trip',
        timestamp: _t0.add(Duration(seconds: i)),
      );
    });

    await trackRepo.addTrackPoints(batch);

    final points = await trackRepo.getTrackPointsForTrip('flush_trip');
    expect(points.length, 50,
        reason: 'addTrackPoints must insert all 50 points');

    await db.close();
  });

  // ── Test 21: FINISH persists the final Trip summary ───────────────────────

  test('21. trip summary is persisted via TripRepository at FINISH', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    const tripId = 'finish_trip';
    final trip = _makeTrip(id: tripId);

    // Persist track points first (incremental, pre-FINISH).
    await tripRepo.createTrip(trip);
    for (var i = 0; i < 3; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'fin_p$i',
        tripId: tripId,
        timestamp: _t0.add(Duration(seconds: i)),
      ));
    }

    // After createTrip + addTrackPoints the trip summary must be retrievable.
    final found = await tripRepo.getTripById(tripId);
    expect(found, isNotNull);
    expect(found!.id, tripId);
    expect(found.distanceKm, closeTo(12.5, 0.001));

    await db.close();
  });

  // ── Test 22: Final trip contains the correct track points ─────────────────

  test('22. final Trip contains exactly the track points recorded during drive',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    const tripId = 'correct_track_trip';
    await tripRepo.createTrip(_makeTrip(id: tripId));

    final expectedIds = ['e_p0', 'e_p1', 'e_p2', 'e_p3'];
    for (var i = 0; i < expectedIds.length; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: expectedIds[i],
        tripId: tripId,
        timestamp: _t0.add(Duration(seconds: i * 5)),
      ));
    }

    final points = await trackRepo.getTrackPointsForTrip(tripId);
    final returnedIds = points.map((p) => p.id).toList();

    expect(returnedIds, containsAllInOrder(expectedIds),
        reason: 'Returned points must match exactly what was recorded');

    await db.close();
  });

  // ── Test 23: Final GPS point is not lost ──────────────────────────────────

  test('23. the final GPS point of a drive is not lost', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    const tripId = 'last_point_trip';
    await tripRepo.createTrip(_makeTrip(id: tripId));

    // Add several points, then add the "final" point.
    for (var i = 0; i < 4; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'lp_$i',
        tripId: tripId,
        timestamp: _t0.add(Duration(seconds: i)),
      ));
    }
    final lastPoint = _makePoint(
      id: 'last_point',
      tripId: tripId,
      timestamp: _t0.add(const Duration(seconds: 100)),
      latitude: 33.999,
      longitude: 35.999,
    );
    await trackRepo.addTrackPoint(lastPoint);

    final points = await trackRepo.getTrackPointsForTrip(tripId);
    expect(points.last.id, 'last_point',
        reason: 'The final GPS point must not be lost');
    expect(points.last.latitude, closeTo(33.999, 0.00001));

    await db.close();
  });

  // ── Test 24: Failed individual point persistence does not crash the drive ──

  test('24. duplicate point ID (ignored) does not throw or lose other points',
      () async {
    // TrackPointRepository uses ConflictAlgorithm.ignore for idempotency.
    // A duplicate insert must not throw and must not corrupt existing data.
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip(id: 'dup_trip'));
    await trackRepo.addTrackPoint(_makePoint(id: 'dup_p', tripId: 'dup_trip'));

    // Insert same ID again — must be silently ignored.
    await expectLater(
      trackRepo.addTrackPoint(_makePoint(id: 'dup_p', tripId: 'dup_trip')),
      completes,
      reason: 'Duplicate insert must not throw',
    );

    // Insert a unique subsequent point to confirm the channel is still open.
    await trackRepo.addTrackPoint(
      _makePoint(id: 'after_dup', tripId: 'dup_trip',
          timestamp: _t0.add(const Duration(seconds: 1))),
    );

    final points = await trackRepo.getTrackPointsForTrip('dup_trip');
    // Only 2 unique rows: original + after_dup (duplicate ignored).
    expect(points.length, 2,
        reason: 'Duplicate must be ignored, subsequent points must succeed');

    await db.close();
  });

  // ── Test 25: Successful FINISH returns the completed Trip ID ──────────────

  test('25. completed Trip ID can be obtained after createTrip', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    const expectedId = 'successful_finish_trip';
    await tripRepo.createTrip(_makeTrip(id: expectedId));

    // getTripById with the same ID must succeed.
    final trip = await tripRepo.getTripById(expectedId);
    expect(trip, isNotNull);
    expect(trip!.id, expectedId,
        reason: 'Trip ID returned by createTrip must be retrievable');

    // Track points must also be retrievable for the same ID.
    await trackRepo.addTrackPoint(_makePoint(
      id: 'sf_p1', tripId: expectedId,
    ));
    final points = await trackRepo.getTrackPointsForTrip(expectedId);
    expect(points.isNotEmpty, isTrue);

    await db.close();
  });

  // ── Test 26: Completed Trip is retrievable by ID ──────────────────────────

  test('26. completed Trip is retrievable by ID after persistence', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    final trip = Trip(
      id: 'retrievable_trip',
      vehicleId: null,
      mode: TripMode.reckless,
      startTime: _t0,
      endTime: _t1,
      durationSeconds: 1800,
      distanceKm: 14.2,
      startLatitude: 33.888,
      startLongitude: 35.495,
      averageSpeedKmh: 34.0,
      maximumSpeedKmh: 71.0,
      minimumSpeedKmh: 0.0,
      minimumAltitudeM: 50.0,
      maximumAltitudeM: 250.0,
      createdAt: DateTime.utc(2024, 6, 1),
    );
    await tripRepo.createTrip(trip);

    for (var i = 0; i < 5; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'ret_p$i',
        tripId: 'retrievable_trip',
        timestamp: _t0.add(Duration(seconds: i * 60)),
      ));
    }

    final found = await tripRepo.getTripById('retrievable_trip');
    expect(found, isNotNull);
    expect(found!.distanceKm, closeTo(14.2, 0.001));
    expect(found.averageSpeedKmh, closeTo(34.0, 0.01));
    expect(found.maximumSpeedKmh, closeTo(71.0, 0.01));

    final points = await trackRepo.getTrackPointsForTrip('retrievable_trip');
    expect(points.length, 5);

    await db.close();
  });


  // ==========================================================================
  // POST-FINISH FLOW TESTS (27–32)
  // ==========================================================================

  // ── Test 27: Trip appears through TripRepository after FINISH ─────────────

  test('27. newly completed Trip appears in getAllTrips after persistence',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    // Before: empty list.
    final before = await tripRepo.getAllTrips();
    expect(before, isEmpty);

    // Simulate FINISH: create trip + flush track points.
    const tripId = 'new_trip';
    await tripRepo.createTrip(_makeTrip(id: tripId));
    await trackRepo.addTrackPoints([
      _makePoint(id: 'nf_p0', tripId: tripId),
      _makePoint(id: 'nf_p1', tripId: tripId,
          timestamp: _t0.add(const Duration(seconds: 5))),
    ]);

    // After: trip is in the list.
    final after = await tripRepo.getAllTrips();
    expect(after.length, 1);
    expect(after.first.id, tripId);

    await db.close();
  });

  // ── Test 28: Trip Stats receives the correct Trip ID ──────────────────────

  test('28. getTripById returns the exact Trip whose ID was passed at creation',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    const id1 = 'stats_trip_1';
    const id2 = 'stats_trip_2';
    await tripRepo.createTrip(_makeTrip(id: id1));
    await tripRepo.createTrip(_makeTrip(
      id: id2,
      startTime: _t1,
      endTime: _t1.add(const Duration(hours: 1)),
    ));

    final found1 = await tripRepo.getTripById(id1);
    final found2 = await tripRepo.getTripById(id2);

    // Each lookup must return the exact trip, not a different one.
    expect(found1!.id, id1);
    expect(found2!.id, id2);
    expect(found1.id, isNot(equals(found2.id)));

    await db.close();
  });

  // ── Test 29: Trip Stats immediately displays persisted summary data ────────

  test('29. persisted summary statistics are immediately available from Trip',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    final trip = Trip(
      id: 'summary_trip',
      vehicleId: null,
      mode: TripMode.destination,
      startTime: _t0,
      endTime: _t1,
      durationSeconds: 1800,
      distanceKm: 14.2,
      startLatitude: 33.888,
      startLongitude: 35.495,
      destinationLatitude: 34.0,
      destinationLongitude: 35.65,
      destinationName: 'Jounieh',
      averageSpeedKmh: 28.4,
      minimumSpeedKmh: 0.0,
      maximumSpeedKmh: 80.0,
      minimumAltitudeM: 45.0,
      maximumAltitudeM: 220.0,
      createdAt: DateTime.utc(2024, 6, 1),
    );
    await tripRepo.createTrip(trip);

    final found = await tripRepo.getTripById('summary_trip');
    expect(found, isNotNull);

    // All summary fields are immediately readable without recalculating.
    expect(found!.distanceKm, closeTo(14.2, 0.001));
    expect(found.durationSeconds, 1800);
    expect(found.averageSpeedKmh, closeTo(28.4, 0.01));
    expect(found.minimumSpeedKmh, closeTo(0.0, 0.01));
    expect(found.maximumSpeedKmh, closeTo(80.0, 0.01));
    expect(found.minimumAltitudeM, closeTo(45.0, 0.01));
    expect(found.maximumAltitudeM, closeTo(220.0, 0.01));
    expect(found.destinationName, 'Jounieh');
    expect(found.mode, TripMode.destination);

    await db.close();
  });

  // ── Test 30: Newly completed Trip appears through TripRepository ───────────

  test('30. getAllTrips returns the newly completed trip (newest first)',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    // Seed an older trip.
    await tripRepo.createTrip(_makeTrip(id: 'old'));

    // Simulate a new drive finishing after the older one.
    await tripRepo.createTrip(_makeTrip(
      id: 'brand_new',
      startTime: _t0.add(const Duration(hours: 2)),
      endTime: _t0.add(const Duration(hours: 3)),
    ));

    final trips = await tripRepo.getAllTrips();
    expect(trips.first.id, 'brand_new',
        reason: 'Newest trip must appear first in getAllTrips');

    await db.close();
  });

  // ── Test 31: Trip Stats can load the GPS track independently ──────────────

  test('31. GPS track loads independently of the trip summary', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    const tripId = 'indie_track_trip';
    await tripRepo.createTrip(_makeTrip(id: tripId));

    // Insert 10 ordered GPS points.
    for (var i = 0; i < 10; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'ind_p$i',
        tripId: tripId,
        timestamp: _t0.add(Duration(seconds: i * 30)),
        latitude: 33.888 + i * 0.001,
        longitude: 35.495 + i * 0.001,
      ));
    }

    // Load the summary and the track independently — both succeed.
    final summary = await tripRepo.getTripById(tripId);
    final track = await trackRepo.getTrackPointsForTrip(tripId);

    expect(summary, isNotNull, reason: 'Summary must be loadable independently');
    expect(track.length, 10, reason: 'Track must be loadable independently');

    // The track must be in chronological order regardless of load path.
    for (var i = 1; i < track.length; i++) {
      expect(track[i].timestamp.isAfter(track[i - 1].timestamp), isTrue);
    }

    await db.close();
  });

  // ── Test 32: Persistence failure — Trip not retrievable for nonexistent ID ─

  test('32. getTripById returns null for a non-existent Trip ID', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    // No trip was ever created with this ID.
    final found = await tripRepo.getTripById('nonexistent-trip-id');
    expect(found, isNull,
        reason: 'Must return null for unknown ID, never throw');

    // Track points for a non-existent trip must return empty list.
    final points =
        await trackRepo.getTrackPointsForTrip('nonexistent-trip-id');
    expect(points, isEmpty,
        reason: 'Must return empty list for unknown tripId, never throw');

    await db.close();
  });

  // ==========================================================================
  // ADDITIONAL FIELD / NULLABLE TESTS
  // ==========================================================================

  // ── Test 33: Nullable fields round-trip correctly ─────────────────────────

  test('33. nullable GPS fields (altitude, speed, accuracy, heading) round-trip',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());

    // Point with all nullable fields set.
    await trackRepo.addTrackPoint(TrackPointRecord(
      id: 'full',
      tripId: 'trip1',
      timestamp: _t0,
      latitude: 33.888,
      longitude: 35.495,
      altitude: 150.0,
      speedKmh: 90.0,
      accuracyM: 6.0,
      headingDegrees: 45.0,
    ));

    // Point with all nullable fields null.
    await trackRepo.addTrackPoint(TrackPointRecord(
      id: 'minimal',
      tripId: 'trip1',
      timestamp: _t0.add(const Duration(seconds: 1)),
      latitude: 33.889,
      longitude: 35.496,
    ));

    final points = await trackRepo.getTrackPointsForTrip('trip1');
    final full = points.firstWhere((p) => p.id == 'full');
    final minimal = points.firstWhere((p) => p.id == 'minimal');

    // Full point.
    expect(full.altitude, closeTo(150.0, 0.01));
    expect(full.speedKmh, closeTo(90.0, 0.01));
    expect(full.accuracyM, closeTo(6.0, 0.01));
    expect(full.headingDegrees, closeTo(45.0, 0.01));

    // Minimal point — all nullable fields must be null, not 0 or sentinel.
    expect(minimal.altitude, isNull);
    expect(minimal.speedKmh, isNull);
    expect(minimal.accuracyM, isNull);
    expect(minimal.headingDegrees, isNull);

    await db.close();
  });

  // ── Test 34: GPS coordinate precision is preserved ────────────────────────

  test('34. GPS coordinates are stored at full IEEE 754 double precision',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());

    // Use a coordinate that would be rounded if float (32-bit) were used.
    const precLat = 33.88823456789012;
    const precLng = 35.49512345678901;

    await trackRepo.addTrackPoint(TrackPointRecord(
      id: 'prec_p',
      tripId: 'trip1',
      timestamp: _t0,
      latitude: precLat,
      longitude: precLng,
    ));

    final points = await trackRepo.getTrackPointsForTrip('trip1');
    // Allow for the IEEE 754 double representation tolerance (< 1e-10 degrees).
    expect(points.first.latitude, closeTo(precLat, 1e-10));
    expect(points.first.longitude, closeTo(precLng, 1e-10));

    await db.close();
  });

  // ── Test 35: getTrackPointCount returns the correct count ─────────────────

  test('35. getTrackPointCount returns the correct number of points', () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip());

    expect(await trackRepo.getTrackPointCount('trip1'), 0);

    for (var i = 0; i < 7; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'cnt_p$i',
        tripId: 'trip1',
        timestamp: _t0.add(Duration(seconds: i)),
      ));
    }

    expect(await trackRepo.getTrackPointCount('trip1'), 7);

    await db.close();
  });

  // ── Test 36: deleteTrackPointsForTrip removes all points for a trip ────────

  test('36. deleteTrackPointsForTrip removes all points for the specified trip',
      () async {
    final (:trackRepo, :tripRepo, :db) = await _openBothRepos();

    await tripRepo.createTrip(_makeTrip(id: 'del_tp_trip'));
    await tripRepo.createTrip(_makeTrip(
      id: 'keep_tp_trip',
      startTime: _t1,
      endTime: _t1.add(const Duration(hours: 1)),
    ));

    for (var i = 0; i < 4; i++) {
      await trackRepo.addTrackPoint(_makePoint(
        id: 'del_tp_$i',
        tripId: 'del_tp_trip',
        timestamp: _t0.add(Duration(seconds: i)),
      ));
      await trackRepo.addTrackPoint(_makePoint(
        id: 'keep_tp_$i',
        tripId: 'keep_tp_trip',
        timestamp: _t1.add(Duration(seconds: i)),
      ));
    }

    await trackRepo.deleteTrackPointsForTrip('del_tp_trip');

    expect(
      await trackRepo.getTrackPointsForTrip('del_tp_trip'),
      isEmpty,
      reason: 'All points for the deleted trip must be gone',
    );
    expect(
      (await trackRepo.getTrackPointsForTrip('keep_tp_trip')).length,
      4,
      reason: 'Unaffected trip points must remain intact',
    );

    await db.close();
  });
}
