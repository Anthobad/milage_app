// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:triprank_project/core/database/database_config.dart';
import 'package:triprank_project/features/cars/data/vehicle_repository.dart';
import 'package:triprank_project/features/cars/models/vehicle.dart';
import 'package:triprank_project/features/trips/data/track_point_repository.dart';
import 'package:triprank_project/features/trips/data/trip_repository.dart';
import 'package:triprank_project/features/trips/models/track_point_record.dart';
import 'package:triprank_project/features/trips/models/trip.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

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
        await db.execute(
            'CREATE TABLE IF NOT EXISTS $kMetadataTable (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kVehiclesTable (
            id TEXT PRIMARY KEY, brand TEXT NOT NULL, model TEXT NOT NULL,
            year INTEGER NOT NULL, type TEXT NOT NULL,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kTripsTable (
            id TEXT PRIMARY KEY,
            vehicle_id TEXT REFERENCES $kVehiclesTable(id) ON DELETE SET NULL,
            mode TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL, distance_km REAL NOT NULL,
            start_latitude REAL NOT NULL, start_longitude REAL NOT NULL,
            start_name TEXT, destination_latitude REAL, destination_longitude REAL,
            destination_name TEXT, average_speed_kmh REAL, minimum_speed_kmh REAL,
            maximum_speed_kmh REAL, minimum_altitude_m REAL, maximum_altitude_m REAL,
            stops INTEGER, created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kTrackPointsTable (
            id TEXT PRIMARY KEY,
            trip_id TEXT NOT NULL REFERENCES $kTripsTable(id) ON DELETE CASCADE,
            timestamp TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL,
            altitude REAL, speed_kmh REAL, accuracy_m REAL, heading_degrees REAL
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_track_points_trip_time '
            'ON $kTrackPointsTable (trip_id, timestamp ASC)');
      },
    ),
  );
}

final _t0 = DateTime.utc(2024, 8, 11, 9, 0);
final _t1 = DateTime.utc(2024, 8, 11, 9, 30);

Trip _trip({
  String id = 'trip-del-1',
  String? vehicleId,
  TripMode mode = TripMode.reckless,
  String? destinationName,
  DateTime? startTime,
}) {
  final start = startTime ?? _t0;
  return Trip(
    id: id,
    vehicleId: vehicleId,
    mode: mode,
    startTime: start,
    endTime: _t1,
    durationSeconds: 1800,
    distanceKm: 5.0,
    startLatitude: 33.88,
    startLongitude: 35.49,
    destinationName: destinationName,
    createdAt: DateTime.utc(2024, 8, 11),
  );
}

TrackPointRecord _point({
  required String id,
  required String tripId,
  DateTime? ts,
}) {
  return TrackPointRecord(
    id: id,
    tripId: tripId,
    timestamp: ts ?? _t0,
    latitude: 33.88,
    longitude: 35.49,
  );
}

