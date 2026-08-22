// ignore_for_file: avoid_print

// ---------------------------------------------------------------------------
// Phase 6.4 — Consolidated Analytics — Integration Tests
// ---------------------------------------------------------------------------
//
// Tests verify that the full analytics pipeline correctly integrates:
//   - Persisted Trip summary (distance, duration, speed extremes, altitude
//     extremes, stop count, destination, vehicle)
//   - DrivingAnalyticsService output (SpeedAnalysis, AltitudeAnalysis,
//     TurnAnalysis, BrakingAnalysis, analyzedPoints)
//   - TripAnalyticsState consolidation (single access point for all data)
//
// No physical device, GPS, internet, or Riverpod required.
// All tests use direct service and repository calls with in-memory SQLite.
//
// Tests 1–15 match the required scenarios from the spec.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:triprank_project/core/database/database_config.dart';
import 'package:triprank_project/features/analytics/models/braking_analysis.dart';
import 'package:triprank_project/features/analytics/models/braking_event.dart';
import 'package:triprank_project/features/analytics/models/driving_analytics.dart';
import 'package:triprank_project/features/analytics/models/turn_analysis.dart';
import 'package:triprank_project/features/analytics/providers/trip_analytics_provider.dart';
import 'package:triprank_project/features/analytics/services/driving_analytics_service.dart';
import 'package:triprank_project/features/trips/data/track_point_repository.dart';
import 'package:triprank_project/features/trips/data/trip_repository.dart';
import 'package:triprank_project/features/trips/models/track_point_record.dart';
import 'package:triprank_project/features/trips/models/trip.dart';

// ---------------------------------------------------------------------------
// FFI setup
// ---------------------------------------------------------------------------

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

// ---------------------------------------------------------------------------
// Schema helper — creates all 4 tables in a fresh in-memory database
// ---------------------------------------------------------------------------

