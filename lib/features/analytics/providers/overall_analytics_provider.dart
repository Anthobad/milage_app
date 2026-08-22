// ---------------------------------------------------------------------------
// Overall Analytics Provider — Phase 6.6
// ---------------------------------------------------------------------------
//
// Riverpod provider that aggregates all trips for ONE selected vehicle into
// [OverallDrivingAnalytics].
//
// ## Loading strategy
//
// 1. Load all trips for the vehicle via TripRepository (one SQL query).
// 2. For each trip, load track points via TrackPointRepository, then run
//    DrivingAnalyticsService.analyze(). This gives us TurnAnalysis,
//    BrakingAnalysis, AltitudeAnalysis (elevation gain/loss), and
//    SpeedAnalysis.movingDurationS for weighted average speed.
// 3. OverallAnalyticsService.aggregate() combines everything.
//
// Track points are loaded per-trip only — not all GPS points at once.
// For vehicles with many trips, this runs trips in parallel.
//
// ## Automatic refresh
//
// Watches [vehicleTripsProvider] so when it is invalidated (after FINISH
// persists a new trip), this provider rebuilds automatically.
//
// ## Caching
//
// Riverpod caches per vehicleId. Switching vehicles builds a fresh state.
// Returning to the same vehicle reuses the cached result.
//
// ## State variants
//
// isLoading=true, analytics=null           → loading
// isLoading=false, analytics.isEmpty=true  → empty (no trips)
// isLoading=false, analytics.isEmpty=false → loaded with data
// isLoading=false, error!=null             → error

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trips/providers/track_point_repository_provider.dart';
import '../../trips/providers/trip_repository_provider.dart';
import '../../trips/providers/trips_filter_provider.dart';
import '../models/overall_driving_analytics.dart';
import '../services/driving_analytics_service.dart';
import '../services/overall_analytics_service.dart';
import 'trip_analytics_provider.dart';

export 'trip_analytics_provider.dart' show TripAnalyticsState;

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides the singleton [OverallAnalyticsService] instance.
final Provider<OverallAnalyticsService> overallAnalyticsServiceProvider =
    Provider<OverallAnalyticsService>((_) => const OverallAnalyticsService());

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the Overall Analytics dashboard.
class OverallAnalyticsState {
  const OverallAnalyticsState({
    this.analytics,
    this.isLoading = true,
    this.error,
  });

  /// The aggregated analytics result.  Null while loading or on error.
  final OverallDrivingAnalytics? analytics;

  /// True while trips or per-trip analytics are being loaded.
  final bool isLoading;

  /// Non-null when an unrecoverable error occurred.
  final String? error;

  bool get hasAnalytics => analytics != null;
  bool get isEmpty => analytics?.isEmpty == true;
  bool get isComplete => !isLoading && analytics != null && error == null;

  OverallAnalyticsState copyWith({
    OverallDrivingAnalytics? analytics,
    bool? isLoading,
    String? error,
  }) {
    return OverallAnalyticsState(
      analytics: analytics ?? this.analytics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Loads all trips for [_vehicleId] and runs [OverallAnalyticsService].
///
/// ## Riverpod 3.4.2 family pattern
///
/// The vehicle ID is captured by the factory lambda and stored as [_vehicleId]
/// before [build] is called.  [build] takes no arguments.
class OverallAnalyticsNotifier extends Notifier<OverallAnalyticsState> {
  OverallAnalyticsNotifier(this._vehicleId);

  final String _vehicleId;

  @override
  OverallAnalyticsState build() {
    // Watch vehicleTripsProvider to get automatic rebuild when a new trip
    // is finished (FINISH invalidates vehicleTripsProvider).
    ref.watch(vehicleTripsProvider);

    Future.microtask(() => _load());
    return const OverallAnalyticsState();
  }

  Future<void> _load() async {
    try {
      // ── Step 1: Load trips for this vehicle ───────────────────────────────
      final tripRepo = ref.read(tripRepositoryProvider);
      final trips = await tripRepo.getTripsForVehicle(_vehicleId);

      if (trips.isEmpty) {
        state = OverallAnalyticsState(
          isLoading: false,
          analytics: OverallDrivingAnalytics(
            vehicleId: _vehicleId,
            tripCount: 0,
            totalDistanceKm: 0,
            totalDurationSeconds: 0,
            tripDataPoints: const [],
          ),
        );
        return;
      }

      // ── Step 2: Load per-trip analytics in parallel ───────────────────────
      final trackRepo = ref.read(trackPointRepositoryProvider);
      final analyticsService = const DrivingAnalyticsService();

      final analyticsMap = <String, TripAnalyticsState>{};

      await Future.wait(trips.map((trip) async {
        try {
          final points = await trackRepo.getTrackPointsForTrip(trip.id);
          final analytics = analyticsService.analyze(
            tripId: trip.id,
            points: points,
          );
          analyticsMap[trip.id] = TripAnalyticsState(
            trip: trip,
            analytics: analytics,
            isLoading: false,
          );
        } catch (_) {
          // Per-trip analytics failure: skip, aggregation continues without it.
        }
      }));

      // ── Step 3: Aggregate ────────────────────────────────────────────────
      final service = ref.read(overallAnalyticsServiceProvider);
      final overall = service.aggregate(
        vehicleId: _vehicleId,
        trips: trips,
        analyticsMap: analyticsMap,
      );

      state = OverallAnalyticsState(
        isLoading: false,
        analytics: overall,
      );
    } catch (error, stack) {
      // ignore: avoid_print
      print('[OverallAnalyticsNotifier] Failed to aggregate: $error\n$stack');
      state = OverallAnalyticsState(
        isLoading: false,
        error: 'Failed to load analytics.',
      );
    }
  }

  /// Reload analytics (e.g. pull-to-refresh or after error).
  Future<void> reload() async {
    state = const OverallAnalyticsState();
    await _load();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Family provider — parameterised by vehicleId string.
///
/// Usage:
/// ```dart
/// final state = ref.watch(overallAnalyticsProvider('vehicle-uuid'));
/// ```
///
/// Automatically rebuilds when [vehicleTripsProvider] is invalidated
/// (triggered by the FINISH button completing a new trip, or by trip deletion).
final overallAnalyticsProvider = NotifierProvider.family<
    OverallAnalyticsNotifier, OverallAnalyticsState, String>(
  (vehicleId) => OverallAnalyticsNotifier(vehicleId),
);
