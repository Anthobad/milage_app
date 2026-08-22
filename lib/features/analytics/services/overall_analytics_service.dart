// ---------------------------------------------------------------------------
// OverallAnalyticsService — Phase 6.6 Overall Dashboard
// ---------------------------------------------------------------------------
//
// Aggregates per-trip data into [OverallDrivingAnalytics].
//
// ## Performance design
//
// Two-step aggregation:
//
// Step 1 — Persisted summary (fast, no GPS):
//   Uses Trip.distanceKm, Trip.durationSeconds, Trip.averageSpeedKmh,
//   Trip.minimumSpeedKmh, Trip.maximumSpeedKmh, Trip.minimumAltitudeM,
//   Trip.maximumAltitudeM, Trip.stops from the trips table.
//   Also builds TripDataPoint list for trend graphs.
//
// Step 2 — Detailed analytics (per trip, requires GPS track points):
//   Uses DrivingAnalytics.turnAnalysis, brakingAnalysis, altitudeAnalysis
//   (elevation gain/loss), and speedAnalysis.movingDurationS.
//   Called only for the trips where this data genuinely adds value.
//   For trips with no GPS track points, the relevant fields remain null.
//
// ## Aggregation rules
//
// - totalDistanceKm: sum(trip.distanceKm)
// - totalDurationSeconds: sum(trip.durationSeconds)
// - averageSpeedKmh: totalDistanceKm / (movingDurationSeconds / 3600)
//   (weighted; null when movingDurationSeconds is unavailable)
// - maximumSpeedKmh: max(trip.maximumSpeedKmh) — excludes null
// - minimumSpeedKmh: min(trip.minimumSpeedKmh) — excludes null
// - totalStops: sum(trip.stops) — only counts trips where stops != null
// - turns / braking: sum from per-trip DrivingAnalytics
// - elevation gain/loss: sum from per-trip AltitudeAnalysis
// - movingDurationSeconds: sum(SpeedAnalysis.movingDurationS)

import '../models/overall_driving_analytics.dart';
import '../models/trip_data_point.dart';
import '../providers/trip_analytics_provider.dart';
import '../../trips/models/trip.dart';

/// Service that builds [OverallDrivingAnalytics] from a list of trips and
/// their associated per-trip [TripAnalyticsState] objects.
///
/// No Flutter dependency. No Riverpod dependency.
/// Fully testable in a plain Dart VM.
class OverallAnalyticsService {
  const OverallAnalyticsService();

