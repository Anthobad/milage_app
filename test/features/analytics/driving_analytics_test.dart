// ignore_for_file: avoid_print

// ---------------------------------------------------------------------------
// Phase 6.1 — Driving Analytics Foundation — Unit Tests
// ---------------------------------------------------------------------------
//
// All 28+ required test cases from the spec §21, plus additional coverage.
//
// No physical device, GPS, internet, or map tiles required.
// The analytics service and GPS math utils are pure Dart — no DB needed.
//
// Test groups:
//   1. Basic input (tests 1–4)
//   2. Ordering (tests 5–7)
//   3. Distance (tests 8–10)
//   4. Time (tests 11–13)
//   5. Speed (tests 14–17)
//   6. Acceleration (tests 18–20)
//   7. Altitude (tests 21–23)
//   8. Heading (tests 24–25)
//   9. Data quality (tests 26–27)
//  10. Performance (test 28)
//  11. Additional GpsMathUtils unit tests

import 'package:flutter_test/flutter_test.dart';

import 'package:triprank_project/features/analytics/models/driving_analytics.dart';
import 'package:triprank_project/features/analytics/services/driving_analytics_service.dart';
import 'package:triprank_project/features/analytics/services/gps_math_utils.dart';
import 'package:triprank_project/features/trips/models/track_point_record.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a minimal [TrackPointRecord] with required lat/lng/timestamp.
TrackPointRecord _pt({
  required String id,
  String tripId = 'trip-1',
  required DateTime timestamp,
  required double lat,
  required double lng,
  double? altitude,
  double? speedKmh,
  double? accuracyM,
  double? headingDegrees,
}) {
  return TrackPointRecord(
    id: id,
    tripId: tripId,
    timestamp: timestamp,
    latitude: lat,
    longitude: lng,
    altitude: altitude,
    speedKmh: speedKmh,
    accuracyM: accuracyM,
    headingDegrees: headingDegrees,
  );
}

final _t0 = DateTime.utc(2024, 1, 1, 9, 0, 0);

DateTime _ts(int secondsAfterT0) =>
    _t0.add(Duration(seconds: secondsAfterT0));

