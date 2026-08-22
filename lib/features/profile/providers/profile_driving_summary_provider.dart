// ---------------------------------------------------------------------------
// ProfileDrivingSummaryProvider — Phase 7.1
// ---------------------------------------------------------------------------
//
// Provides an ALL-VEHICLE driving summary for the Profile page.
//
// ## Key distinction from overallAnalyticsProvider (Phase 6.6)
//
// [overallAnalyticsProvider] is scoped to ONE selected vehicle.
// This provider aggregates ALL trips across ALL vehicles — it is the
// global driving summary shown at the top of the Profile page.
//
// ## Data source
//
// Uses TripRepository.getAllTrips() — returns every trip regardless of
// which vehicle recorded it, including trips whose vehicle was later deleted
// (vehicle_id = NULL after ON DELETE SET NULL).
//
// ## Statistics exposed
//
// * tripCount   — total number of completed trips
// * totalDistanceKm — sum of all trip distances
// * totalDurationSeconds — sum of all trip durations
//
// These are deliberately minimal for Phase 7.1.  The Profile page is a
// hub — not a second analytics dashboard.
//
// ## Loading strategy
//
// A single SQL query (getAllTrips) is sufficient — no per-trip GPS analysis
// needed for these three summary fields.
//
// ## Refresh
//
// Call [reload()] after a new trip is completed, or invalidate this
// provider via ref.invalidate(profileDrivingSummaryProvider).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trips/providers/trip_repository_provider.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Lightweight all-vehicle driving summary for the Profile page.
///
/// Intentionally minimal — the Profile page shows a hub, not a dashboard.
class ProfileDrivingSummary {
  const ProfileDrivingSummary({
    required this.tripCount,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
  });

  /// Total completed trips across all vehicles.
  final int tripCount;

  /// Sum of all trip distances in km.
  final double totalDistanceKm;

  /// Sum of all trip durations in seconds.
  final int totalDurationSeconds;

  /// Zero-trip empty state.
  static const ProfileDrivingSummary zero = ProfileDrivingSummary(
    tripCount: 0,
    totalDistanceKm: 0,
    totalDurationSeconds: 0,
  );

  // ── Formatted labels ───────────────────────────────────────────────────────

  /// Human-readable total distance.  E.g. "142.3 km" or "850 m".
  String get distanceLabel {
    if (totalDistanceKm < 1.0) {
      return '${(totalDistanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${totalDistanceKm.toStringAsFixed(1)} km';
  }

  /// Human-readable total driving time.  E.g. "3h 25m" or "45m" or "30s".
  String get durationLabel {
    final h = totalDurationSeconds ~/ 3600;
    final m = (totalDurationSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${totalDurationSeconds}s';
  }

  @override
  String toString() =>
      'ProfileDrivingSummary(trips: $tripCount, '
      'dist: ${totalDistanceKm.toStringAsFixed(1)} km, '
      'dur: ${totalDurationSeconds}s)';
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ProfileDrivingSummaryState {
  const ProfileDrivingSummaryState({
    this.summary,
    this.isLoading = true,
    this.error,
  });

  final ProfileDrivingSummary? summary;
  final bool isLoading;
  final String? error;

  bool get isComplete => !isLoading && summary != null && error == null;

  ProfileDrivingSummaryState copyWith({
    ProfileDrivingSummary? summary,
    bool? isLoading,
    String? error,
  }) {
    return ProfileDrivingSummaryState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ProfileDrivingSummaryNotifier
    extends Notifier<ProfileDrivingSummaryState> {
  @override
  ProfileDrivingSummaryState build() {
    Future.microtask(() => _load());
    return const ProfileDrivingSummaryState();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(tripRepositoryProvider);

      // Single query — all trips, all vehicles.
      final trips = await repo.getAllTrips();

      if (trips.isEmpty) {
        state = const ProfileDrivingSummaryState(
          isLoading: false,
          summary: ProfileDrivingSummary.zero,
        );
        return;
      }

      int totalDuration = 0;
      double totalDistance = 0.0;
      for (final t in trips) {
        totalDuration += t.durationSeconds;
        totalDistance += t.distanceKm;
      }

      state = ProfileDrivingSummaryState(
        isLoading: false,
        summary: ProfileDrivingSummary(
          tripCount: trips.length,
          totalDistanceKm: totalDistance,
          totalDurationSeconds: totalDuration,
        ),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[ProfileDrivingSummaryNotifier] Failed: $e\n$st');
      state = const ProfileDrivingSummaryState(
        isLoading: false,
        error: 'Failed to load summary.',
      );
    }
  }

  /// Force reload — call after completing a drive, or on pull-to-refresh.
  Future<void> reload() async {
    state = const ProfileDrivingSummaryState();
    await _load();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// All-vehicle driving summary for the Profile page.
///
/// This is NOT scoped to the selected vehicle.  It aggregates every trip
/// in the database regardless of vehicle.
///
/// Usage:
/// ```dart
/// final state = ref.watch(profileDrivingSummaryProvider);
/// final summary = state.summary; // null while loading
/// ```
final profileDrivingSummaryProvider = NotifierProvider<
    ProfileDrivingSummaryNotifier, ProfileDrivingSummaryState>(
  ProfileDrivingSummaryNotifier.new,
);
