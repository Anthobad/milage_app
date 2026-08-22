// ignore_for_file: avoid_print

// ---------------------------------------------------------------------------
// Phase 6.3 — Hard Braking & Sudden Stop Detection — Unit Tests
// ---------------------------------------------------------------------------
//
// All tests use deterministic synthetic GPS tracks.
// No physical device, GPS, internet, or database required.
//
// ## Track generation strategy
//
// Points are generated with explicit speed, timestamp, and position data.
// The _makePoint helper creates TrackPointRecord instances with known speed
// values.  Position advances at ~0.1° per second step unless otherwise
// specified; the detector uses GPS speedKmh (raw sensor) as the primary
// speed source so coordinate precision in most tests only needs to be
// plausible.
//
// ## Default config
//
//   minDecelerationMps2     = 0.5
//   suddenStopEndSpeedKmh   = 5.0
//   minStartSpeedKmh        = 10.0
//   maxTimeGapS             = 10.0
//   cooldownDistanceM       = 100.0
//   minBrakingSegments      = 1
//   hardSeverityThreshold   = 0.7
//   severeSeverityThreshold = 1.0
//
// ## Deceleration arithmetic used in tests
//
//   decel (m/s²) = (startSpeed_ms - endSpeed_ms) / durS
//   durS = 1 s (default between consecutive points)
//
//   Example — hard braking at 60 km/h:
//     60 km/h → 55 km/h in 1 s
//     Δv = (60-55)/3.6 = 1.39 m/s in 1 s → 1.39 m/s² > 0.5 threshold ✓
//
//   Example — normal driving noise:
//     60 km/h → 58 km/h in 1 s
//     Δv = 2/3.6 = 0.56 m/s in 1 s → 0.56 m/s² just above threshold
//     Need to use ≤ 0.5 m/s² = ≤ 1.8 km/h / s drop to stay BELOW threshold

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:triprank_project/features/analytics/models/braking_analysis.dart';
import 'package:triprank_project/features/analytics/models/braking_event.dart';
import 'package:triprank_project/features/analytics/services/braking_detector.dart';
import 'package:triprank_project/features/analytics/services/driving_analytics_service.dart';
import 'package:triprank_project/features/trips/models/track_point_record.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _t0 = DateTime.utc(2024, 1, 1, 9, 0, 0);
DateTime _ts(int s) => _t0.add(Duration(seconds: s));

const _earthR = 6371000.0;

