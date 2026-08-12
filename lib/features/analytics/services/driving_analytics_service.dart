// ---------------------------------------------------------------------------
// DrivingAnalyticsService — Phase 6.1 Foundation
// ---------------------------------------------------------------------------
//
// The analytics engine that processes a list of persisted GPS track points
// and produces a [DrivingAnalytics] result.
//
// ## Responsibilities
//
//   1. Accept a list of [TrackPointRecord]s and a trip ID.
//   2. Sort the points chronologically (authoritative order by timestamp).
//   3. Compute per-segment derived values (distance, duration, speed,
//      acceleration, heading change, altitude change) using [GpsMathUtils].
//   4. Aggregate speed and altitude analyses.
//   5. Return a structured, immutable [DrivingAnalytics] result.
//
// ## What this service does NOT do
//
//   - Turn detection       (Phase 6.2)
//   - Braking detection    (Phase 6.3)
//   - Driving score        (Phase 6.4)
//   - UI rendering
//   - Database access
//   - Network access
//   - Riverpod state management
//
// ## Performance
//
//   Single pass over the sorted list: O(n).
//   No nested loops.  No repeated allocations inside the hot path.
//
// ## Safety
//
//   Never throws on malformed data.
//   Returns [DrivingAnalytics.empty] for empty input.

import '../models/altitude_analysis.dart';
import '../models/analyzed_track_point.dart';
import '../models/driving_analytics.dart';
import '../models/speed_analysis.dart';
import 'gps_math_utils.dart';
import '../../trips/models/track_point_record.dart';