const _service = DrivingAnalyticsService();

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Group 1: Basic input
  // ──────────────────────────────────────────────────────────────────────────
  group('Basic input', () {
    // Test 1
    test('1. Empty track returns a valid empty analytics result', () {
      final result = _service.analyze(tripId: 'trip-empty', points: []);

      expect(result, isA<DrivingAnalytics>());
      expect(result.tripId, equals('trip-empty'));
      expect(result.isEmpty, isTrue);
      expect(result.pointCount, equals(0));
      expect(result.analyzedPoints, isEmpty);
      expect(result.speedAnalysis.pointCount, equals(0));
      expect(result.altitudeAnalysis.pointCount, equals(0));
    });

    // Test 2
    test('2. One track point does not crash', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result, isA<DrivingAnalytics>());
      expect(result.pointCount, equals(1));
      // First point has no segment values
      final p = result.analyzedPoints.first;
      expect(p.segmentDistanceM, isNull);
      expect(p.segmentDurationS, isNull);
      expect(p.derivedSpeedMs, isNull);
    });

    // Test 3
    test('3. Two valid points process successfully', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5000, lng: -0.1),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.5001, lng: -0.1),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result.pointCount, equals(2));
      final second = result.analyzedPoints[1];
      expect(second.segmentDistanceM, isNotNull);
      expect(second.segmentDistanceM, greaterThan(0));
      expect(second.segmentDurationS, closeTo(10.0, 0.01));
      expect(second.derivedSpeedMs, isNotNull);
      expect(second.derivedSpeedKmh, isNotNull);
    });

    // Test 4
    test('4. Multiple chronological points process successfully', () {
      final points = List.generate(10, (i) {
        return _pt(
          id: 'p${i + 1}',
          timestamp: _ts(i * 5),
          lat: 51.5 + i * 0.001,
          lng: -0.1,
          speedKmh: 30.0 + i.toDouble(),
          altitude: 100.0 + i.toDouble(),
        );
      });

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result.pointCount, equals(10));
      // 9 segments (indices 1–9) have segment values; first has null
      expect(result.analyzedPoints.first.segmentDistanceM, isNull);
      for (var i = 1; i < result.analyzedPoints.length; i++) {
        expect(result.analyzedPoints[i].segmentDistanceM, isNotNull);
        expect(result.analyzedPoints[i].segmentDurationS, closeTo(5.0, 0.01));
      }
      expect(result.speedAnalysis.pointCount, equals(10));
      expect(result.altitudeAnalysis.pointsWithAltitude, equals(10));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 2: Ordering
  // ──────────────────────────────────────────────────────────────────────────
  group('Ordering', () {
    // Test 5
    test('5. Out-of-order timestamps are sorted and handled safely', () {
      // Points given in reverse chronological order
      final points = [
        _pt(id: 'p3', timestamp: _ts(20), lat: 51.502, lng: -0.1),
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.500, lng: -0.1),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.501, lng: -0.1),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result.pointCount, equals(3));
      // After sorting, all segment durations should be positive
      for (var i = 1; i < result.analyzedPoints.length; i++) {
        final dur = result.analyzedPoints[i].segmentDurationS;
        expect(dur, isNotNull);
        expect(dur!, greaterThan(0));
      }
      // First point after sorting should be the earliest timestamp
      expect(result.analyzedPoints.first.id, equals('p1'));
    });

    // Test 6
    test('6. Duplicate timestamps do not cause division-by-zero', () {
      final sameTime = _ts(0);
      final points = [
        _pt(id: 'p1', timestamp: sameTime, lat: 51.5, lng: -0.1),
        _pt(id: 'p2', timestamp: sameTime, lat: 51.5, lng: -0.1),
        _pt(id: 'p3', timestamp: _ts(10), lat: 51.501, lng: -0.1),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      // Must not throw or produce NaN/Infinity
      expect(result, isA<DrivingAnalytics>());
      for (final p in result.analyzedPoints) {
        if (p.derivedSpeedMs != null) {
          expect(p.derivedSpeedMs!.isNaN, isFalse);
          expect(p.derivedSpeedMs!.isInfinite, isFalse);
        }
        if (p.accelerationMps2 != null) {
          expect(p.accelerationMps2!.isNaN, isFalse);
          expect(p.accelerationMps2!.isInfinite, isFalse);
        }
      }
    });

    // Test 7
    test('7. Invalid (zero/negative) intervals do not crash', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(10), lat: 51.5, lng: -0.1),
        // Timestamp before p1 — negative delta after sort
        _pt(id: 'p2', timestamp: _ts(0), lat: 51.501, lng: -0.1),
      ];

      expect(
        () => _service.analyze(tripId: 'trip-1', points: points),
        returnsNormally,
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 3: Distance
  // ──────────────────────────────────────────────────────────────────────────
  group('Distance', () {
    // Test 8
    test('8. Known coordinate pairs produce reasonable distances', () {
      // London (51.5074, -0.1278) to Oxford (51.7520, -1.2577)
      // Straight-line haversine ≈ 82–85 km
      final dist = GpsMathUtils.distanceMetres(
        51.5074, -0.1278, // London
        51.7520, -1.2577, // Oxford
      );

      expect(dist, greaterThan(80000));
      expect(dist, lessThan(90000));
    });

    // Test 9
    test('9. Identical coordinates produce zero distance', () {
      final dist = GpsMathUtils.distanceMetres(51.5, -0.1, 51.5, -0.1);
      expect(dist, equals(0.0));
    });

    // Test 10
    test('10. Very small movements are handled safely (sub-metre)', () {
      // ~0.000001° latitude ≈ 0.11 m
      final dist = GpsMathUtils.distanceMetres(
        51.500000, -0.1,
        51.500001, -0.1,
      );
      expect(dist, isA<double>());
      expect(dist.isNaN, isFalse);
      expect(dist.isInfinite, isFalse);
      expect(dist, greaterThanOrEqualTo(0.0));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 4: Time
  // ──────────────────────────────────────────────────────────────────────────
  group('Time', () {
    // Test 11
    test('11. Normal timestamp difference returns correct seconds', () {
      final from = DateTime.utc(2024, 1, 1, 9, 0, 0);
      final to = DateTime.utc(2024, 1, 1, 9, 0, 30);

      final dt = GpsMathUtils.timeDeltaSeconds(from, to);

      expect(dt, isNotNull);
      expect(dt!, closeTo(30.0, 0.001));
    });

    // Test 12
    test('12. Zero time difference returns null (not 0, to prevent /0)', () {
      final t = DateTime.utc(2024, 1, 1, 9, 0, 0);
      final dt = GpsMathUtils.timeDeltaSeconds(t, t);

      expect(dt, isNull);
    });

    // Test 13
    test('13. Negative time difference returns null', () {
      final from = DateTime.utc(2024, 1, 1, 9, 0, 30);
      final to = DateTime.utc(2024, 1, 1, 9, 0, 0); // earlier!

      final dt = GpsMathUtils.timeDeltaSeconds(from, to);

      expect(dt, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 5: Speed
  // ──────────────────────────────────────────────────────────────────────────
  group('Speed', () {
    // Test 14
    test('14. Valid speed data is processed and aggregated', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.500, lng: -0.1, speedKmh: 30),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.501, lng: -0.1, speedKmh: 60),
        _pt(id: 'p3', timestamp: _ts(20), lat: 51.502, lng: -0.1, speedKmh: 90),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result.speedAnalysis.pointsWithSpeed, equals(3));
      expect(result.speedAnalysis.maxDerivedSpeedKmh, isNotNull);
      expect(result.speedAnalysis.maxDerivedSpeedKmh!, greaterThan(0));
    });

    // Test 15
    test('15. Missing speed does not crash (null speedKmh)', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.501, lng: -0.1),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result, isA<DrivingAnalytics>());
      expect(result.speedAnalysis.pointsWithSpeed, equals(0));
      // Derived speed is still computed from distance/time even without GPS speed
      expect(result.analyzedPoints[1].derivedSpeedMs, isNotNull);
    });

    // Test 16
    test('16. Zero speed is handled correctly', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1, speedKmh: 0),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.5, lng: -0.1, speedKmh: 0),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      // Zero derived speed should not appear in minDerivedSpeedKmh (moving only)
      expect(result.speedAnalysis.minDerivedSpeedKmh, isNull);
      expect(result, isA<DrivingAnalytics>());
    });

    // Test 17
    test('17. Speed changes can be derived between consecutive valid segments',
        () {
      // Three points: stationary → moving → faster
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5000, lng: -0.1),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.5005, lng: -0.1),
        _pt(id: 'p3', timestamp: _ts(20), lat: 51.5015, lng: -0.1),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      // p3 should have a speed change (derived speed differs from p2→p3 vs p1→p2)
      final p3 = result.analyzedPoints[2];
      expect(p3.speedChangeMps, isNotNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 6: Acceleration
  // ──────────────────────────────────────────────────────────────────────────
  group('Acceleration', () {
    // Test 18
    test('18. Positive acceleration is calculated correctly', () {
      // 10 m/s speed increase over 5 s → 2 m/s²
      final a = GpsMathUtils.accelerationMps2(10.0, 5.0);
      expect(a, isNotNull);
      expect(a!, closeTo(2.0, 0.001));
    });

    // Test 19
    test('19. Negative acceleration (deceleration) is calculated correctly',
        () {
      // −8 m/s speed change over 4 s → −2 m/s²
      final a = GpsMathUtils.accelerationMps2(-8.0, 4.0);
      expect(a, isNotNull);
      expect(a!, closeTo(-2.0, 0.001));
    });

    // Test 20
    test('20. Zero time delta does not produce Infinity or NaN', () {
      final a = GpsMathUtils.accelerationMps2(10.0, 0.0);
      expect(a, isNull); // safe: returns null instead of Inf
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 7: Altitude
  // ──────────────────────────────────────────────────────────────────────────
  group('Altitude', () {
    // Test 21
    test('21. Valid altitude data is handled', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1, altitude: 100),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.501, lng: -0.1, altitude: 120),
        _pt(id: 'p3', timestamp: _ts(20), lat: 51.502, lng: -0.1, altitude: 90),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result.altitudeAnalysis.pointsWithAltitude, equals(3));
      expect(result.altitudeAnalysis.minAltitudeM, closeTo(90, 0.01));
      expect(result.altitudeAnalysis.maxAltitudeM, closeTo(120, 0.01));
      expect(result.altitudeAnalysis.altitudeRangeM, closeTo(30, 0.01));
      expect(result.altitudeAnalysis.totalElevationGainM, closeTo(20, 0.01));
      expect(result.altitudeAnalysis.totalElevationLossM, closeTo(30, 0.01));
    });

    // Test 22
    test('22. Missing altitude is handled gracefully', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.501, lng: -0.1),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result.altitudeAnalysis.pointsWithAltitude, equals(0));
      expect(result.altitudeAnalysis.minAltitudeM, isNull);
      expect(result.altitudeAnalysis.maxAltitudeM, isNull);
      expect(result.altitudeAnalysis.isEmpty, isTrue);
    });

    // Test 23
    test('23. Null altitude is never silently converted to zero', () {
      final change = GpsMathUtils.altitudeChangeMetre(null, 100.0);
      expect(change, isNull); // NOT 100 (which would imply "from 0 m")

      final change2 = GpsMathUtils.altitudeChangeMetre(100.0, null);
      expect(change2, isNull);

      final change3 = GpsMathUtils.altitudeChangeMetre(null, null);
      expect(change3, isNull);

      // In the analytics result, a point with null altitude keeps it null
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.501, lng: -0.1),
      ];
      final result = _service.analyze(tripId: 'trip-1', points: points);
      expect(result.analyzedPoints.first.altitude, isNull);
      expect(result.analyzedPoints[1].altitudeChangeMetre, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 8: Heading
  // ──────────────────────────────────────────────────────────────────────────
  group('Heading', () {
    // Test 24
    test('24. Valid heading is preserved in analyzed points', () {
      final points = [
        _pt(
            id: 'p1',
            timestamp: _ts(0),
            lat: 51.5,
            lng: -0.1,
            headingDegrees: 0),
        _pt(
            id: 'p2',
            timestamp: _ts(10),
            lat: 51.501,
            lng: -0.1,
            headingDegrees: 30),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result.analyzedPoints.first.headingDegrees, closeTo(0, 0.001));
      expect(result.analyzedPoints[1].headingDegrees, closeTo(30, 0.001));
      expect(result.analyzedPoints[1].headingChangeDeg, closeTo(30, 0.001));
    });

    // Test 25
    test('25. Null heading is handled without crash or fabrication', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.501, lng: -0.1),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      expect(result.analyzedPoints.first.headingDegrees, isNull);
      expect(result.analyzedPoints[1].headingDegrees, isNull);
      expect(result.analyzedPoints[1].headingChangeDeg, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 9: Data quality
  // ──────────────────────────────────────────────────────────────────────────
  group('Data quality', () {
    // Test 26
    test('26. Single point with all nullable fields does not crash', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1),
      ];

      expect(
        () => _service.analyze(tripId: 'trip-1', points: points),
        returnsNormally,
      );
    });

    // Test 27
    test('27. NaN and Infinity are not produced in the analytics result', () {
      // Pathological case: duplicate timestamps → zero time delta
      final t = _ts(0);
      final points = [
        _pt(id: 'p1', timestamp: t, lat: 51.5, lng: -0.1, speedKmh: 60),
        _pt(id: 'p2', timestamp: t, lat: 51.501, lng: -0.1, speedKmh: 0),
        _pt(id: 'p3', timestamp: _ts(5), lat: 51.502, lng: -0.1, speedKmh: 30),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);

      // Validate every numeric field in every analyzed point
      for (final p in result.analyzedPoints) {
        _assertNoNaNOrInfinity(p.segmentDistanceM, 'segmentDistanceM');
        _assertNoNaNOrInfinity(p.segmentDurationS, 'segmentDurationS');
        _assertNoNaNOrInfinity(p.derivedSpeedMs, 'derivedSpeedMs');
        _assertNoNaNOrInfinity(p.derivedSpeedKmh, 'derivedSpeedKmh');
        _assertNoNaNOrInfinity(p.speedChangeMps, 'speedChangeMps');
        _assertNoNaNOrInfinity(p.accelerationMps2, 'accelerationMps2');
        _assertNoNaNOrInfinity(p.headingChangeDeg, 'headingChangeDeg');
        _assertNoNaNOrInfinity(p.altitudeChangeMetre, 'altitudeChangeMetre');
      }
      // Validate aggregated analyses
      _assertNoNaNOrInfinity(
          result.speedAnalysis.maxDerivedSpeedKmh, 'maxDerivedSpeedKmh');
      _assertNoNaNOrInfinity(
          result.speedAnalysis.minDerivedSpeedKmh, 'minDerivedSpeedKmh');
      _assertNoNaNOrInfinity(
          result.speedAnalysis.avgDerivedSpeedKmh, 'avgDerivedSpeedKmh');
      _assertNoNaNOrInfinity(
          result.speedAnalysis.totalDistanceM, 'totalDistanceM');
      _assertNoNaNOrInfinity(
          result.altitudeAnalysis.minAltitudeM, 'minAltitudeM');
      _assertNoNaNOrInfinity(
          result.altitudeAnalysis.maxAltitudeM, 'maxAltitudeM');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 10: Performance
  // ──────────────────────────────────────────────────────────────────────────
  group('Performance', () {
    // Test 28
    test('28. 10 000-point track can be analyzed in reasonable time', () {
      const n = 10000;
      final points = List.generate(n, (i) {
        return _pt(
          id: 'p${i + 1}',
          timestamp: _ts(i),
          lat: 51.5 + i * 0.00001,
          lng: -0.1 + i * 0.00001,
          altitude: 100.0 + (i % 50),
          speedKmh: 30.0 + (i % 10),
          headingDegrees: (i * 5.0) % 360,
        );
      });

      final sw = Stopwatch()..start();
      final result = _service.analyze(tripId: 'trip-perf', points: points);
      sw.stop();

      expect(result.pointCount, equals(n));
      expect(result.speedAnalysis.pointCount, equals(n));
      expect(result.altitudeAnalysis.pointsWithAltitude, equals(n));

      // Should complete well within 5 seconds on any modern device/CI
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: 'Analysis of $n points took ${sw.elapsedMilliseconds} ms');
      print('[perf] Analyzed $n points in ${sw.elapsedMilliseconds} ms');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 11: GpsMathUtils unit tests (additional granular coverage)
  // ──────────────────────────────────────────────────────────────────────────
  group('GpsMathUtils', () {
    test('derivedSpeedMs: 100 m in 10 s = 10 m/s', () {
      expect(GpsMathUtils.derivedSpeedMs(100, 10), closeTo(10.0, 0.001));
    });

    test('derivedSpeedMs: null distance returns null', () {
      expect(GpsMathUtils.derivedSpeedMs(null, 10), isNull);
    });

    test('derivedSpeedMs: null duration returns null', () {
      expect(GpsMathUtils.derivedSpeedMs(100, null), isNull);
    });

    test('derivedSpeedMs: zero duration returns null (no division by zero)',
        () {
      expect(GpsMathUtils.derivedSpeedMs(100, 0), isNull);
    });

    test('speedMsToKmh: 10 m/s = 36 km/h', () {
      expect(GpsMathUtils.speedMsToKmh(10), closeTo(36.0, 0.001));
    });

    test('speedKmhToMs: 36 km/h = 10 m/s', () {
      expect(GpsMathUtils.speedKmhToMs(36), closeTo(10.0, 0.001));
    });

    test('speedMsToKmh: null returns null', () {
      expect(GpsMathUtils.speedMsToKmh(null), isNull);
    });

    test('headingChangeDegrees: 350° → 10° = +20° (short right)', () {
      expect(GpsMathUtils.headingChangeDegrees(350, 10), closeTo(20, 0.001));
    });

    test('headingChangeDegrees: 10° → 350° = −20° (short left)', () {
      expect(GpsMathUtils.headingChangeDegrees(10, 350), closeTo(-20, 0.001));
    });

    test('headingChangeDegrees: 0° → 180° = +180° (straight reverse)', () {
      final change = GpsMathUtils.headingChangeDegrees(0, 180);
      expect(change, isNotNull);
      // 180 normalises to ±180 — both are acceptable; must be finite
      expect(change!.abs(), closeTo(180, 0.001));
    });

    test('headingChangeDegrees: null inputs return null', () {
      expect(GpsMathUtils.headingChangeDegrees(null, 90), isNull);
      expect(GpsMathUtils.headingChangeDegrees(90, null), isNull);
    });

    test('bearingDegrees: identical points return null', () {
      expect(GpsMathUtils.bearingDegrees(51.5, -0.1, 51.5, -0.1), isNull);
    });

    test('bearingDegrees: north is ~0°', () {
      // Moving north (increasing latitude, same longitude)
      final b = GpsMathUtils.bearingDegrees(51.5, -0.1, 51.6, -0.1);
      expect(b, isNotNull);
      expect(b!, closeTo(0.0, 1.0)); // within 1°
    });

    test('bearingDegrees: east is ~90°', () {
      // Moving east (increasing longitude, same latitude)
      final b = GpsMathUtils.bearingDegrees(51.5, -0.1, 51.5, 0.0);
      expect(b, isNotNull);
      expect(b!, closeTo(90.0, 2.0)); // within 2°
    });

    test('isValid: returns false for null', () {
      expect(GpsMathUtils.isValid(null), isFalse);
    });

    test('isValid: returns false for NaN', () {
      expect(GpsMathUtils.isValid(double.nan), isFalse);
    });

    test('isValid: returns false for infinity', () {
      expect(GpsMathUtils.isValid(double.infinity), isFalse);
    });

    test('isValid: returns true for normal double', () {
      expect(GpsMathUtils.isValid(3.14), isTrue);
    });

    test('altitudeChangeMetre: 100 → 150 = +50 m', () {
      expect(GpsMathUtils.altitudeChangeMetre(100, 150), closeTo(50, 0.001));
    });

    test('altitudeChangeMetre: 150 → 100 = −50 m (descending)', () {
      expect(GpsMathUtils.altitudeChangeMetre(150, 100), closeTo(-50, 0.001));
    });

    test('altitudeChangeMetre: null from returns null', () {
      expect(GpsMathUtils.altitudeChangeMetre(null, 100), isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 12: Additional service integration tests
  // ──────────────────────────────────────────────────────────────────────────
  group('DrivingAnalytics.empty factory', () {
    test('empty factory produces valid zero-state', () {
      final empty = DrivingAnalytics.empty('trip-x');
      expect(empty.tripId, equals('trip-x'));
      expect(empty.isEmpty, isTrue);
      expect(empty.analyzedPoints, isEmpty);
      expect(empty.speedAnalysis.pointCount, equals(0));
      expect(empty.altitudeAnalysis.pointCount, equals(0));
    });
  });

  group('Elevation gain/loss accumulation', () {
    test('Gain and loss are computed independently', () {
      final points = [
        _pt(id: 'p1', timestamp: _ts(0), lat: 51.5, lng: -0.1, altitude: 100),
        _pt(id: 'p2', timestamp: _ts(10), lat: 51.501, lng: -0.1, altitude: 150),
        _pt(id: 'p3', timestamp: _ts(20), lat: 51.502, lng: -0.1, altitude: 130),
        _pt(id: 'p4', timestamp: _ts(30), lat: 51.503, lng: -0.1, altitude: 180),
      ];

      final result = _service.analyze(tripId: 'trip-1', points: points);
      final alt = result.altitudeAnalysis;

      // Gains: +50 (100→150), +50 (130→180) = 100 m
      expect(alt.totalElevationGainM, closeTo(100, 0.01));
      // Losses: 20 (150→130)
      expect(alt.totalElevationLossM, closeTo(20, 0.01));
    });
  });

  group('tripId propagated correctly', () {
    test('tripId is passed through to DrivingAnalytics', () {
      const id = 'my-unique-trip-id';
      final result = _service.analyze(tripId: id, points: []);
      expect(result.tripId, equals(id));
    });
  });
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Asserts that [value] is either null or a finite, non-NaN double.
void _assertNoNaNOrInfinity(double? value, String fieldName) {
  if (value == null) return;
  expect(value.isNaN, isFalse,
      reason: '$fieldName must not be NaN, got: $value');
  expect(value.isInfinite, isFalse,
      reason: '$fieldName must not be Infinite, got: $value');
}
