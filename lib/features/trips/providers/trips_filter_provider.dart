import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/cars/providers/vehicle_provider.dart';
import '../data/trip_repository.dart';
import '../models/trip.dart';
import 'trip_repository_provider.dart';

// ---------------------------------------------------------------------------
// TripsFilterState
// ---------------------------------------------------------------------------

/// Holds the current search/date filter state for the Trips page.
///
/// Filter logic is applied client-side after loading the selected vehicle's
/// trips from SQLite.  All three filters are ANDed together.
class TripsFilterState {
  const TripsFilterState({
    this.searchQuery = '',
    this.startDate,
    this.endDate,
  });

  /// Case-insensitive destination search query (empty = no filter).
  final String searchQuery;

  /// Inclusive start date for the date range filter (null = no lower bound).
  final DateTime? startDate;

  /// Inclusive end date for the date range filter (null = no upper bound).
  final DateTime? endDate;

  bool get hasSearch => searchQuery.trim().isNotEmpty;
  bool get hasDateFilter => startDate != null || endDate != null;
  bool get hasAnyFilter => hasSearch || hasDateFilter;

  TripsFilterState copyWith({
    String? searchQuery,
    Object? startDate = _keep,
    Object? endDate = _keep,
  }) {
    return TripsFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: identical(startDate, _keep) ? this.startDate : startDate as DateTime?,
      endDate: identical(endDate, _keep) ? this.endDate : endDate as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripsFilterState &&
          searchQuery == other.searchQuery &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(searchQuery, startDate, endDate);
}

const Object _keep = Object();

// ---------------------------------------------------------------------------
// TripsFilterNotifier
// ---------------------------------------------------------------------------

/// Manages the active search/date filters for the Trips page.
///
/// This state does NOT need to persist across sessions — it is local to the
/// screen.  The notifier is not family-parameterised: there is exactly one
/// filter state for the Trips tab.
class TripsFilterNotifier extends Notifier<TripsFilterState> {
  @override
  TripsFilterState build() => const TripsFilterState();

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDate: start, endDate: end);
  }

  void clearDateFilter() {
    state = state.copyWith(startDate: null, endDate: null);
  }

  void clearAll() {
    state = const TripsFilterState();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Filter state provider for the Trips page.
final tripsFilterProvider =
    NotifierProvider<TripsFilterNotifier, TripsFilterState>(
  TripsFilterNotifier.new,
);

/// Async provider that loads trips for the selected vehicle, newest first.
///
/// Returns an empty list when no vehicle is selected.
/// Automatically refreshes when the selected vehicle changes.
final vehicleTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return [];
  final repo = ref.read(tripRepositoryProvider);
  return repo.getTripsForVehicle(vehicle.id);
});

/// Derived provider that applies the active filters to [vehicleTripsProvider].
///
/// Returns filtered + sorted (newest first) trips.
final filteredTripsProvider = Provider<AsyncValue<List<Trip>>>((ref) {
  final asyncTrips = ref.watch(vehicleTripsProvider);
  final filter = ref.watch(tripsFilterProvider);

  return asyncTrips.whenData((trips) {
    if (!filter.hasAnyFilter) return trips;

    return trips.where((trip) {
      // ── Destination search ─────────────────────────────────────────────
      if (filter.hasSearch) {
        final q = filter.searchQuery.trim().toLowerCase();
        // Only destination-mode trips can match a non-empty search.
        final dest = trip.destinationName?.toLowerCase() ?? '';
        if (dest.isEmpty || !dest.contains(q)) return false;
      }

      // ── Date filter ────────────────────────────────────────────────────
      if (filter.hasDateFilter) {
        final tripDate = trip.startTime.toLocal();
        final tripDay = DateTime(tripDate.year, tripDate.month, tripDate.day);

        if (filter.startDate != null) {
          final start = DateTime(
            filter.startDate!.year,
            filter.startDate!.month,
            filter.startDate!.day,
          );
          if (tripDay.isBefore(start)) return false;
        }
        if (filter.endDate != null) {
          final end = DateTime(
            filter.endDate!.year,
            filter.endDate!.month,
            filter.endDate!.day,
          );
          if (tripDay.isAfter(end)) return false;
        }
      }

      return true;
    }).toList();
  });
});

// Re-export TripRepository for convenience (avoids extra imports in tests).
final Provider<TripRepository> tripRepoForFilterProvider = tripRepositoryProvider;