/// Plain Dart service that processes GPS track points into [DrivingAnalytics].
///
/// No Flutter, no Riverpod, no database.  Fully testable in a plain Dart VM.
///
/// ## Usage
///
/// ```dart
/// final service = DrivingAnalyticsService();
/// final analytics = service.analyze(tripId: trip.id, points: trackPoints);
/// ```
class DrivingAnalyticsService {
  const DrivingAnalyticsService();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Analyzes a list of [TrackPointRecord]s and returns [DrivingAnalytics].
  ///
  /// [tripId] — the trip these points belong to.
  /// [points] — raw GPS track points from the database (any order).
  ///
  /// Returns [DrivingAnalytics.empty] when [points] is empty.
  /// Never throws.
  DrivingAnalytics analyze({
    required String tripId,
    required List<TrackPointRecord> points,
  }) {
    if (points.isEmpty) {
      return DrivingAnalytics.empty(tripId);
    }

    // ── Step 1: sort chronologically ───────────────────────────────────────
    // Timestamp is the authoritative ordering field per spec §4.
    final sorted = List<TrackPointRecord>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // ── Step 2: single-pass derivation ─────────────────────────────────────
    final analyzedPoints = <AnalyzedTrackPoint>[];

    // Speed accumulators
    double totalDistanceM = 0;
    double movingDurationS = 0;
    double? maxDerivedSpeedKmh;
    double? minDerivedSpeedKmh; // non-zero moving segments only
    double sumMovingSpeedKmh = 0;
    int movingSegments = 0;
    int pointsWithSpeed = 0;
    double? maxSpeedChangeMps;
    double? prevDerivedSpeedMs;

    // Altitude accumulators
    double? minAltitudeM;
    double? maxAltitudeM;
    double totalGainM = 0;
    double totalLossM = 0;
    int pointsWithAlt = 0;

    for (var i = 0; i < sorted.length; i++) {
      final cur = sorted[i];

      // ── Altitude coverage ────────────────────────────────────────────────
      final curAlt = cur.altitude;
      if (curAlt != null) {
        pointsWithAlt++;
        final curMin = minAltitudeM;
        final curMax = maxAltitudeM;
        minAltitudeM = curMin == null ? curAlt : (curAlt < curMin ? curAlt : curMin);
        maxAltitudeM = curMax == null ? curAlt : (curAlt > curMax ? curAlt : curMax);
      }

      // ── Speed coverage (raw GPS speed) ───────────────────────────────────
      if (cur.speedKmh != null) pointsWithSpeed++;

      if (i == 0) {
        // First point — no segment values
        analyzedPoints.add(_buildFirstPoint(cur));
        continue;
      }

      final prev = sorted[i - 1];

      // ── Segment geometry ─────────────────────────────────────────────────
      final distM = GpsMathUtils.distanceMetres(
        prev.latitude, prev.longitude,
        cur.latitude, cur.longitude,
      );

      final durS = GpsMathUtils.timeDeltaSeconds(
        prev.timestamp, cur.timestamp,
      );

      // ── Derived speed ────────────────────────────────────────────────────
      final spdMs = GpsMathUtils.derivedSpeedMs(distM, durS);
      final spdKmh = GpsMathUtils.speedMsToKmh(spdMs);

      // ── Speed accumulation ───────────────────────────────────────────────
      if (spdKmh != null && durS != null && durS > 0) {
        totalDistanceM += distM;
        if (spdKmh > 0) {
          // Moving segment
          movingDurationS += durS;
          sumMovingSpeedKmh += spdKmh;
          movingSegments++;
          final curMax = maxDerivedSpeedKmh;
          maxDerivedSpeedKmh =
              curMax == null ? spdKmh : (spdKmh > curMax ? spdKmh : curMax);
          final curMin = minDerivedSpeedKmh;
          if (curMin == null || spdKmh < curMin) {
            minDerivedSpeedKmh = spdKmh;
          }
        }
      }

      // ── Speed change & acceleration ──────────────────────────────────────
      double? speedChangeMps;
      double? accelMps2;
      final prevSpd = prevDerivedSpeedMs;
      if (spdMs != null && prevSpd != null) {
        speedChangeMps = spdMs - prevSpd;
        accelMps2 = GpsMathUtils.accelerationMps2(speedChangeMps, durS);
        final absChange = speedChangeMps.abs();
        final curMaxChange = maxSpeedChangeMps;
        if (curMaxChange == null || absChange > curMaxChange) {
          maxSpeedChangeMps = absChange;
        }
      }
      if (spdMs != null) {
        prevDerivedSpeedMs = spdMs;
      }

      // ── Heading change ───────────────────────────────────────────────────
      final headingChange = GpsMathUtils.headingChangeDegrees(
        prev.headingDegrees, cur.headingDegrees,
      );

      // ── Altitude change ──────────────────────────────────────────────────
      final altChange = GpsMathUtils.altitudeChangeMetre(
        prev.altitude, cur.altitude,
      );
      if (altChange != null) {
        if (altChange > 0) totalGainM += altChange;
        if (altChange < 0) totalLossM += altChange.abs();
      }

      analyzedPoints.add(AnalyzedTrackPoint(
        id: cur.id,
        tripId: cur.tripId,
        timestamp: cur.timestamp,
        latitude: cur.latitude,
        longitude: cur.longitude,
        altitude: cur.altitude,
        rawSpeedKmh: cur.speedKmh,
        accuracyM: cur.accuracyM,
        headingDegrees: cur.headingDegrees,
        segmentDistanceM: distM,
        segmentDurationS: durS,
        derivedSpeedMs: spdMs,
        derivedSpeedKmh: spdKmh,
        speedChangeMps: speedChangeMps,
        accelerationMps2: accelMps2,
        headingChangeDeg: headingChange,
        altitudeChangeMetre: altChange,
      ));
    }

    // ── Step 3: build sub-analyses ─────────────────────────────────────────
    final speedAnalysis = SpeedAnalysis(
      pointCount: sorted.length,
      pointsWithSpeed: pointsWithSpeed,
      maxDerivedSpeedKmh: maxDerivedSpeedKmh,
      minDerivedSpeedKmh: minDerivedSpeedKmh,
      avgDerivedSpeedKmh: movingSegments > 0
          ? sumMovingSpeedKmh / movingSegments
          : null,
      maxSpeedChangeMps: maxSpeedChangeMps,
      totalDistanceM: totalDistanceM > 0 ? totalDistanceM : null,
      movingDurationS: movingDurationS > 0 ? movingDurationS : null,
    );

    final localMin = minAltitudeM;
    final localMax = maxAltitudeM;

    final altitudeAnalysis = AltitudeAnalysis(
      pointCount: sorted.length,
      pointsWithAltitude: pointsWithAlt,
      minAltitudeM: localMin,
      maxAltitudeM: localMax,
      totalElevationGainM: pointsWithAlt > 0 ? totalGainM : null,
      totalElevationLossM: pointsWithAlt > 0 ? totalLossM : null,
      altitudeRangeM: (localMin != null && localMax != null)
          ? localMax - localMin
          : null,
    );

    return DrivingAnalytics(
      tripId: tripId,
      analyzedPoints: analyzedPoints,
      speedAnalysis: speedAnalysis,
      altitudeAnalysis: altitudeAnalysis,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Builds the first [AnalyzedTrackPoint] which has no segment values.
  AnalyzedTrackPoint _buildFirstPoint(TrackPointRecord p) {
    return AnalyzedTrackPoint(
      id: p.id,
      tripId: p.tripId,
      timestamp: p.timestamp,
      latitude: p.latitude,
      longitude: p.longitude,
      altitude: p.altitude,
      rawSpeedKmh: p.speedKmh,
      accuracyM: p.accuracyM,
      headingDegrees: p.headingDegrees,
      // No segment values for the first point
    );
  }
}
