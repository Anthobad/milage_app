// ---------------------------------------------------------------------------
// Analytics Providers — Phase 6.1 Foundation
// ---------------------------------------------------------------------------
//
// Riverpod integration for the analytics layer.
//
// ## Dependency chain
//
//   tripId (String)
//       ↓
//   tripAnalyticsProvider (NotifierProvider.family)
//       ↓
//   TrackPointRepository  ←  trackPointRepositoryProvider
//       ↓
//   DrivingAnalyticsService  ←  drivingAnalyticsServiceProvider
//       ↓
//   DrivingAnalytics
//
// ## Design rules
//
// - [DrivingAnalyticsService] is a plain Dart class — zero Riverpod
//   dependency.  Riverpod only wires the pieces together.
// - The service is exposed as a [Provider] so it can be overridden in
//   tests without re-implementing the full dependency chain.
// - [TripAnalyticsNotifier] follows the same family-notifier pattern used by
//   [TripStatsNotifier] in the trips feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trips/providers/track_point_repository_provider.dart';
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

/// State held by [TripAnalyticsNotifier].
class TripAnalyticsState {
  const TripAnalyticsState({
    this.analytics,
    this.isLoading = true,
    this.error,
  });

  /// The computed analytics result.  Null while loading or on error.
  final DrivingAnalytics? analytics;

  /// True while track points are being loaded and analyzed.
  final bool isLoading;

  /// Non-null when an error occurred during loading or analysis.
  final String? error;

  bool get hasAnalytics => analytics != null;

  TripAnalyticsState copyWith({
    DrivingAnalytics? analytics,
    bool? isLoading,
    String? error,
  }) {
    return TripAnalyticsState(
      analytics: analytics ?? this.analytics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Loads GPS track points for a trip and runs [DrivingAnalyticsService] on
/// them.
///
/// ## Riverpod 3.4.2 family pattern
///
/// The trip ID is passed to the factory function that creates the notifier,
/// not to [build].  [build] takes no arguments; [_tripId] is stored by the
/// constructor before [build] is called.
///
/// ## Loading strategy
///
/// Track points are loaded from [TrackPointRepository] and passed directly
/// to [DrivingAnalyticsService.analyze].  No separate analytics persistence
/// layer exists in Phase 6.1 — results are computed on demand.
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
      final trackRepo = ref.read(trackPointRepositoryProvider);
      final service = ref.read(drivingAnalyticsServiceProvider);

      final points = await trackRepo.getTrackPointsForTrip(_tripId);
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

  /// Reload analytics (e.g. after a pull-to-refresh).
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
/// Usage:
/// ```dart
/// final analyticsState = ref.watch(tripAnalyticsProvider('some-trip-uuid'));
/// final analytics = analyticsState.analytics;
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