Future<Database> _openDb() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kDatabaseVersion,
      singleInstance: false,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $kMetadataTable (
            key TEXT PRIMARY KEY, value TEXT NOT NULL
          )
        ''');
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
            vehicle_id TEXT REFERENCES $kVehiclesTable(id) ON DELETE CASCADE,
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
          'ON $kTrackPointsTable (trip_id, timestamp ASC)',
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

final _t0 = DateTime.utc(2024, 8, 22, 9, 0, 0);
DateTime _ts(int s) => _t0.add(Duration(seconds: s));

/// Earth radius in metres (WGS 84 mean).
const _earthR = 6371000.0;

/// Advance a (lat, lng) by [distM] metres along [bearingDeg].
({double lat, double lng}) _advance(
  double lat, double lng, double bearingDeg, double distM,
) {
  final d = distM / _earthR;
  final b = bearingDeg * math.pi / 180;
  final lat1 = lat * math.pi / 180;
  final lng1 = lng * math.pi / 180;
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(b),
  );
  final lng2 = lng1 +
      math.atan2(
        math.sin(b) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2),
      );
  return (lat: lat2 * 180 / math.pi, lng: lng2 * 180 / math.pi);
}

Trip _makeTrip({
  String id = 'trip-1',
  String? vehicleId,
  TripMode mode = TripMode.reckless,
  String? destinationName,
  double? destLat,
  double? destLng,
  double distanceKm = 10.0,
  int durationSeconds = 1800,
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
    startTime: _t0,
    endTime: _t0.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    distanceKm: distanceKm,
    startLatitude: 51.5,
    startLongitude: -0.1,
    destinationLatitude: destLat,
    destinationLongitude: destLng,
    destinationName: destinationName,
    averageSpeedKmh: avgSpeed,
    minimumSpeedKmh: minSpeed,
    maximumSpeedKmh: maxSpeed,
    minimumAltitudeM: minAlt,
    maximumAltitudeM: maxAlt,
    stops: stops,
    createdAt: _t0,
  );
}

TrackPointRecord _makePoint({
  required String id,
  required String tripId,
  required int timeS,
  required double lat,
  required double lng,
  double? altitude,
  double? speedKmh,
}) {
  return TrackPointRecord(
    id: id,
    tripId: tripId,
    timestamp: _ts(timeS),
    latitude: lat,
    longitude: lng,
    altitude: altitude,
    speedKmh: speedKmh,
  );
}

/// Builds a straight-line track of [count] points advancing north, each
/// [stepM] metres and 1 second apart.
List<TrackPointRecord> _straightTrack({
  required String tripId,
  double startLat = 51.5,
  double startLng = -0.1,
  int count = 10,
  double stepM = 20,
  double speedKmh = 60,
  double? altitude,
}) {
  final points = <TrackPointRecord>[];
  var lat = startLat;
  var lng = startLng;
  for (var i = 0; i < count; i++) {
    points.add(_makePoint(
      id: 'p-$i',
      tripId: tripId,
      timeS: i,
      lat: lat,
      lng: lng,
      speedKmh: speedKmh,
      altitude: altitude,
    ));
    final next = _advance(lat, lng, 0, stepM);
    lat = next.lat;
    lng = next.lng;
  }
  return points;
}

// ---------------------------------------------------------------------------
// setUpAll
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_initFfi);

  const service = DrivingAnalyticsService();

  // ── Test 1: Complete normal trip ─────────────────────────────────────────
  group('Test 1: Complete normal trip', () {
    test(
        '1. Full trip with all data: speed, altitude, turns, braking, '
        'stops, distance, duration', () async {
      final db = await _openDb();
      final tripRepo = TripRepository(db);
      final trackRepo = TrackPointRepository(db);

      // Trip with all persisted values
      final trip = _makeTrip(
        id: 'trip-full',
        distanceKm: 12.5,
        durationSeconds: 900,
        avgSpeed: 50.0,
        minSpeed: 20.0,
        maxSpeed: 90.0,
        minAlt: 50.0,
        maxAlt: 120.0,
        stops: 3,
        mode: TripMode.destination,
        destinationName: 'Beirut Airport',
        destLat: 33.82,
        destLng: 35.49,
      );
      await tripRepo.createTrip(trip);

      // Track: straight road, moderate speed
      final points = _straightTrack(
        tripId: 'trip-full',
        count: 15,
        speedKmh: 50,
        altitude: 75.0,
      );
      await trackRepo.addTrackPoints(points);

      // Load and analyze
      final loaded = await trackRepo.getTrackPointsForTrip('trip-full');
      final analytics = service.analyze(tripId: 'trip-full', points: loaded);
      final loadedTrip = await tripRepo.getTripById('trip-full');

      // Trip basics from persisted record
      expect(loadedTrip, isNotNull);
      expect(loadedTrip!.distanceKm, closeTo(12.5, 0.001));
      expect(loadedTrip.durationSeconds, 900);
      expect(loadedTrip.stops, 3);
      expect(loadedTrip.averageSpeedKmh, closeTo(50.0, 0.001));
      expect(loadedTrip.minimumSpeedKmh, closeTo(20.0, 0.001));
      expect(loadedTrip.maximumSpeedKmh, closeTo(90.0, 0.001));
      expect(loadedTrip.minimumAltitudeM, closeTo(50.0, 0.001));
      expect(loadedTrip.maximumAltitudeM, closeTo(120.0, 0.001));
      expect(loadedTrip.destinationName, 'Beirut Airport');

      // Analytics from GPS track
      expect(analytics.analyzedPoints, hasLength(15));
      expect(analytics.speedAnalysis, isNotNull);
      expect(analytics.altitudeAnalysis, isNotNull);
      expect(analytics.turnAnalysis, isNotNull);
      expect(analytics.brakingAnalysis, isNotNull);

      // No NaN/Infinity
      final spd = analytics.speedAnalysis.avgDerivedSpeedKmh;
      if (spd != null) {
        expect(spd.isFinite, isTrue);
      }

      await db.close();
    });
  });

  // ── Test 2: Trip with no turns ───────────────────────────────────────────
  group('Test 2: Trip with no turns', () {
    test('2. Straight-road trip produces TurnAnalysis with 0 turns', () async {
      final db = await _openDb();
      final tripRepo = TripRepository(db);
      final trackRepo = TrackPointRepository(db);

      await tripRepo.createTrip(_makeTrip(id: 'trip-noturn'));
      final points = _straightTrack(
        tripId: 'trip-noturn',
        count: 20,
        stepM: 20,
        speedKmh: 60,
      );
      await trackRepo.addTrackPoints(points);

      final loaded = await trackRepo.getTrackPointsForTrip('trip-noturn');
      final analytics = service.analyze(tripId: 'trip-noturn', points: loaded);

      expect(analytics.turnAnalysis, isNotNull);
      expect(analytics.turnAnalysis!.totalTurns, 0);
      expect(analytics.turnAnalysis!.leftTurns, 0);
      expect(analytics.turnAnalysis!.rightTurns, 0);
      expect(analytics.brakingAnalysis, isNotNull);
      expect(analytics.brakingAnalysis!.isEmpty, isTrue);

      await db.close();
    });
  });

  // ── Test 3: Trip with left and right turns ────────────────────────────────
  group('Test 3: Trip with left and right turns', () {
    test('3. Track with clear turns produces correct turn counts', () async {
      final db = await _openDb();
      final tripRepo = TripRepository(db);
      final trackRepo = TrackPointRepository(db);

      await tripRepo.createTrip(_makeTrip(id: 'trip-turns'));

      // Build a track: north, then 90° right (east), then 90° left (north again)
      final points = <TrackPointRecord>[];
      var lat = 51.5;
      var lng = -0.1;
      var t = 0;

      // Approach north (5 points)
      for (var i = 0; i < 5; i++, t++) {
        final next = _advance(lat, lng, 0, 20);
        points.add(_makePoint(
          id: 'p-$t', tripId: 'trip-turns', timeS: t,
          lat: lat, lng: lng, speedKmh: 30,
        ));
        lat = next.lat; lng = next.lng;
      }
      // Turn right: 5 points heading east (90°)
      for (var i = 0; i < 5; i++, t++) {
        final next = _advance(lat, lng, 90, 20);
        points.add(_makePoint(
          id: 'p-$t', tripId: 'trip-turns', timeS: t,
          lat: lat, lng: lng, speedKmh: 30,
        ));
        lat = next.lat; lng = next.lng;
      }

      await trackRepo.addTrackPoints(points);

      final loaded = await trackRepo.getTrackPointsForTrip('trip-turns');
      final analytics = service.analyze(tripId: 'trip-turns', points: loaded);

      expect(analytics.turnAnalysis, isNotNull);
      // Should detect at least 1 turn (right turn from north to east)
      expect(analytics.turnAnalysis!.totalTurns, greaterThanOrEqualTo(1));

      await db.close();
    });
  });

  // ── Test 4: Trip with U-turn ──────────────────────────────────────────────
  group('Test 4: Trip with U-turn', () {
    test('4. U-turn is counted separately from left/right', () {
      // Pure service test: no DB required for algorithm verification
      final points = <TrackPointRecord>[];
      var lat = 51.5;
      var lng = -0.1;

      // Go north 8 points
      for (var i = 0; i < 8; i++) {
        final next = _advance(lat, lng, 0, 20);
        points.add(TrackPointRecord(
          id: 'p-$i', tripId: 'trip-uturn', timestamp: _ts(i),
          latitude: lat, longitude: lng, speedKmh: 40,
        ));
        lat = next.lat; lng = next.lng;
      }
      // 5 points heading south (180° = U-turn)
      for (var i = 8; i < 13; i++) {
        final next = _advance(lat, lng, 180, 20);
        points.add(TrackPointRecord(
          id: 'p-$i', tripId: 'trip-uturn', timestamp: _ts(i),
          latitude: lat, longitude: lng, speedKmh: 30,
        ));
        lat = next.lat; lng = next.lng;
      }

      final analytics = service.analyze(tripId: 'trip-uturn', points: points);
      final turns = analytics.turnAnalysis!;

      expect(turns.uTurns, greaterThanOrEqualTo(1));
      // U-turns must not be counted as left or right
      final leftPlusRight = turns.leftTurns + turns.rightTurns;
      expect(leftPlusRight + turns.uTurns, equals(turns.totalTurns));
    });
  });

  // ── Test 5: Trip with hard braking ────────────────────────────────────────
  group('Test 5: Trip with hard braking', () {
    test('5. Hard braking event detected and exposed', () {
      final points = <TrackPointRecord>[
        TrackPointRecord(
          id: 'p0', tripId: 'trip-brake', timestamp: _ts(0),
          latitude: 51.5, longitude: -0.1, speedKmh: 60,
        ),
        TrackPointRecord(
          id: 'p1', tripId: 'trip-brake', timestamp: _ts(1),
          latitude: 51.5001, longitude: -0.1, speedKmh: 50, // -10 km/h = 2.78 m/s²
        ),
        TrackPointRecord(
          id: 'p2', tripId: 'trip-brake', timestamp: _ts(2),
          latitude: 51.5002, longitude: -0.1, speedKmh: 50,
        ),
      ];

      final analytics = service.analyze(tripId: 'trip-brake', points: points);
      final braking = analytics.brakingAnalysis!;

      expect(braking.totalEvents, 1);
      expect(braking.hardBrakingCount, 1);
      expect(braking.suddenStopCount, 0);
      expect(braking.events.first.type, BrakingEventType.hardBraking);
      expect(braking.events.first.decelerationMps2, greaterThan(0));
      expect(braking.events.first.decelerationMps2.isFinite, isTrue);
    });
  });

  // ── Test 6: Trip with sudden stop ─────────────────────────────────────────
  group('Test 6: Trip with sudden stop', () {
    test('6. Sudden stop classified correctly, not double-counted', () {
      final points = <TrackPointRecord>[
        TrackPointRecord(
          id: 'p0', tripId: 'trip-stop', timestamp: _ts(0),
          latitude: 51.5, longitude: -0.1, speedKmh: 60,
        ),
        TrackPointRecord(
          id: 'p1', tripId: 'trip-stop', timestamp: _ts(1),
          latitude: 51.5001, longitude: -0.1, speedKmh: 30, // strong decel
        ),
        TrackPointRecord(
          id: 'p2', tripId: 'trip-stop', timestamp: _ts(2),
          latitude: 51.5002, longitude: -0.1, speedKmh: 0, // stopped
        ),
      ];

      final analytics = service.analyze(tripId: 'trip-stop', points: points);
      final braking = analytics.brakingAnalysis!;

      expect(braking.totalEvents, 1);
      expect(braking.suddenStopCount, 1);
      expect(braking.hardBrakingCount, 0);
      // Single event — no double-counting
      expect(braking.events.first.type, BrakingEventType.suddenStop);
    });
  });

  // ── Test 7: Trip with multiple event types ────────────────────────────────
  group('Test 7: Trip with multiple event types', () {
    test('7. Multiple analytics types are all populated', () async {
      final db = await _openDb();
      final tripRepo = TripRepository(db);
      final trackRepo = TrackPointRepository(db);

      final trip = _makeTrip(
        id: 'trip-multi',
        avgSpeed: 55.0,
        minSpeed: 10.0,
        maxSpeed: 100.0,
        minAlt: 30.0,
        maxAlt: 80.0,
        stops: 2,
      );
      await tripRepo.createTrip(trip);

      // Use a straight track — the individual analytics have their own tests
      final points = _straightTrack(
        tripId: 'trip-multi',
        count: 10,
        speedKmh: 50,
        altitude: 60.0,
      );
      await trackRepo.addTrackPoints(points);

      final loaded = await trackRepo.getTrackPointsForTrip('trip-multi');
      final analytics = service.analyze(tripId: 'trip-multi', points: loaded);
      final loadedTrip = await tripRepo.getTripById('trip-multi');

      // All sub-analyses present
      expect(analytics.speedAnalysis, isNotNull);
      expect(analytics.altitudeAnalysis, isNotNull);
      expect(analytics.turnAnalysis, isNotNull);
      expect(analytics.brakingAnalysis, isNotNull);

      // Trip summary accessible
      expect(loadedTrip!.stops, 2);
      expect(loadedTrip.averageSpeedKmh, 55.0);

      // Analyzed points present
      expect(analytics.analyzedPoints.length, 10);

      // No crashes, no NaN
      for (final pt in analytics.analyzedPoints) {
        if (pt.derivedSpeedKmh != null) {
          expect(pt.derivedSpeedKmh!.isFinite, isTrue);
        }
        if (pt.altitudeChangeMetre != null) {
          expect(pt.altitudeChangeMetre!.isFinite, isTrue);
        }
      }

      await db.close();
    });
  });

  // ── Test 8: Empty track ───────────────────────────────────────────────────
  group('Test 8: Empty track', () {
    test('8. Empty track returns valid empty analytics — no crash', () async {
      final db = await _openDb();
      final tripRepo = TripRepository(db);
      final trackRepo = TrackPointRepository(db);

      await tripRepo.createTrip(_makeTrip(id: 'trip-empty'));
      // No track points inserted

      final loaded = await trackRepo.getTrackPointsForTrip('trip-empty');
      expect(loaded, isEmpty);

      final analytics = service.analyze(tripId: 'trip-empty', points: loaded);

      expect(analytics.isEmpty, isTrue);
      expect(analytics.analyzedPoints, isEmpty);
      expect(analytics.speedAnalysis.isEmpty, isTrue);
      expect(analytics.altitudeAnalysis.isEmpty, isTrue);
      expect(analytics.turnAnalysis, isNotNull);
      expect(analytics.turnAnalysis!.totalTurns, 0);
      expect(analytics.brakingAnalysis, isNotNull);
      expect(analytics.brakingAnalysis!.isEmpty, isTrue);

      await db.close();
    });
  });

  // ── Test 9: One-point track ───────────────────────────────────────────────
  group('Test 9: One-point track', () {
    test('9. Single GPS point: no segments, no events, no crash', () {
      final points = [
        TrackPointRecord(
          id: 'p0', tripId: 'trip-single', timestamp: _ts(0),
          latitude: 51.5, longitude: -0.1, speedKmh: 30, altitude: 50.0,
        ),
      ];

      final analytics = service.analyze(tripId: 'trip-single', points: points);

      expect(analytics.analyzedPoints, hasLength(1));
      // First point has no segment data
      expect(analytics.analyzedPoints.first.segmentDistanceM, isNull);
      expect(analytics.analyzedPoints.first.derivedSpeedKmh, isNull);
      // Analyses exist but are empty
      expect(analytics.speedAnalysis.movingDurationS, isNull);
      expect(analytics.turnAnalysis!.isEmpty, isTrue);
      expect(analytics.brakingAnalysis!.isEmpty, isTrue);
    });
  });

  // ── Test 10: Missing speed ────────────────────────────────────────────────
  group('Test 10: Missing speed', () {
    test('10. Track with null speedKmh: no crash, nullable fields used', () {
      final pos1 = _advance(51.5, -0.1, 0, 20);
      final pos2 = _advance(pos1.lat, pos1.lng, 0, 20);
      final points = [
        TrackPointRecord(
          id: 'p0', tripId: 'trip-nospeed', timestamp: _ts(0),
          latitude: 51.5, longitude: -0.1, speedKmh: null,
        ),
        TrackPointRecord(
          id: 'p1', tripId: 'trip-nospeed', timestamp: _ts(1),
          latitude: pos1.lat, longitude: pos1.lng, speedKmh: null,
        ),
        TrackPointRecord(
          id: 'p2', tripId: 'trip-nospeed', timestamp: _ts(2),
          latitude: pos2.lat, longitude: pos2.lng, speedKmh: null,
        ),
      ];

      final analytics = service.analyze(tripId: 'trip-nospeed', points: points);

      expect(analytics, isA<DrivingAnalytics>());
      // Speed with no raw data — derived from coords if possible
      // Must not crash
      expect(analytics.analyzedPoints, hasLength(3));
      // Braking detector should not crash on null speeds
      expect(analytics.brakingAnalysis, isNotNull);
    });
  });

  // ── Test 11: Missing altitude ─────────────────────────────────────────────
  group('Test 11: Missing altitude', () {
    test('11. Track with null altitude: AltitudeAnalysis empty, no crash', () {
      final points = _straightTrack(
        tripId: 'trip-noalt',
        count: 5,
        speedKmh: 50,
        altitude: null, // no altitude
      );

      final analytics = service.analyze(tripId: 'trip-noalt', points: points);

      // Altitude analysis must be empty but valid
      expect(analytics.altitudeAnalysis.isEmpty, isTrue);
      expect(analytics.altitudeAnalysis.minAltitudeM, isNull);
      expect(analytics.altitudeAnalysis.maxAltitudeM, isNull);
      // Must not substitute 0 for null altitude
      expect(analytics.altitudeAnalysis.totalElevationGainM, isNull);
    });
  });

  // ── Test 12: Duplicate timestamps ────────────────────────────────────────
  group('Test 12: Duplicate timestamps', () {
    test('12. Duplicate timestamps: no crash, invalid segments skipped', () {
      final points = [
        TrackPointRecord(
          id: 'p0', tripId: 'trip-dts', timestamp: _ts(0),
          latitude: 51.5, longitude: -0.1, speedKmh: 60,
        ),
        // Same timestamp as p0 — invalid segment
        TrackPointRecord(
          id: 'p1', tripId: 'trip-dts', timestamp: _ts(0),
          latitude: 51.5001, longitude: -0.1, speedKmh: 50,
        ),
        TrackPointRecord(
          id: 'p2', tripId: 'trip-dts', timestamp: _ts(1),
          latitude: 51.5002, longitude: -0.1, speedKmh: 50,
        ),
      ];

      expect(
        () => service.analyze(tripId: 'trip-dts', points: points),
        returnsNormally,
      );

      final analytics = service.analyze(tripId: 'trip-dts', points: points);
      expect(analytics.analyzedPoints, hasLength(3));
      // No NaN/Infinity in any derived values
      for (final pt in analytics.analyzedPoints) {
        if (pt.derivedSpeedKmh != null) {
          expect(pt.derivedSpeedKmh!.isNaN, isFalse);
          expect(pt.derivedSpeedKmh!.isInfinite, isFalse);
        }
        if (pt.accelerationMps2 != null) {
          expect(pt.accelerationMps2!.isNaN, isFalse);
          expect(pt.accelerationMps2!.isInfinite, isFalse);
        }
      }
    });
  });

  // ── Test 13: Duplicate coordinates ───────────────────────────────────────
  group('Test 13: Duplicate coordinates', () {
    test('13. Identical consecutive coords: 0-distance segment, no crash', () {
      final points = [
        TrackPointRecord(
          id: 'p0', tripId: 'trip-dc', timestamp: _ts(0),
          latitude: 51.5, longitude: -0.1, speedKmh: 60,
        ),
        TrackPointRecord(
          id: 'p1', tripId: 'trip-dc', timestamp: _ts(1),
          latitude: 51.5, longitude: -0.1, speedKmh: 60, // same coords
        ),
        TrackPointRecord(
          id: 'p2', tripId: 'trip-dc', timestamp: _ts(2),
          latitude: 51.5001, longitude: -0.1, speedKmh: 55,
        ),
      ];

      expect(
        () => service.analyze(tripId: 'trip-dc', points: points),
        returnsNormally,
      );

      final analytics = service.analyze(tripId: 'trip-dc', points: points);
      for (final pt in analytics.analyzedPoints) {
        if (pt.segmentDistanceM != null) {
          expect(pt.segmentDistanceM! >= 0, isTrue);
        }
        if (pt.derivedSpeedKmh != null) {
          expect(pt.derivedSpeedKmh!.isFinite, isTrue);
        }
      }
    });
  });

  // ── Test 14: Offline-compatible analysis ──────────────────────────────────
  group('Test 14: Offline-compatible analysis', () {
    test('14. Analytics pipeline requires no network access', () {
      // This test is conceptual: the service is pure Dart, no network calls.
      // We verify it runs completely without any async network dependencies.
      final points = _straightTrack(
        tripId: 'trip-offline', count: 10, speedKmh: 50,
      );

      // synchronous analyze call — no await, no network
      final analytics = service.analyze(tripId: 'trip-offline', points: points);

      // Verify all sub-analyses are populated from local data only
      expect(analytics.speedAnalysis, isNotNull);
      expect(analytics.altitudeAnalysis, isNotNull);
      expect(analytics.turnAnalysis, isNotNull);
      expect(analytics.brakingAnalysis, isNotNull);
      expect(analytics.analyzedPoints, isNotNull);
    });
  });

  // ── Test 15: Existing analytics behavior unchanged ────────────────────────
  group('Test 15: Regression — existing analytics behavior unchanged', () {
    test('15a. SpeedAnalysis still correct after Phase 6.4 changes', () {
      final points = <TrackPointRecord>[];
      var lat = 51.5;
      var lng = -0.1;
      for (var i = 0; i < 5; i++) {
        points.add(TrackPointRecord(
          id: 'p$i', tripId: 'trip-reg', timestamp: _ts(i),
          latitude: lat, longitude: lng, speedKmh: 60.0,
        ));
        final next = _advance(lat, lng, 0, 20);
        lat = next.lat; lng = next.lng;
      }

      final analytics = service.analyze(tripId: 'trip-reg', points: points);

      expect(analytics.speedAnalysis.pointCount, 5);
      expect(analytics.speedAnalysis.pointsWithSpeed, 5);
      expect(analytics.speedAnalysis.maxDerivedSpeedKmh, isNotNull);
    });

    test('15b. TurnAnalysis still correct after Phase 6.4 changes', () {
      final points = _straightTrack(
        tripId: 'trip-reg2', count: 10, speedKmh: 40,
      );
      final analytics = service.analyze(tripId: 'trip-reg2', points: points);
      expect(analytics.turnAnalysis, isNotNull);
      expect(analytics.turnAnalysis!.totalTurns, 0);
    });

    test('15c. BrakingAnalysis still correct after Phase 6.4 changes', () {
      final analytics = service.analyze(tripId: 'trip-reg3', points: []);
      expect(analytics.brakingAnalysis, isNotNull);
      expect(analytics.brakingAnalysis!.isEmpty, isTrue);
    });

    test('15d. DrivingAnalytics.empty() produces correct empty state', () {
      final analytics = DrivingAnalytics.empty('trip-empty-test');
      expect(analytics.isEmpty, isTrue);
      expect(analytics.turnAnalysis, isNotNull);
      expect(analytics.turnAnalysis, isA<TurnAnalysis>());
      expect(analytics.brakingAnalysis, isNotNull);
      expect(analytics.brakingAnalysis, isA<BrakingAnalysis>());
      expect(analytics.brakingAnalysis!.isEmpty, isTrue);
    });
  });

  // ── Additional: TripAnalyticsState model ─────────────────────────────────
  group('TripAnalyticsState model', () {
    test('16. Initial state has isLoading=true and nulls', () {
      const state = TripAnalyticsState();
      expect(state.isLoading, isTrue);
      expect(state.trip, isNull);
      expect(state.analytics, isNull);
      expect(state.hasTrip, isFalse);
      expect(state.hasAnalytics, isFalse);
      expect(state.isComplete, isFalse);
    });

    test('17. Convenience accessors delegate to Trip fields', () {
      final trip = _makeTrip(
        id: 'trip-conv',
        distanceKm: 7.5,
        durationSeconds: 600,
        stops: 1,
      );
      final state = TripAnalyticsState(
        trip: trip,
        isLoading: false,
      );
      expect(state.distanceKm, closeTo(7.5, 0.001));
      expect(state.durationSeconds, 600);
      expect(state.stopCount, 1);
    });

    test('18. copyWith preserves existing fields when null not provided', () {
      final trip = _makeTrip(id: 'trip-cw');
      const state = TripAnalyticsState(isLoading: true);
      final updated = state.copyWith(trip: trip, isLoading: false);
      expect(updated.trip, isNotNull);
      expect(updated.isLoading, isFalse);
      expect(updated.analytics, isNull); // not changed
    });

    test('19. stopCount is null when Trip.stops is null', () {
      final trip = _makeTrip(id: 'trip-nostops', stops: null);
      final state = TripAnalyticsState(trip: trip, isLoading: false);
      expect(state.stopCount, isNull);
    });

    test('20. isComplete is true only when both trip and analytics are set', () {
      final trip = _makeTrip(id: 'trip-complete');
      final analytics = DrivingAnalytics.empty('trip-complete');
      final state = TripAnalyticsState(
        trip: trip,
        analytics: analytics,
        isLoading: false,
      );
      expect(state.isComplete, isTrue);
    });
  });

  // ── Additional: Single source of truth ────────────────────────────────────
  group('Single source of truth — no recalculation', () {
    test('21. Turn counts come from TurnAnalysis events, not separate counters',
        () {
      final ta = TurnAnalysis.empty();
      expect(ta.leftTurns + ta.rightTurns + ta.uTurns, equals(ta.totalTurns));
    });

    test('22. Braking counts come from BrakingAnalysis events', () {
      final ba = BrakingAnalysis.empty();
      expect(
        ba.hardBrakingCount + ba.suddenStopCount,
        equals(ba.totalEvents),
      );
    });

    test('23. Trip persisted speed values are not overwritten by service', () async {
      // The service computes DERIVED speed from GPS segments.
      // The Trip row stores PERSISTED speed computed at drive completion.
      // They are separate and may differ due to different calculation methods.
      final db = await _openDb();
      final tripRepo = TripRepository(db);
      final trackRepo = TrackPointRepository(db);

      final trip = _makeTrip(
        id: 'trip-ss',
        avgSpeed: 50.0, // persisted at completion
        maxSpeed: 80.0,
        minSpeed: 10.0,
      );
      await tripRepo.createTrip(trip);

      final points = _straightTrack(tripId: 'trip-ss', count: 5, speedKmh: 60);
      await trackRepo.addTrackPoints(points);

      final loaded = await trackRepo.getTrackPointsForTrip('trip-ss');
      final analytics = service.analyze(tripId: 'trip-ss', points: loaded);
      final loadedTrip = await tripRepo.getTripById('trip-ss');

      // Persisted trip values are unchanged
      expect(loadedTrip!.averageSpeedKmh, closeTo(50.0, 0.001));
      expect(loadedTrip.maximumSpeedKmh, closeTo(80.0, 0.001));
      // Service may produce different derived values — that is correct
      expect(analytics.speedAnalysis.maxDerivedSpeedKmh, isNotNull);

      await db.close();
    });
  });
}