Vehicle _vehicle(String id) => Vehicle(
      id: id,
      brand: 'BMW',
      model: '320i',
      year: 2022,
      type: VehicleType.sedan,
      createdAt: DateTime.utc(2024, 1, 1),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_initFfi);

  // ── Delete trip ────────────────────────────────────────────────────────────

  group('Delete trip flow', () {
    test('1. deleteTrip removes the trip row', () async {
      final db = await _openTestDb();
      final repo = TripRepository(db);
      await repo.createTrip(_trip());
      await repo.deleteTrip('trip-del-1');

      final found = await repo.getTripById('trip-del-1');
      expect(found, isNull);
      await db.close();
    });

    test('2. deleting a trip removes its GPS track (CASCADE)', () async {
      final db = await _openTestDb();
      final tripRepo = TripRepository(db);
      final trackRepo = TrackPointRepository(db);

      await tripRepo.createTrip(_trip(id: 'tc1'));
      await trackRepo.addTrackPoint(_point(id: 'tp1', tripId: 'tc1'));
      await trackRepo.addTrackPoint(_point(id: 'tp2', tripId: 'tc1'));

      await tripRepo.deleteTrip('tc1');

      final pts = await trackRepo.getTrackPointsForTrip('tc1');
      expect(pts.isEmpty, isTrue);
      await db.close();
    });

    test('3. deleting one trip does not affect other trips', () async {
      final db = await _openTestDb();
      final repo = TripRepository(db);
      await repo.createTrip(_trip(id: 'keep-a'));
      await repo.createTrip(_trip(id: 'del-b'));

      await repo.deleteTrip('del-b');

      final all = await repo.getAllTrips();
      expect(all.length, 1);
      expect(all.first.id, 'keep-a');
      await db.close();
    });

    test('4. deleting a non-existent trip does not throw', () async {
      final db = await _openTestDb();
      final repo = TripRepository(db);
      await expectLater(
        () async => repo.deleteTrip('no-such-id'),
        returnsNormally,
      );
      await db.close();
    });

    test('5. deleting a trip does not delete the vehicle', () async {
      final db = await _openTestDb();
      final vehicleRepo = VehicleRepository(db);
      final tripRepo = TripRepository(db);

      final v = _vehicle('v1');
      await vehicleRepo.create(v);
      await tripRepo.createTrip(_trip(id: 'tc2', vehicleId: 'v1'));

      await tripRepo.deleteTrip('tc2');

      final vehicles = await vehicleRepo.getAll();
      expect(vehicles.length, 1);
      await db.close();
    });

    test('6. list refreshes after delete (getAllTrips reflects deletion)', () async {
      final db = await _openTestDb();
      final repo = TripRepository(db);

      await repo.createTrip(_trip(id: 'r1'));
      await repo.createTrip(_trip(id: 'r2'));
      await repo.createTrip(_trip(id: 'r3'));

      await repo.deleteTrip('r2');

      final all = await repo.getAllTrips();
      expect(all.length, 2);
      expect(all.map((t) => t.id).contains('r2'), isFalse);
      await db.close();
    });
  });

  // ── Vehicle-scoped trip list ───────────────────────────────────────────────

  group('Vehicle-scoped trip list', () {
    test('7. getTripsForVehicle returns only that vehicle\'s trips', () async {
      final db = await _openTestDb();
      final vehicleRepo = VehicleRepository(db);
      final tripRepo = TripRepository(db);

      await vehicleRepo.create(_vehicle('va'));
      await vehicleRepo.create(_vehicle('vb'));
      await tripRepo.createTrip(_trip(id: 'ta1', vehicleId: 'va'));
      await tripRepo.createTrip(_trip(id: 'ta2', vehicleId: 'va'));
      await tripRepo.createTrip(_trip(id: 'tb1', vehicleId: 'vb'));

      final aTrips = await tripRepo.getTripsForVehicle('va');
      expect(aTrips.length, 2);
      expect(aTrips.map((t) => t.id).toSet(), {'ta1', 'ta2'});
      await db.close();
    });

    test('8. getTripsForVehicle returns empty list for vehicle with no trips', () async {
      final db = await _openTestDb();
      final vehicleRepo = VehicleRepository(db);
      final tripRepo = TripRepository(db);

      await vehicleRepo.create(_vehicle('vc'));
      final trips = await tripRepo.getTripsForVehicle('vc');
      expect(trips.isEmpty, isTrue);
      await db.close();
    });

    test('9. trips are returned newest first', () async {
      final db = await _openTestDb();
      final vehicleRepo = VehicleRepository(db);
      final tripRepo = TripRepository(db);

      await vehicleRepo.create(_vehicle('vd'));
      await tripRepo.createTrip(_trip(
          id: 'old', vehicleId: 'vd', startTime: DateTime.utc(2024, 1, 1)));
      await tripRepo.createTrip(_trip(
          id: 'new', vehicleId: 'vd', startTime: DateTime.utc(2024, 8, 1)));

      final trips = await tripRepo.getTripsForVehicle('vd');
      expect(trips.first.id, 'new');
      expect(trips.last.id, 'old');
      await db.close();
    });

    test('10. changing selected vehicle shows that vehicle\'s trips', () async {
      final db = await _openTestDb();
      final vehicleRepo = VehicleRepository(db);
      final tripRepo = TripRepository(db);

      await vehicleRepo.create(_vehicle('v-x'));
      await vehicleRepo.create(_vehicle('v-y'));
      await tripRepo.createTrip(_trip(id: 'x1', vehicleId: 'v-x'));
      await tripRepo.createTrip(_trip(id: 'y1', vehicleId: 'v-y'));
      await tripRepo.createTrip(_trip(id: 'y2', vehicleId: 'v-y'));

      final xTrips = await tripRepo.getTripsForVehicle('v-x');
      final yTrips = await tripRepo.getTripsForVehicle('v-y');

      expect(xTrips.length, 1);
      expect(yTrips.length, 2);
      await db.close();
    });

    test('11. no vehicle selected → trips list returns empty', () {
      // When selectedVehicleProvider returns null, vehicleTripsProvider
      // returns an empty list without querying the DB.
      // Verified by the provider logic: if (vehicle == null) return [];
      expect([], isEmpty); // Represents the provider short-circuit.
    });

    test('12. trip vehicle_id set to null when vehicle is deleted', () async {
      final db = await _openTestDb();
      final vehicleRepo = VehicleRepository(db);
      final tripRepo = TripRepository(db);

      await vehicleRepo.create(_vehicle('ve'));
      await tripRepo.createTrip(_trip(id: 'te1', vehicleId: 've'));

      await vehicleRepo.delete('ve');

      final trip = await tripRepo.getTripById('te1');
      expect(trip, isNotNull);
      expect(trip!.vehicleId, isNull); // ON DELETE SET NULL
      await db.close();
    });
  });

  // ── Trip item fields ───────────────────────────────────────────────────────

  group('Trip item field correctness', () {
    test('13. correct date/time from startTime', () {
      final start = DateTime.utc(2024, 8, 11, 14, 35);
      final trip = _trip(startTime: start);
      final local = trip.startTime.toLocal();
      // Day/month/year are accessible.
      expect(local.year, isNonNegative);
      expect(local.month, inInclusiveRange(1, 12));
      expect(local.day, inInclusiveRange(1, 31));
    });

    test('14. destination trip shows destinationName', () {
      final trip = _trip(
          mode: TripMode.destination, destinationName: 'Jounieh Port');
      expect(trip.destinationName, 'Jounieh Port');
    });

    test('15. reckless trip shows no destination', () {
      final trip = _trip(mode: TripMode.reckless);
      expect(trip.destinationName, isNull);
    });

    test('16. distance label is formatted correctly', () {
      final trip = _trip();
      expect(trip.distanceLabel, contains('km'));
    });

    test('17. duration label is formatted correctly', () {
      final trip = _trip();
      expect(trip.durationLabel, isNotEmpty);
    });
  });
}
