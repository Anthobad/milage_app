import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/trips/data/track_point_repository.dart';
import '../../../features/trips/models/track_point_record.dart';
import '../../../features/trips/models/trip.dart';
import '../../../features/trips/providers/track_point_repository_provider.dart';
import '../../../features/trips/providers/trip_repository_provider.dart';

// ---------------------------------------------------------------------------
// TripStatsState
// ---------------------------------------------------------------------------

/// State held by [TripStatsNotifier].
///
/// The persisted [Trip] summary is loaded first (fast) — it contains all
/// pre-computed statistics and requires no heavy computation.
///
/// The raw GPS track ([trackPoints]) is loaded afterwards.  On typical
/// drives (< 2 000 points) this is nearly instant.  Keeping them separate
/// allows the UI to show stats immediately while the track loads.
class TripStatsState {
  const TripStatsState({
    this.trip,
    this.trackPoints = const [],
    this.isLoadingTrip = true,
    this.isLoadingTrack = true,
    this.tripError,
    this.trackError,
  });

  /// The persisted [Trip] record.  Null while loading or on error.
  final Trip? trip;

  /// Raw GPS track points in chronological order.
  final List<TrackPointRecord> trackPoints;

  /// True while the [Trip] summary is being loaded from SQLite.
  final bool isLoadingTrip;

  /// True while the GPS track is being loaded from SQLite.
  final bool isLoadingTrack;

  /// Non-null when the trip failed to load.
  final String? tripError;

  /// Non-null when the track failed to load.
  final String? trackError;

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  bool get hasTrip => trip != null;
  bool get hasTrack => trackPoints.isNotEmpty;

  TripStatsState copyWith({
    Trip? trip,
    List<TrackPointRecord>? trackPoints,
    bool? isLoadingTrip,
    bool? isLoadingTrack,
    String? tripError,
    String? trackError,
  }) {
    return TripStatsState(
      trip: trip ?? this.trip,
      trackPoints: trackPoints ?? this.trackPoints,
      isLoadingTrip: isLoadingTrip ?? this.isLoadingTrip,
      isLoadingTrack: isLoadingTrack ?? this.isLoadingTrack,
      tripError: tripError ?? this.tripError,
      trackError: trackError ?? this.trackError,
    );
  }
}

// ---------------------------------------------------------------------------
// TripStatsNotifier
// ---------------------------------------------------------------------------

/// Loads the [Trip] summary and GPS track for a given trip ID.
///
/// ## Riverpod 3.4.2 family pattern
///
/// `NotifierProvider.family` passes the argument (trip ID) to the **factory
/// function** that constructs the notifier — not to [build].  [build] takes
/// no arguments; the trip ID is stored as [_tripId] by the factory before
/// [build] is called.
///
/// ## Loading strategy
///
/// 1. Load the [Trip] summary row (fast — single row read).
///    UI can display distance, duration, speed stats immediately.
///
/// 2. Load all [TrackPointRecord] rows for the trip.
///    Used for route visualisation and future detailed analytics.
///
/// Both steps complete independently — the UI displays whichever data is
/// ready without waiting for both.
class TripStatsNotifier extends Notifier<TripStatsState> {
  TripStatsNotifier(this._tripId);

  /// The trip ID this notifier was created for.
  final String _tripId;

  @override
  TripStatsState build() {
    Future.microtask(() => _load(_tripId));
    return const TripStatsState();
  }

  Future<void> _load(String tripId) async {
    await _loadTrip(tripId);
    await _loadTrack(tripId);
  }

  Future<void> _loadTrip(String tripId) async {
    try {
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.getTripById(tripId);
      if (trip == null) {
        state = state.copyWith(
          isLoadingTrip: false,
          tripError: 'Trip not found.',
        );
      } else {
        state = state.copyWith(
          trip: trip,
          isLoadingTrip: false,
        );
      }
    } catch (error, stack) {
      // ignore: avoid_print
      print('[TripStatsNotifier] Failed to load trip: $error\n$stack');
      state = state.copyWith(
        isLoadingTrip: false,
        tripError: 'Failed to load trip.',
      );
    }
  }

  Future<void> _loadTrack(String tripId) async {
    try {
      final repo = ref.read(trackPointRepositoryProvider);
      final points = await repo.getTrackPointsForTrip(tripId);
      state = state.copyWith(
        trackPoints: points,
        isLoadingTrack: false,
      );
    } catch (error, stack) {
      // ignore: avoid_print
      print('[TripStatsNotifier] Failed to load track: $error\n$stack');
      state = state.copyWith(
        isLoadingTrack: false,
        trackError: 'Failed to load GPS track.',
      );
    }
  }

  /// Reload both trip and track (e.g. after a pull-to-refresh).
  Future<void> reload() async {
    state = const TripStatsState();
    await _load(_tripId);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Family provider — parameterised by trip ID string.
///
/// Usage:
/// ```dart
/// final stats = ref.watch(tripStatsProvider('some-trip-uuid'));
/// ```
///
/// ## Riverpod 3.4.2 family API
///
/// `NotifierProvider.family` calls the lambda with [tripId] to create a new
/// [TripStatsNotifier] instance for each unique argument.  [build] is then
/// called on that instance with no arguments.
final tripStatsProvider = NotifierProvider.family<TripStatsNotifier,
    TripStatsState, String>(
  (tripId) => TripStatsNotifier(tripId),
);

// ---------------------------------------------------------------------------
// TrackPointRepository re-export for test convenience
// ---------------------------------------------------------------------------

/// Re-export so callers can reach the [TrackPointRepository] provider from
/// a single import path.
final Provider<TrackPointRepository> trackPointRepoForStatsProvider =
    trackPointRepositoryProvider;
