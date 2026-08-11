// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:triprank_project/features/trips/models/trip.dart';
import 'package:triprank_project/features/trips/providers/trips_filter_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Builds a minimal [Trip] with sensible defaults.
Trip _trip({
  String id = 't1',
  String? vehicleId,
  TripMode mode = TripMode.reckless,
  DateTime? startTime,
  String? destinationName,
  double? averageSpeedKmh,
  double distanceKm = 5.0,
  int durationSeconds = 600,
}) {
  final start = startTime ?? DateTime.utc(2024, 8, 1, 9, 0);
  return Trip(
    id: id,
    vehicleId: vehicleId,
    mode: mode,
    startTime: start,
    endTime: start.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    distanceKm: distanceKm,
    startLatitude: 33.88,
    startLongitude: 35.49,
    destinationName: destinationName,
    averageSpeedKmh: averageSpeedKmh,
    createdAt: DateTime.utc(2024, 8, 1),
  );
}

// ---------------------------------------------------------------------------
// TripsFilterState unit tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_initFfi);

  group('TripsFilterState', () {
    test('1. default state has no filters', () {
      const state = TripsFilterState();
      expect(state.hasSearch, isFalse);
      expect(state.hasDateFilter, isFalse);
      expect(state.hasAnyFilter, isFalse);
    });

    test('2. hasSearch is true when searchQuery is non-empty', () {
      const state = TripsFilterState(searchQuery: 'Jounieh');
      expect(state.hasSearch, isTrue);
    });

    test('3. hasSearch is false for whitespace-only query', () {
      const state = TripsFilterState(searchQuery: '   ');
      expect(state.hasSearch, isFalse);
    });

    test('4. hasDateFilter is true when start date is set', () {
      final state =
          TripsFilterState(startDate: DateTime(2024, 8, 1));
      expect(state.hasDateFilter, isTrue);
    });

    test('5. hasDateFilter is true when end date is set', () {
      final state = TripsFilterState(endDate: DateTime(2024, 8, 31));
      expect(state.hasDateFilter, isTrue);
    });

    test('6. copyWith preserves unmodified fields', () {
      const original = TripsFilterState(searchQuery: 'abc');
      final updated = original.copyWith(searchQuery: 'xyz');
      expect(updated.searchQuery, 'xyz');
      expect(updated.startDate, isNull);
    });

    test('7. copyWith can clear nullable fields', () {
      final original = TripsFilterState(
        startDate: DateTime(2024, 8, 1),
        endDate: DateTime(2024, 8, 31),
      );
      final cleared = original.copyWith(startDate: null, endDate: null);
      expect(cleared.startDate, isNull);
      expect(cleared.endDate, isNull);
    });

    test('8. equality works for identical states', () {
      const a = TripsFilterState(searchQuery: 'test');
      const b = TripsFilterState(searchQuery: 'test');
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // TripsFilterNotifier unit tests
  // ---------------------------------------------------------------------------

  group('TripsFilterNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('9. initial state has no filters', () {
      final state = container.read(tripsFilterProvider);
      expect(state.hasAnyFilter, isFalse);
    });

    test('10. setSearch updates searchQuery', () {
      container.read(tripsFilterProvider.notifier).setSearch('Beirut');
      expect(container.read(tripsFilterProvider).searchQuery, 'Beirut');
    });

    test('11. clearSearch resets searchQuery to empty', () {
      container.read(tripsFilterProvider.notifier).setSearch('Beirut');
      container.read(tripsFilterProvider.notifier).clearSearch();
      expect(container.read(tripsFilterProvider).searchQuery, '');
    });

    test('12. setDateRange sets both dates', () {
      final start = DateTime(2024, 8, 1);
      final end = DateTime(2024, 8, 31);
      container.read(tripsFilterProvider.notifier).setDateRange(start, end);
      final state = container.read(tripsFilterProvider);
      expect(state.startDate, start);
      expect(state.endDate, end);
    });

    test('13. clearDateFilter removes date range', () {
      container.read(tripsFilterProvider.notifier)
          .setDateRange(DateTime(2024, 8, 1), DateTime(2024, 8, 31));
      container.read(tripsFilterProvider.notifier).clearDateFilter();
      final state = container.read(tripsFilterProvider);
      expect(state.startDate, isNull);
      expect(state.endDate, isNull);
    });

    test('14. clearAll resets everything', () {
      container.read(tripsFilterProvider.notifier).setSearch('test');
      container.read(tripsFilterProvider.notifier)
          .setDateRange(DateTime(2024, 8, 1), DateTime(2024, 8, 31));
      container.read(tripsFilterProvider.notifier).clearAll();
      final state = container.read(tripsFilterProvider);
      expect(state.hasAnyFilter, isFalse);
    });

    test('15. setting search preserves existing date filter', () {
      container.read(tripsFilterProvider.notifier)
          .setDateRange(DateTime(2024, 8, 1), null);
      container.read(tripsFilterProvider.notifier).setSearch('Jounieh');
      final state = container.read(tripsFilterProvider);
      expect(state.hasSearch, isTrue);
      expect(state.hasDateFilter, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // filteredTripsProvider filtering logic tests
  // ---------------------------------------------------------------------------

  group('Trip filtering logic', () {
    // We test the pure filtering logic directly, not via the full provider
    // (which requires a real DB).  We use the same filter predicate logic.

    List<Trip> applyFilter(List<Trip> trips, TripsFilterState filter) {
      if (!filter.hasAnyFilter) return trips;
      return trips.where((trip) {
        if (filter.hasSearch) {
          final q = filter.searchQuery.trim().toLowerCase();
          final dest = trip.destinationName?.toLowerCase() ?? '';
          if (dest.isEmpty || !dest.contains(q)) return false;
        }
        if (filter.hasDateFilter) {
          final tripDate = trip.startTime.toLocal();
          final tripDay =
              DateTime(tripDate.year, tripDate.month, tripDate.day);
          if (filter.startDate != null) {
            final start = DateTime(filter.startDate!.year,
                filter.startDate!.month, filter.startDate!.day);
            if (tripDay.isBefore(start)) return false;
          }
          if (filter.endDate != null) {
            final end = DateTime(filter.endDate!.year,
                filter.endDate!.month, filter.endDate!.day);
            if (tripDay.isAfter(end)) return false;
          }
        }
        return true;
      }).toList();
    }

    test('16. no filter returns all trips', () {
      final trips = [
        _trip(id: 'a'),
        _trip(id: 'b'),
      ];
      final result = applyFilter(trips, const TripsFilterState());
      expect(result.length, 2);
    });

    test('17. destination search filters correctly', () {
      final trips = [
        _trip(
            id: 'a',
            mode: TripMode.destination,
            destinationName: 'Jounieh'),
        _trip(
            id: 'b',
            mode: TripMode.destination,
            destinationName: 'Beirut'),
      ];
      final result = applyFilter(
          trips, const TripsFilterState(searchQuery: 'Jounieh'));
      expect(result.length, 1);
      expect(result.first.id, 'a');
    });

    test('18. search is case-insensitive', () {
      final trips = [
        _trip(
            id: 'a',
            mode: TripMode.destination,
            destinationName: 'JOUNIEH'),
      ];
      final result = applyFilter(
          trips, const TripsFilterState(searchQuery: 'jounieh'));
      expect(result.length, 1);
    });

    test('19. reckless trips do not match destination search', () {
      final trips = [
        _trip(id: 'a', mode: TripMode.reckless),
      ];
      final result = applyFilter(
          trips, const TripsFilterState(searchQuery: 'anything'));
      expect(result.isEmpty, isTrue);
    });

    test('20. empty search returns all trips', () {
      final trips = [_trip(id: 'a'), _trip(id: 'b')];
      final result =
          applyFilter(trips, const TripsFilterState(searchQuery: ''));
      expect(result.length, 2);
    });

    test('21. date filter includes trips on matching day', () {
      final day = DateTime(2024, 8, 5);
      final trips = [
        _trip(id: 'a', startTime: DateTime.utc(2024, 8, 5, 10, 0)),
        _trip(id: 'b', startTime: DateTime.utc(2024, 8, 6, 10, 0)),
      ];
      final result =
          applyFilter(trips, TripsFilterState(startDate: day, endDate: day));
      expect(result.length, 1);
      expect(result.first.id, 'a');
    });

    test('22. date filter excludes trips outside range', () {
      // Use noon UTC so .toLocal() stays on the same calendar day
      // regardless of the test machine's UTC offset (UTC-12 to UTC+14).
      final trips = [
        _trip(id: 'a', startTime: DateTime.utc(2024, 7, 20, 12, 0)),
        _trip(id: 'b', startTime: DateTime.utc(2024, 8, 10, 12, 0)),
        _trip(id: 'c', startTime: DateTime.utc(2024, 8, 20, 12, 0)),
        _trip(id: 'd', startTime: DateTime.utc(2024, 9, 5, 12, 0)),
      ];
      final result = applyFilter(
          trips,
          TripsFilterState(
            startDate: DateTime(2024, 8, 1),
            endDate: DateTime(2024, 8, 31),
          ));
      expect(result.length, 2);
      expect(result.map((t) => t.id).toSet(), {'b', 'c'});
    });

    test('23. search + date filter work together (AND)', () {
      final aug5 = DateTime.utc(2024, 8, 5, 10, 0);
      final aug10 = DateTime.utc(2024, 8, 10, 10, 0);
      final trips = [
        _trip(
            id: 'a',
            mode: TripMode.destination,
            destinationName: 'Jounieh',
            startTime: aug5),
        _trip(
            id: 'b',
            mode: TripMode.destination,
            destinationName: 'Jounieh',
            startTime: aug10),
        _trip(
            id: 'c',
            mode: TripMode.destination,
            destinationName: 'Beirut',
            startTime: aug5),
      ];
      final result = applyFilter(
          trips,
          TripsFilterState(
            searchQuery: 'Jounieh',
            startDate: DateTime(2024, 8, 5),
            endDate: DateTime(2024, 8, 7),
          ));
      expect(result.length, 1);
      expect(result.first.id, 'a');
    });

    test('24. clearing search leaves date filter active', () {
      final trips = [
        _trip(id: 'a', startTime: DateTime.utc(2024, 8, 5, 10, 0)),
        _trip(id: 'b', startTime: DateTime.utc(2024, 9, 1, 10, 0)),
      ];
      // Search active + date active.
      final withBoth = applyFilter(
          trips,
          TripsFilterState(
            searchQuery: 'test',
            startDate: DateTime(2024, 8, 1),
            endDate: DateTime(2024, 8, 31),
          ));
      // Search cleared — date still active.
      final dateOnly = applyFilter(
          trips,
          TripsFilterState(
            searchQuery: '',
            startDate: DateTime(2024, 8, 1),
            endDate: DateTime(2024, 8, 31),
          ));
      expect(withBoth.isEmpty, isTrue); // reckless trips excluded
      expect(dateOnly.length, 1);
      expect(dateOnly.first.id, 'a');
    });

    test('25. newest trips appear first (ordering preserved)', () {
      // Repository returns newest first; filter must not reorder.
      final trips = [
        _trip(id: 'new', startTime: DateTime.utc(2024, 8, 10)),
        _trip(id: 'old', startTime: DateTime.utc(2024, 8, 1)),
      ];
      final result = applyFilter(trips, const TripsFilterState());
      expect(result.first.id, 'new');
      expect(result.last.id, 'old');
    });
  });

  // ---------------------------------------------------------------------------
  // Trip model convenience getters
  // ---------------------------------------------------------------------------

  group('Trip model', () {
    test('26. durationLabel formats hours and minutes', () {
      final trip = _trip(durationSeconds: 3665); // 1h 1m
      expect(trip.durationLabel, '1h 1m');
    });

    test('27. durationLabel formats minutes and seconds', () {
      final trip = _trip(durationSeconds: 95); // 1m 35s
      expect(trip.durationLabel, '1m 35s');
    });

    test('28. durationLabel formats seconds only', () {
      final trip = _trip(durationSeconds: 45);
      expect(trip.durationLabel, '45s');
    });

    test('29. distanceLabel uses km for ≥1km', () {
      final trip = _trip(distanceKm: 12.5);
      expect(trip.distanceLabel, '12.50 km');
    });

    test('30. distanceLabel uses metres for <1km', () {
      final trip = _trip(distanceKm: 0.45);
      expect(trip.distanceLabel, '450 m');
    });

    test('31. correct date components round-trip via startTime', () {
      final start = DateTime.utc(2024, 8, 11, 14, 30);
      final trip = _trip(startTime: start);
      expect(trip.startTime.year, 2024);
      expect(trip.startTime.month, 8);
      expect(trip.startTime.day, 11);
    });

    test('32. destination trip has correct destinationName', () {
      final trip = _trip(
          mode: TripMode.destination, destinationName: 'Jounieh Marina');
      expect(trip.destinationName, 'Jounieh Marina');
    });

    test('33. reckless trip has null destinationName', () {
      final trip = _trip(mode: TripMode.reckless);
      expect(trip.destinationName, isNull);
    });

    test('34. averageSpeedKmh is stored correctly', () {
      final trip = _trip(averageSpeedKmh: 54.3);
      expect(trip.averageSpeedKmh, closeTo(54.3, 0.01));
    });
  });
}
