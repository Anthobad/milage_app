// ---------------------------------------------------------------------------
// Analytics Providers — Phase 6.1 Foundation / Phase 6.4 Consolidated
// ---------------------------------------------------------------------------
//
// Riverpod integration for the analytics layer.
//
// ## Phase 6.4 changes
//
// The provider now loads both the persisted [Trip] summary AND the GPS track
// points before running [DrivingAnalyticsService].  This gives consumers a
// single place that exposes:
//
//   • Trip basics: distance, duration, start/end time, vehicle, destination,
//     mode, start location, stop count.
//   • SpeedAnalysis: derived speed extremes + graph data.
//   • AltitudeAnalysis: altitude extremes + graph data.
//   • TurnAnalysis: left/right/U-turn counts and events.
//   • BrakingAnalysis: hard-braking and sudden-stop counts and events.
//   • analyzedPoints: chronological track with per-segment derived values
//     for speed-over-time and altitude-over-time graphs.
//
// ## Dependency chain
//
//   tripId (String)
//       ↓
//   tripAnalyticsProvider (NotifierProvider.family)
//       ↓
//   TripAnalyticsNotifier
//       ├── TripRepository  ←  tripRepositoryProvider       (Phase 6.4)
//       ├── TrackPointRepository  ←  trackPointRepositoryProvider
//       └── DrivingAnalyticsService  ←  drivingAnalyticsServiceProvider
//               ↓
//           DrivingAnalytics   (Phase 6.1–6.3 sub-analyses)
//
// ## Design rules
//
// - [DrivingAnalyticsService] is a plain Dart class — zero Riverpod
//   dependency.  Riverpod only wires the pieces together.
// - [TripAnalyticsNotifier] follows the same family-notifier pattern used by
//   [TripStatsNotifier] in the trips feature.
// - The [Trip] is exposed directly in [TripAnalyticsState] so the UI has one
//   authoritative source for both trip summary values and computed analytics.
// - No statistics are duplicated or recalculated here if they already exist
//   on [Trip] (distance, duration, persisted speed/altitude extremes).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trips/models/trip.dart';
import '../../trips/providers/track_point_repository_provider.dart';
import '../../trips/providers/trip_repository_provider.dart';
import '../models/driving_analytics.dart';
import '../services/driving_analytics_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides the singleton [DrivingAnalyticsService] instance.
///
/// The service is a pure Dart object — this provider just makes it available
/// in the Riverpod graph so it can be swapped out in tests if needed.
final Provider<DrivingAnalyticsService> drivingAnalyticsServiceProvider =
    Provider<DrivingAnalyticsService>((ref) {
  return const DrivingAnalyticsService();
});

// ---------------------------------------------------------------------------
// Analytics state
// ---------------------------------------------------------------------------

/// Complete analytics state for one trip.
///
/// ## Source of truth
///
/// | Statistic | Authoritative source |
/// |---|---|
/// | Distance | `trip.distanceKm` |
/// | Duration | `trip.durationSeconds` |
/// | Start/end time | `trip.startTime` / `trip.endTime` |
/// | Vehicle | `trip.vehicleId` |
/// | Destination | `trip.destinationName` / `trip.destinationLatitude/Longitude` |
/// | Stop count | `trip.stops` (persisted at drive completion) |
/// | Avg/min/max speed | `trip.averageSpeedKmh` / `.minimumSpeedKmh` / `.maximumSpeedKmh` |
/// | Min/max altitude | `trip.minimumAltitudeM` / `.maximumAltitudeM` |
/// | Derived speed extremes | `analytics.speedAnalysis` |
/// | Elevation gain/loss | `analytics.altitudeAnalysis` |
/// | Left/right/U-turn counts | `analytics.turnAnalysis` |
/// | Hard-braking/sudden-stop | `analytics.brakingAnalysis` |
/// | Speed graph data | `analytics.analyzedPoints` |
/// | Altitude graph data | `analytics.analyzedPoints` |
class TripAnalyticsState {
  const TripAnalyticsState({
    this.trip,
    this.analytics,
    this.isLoading = true,
    this.error,
  });

  /// The persisted [Trip] record.
  ///
  /// Null while loading or on error.  Contains all trip summary values
  /// (distance, duration, speed extremes, altitude extremes, stop count,
  /// destination, vehicle ID) that were pre-computed at drive completion.
  final Trip? trip;

  /// The computed analytics result, including all sub-analyses from
  /// Phases 6.1–6.3.
  ///
  /// Null while loading or on error.
  final DrivingAnalytics? analytics;

  /// True while the trip or track points are being loaded or analyzed.
  final bool isLoading;

  /// Non-null when an error occurred during loading or analysis.
  final String? error;

  // ── Convenience ────────────────────────────────────────────────────────────

  bool get hasTrip => trip != null;
  bool get hasAnalytics => analytics != null;

  /// True when both [trip] and [analytics] are available.
  bool get isComplete => trip != null && analytics != null;