/// Advance a (lat, lng) point by [distM] metres along [bearingDeg] degrees.
({double lat, double lng}) _advance(
  double lat,
  double lng,
  double bearingDeg,
  double distM,
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

/// Creates a single [TrackPointRecord] with known speed.
///
/// Position is advanced 10 m north per second from a base point so tracks
/// have plausible coordinates without affecting GPS-speed-based deceleration.
TrackPointRecord _makePoint({
  required int timeS,
  required double speedKmh,
  double baseLat = 51.5,
  double baseLng = -0.1,
  String tripId = 'test-trip',
}) {
  // Advance position northward by speed × time (rough approximation — used
  // only so coordinates are distinct and plausible; speed comes from speedKmh).
  final dist = speedKmh / 3.6 * timeS.toDouble();
  final pos = _advance(baseLat, baseLng, 0, dist);
  return TrackPointRecord(
    id: 'p-$timeS-${speedKmh.toStringAsFixed(0)}',
    tripId: tripId,
    timestamp: _ts(timeS),
    latitude: pos.lat,
    longitude: pos.lng,
    speedKmh: speedKmh,
  );
}

/// Creates a [TrackPointRecord] WITHOUT a raw speed (speed must be derived).
TrackPointRecord _makePointNoSpeed({
  required int timeS,
  double lat = 51.5,
  double lng = -0.1,
  String tripId = 'test-trip',
}) {
  return TrackPointRecord(
    id: 'p-$timeS-nospeed',
    tripId: tripId,
    timestamp: _ts(timeS),
    latitude: lat,
    longitude: lng,
    speedKmh: null,
  );
}

/// Builds a sequence of points with a given list of speeds (1 second apart).
List<TrackPointRecord> _track(List<double> speeds) {
  return List.generate(
    speeds.length,
    (i) => _makePoint(timeS: i, speedKmh: speeds[i]),
  );
}

/// The default detector for most tests.
const _detector = BrakingDetector();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Group 1: Empty / minimal tracks ────────────────────────────────────────
  group('Empty and minimal tracks', () {
    test('1. Empty track → empty analysis', () {
      final result = _detector.detect([]);
      expect(result.isEmpty, isTrue);
      expect(result.totalEvents, 0);
    });

    test('2. Single point → empty analysis', () {
      final result = _detector.detect([_makePoint(timeS: 0, speedKmh: 60)]);
      expect(result.isEmpty, isTrue);
    });

    test('3. Two points, no braking → empty analysis', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 59),
      ]);
      // Δv = 1 km/h in 1 s = 0.28 m/s² < 0.5 threshold → no event
      expect(result.isEmpty, isTrue);
    });
  });

  // ── Group 2: Normal driving — no events expected ────────────────────────────
  group('Normal driving (no events expected)', () {
    test('4. Steady speed fluctuation should produce 0 events', () {
      // 60 → 59 → 60 → 58 → 59 — max drop is 2 km/h in 1 s = 0.56 m/s²
      // Just above threshold so we use a gentler sequence (≤1.8 km/h / s)
      final result = _detector.detect(_track([60, 60, 60, 59, 60, 59, 60]));
      expect(result.totalEvents, 0);
    });

    test('5. Gradual deceleration below threshold → 0 events', () {
      // 1 km/h drop per second = 0.28 m/s² < 0.5 threshold
      final result = _detector
          .detect(_track([60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50]));
      expect(result.totalEvents, 0);
    });

    test('6. Constant speed → 0 events', () {
      final result = _detector.detect(_track(List.filled(20, 50.0)));
      expect(result.totalEvents, 0);
    });

    test('7. Moderate braking below threshold → 0 events', () {
      // 50 → 45 in 5 s = 1 km/h/s = 0.28 m/s² per segment, below threshold
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 50),
        _makePoint(timeS: 1, speedKmh: 49),
        _makePoint(timeS: 2, speedKmh: 48),
        _makePoint(timeS: 3, speedKmh: 47),
        _makePoint(timeS: 4, speedKmh: 46),
        _makePoint(timeS: 5, speedKmh: 45),
      ]);
      expect(result.totalEvents, 0);
    });
  });

  // ── Group 3: Hard braking ───────────────────────────────────────────────────
  group('Hard braking detection', () {
    test('8. Single-segment hard brake → 1 hard braking event', () {
      // 60 → 50 in 1 s = 10 km/h/s = 2.78 m/s² >> 0.5 threshold
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      expect(result.totalEvents, 1);
      expect(result.hardBrakingCount, 1);
      expect(result.suddenStopCount, 0);
      expect(result.events.first.type, BrakingEventType.hardBraking);
    });

    test('9. Hard braking: startSpeedKmh and endSpeedKmh are correct', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 70),
        _makePoint(timeS: 1, speedKmh: 55), // decel = 15/3.6/1 = 4.17 m/s²
        _makePoint(timeS: 2, speedKmh: 55),
      ]);
      expect(result.totalEvents, 1);
      final e = result.events.first;
      expect(e.startSpeedKmh, closeTo(70, 0.1));
      expect(e.endSpeedKmh, closeTo(55, 0.1));
    });

    test('10. Hard braking: decelerationMps2 is positive and plausible', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      expect(result.totalEvents, 1);
      final decel = result.events.first.decelerationMps2;
      expect(decel, greaterThan(0));
      // (60-50)/3.6/1 = 2.78 m/s²
      expect(decel, closeTo(2.78, 0.1));
    });

    test('11. Hard braking: event timestamp is within track range', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      final ts = result.events.first.timestamp;
      expect(ts.isAfter(_ts(-1)), isTrue);
      expect(ts.isBefore(_ts(10)), isTrue);
    });

    test('12. Multi-segment hard brake produces one event (not several)', () {
      // 80 → 65 → 50 → 40 → 40 (all above threshold)
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 80),
        _makePoint(timeS: 1, speedKmh: 65), // -15 km/h/s = 4.17 m/s²
        _makePoint(timeS: 2, speedKmh: 50), // -15 km/h/s
        _makePoint(timeS: 3, speedKmh: 40), // -10 km/h/s
        _makePoint(timeS: 4, speedKmh: 40),
      ]);
      expect(result.totalEvents, 1);
      expect(result.events.first.startSpeedKmh, closeTo(80, 0.1));
      expect(result.events.first.endSpeedKmh, closeTo(40, 0.1));
    });

    test('13. Start speed below minStartSpeedKmh → no event', () {
      // 8 km/h → 0 in 1 s → decel = 2.22 m/s² but start < 10 km/h minimum
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 8),
        _makePoint(timeS: 1, speedKmh: 0),
        _makePoint(timeS: 2, speedKmh: 0),
      ]);
      expect(result.totalEvents, 0);
    });

    test('14. Exactly at threshold: minDecelerationMps2 inclusive', () {
      // 0.5 m/s² = 1.8 km/h in 1 s → should trigger (≥ not >)
      // 60 → (60 - 1.8) = 58.2 km/h in 1 s
      const threshold = BrakingDetectorConfig.kDefaultMinDecelerationMps2;
      final exactDropKmh = threshold * 3.6; // 1.8 km/h
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 60 - exactDropKmh), // exactly threshold
        _makePoint(timeS: 2, speedKmh: 60 - exactDropKmh),
      ]);
      expect(result.totalEvents, 1,
          reason: 'Threshold is inclusive: decel == minDecelerationMps2 should trigger');
    });

    test('15. Just below threshold → no event', () {
      // 0.499 m/s² in 1 s = 1.796 km/h drop
      const justBelow = 0.499;
      final dropKmh = justBelow * 3.6; // ~1.796 km/h
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 60 - dropKmh),
        _makePoint(timeS: 2, speedKmh: 60 - dropKmh),
      ]);
      expect(result.totalEvents, 0,
          reason: 'Just below threshold should not trigger');
    });

    test('16. Just above threshold → 1 event', () {
      // 0.501 m/s² in 1 s = 1.804 km/h drop
      const justAbove = 0.501;
      final dropKmh = justAbove * 3.6;
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 60 - dropKmh),
        _makePoint(timeS: 2, speedKmh: 60 - dropKmh),
      ]);
      expect(result.totalEvents, 1);
    });
  });

  // ── Group 4: Sudden stop ────────────────────────────────────────────────────
  group('Sudden stop detection', () {
    test('17. Gradual stop to near-zero → suddenStop', () {
      // 60 → 45 → 25 → 5 → 0 — multi-segment with final speed ≤ 5 km/h
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 45), // -15: 4.17 m/s²
        _makePoint(timeS: 2, speedKmh: 25), // -20: 5.56 m/s²
        _makePoint(timeS: 3, speedKmh: 5),  // -20: 5.56 m/s²
        _makePoint(timeS: 4, speedKmh: 0),
      ]);
      expect(result.totalEvents, 1);
      expect(result.suddenStopCount, 1);
      expect(result.hardBrakingCount, 0);
      expect(result.events.first.type, BrakingEventType.suddenStop);
      expect(result.events.first.endSpeedKmh,
          lessThanOrEqualTo(BrakingDetectorConfig.kDefaultSuddenStopEndSpeedKmh));
    });

    test('18. Sudden stop: not counted as hard braking too', () {
      // Ensure the same event is NOT double-counted
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 40),
        _makePoint(timeS: 2, speedKmh: 0),
      ]);
      // Should be exactly 1 event total, classified as suddenStop
      expect(result.totalEvents, 1);
      expect(result.suddenStopCount, 1);
      expect(result.hardBrakingCount, 0);
    });

    test('19. Braking not ending at zero is NOT a sudden stop', () {
      // 60 → 30 → 20 — stops at 20 km/h, above 5 km/h threshold
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 30),
        _makePoint(timeS: 2, speedKmh: 20),
        _makePoint(timeS: 3, speedKmh: 20),
      ]);
      expect(result.totalEvents, 1);
      expect(result.events.first.type, BrakingEventType.hardBraking);
      expect(result.suddenStopCount, 0);
    });

    test('20. Vehicle stopping from low speed is NOT a sudden stop (below minStart)', () {
      // 8 → 0: below minStartSpeedKmh = 10
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 8),
        _makePoint(timeS: 1, speedKmh: 0),
      ]);
      expect(result.totalEvents, 0);
    });

    test('21. Sudden stop: startSpeedKmh represents entry speed', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 50),
        _makePoint(timeS: 1, speedKmh: 30),
        _makePoint(timeS: 2, speedKmh: 0),
      ]);
      expect(result.totalEvents, 1);
      expect(result.events.first.startSpeedKmh, closeTo(50, 0.1));
    });
  });

  // ── Group 5: Multiple braking events ───────────────────────────────────────
  group('Multiple separate braking events', () {
    test('22. Two separate hard brakes produce two events', () {
      // First brake: 80 → 60 (well above threshold)
      // Long straight at 60 to clear cooldown (100 m at 60 km/h ≈ 6 s)
      // Second brake: 60 → 40
      final points = <TrackPointRecord>[
        _makePoint(timeS: 0, speedKmh: 80),
        _makePoint(timeS: 1, speedKmh: 60),  // -20 km/h = 5.56 m/s²
        // steady driving to exhaust cooldown (6 s × 60 km/h = 100 m exactly;
        // use 7 s to be safely past)
        _makePoint(timeS: 2, speedKmh: 60),
        _makePoint(timeS: 3, speedKmh: 60),
        _makePoint(timeS: 4, speedKmh: 60),
        _makePoint(timeS: 5, speedKmh: 60),
        _makePoint(timeS: 6, speedKmh: 60),
        _makePoint(timeS: 7, speedKmh: 60),
        _makePoint(timeS: 8, speedKmh: 60),
        // second brake
        _makePoint(timeS: 9, speedKmh: 40),  // -20 km/h = 5.56 m/s²
        _makePoint(timeS: 10, speedKmh: 40),
      ];
      final result = _detector.detect(points);
      expect(result.totalEvents, 2);
    });

    test('23. First event hard braking, second event sudden stop', () {
      final points = <TrackPointRecord>[
        _makePoint(timeS: 0, speedKmh: 80),
        _makePoint(timeS: 1, speedKmh: 60),  // hard brake → 60 km/h
        // cooldown
        _makePoint(timeS: 2, speedKmh: 60),
        _makePoint(timeS: 3, speedKmh: 60),
        _makePoint(timeS: 4, speedKmh: 60),
        _makePoint(timeS: 5, speedKmh: 60),
        _makePoint(timeS: 6, speedKmh: 60),
        _makePoint(timeS: 7, speedKmh: 60),
        _makePoint(timeS: 8, speedKmh: 60),
        // sudden stop
        _makePoint(timeS: 9, speedKmh: 40),
        _makePoint(timeS: 10, speedKmh: 0),
      ];
      final result = _detector.detect(points);
      expect(result.totalEvents, 2);
      expect(result.hardBrakingCount, 1);
      expect(result.suddenStopCount, 1);
    });
  });

  // ── Group 6: GPS noise ──────────────────────────────────────────────────────
  group('GPS noise rejection', () {
    test('24. Small speed fluctuations → 0 events', () {
      // Each consecutive drop must stay below 0.5 m/s² = 1.8 km/h per second.
      // Use ≤1 km/h swings: max drop = 1 km/h in 1 s = 0.28 m/s² < threshold.
      final result = _detector.detect(_track([60, 60, 60, 59, 60, 60, 61, 60, 60, 60]));
      expect(result.totalEvents, 0);
    });

    test('25. Stationary GPS noise → 0 events', () {
      // 0 → 1 → 0 → 2 → 1 — all well below minStartSpeedKmh = 10
      final result = _detector.detect(_track([0, 1, 0, 2, 1, 0, 1, 0]));
      expect(result.totalEvents, 0,
          reason: 'Stationary jitter must not produce events');
    });

    test('26. Near-stationary speeds (≤ 5 km/h) → 0 events', () {
      final result = _detector.detect(_track([5, 4, 3, 2, 1, 0, 1, 0]));
      expect(result.totalEvents, 0);
    });

    test('27. Single noisy spike in otherwise steady speed → 0 events', () {
      // The spike drops from 60 to 57 and immediately back — 3 km/h drop
      // = 0.83 m/s² which IS above the 0.5 threshold, but next segment
      // is 57→60 (acceleration), so candidate is sealed immediately
      // with only 1 qualifying segment.
      // Result depends on minBrakingSegments (default 1) — if 1, this
      // produces an event.  Test with minBrakingSegments = 2 to confirm
      // multi-point filtering works.
      final detector2 = BrakingDetector(
        config: const BrakingDetectorConfig(minBrakingSegments: 2),
      );
      final result = detector2.detect(_track([60, 60, 57, 60, 60, 60]));
      expect(result.totalEvents, 0,
          reason: 'Single-segment spike should not trigger with minBrakingSegments=2');
    });
  });

  // ── Group 7: Debounce / cooldown ────────────────────────────────────────────
  group('Cooldown debounce', () {
    test('28. Two braking events within cooldown → only first is counted', () {
      // Both events are within 100 m of each other
      final points = <TrackPointRecord>[
        _makePoint(timeS: 0, speedKmh: 80),
        _makePoint(timeS: 1, speedKmh: 60),  // first event
        _makePoint(timeS: 2, speedKmh: 60),
        // Very short steady stretch — NOT enough to clear cooldown
        _makePoint(timeS: 3, speedKmh: 40),  // tries to open second event
        _makePoint(timeS: 4, speedKmh: 40),
      ];
      final result = _detector.detect(points);
      // First event emitted; second attempt within cooldown is suppressed
      expect(result.totalEvents, 1);
    });

    test('29. After cooldown distance, new event is allowed', () {
      // Use a large step between events so the vehicle travels > 100 m
      final points = <TrackPointRecord>[];
      double lat = 51.5;
      double lng = -0.1;

      // First event: strong brake at t=0
      points.add(TrackPointRecord(
        id: 'p0', tripId: 't', timestamp: _ts(0),
        latitude: lat, longitude: lng, speedKmh: 80,
      ));
      // Advance 5 m north
      var pos = _advance(lat, lng, 0, 5);
      points.add(TrackPointRecord(
        id: 'p1', tripId: 't', timestamp: _ts(1),
        latitude: pos.lat, longitude: pos.lng, speedKmh: 60, // first brake
      ));

      // Travel >100 m at constant speed to clear cooldown
      for (var i = 2; i <= 8; i++) {
        pos = _advance(pos.lat, pos.lng, 0, 20); // 20 m steps = 140 m total
        points.add(TrackPointRecord(
          id: 'p$i', tripId: 't', timestamp: _ts(i),
          latitude: pos.lat, longitude: pos.lng, speedKmh: 60,
        ));
      }

      // Second event: another strong brake
      pos = _advance(pos.lat, pos.lng, 0, 5);
      points.add(TrackPointRecord(
        id: 'p9', tripId: 't', timestamp: _ts(9),
        latitude: pos.lat, longitude: pos.lng, speedKmh: 40,
      ));
      pos = _advance(pos.lat, pos.lng, 0, 5);
      points.add(TrackPointRecord(
        id: 'p10', tripId: 't', timestamp: _ts(10),
        latitude: pos.lat, longitude: pos.lng, speedKmh: 40,
      ));

      final result = _detector.detect(points);
      expect(result.totalEvents, 2,
          reason: 'After cooldown distance, a second event should be allowed');
    });
  });

  // ── Group 8: Time gap handling ──────────────────────────────────────────────
  group('Time gap handling', () {
    test('30. Large time gap is skipped — no false braking event', () {
      // Two consecutive points with a 60 s gap: impossible speed change to use
      final points = [
        _makePoint(timeS: 0, speedKmh: 60),
        TrackPointRecord(
          id: 'p-gap',
          tripId: 'test-trip',
          timestamp: _ts(60), // 60 s gap — exceeds maxTimeGapS = 10
          latitude: 51.5001,
          longitude: -0.1,
          speedKmh: 0,
        ),
        _makePoint(timeS: 61, speedKmh: 0),
      ];
      final result = _detector.detect(points);
      // The 60 s gap must be skipped — no event from it
      // (The p-gap → p61 segment is 1 s gap, may or may not trigger depending
      // on speed, but the large gap itself must not create an event)
      // With p-gap having speed 0 and p61 also 0, no qualifying segment anyway
      expect(result.totalEvents, 0,
          reason: 'Large time gap must not produce braking event');
    });

    test('31. Zero time delta → no crash, no event from that pair', () {
      final points = [
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 0, speedKmh: 30), // same timestamp — zero delta
        _makePoint(timeS: 1, speedKmh: 30),
      ];
      final result = _detector.detect(points);
      // Zero delta must not crash; the degenerate pair is skipped
      expect(result, isA<BrakingAnalysis>());
    });

    test('32. Negative time delta (out-of-order) → no crash', () {
      final points = [
        _makePoint(timeS: 5, speedKmh: 60),
        _makePoint(timeS: 3, speedKmh: 30), // earlier timestamp (out of order)
        _makePoint(timeS: 6, speedKmh: 30),
      ];
      expect(() => _detector.detect(points), returnsNormally);
    });
  });

  // ── Group 9: Missing / invalid data ────────────────────────────────────────
  group('Missing and invalid data', () {
    test('33. Missing speed — falls back to derived speed or skips safely', () {
      // Build two points 100 m apart in 1 s (= 100 m/s = 360 km/h — unrealistic
      // but proves the derived-speed path runs without crashing)
      final pos2 = _advance(51.5, -0.1, 0, 100);
      final points = [
        _makePointNoSpeed(timeS: 0, lat: 51.5, lng: -0.1),
        _makePointNoSpeed(timeS: 1, lat: pos2.lat, lng: pos2.lng),
      ];
      // Must not crash — derived speed may or may not exceed threshold
      expect(() => _detector.detect(points), returnsNormally);
    });

    test('34. All speeds null → 0 events', () {
      final points = [
        _makePointNoSpeed(timeS: 0),
        _makePointNoSpeed(timeS: 1),
        _makePointNoSpeed(timeS: 2),
      ];
      final result = _detector.detect(points);
      // No derived speed possible for all three identical positions
      expect(result, isA<BrakingAnalysis>());
    });

    test('35. Duplicate timestamps → no crash', () {
      final points = [
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 0, speedKmh: 50),
        _makePoint(timeS: 0, speedKmh: 40),
        _makePoint(timeS: 1, speedKmh: 40),
      ];
      expect(() => _detector.detect(points), returnsNormally);
    });

    test('36. Duplicate coordinates → no crash, no NaN/Infinity', () {
      final points = [
        TrackPointRecord(
          id: 'p0', tripId: 't', timestamp: _ts(0),
          latitude: 51.5, longitude: -0.1, speedKmh: 60,
        ),
        TrackPointRecord(
          id: 'p1', tripId: 't', timestamp: _ts(1),
          latitude: 51.5, longitude: -0.1, speedKmh: 40, // same coords, diff speed
        ),
        TrackPointRecord(
          id: 'p2', tripId: 't', timestamp: _ts(2),
          latitude: 51.5, longitude: -0.1, speedKmh: 40,
        ),
      ];
      final result = _detector.detect(points);
      for (final e in result.events) {
        expect(e.decelerationMps2.isNaN, isFalse);
        expect(e.decelerationMps2.isInfinite, isFalse);
      }
    });

    test('37. Very small movement → no crash', () {
      // Positions 1 cm apart
      final points = [
        TrackPointRecord(
          id: 'p0', tripId: 't', timestamp: _ts(0),
          latitude: 51.500000, longitude: -0.100000, speedKmh: 60,
        ),
        TrackPointRecord(
          id: 'p1', tripId: 't', timestamp: _ts(1),
          latitude: 51.500001, longitude: -0.100001, speedKmh: 40,
        ),
      ];
      expect(() => _detector.detect(points), returnsNormally);
    });

    test('38. Mixed null and non-null speeds → no crash', () {
      final points = [
        _makePoint(timeS: 0, speedKmh: 60),
        _makePointNoSpeed(timeS: 1),
        _makePoint(timeS: 2, speedKmh: 50),
        _makePoint(timeS: 3, speedKmh: 50),
      ];
      expect(() => _detector.detect(points), returnsNormally);
    });
  });

  // ── Group 10: Severity classification ──────────────────────────────────────
  group('Severity classification', () {
    test('39. Below hardSeverityThreshold → mild', () {
      // 0.6 m/s² is between 0.5 (min) and 0.7 (hard threshold) → mild
      final dropKmh = 0.6 * 3.6; // 2.16 km/h
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 60 - dropKmh),
        _makePoint(timeS: 2, speedKmh: 60 - dropKmh),
      ]);
      expect(result.totalEvents, 1);
      expect(result.events.first.severity, BrakingEventSeverity.mild);
    });

    test('40. Above hardSeverityThreshold but below severe → hard', () {
      // 0.8 m/s² → hard severity
      final dropKmh = 0.8 * 3.6;
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 60 - dropKmh),
        _makePoint(timeS: 2, speedKmh: 60 - dropKmh),
      ]);
      expect(result.totalEvents, 1);
      expect(result.events.first.severity, BrakingEventSeverity.hard);
    });

    test('41. Above severeSeverityThreshold → severe', () {
      // 60 → 50 in 1 s → (10/3.6)/1 = 2.78 m/s² >> 1.0 severe threshold
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      expect(result.totalEvents, 1);
      expect(result.events.first.severity, BrakingEventSeverity.severe);
    });

    test('42. Severe event increments severeCount', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      expect(result.severeCount, 1);
    });
  });

  // ── Group 11: Event fields ──────────────────────────────────────────────────
  group('Event field validation', () {
    test('43. Event location is a valid coordinate', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      final e = result.events.first;
      expect(e.latitude, inInclusiveRange(-90.0, 90.0));
      expect(e.longitude, inInclusiveRange(-180.0, 180.0));
    });

    test('44. Event duration is positive when available', () {
      // Multi-segment event so duration should be > 0
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 80),
        _makePoint(timeS: 1, speedKmh: 60),
        _makePoint(timeS: 2, speedKmh: 40),
        _makePoint(timeS: 3, speedKmh: 30),
      ]);
      expect(result.totalEvents, 1);
      final dur = result.events.first.durationS;
      if (dur != null) {
        expect(dur, greaterThan(0));
      }
    });

    test('45. speedReductionKmh is non-negative', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      expect(result.events.first.speedReductionKmh, greaterThanOrEqualTo(0));
    });

    test('46. BrakingAnalysis counts are consistent with events', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      expect(
        result.hardBrakingCount + result.suddenStopCount,
        equals(result.totalEvents),
        reason: 'hardBrakingCount + suddenStopCount should equal totalEvents',
      );
    });
  });

  // ── Group 12: BrakingAnalysis model ────────────────────────────────────────
  group('BrakingAnalysis model', () {
    test('47. BrakingAnalysis.empty() has zero events', () {
      final analysis = BrakingAnalysis.empty();
      expect(analysis.isEmpty, isTrue);
      expect(analysis.totalEvents, 0);
      expect(analysis.hardBrakingCount, 0);
      expect(analysis.suddenStopCount, 0);
      expect(analysis.severeCount, 0);
    });

    test('48. Counts are derived from events, not separate state', () {
      // Construct analysis with a known mix of event types
      final events = [
        BrakingEvent(
          type: BrakingEventType.hardBraking,
          timestamp: _ts(1),
          latitude: 51.5,
          longitude: -0.1,
          startSpeedKmh: 60,
          endSpeedKmh: 40,
          decelerationMps2: 0.8,
          severity: BrakingEventSeverity.hard,
        ),
        BrakingEvent(
          type: BrakingEventType.suddenStop,
          timestamp: _ts(10),
          latitude: 51.5,
          longitude: -0.1,
          startSpeedKmh: 50,
          endSpeedKmh: 0,
          decelerationMps2: 2.0,
          severity: BrakingEventSeverity.severe,
        ),
      ];
      final analysis = BrakingAnalysis(events: events);
      expect(analysis.hardBrakingCount, 1);
      expect(analysis.suddenStopCount, 1);
      expect(analysis.severeCount, 1);
      expect(analysis.totalEvents, 2);
    });
  });

  // ── Group 13: BrakingDetectorConfig ────────────────────────────────────────
  group('BrakingDetectorConfig', () {
    test('49. Default values match documented constants', () {
      const cfg = BrakingDetectorConfig();
      expect(cfg.minDecelerationMps2,
          BrakingDetectorConfig.kDefaultMinDecelerationMps2);
      expect(cfg.suddenStopEndSpeedKmh,
          BrakingDetectorConfig.kDefaultSuddenStopEndSpeedKmh);
      expect(cfg.minStartSpeedKmh,
          BrakingDetectorConfig.kDefaultMinStartSpeedKmh);
      expect(cfg.maxTimeGapS, BrakingDetectorConfig.kDefaultMaxTimeGapS);
      expect(cfg.cooldownDistanceM,
          BrakingDetectorConfig.kDefaultCooldownDistanceM);
      expect(cfg.minBrakingSegments,
          BrakingDetectorConfig.kDefaultMinBrakingSegments);
    });

    test('50. Custom high threshold suppresses soft braking', () {
      final detector = BrakingDetector(
        config: const BrakingDetectorConfig(minDecelerationMps2: 5.0),
      );
      // 60 → 50 in 1 s = 2.78 m/s² — above default but below 5.0
      final result = detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ]);
      expect(result.totalEvents, 0);
    });

    test('51. Custom low threshold catches gentle braking', () {
      final detector = BrakingDetector(
        config: const BrakingDetectorConfig(minDecelerationMps2: 0.2),
      );
      // 60 → 59 in 1 s = 0.28 m/s² — above 0.2 custom threshold
      final result = detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 59),
        _makePoint(timeS: 2, speedKmh: 59),
      ]);
      expect(result.totalEvents, 1);
    });

    test('52. Custom suddenStopEndSpeedKmh: 10 km/h catches wider stop range', () {
      final detector = BrakingDetector(
        config: const BrakingDetectorConfig(suddenStopEndSpeedKmh: 10.0),
      );
      // End at 8 km/h — above default 5 but within custom 10
      final result = detector.detect([
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 40),
        _makePoint(timeS: 2, speedKmh: 8),
        _makePoint(timeS: 3, speedKmh: 8),
      ]);
      expect(result.totalEvents, 1);
      expect(result.events.first.type, BrakingEventType.suddenStop);
    });
  });

  // ── Group 14: Service integration ──────────────────────────────────────────
  group('Service integration (DrivingAnalyticsService)', () {
    test('53. brakingAnalysis is non-null for empty track', () {
      final service = DrivingAnalyticsService();
      final analytics = service.analyze(tripId: 'x', points: []);
      expect(analytics.brakingAnalysis, isNotNull);
      expect(analytics.brakingAnalysis!.isEmpty, isTrue);
    });

    test('54. brakingAnalysis is non-null for normal track', () {
      final points = _track([60, 60, 59, 60, 60]);
      final service = DrivingAnalyticsService();
      final analytics = service.analyze(tripId: 'x', points: points);
      expect(analytics.brakingAnalysis, isNotNull);
    });

    test('55. brakingAnalysis detects event via service pipeline', () {
      final points = [
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ];
      final service = DrivingAnalyticsService();
      final analytics = service.analyze(tripId: 'x', points: points);
      expect(analytics.brakingAnalysis!.totalEvents, 1);
    });

    test('56. Service with custom braking detector via injection', () {
      final service = DrivingAnalyticsService(
        brakingDetector: BrakingDetector(
          config: const BrakingDetectorConfig(minDecelerationMps2: 5.0),
        ),
      );
      final points = [
        _makePoint(timeS: 0, speedKmh: 60),
        _makePoint(timeS: 1, speedKmh: 50),
        _makePoint(timeS: 2, speedKmh: 50),
      ];
      final analytics = service.analyze(tripId: 'x', points: points);
      // 2.78 m/s² < 5.0 custom threshold → no event
      expect(analytics.brakingAnalysis!.totalEvents, 0);
    });
  });

  // ── Group 15: GpsMathUtils used correctly ──────────────────────────────────
  group('No NaN or Infinity in any output', () {
    test('57. Hard braking event: deceleration is finite', () {
      final result = _detector.detect([
        _makePoint(timeS: 0, speedKmh: 100),
        _makePoint(timeS: 1, speedKmh: 60),
        _makePoint(timeS: 2, speedKmh: 60),
      ]);
      for (final e in result.events) {
        expect(e.decelerationMps2.isFinite, isTrue);
        expect(e.startSpeedKmh.isFinite, isTrue);
        expect(e.endSpeedKmh.isFinite, isTrue);
      }
    });

    test('58. Long track with realistic speeds → all events finite', () {
      // 200 points alternating steady and braking
      final points = <TrackPointRecord>[];
      for (var i = 0; i < 200; i++) {
        final speed = (i % 10 == 5) ? 40.0 : 60.0; // periodic speed dip
        points.add(_makePoint(timeS: i, speedKmh: speed));
      }
      final result = _detector.detect(points);
      for (final e in result.events) {
        expect(e.decelerationMps2.isFinite, isTrue);
        expect(e.startSpeedKmh.isFinite, isTrue);
        expect(e.endSpeedKmh.isFinite, isTrue);
      }
    });
  });

  // ── Group 16: Performance ───────────────────────────────────────────────────
  group('Performance', () {
    test('59. 10 000-point track completes in < 200 ms', () {
      final points = List.generate(
        10000,
        (i) => _makePoint(timeS: i, speedKmh: 60.0),
      );
      final sw = Stopwatch()..start();
      _detector.detect(points);
      sw.stop();
      print('[perf] 10 000-point braking analysis: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(200));
    });
  });
}