  /// Builds overall analytics from a list of trips and their pre-loaded analytics.
  ///
  /// [vehicleId]   — the vehicle these trips belong to.
  /// [trips]       — list of trips for the vehicle, any order (will be sorted by startTime).
  /// [analyticsMap] — map from tripId → [TripAnalyticsState] for trips that have
  ///                  been loaded through [DrivingAnalyticsService].
  ///                  Trips not present in the map contribute only persisted summary values.
  ///
  /// Returns [OverallDrivingAnalytics.isEmpty == true] when [trips] is empty.
  OverallDrivingAnalytics aggregate({
    required String vehicleId,
    required List<Trip> trips,
    required Map<String, TripAnalyticsState> analyticsMap,
  }) {
    if (trips.isEmpty) {
      return OverallDrivingAnalytics(
        vehicleId: vehicleId,
        tripCount: 0,
        totalDistanceKm: 0,
        totalDurationSeconds: 0,
        tripDataPoints: const [],
      );
    }

    // Sort chronologically for graph ordering (oldest first).
    final sorted = List<Trip>.from(trips)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // ── Step 1: Persisted summary aggregation ────────────────────────────────

    double totalDistanceKm = 0;
    int totalDurationSeconds = 0;
    double? minSpeedKmh;
    double? maxSpeedKmh;
    int? totalStops;
    double? minAltitudeM;
    double? maxAltitudeM;

    final tripDataPoints = <TripDataPoint>[];

    for (final trip in sorted) {
      totalDistanceKm += trip.distanceKm;
      totalDurationSeconds += trip.durationSeconds;

      // Minimum speed — exclude null, guard against NaN/Infinity.
      final tMinSpd = trip.minimumSpeedKmh;
      if (tMinSpd != null && tMinSpd.isFinite) {
        final cur = minSpeedKmh;
        if (cur == null || tMinSpd < cur) minSpeedKmh = tMinSpd;
      }

      // Maximum speed.
      final tMaxSpd = trip.maximumSpeedKmh;
      if (tMaxSpd != null && tMaxSpd.isFinite) {
        final cur = maxSpeedKmh;
        if (cur == null || tMaxSpd > cur) maxSpeedKmh = tMaxSpd;
      }

      // Stops — only sum trips that have a persisted stop count.
      final tStops = trip.stops;
      if (tStops != null) {
        totalStops = (totalStops ?? 0) + tStops;
      }

      // Altitude extremes.
      final tMinAlt = trip.minimumAltitudeM;
      if (tMinAlt != null && tMinAlt.isFinite) {
        final cur = minAltitudeM;
        if (cur == null || tMinAlt < cur) minAltitudeM = tMinAlt;
      }
      final tMaxAlt = trip.maximumAltitudeM;
      if (tMaxAlt != null && tMaxAlt.isFinite) {
        final cur = maxAltitudeM;
        if (cur == null || tMaxAlt > cur) maxAltitudeM = tMaxAlt;
      }

      // Graph data point (uses persisted summary values).
      tripDataPoints.add(TripDataPoint(
        tripId: trip.id,
        startTime: trip.startTime,
        distanceKm: trip.distanceKm,
        averageSpeedKmh: (trip.averageSpeedKmh?.isFinite ?? false)
            ? trip.averageSpeedKmh
            : null,
        maximumSpeedKmh: (trip.maximumSpeedKmh?.isFinite ?? false)
            ? trip.maximumSpeedKmh
            : null,
      ));
    }

    // ── Step 2: Detailed analytics aggregation ───────────────────────────────

    int? totalLeftTurns;
    int? totalRightTurns;
    int? totalUTurns;
    int? totalHardBraking;
    int? totalSuddenStops;
    double? totalElevationGainM;
    double? totalElevationLossM;
    double? movingDurationSeconds;

    for (final trip in sorted) {
      final state = analyticsMap[trip.id];
      if (state == null) continue;

      final analytics = state.analytics;
      if (analytics == null) continue;

      // Turns.
      final turnAnalysis = analytics.turnAnalysis;
      if (turnAnalysis != null) {
        totalLeftTurns = (totalLeftTurns ?? 0) + turnAnalysis.leftTurns;
        totalRightTurns = (totalRightTurns ?? 0) + turnAnalysis.rightTurns;
        totalUTurns = (totalUTurns ?? 0) + turnAnalysis.uTurns;
      }

      // Braking.
      final brakingAnalysis = analytics.brakingAnalysis;
      if (brakingAnalysis != null) {
        totalHardBraking =
            (totalHardBraking ?? 0) + brakingAnalysis.hardBrakingCount;
        totalSuddenStops =
            (totalSuddenStops ?? 0) + brakingAnalysis.suddenStopCount;
      }

      // Elevation.
      final altAnalysis = analytics.altitudeAnalysis;
      final gain = altAnalysis.totalElevationGainM;
      if (gain != null && gain.isFinite) {
        totalElevationGainM = (totalElevationGainM ?? 0) + gain;
      }
      final loss = altAnalysis.totalElevationLossM;
      if (loss != null && loss.isFinite) {
        totalElevationLossM = (totalElevationLossM ?? 0) + loss;
      }

      // Moving duration (for weighted average speed).
      final speedAnalysis = analytics.speedAnalysis;
      final movingS = speedAnalysis.movingDurationS;
      if (movingS != null && movingS.isFinite && movingS > 0) {
        movingDurationSeconds = (movingDurationSeconds ?? 0) + movingS;
      }
    }

    // ── Step 3: Derived aggregates ───────────────────────────────────────────

    // Weighted average speed: total distance / total moving time.
    double? averageSpeedKmh;
    final movingSec = movingDurationSeconds;
    if (movingSec != null && movingSec > 0) {
      final movingHours = movingSec / 3600.0;
      final candidate = totalDistanceKm / movingHours;
      if (candidate.isFinite && candidate > 0) {
        averageSpeedKmh = candidate;
      }
    }

    return OverallDrivingAnalytics(
      vehicleId: vehicleId,
      tripCount: sorted.length,
      totalDistanceKm: totalDistanceKm,
      totalDurationSeconds: totalDurationSeconds,
      tripDataPoints: tripDataPoints,
      averageSpeedKmh: averageSpeedKmh,
      minimumSpeedKmh: minSpeedKmh,
      maximumSpeedKmh: maxSpeedKmh,
      totalStops: totalStops,
      totalLeftTurns: totalLeftTurns,
      totalRightTurns: totalRightTurns,
      totalUTurns: totalUTurns,
      totalHardBraking: totalHardBraking,
      totalSuddenStops: totalSuddenStops,
      minimumAltitudeM: minAltitudeM,
      maximumAltitudeM: maxAltitudeM,
      totalElevationGainM: totalElevationGainM,
      totalElevationLossM: totalElevationLossM,
      movingDurationSeconds: movingDurationSeconds,
      stoppedDurationSeconds: null, // cannot be derived without GPS reload
    );
  }
}