  // ── Derived trip summary accessors ─────────────────────────────────────────
  //
  // These delegate directly to [trip] so the UI does not need to reach into
  // both objects separately for the most common values.

  /// Distance in km from the persisted trip summary.  Null while loading.
  double? get distanceKm => trip?.distanceKm;

  /// Duration in seconds from the persisted trip summary.  Null while loading.
  int? get durationSeconds => trip?.durationSeconds;

  /// Stop count from the persisted trip summary.
  ///
  /// Null when the trip has not been loaded yet, or when stop detection
  /// has not been run for this trip.
  int? get stopCount => trip?.stops;

  TripAnalyticsState copyWith({
    Trip? trip,
    DrivingAnalytics? analytics,
    bool? isLoading,
    String? error,
  }) {
    return TripAnalyticsState(
      trip: trip ?? this.trip,
      analytics: analytics ?? this.analytics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Loads the [Trip] and GPS track points for a trip, then runs
/// [DrivingAnalyticsService] to produce the full [DrivingAnalytics] result.
///
/// ## Riverpod 3.4.2 family pattern
///
/// The trip ID is passed to the factory function that creates the notifier,
/// not to [build].  [build] takes no arguments; [_tripId] is stored by the
/// constructor before [build] is called.
///
/// ## Loading strategy
///
/// 1. Load the [Trip] summary row (fast — single row read).
///    Contains all pre-computed statistics; available immediately.
///
/// 2. Load all [TrackPointRecord] rows for the trip.
///    Used for GPS graph data and computed sub-analyses.
///
/// 3. Run [DrivingAnalyticsService.analyze] on the sorted track.
///    Produces speed analysis, altitude analysis, turn analysis, and
///    braking analysis in a single O(n) pass.
///
/// ## Performance
///
/// Track points are loaded once and processed once.
/// No repeated SQLite queries.
/// Riverpod caches the result per [tripId] — no re-computation on rebuild.
class TripAnalyticsNotifier extends Notifier<TripAnalyticsState> {
  TripAnalyticsNotifier(this._tripId);

  final String _tripId;

  @override
  TripAnalyticsState build() {
    Future.microtask(() => _load());
    return const TripAnalyticsState();
  }

  Future<void> _load() async {
    try {
      // ── Step 1: Load the trip summary ─────────────────────────────────────
      final tripRepo = ref.read(tripRepositoryProvider);
      final trip = await tripRepo.getTripById(_tripId);

      if (trip == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Trip not found.',
        );
        return;
      }

      // Expose the trip immediately so the UI can render summary stats
      // while the GPS track is still loading.
      state = state.copyWith(trip: trip);

      // ── Step 2: Load GPS track points ─────────────────────────────────────
      final trackRepo = ref.read(trackPointRepositoryProvider);
      final points = await trackRepo.getTrackPointsForTrip(_tripId);

      // ── Step 3: Run analytics service ─────────────────────────────────────
      final service = ref.read(drivingAnalyticsServiceProvider);
      final analytics = service.analyze(tripId: _tripId, points: points);

      state = state.copyWith(
        analytics: analytics,
        isLoading: false,
      );
    } catch (error, stack) {
      // ignore: avoid_print
      print('[TripAnalyticsNotifier] Failed to analyze trip $_tripId: '
          '$error\n$stack');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load analytics.',
      );
    }
  }

  /// Reload trip and analytics (e.g. after a pull-to-refresh).
  Future<void> reload() async {
    state = const TripAnalyticsState();
    await _load();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Family provider — parameterised by trip ID string.
///
/// Exposes the complete consolidated analytics for one trip:
///   • Trip summary (distance, duration, stop count, destination, vehicle…)
///   • SpeedAnalysis (derived speed extremes, graph data)
///   • AltitudeAnalysis (altitude extremes, elevation gain/loss, graph data)
///   • TurnAnalysis (left/right/U-turn counts and events)
///   • BrakingAnalysis (hard-braking and sudden-stop counts and events)
///   • analyzedPoints (chronological track with per-segment derived values)
///
/// Usage:
/// ```dart
/// final state = ref.watch(tripAnalyticsProvider('some-trip-uuid'));
/// final trip = state.trip;
/// final analytics = state.analytics;
/// final leftTurns = analytics?.turnAnalysis?.leftTurns;
/// final hardBrakingCount = analytics?.brakingAnalysis?.hardBrakingCount;
/// final stopCount = state.stopCount;  // from persisted Trip
/// ```
///
/// ## Riverpod 3.4.2 family API
///
/// `NotifierProvider.family` calls the lambda with [tripId] to create a new
/// [TripAnalyticsNotifier] for each unique argument.  [build] is then
/// called with no arguments.
final tripAnalyticsProvider = NotifierProvider.family<TripAnalyticsNotifier,
    TripAnalyticsState, String>(
  (tripId) => TripAnalyticsNotifier(tripId),
);
