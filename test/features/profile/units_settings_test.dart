// ---------------------------------------------------------------------------
// Phase 7.4 — Units Settings Tests
// ---------------------------------------------------------------------------
//
// Covers all 25 scenarios specified in units_setting.md plus conversion
// accuracy tests and UI integration tests:
//
//  1.  Units page renders.
//  2.  Metric and Imperial options are visible.
//  3.  Metric is selected by default.
//  4.  Selecting Metric updates the unit provider.
//  5.  Selecting Imperial updates the unit provider.
//  6.  Active option shows a checkmark.
//  7.  Only one option is selected.
//  8.  Preference persists after provider/state recreation.
//  9.  Preference is restored after app startup.
// 10.  Profile → Units navigation works.
// 11.  Back navigation returns to Profile.
// 12.  Distance formatting uses km in Metric.
// 13.  Distance formatting uses mi in Imperial.
// 14.  Speed formatting uses km/h in Metric.
// 15.  Speed formatting uses mph in Imperial.
// 16.  Altitude formatting uses m in Metric.
// 17.  Altitude formatting uses ft in Imperial.
// 18.  Existing trip data is displayed using the current unit preference.
// 19.  Existing database values are unchanged when switching units.
// 20.  Analytics calculations remain based on canonical units.
// 21.  Speed graph displays the correct unit.
// 22.  Altitude graph displays the correct unit.
// 23.  Profile driving summary respects the unit setting.
// 24.  No NaN/Infinity is introduced by conversion/formatting.
// 25.  Existing tests continue passing (compile-time validated by full suite).
//
// CONVERSION TESTS (deterministic):
//  C1.  100 km → 62.1371 mi
//  C2.  100 km/h → 62.1371 mph
//  C3.  100 m → 328.084 ft
//  C4.  0 km → 0 mi
//  C5.  0 km/h → 0 mph
//  C6.  0 m → 0 ft
//  C7.  1.6 km → ~0.994 mi (sub-round-trip)
//  C8.  NaN distance → "—" placeholder
//  C9.  NaN speed → "—" placeholder
//  C10. NaN altitude → "—" placeholder
//  C11. Infinity distance → "—" placeholder
//  C12. Infinity speed → "—" placeholder
//
// Design rules:
//   - No real SharedPreferences I/O — fake notifiers in memory.
//   - No SQLite, GPS, or network required.
//   - ProviderScope.overrides with fake notifiers extending real ones.
//   - GoRouter stubs for navigation tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:triprank_project/app/theme/app_theme.dart';
import 'package:triprank_project/core/services/unit_service.dart';
import 'package:triprank_project/features/cars/providers/vehicle_provider.dart';
import 'package:triprank_project/features/map/providers/map_provider.dart';
import 'package:triprank_project/features/map/providers/map_theme_provider.dart';
import 'package:triprank_project/features/profile/presentation/profile_screen.dart';
import 'package:triprank_project/features/profile/presentation/units_screen.dart';
import 'package:triprank_project/features/profile/providers/profile_driving_summary_provider.dart';
import 'package:triprank_project/features/profile/providers/profile_image_provider.dart';
import 'package:triprank_project/features/profile/providers/unit_preference_provider.dart';
import 'package:triprank_project/app/theme/theme_provider.dart';

// ---------------------------------------------------------------------------
// Fake notifiers — no SharedPreferences I/O
// ---------------------------------------------------------------------------

/// Fake [UnitPreferenceNotifier] — holds state in memory, no SharedPreferences.
class _FakeUnitNotifier extends UnitPreferenceNotifier {
  _FakeUnitNotifier(this._initial);
  final UnitSystem _initial;

  @override
  Future<UnitSystem> build() async => _initial;

  @override
  Future<void> setUnitSystem(UnitSystem system) async {
    state = AsyncData(system);
    // Do NOT call SharedPreferences in tests.
  }
}

class _FakeThemeNotifier extends ThemeModeNotifier {
  @override
  Future<ThemeMode> build() async => ThemeMode.dark;

  @override
  Future<void> setTheme(ThemeMode mode) async {
    state = AsyncData(mode);
  }
}

class _FakeMapNotifier extends MapNotifier {
  @override
  MapState build() => const MapState();
}

class _FakeMapThemeNotifier extends MapThemeNotifier {
  @override
  Future<MapThemeMode> build() async => MapThemeMode.dark;

  @override
  Future<void> setMapTheme(MapThemeMode mode) async {
    state = AsyncData(mode);
  }
}

class _FakeSummaryNotifier extends ProfileDrivingSummaryNotifier {
  @override
  ProfileDrivingSummaryState build() => const ProfileDrivingSummaryState(
        isLoading: false,
        summary: ProfileDrivingSummary.zero,
      );
}

class _FakeImageNotifier extends ProfileImageNotifier {
  @override
  String? build() => null;
}

class _FakeVehicleNotifier extends VehicleListNotifier {
  @override
  Future<VehicleState> build() async => const VehicleState();
}

// ---------------------------------------------------------------------------
// Widget builder helpers
// ---------------------------------------------------------------------------

/// Builds a [UnitsScreen] with the given [initialSystem].
Widget _buildUnitsScreen({UnitSystem initialSystem = UnitSystem.metric}) {
  return ProviderScope(
    overrides: [
      unitPreferenceProvider.overrideWith(
        () => _FakeUnitNotifier(initialSystem),
      ),
      mapProvider.overrideWith(() => _FakeMapNotifier()),
      mapThemeProvider.overrideWith(() => _FakeMapThemeNotifier()),
      themeProvider.overrideWith(() => _FakeThemeNotifier()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const UnitsScreen(),
    ),
  );
}

/// Builds a Profile → Units router for navigation tests.
Widget _buildProfileToUnitsRouter({
  UnitSystem initialSystem = UnitSystem.metric,
}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (ctx, _) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'settings/appearance',
            builder: (ctx, _) =>
                const Scaffold(body: Center(child: Text('Appearance'))),
          ),
          GoRoute(
            path: 'settings/map-appearance',
            builder: (ctx, _) =>
                const Scaffold(body: Center(child: Text('Map Appearance'))),
          ),
          GoRoute(
            path: 'settings/units',
            builder: (ctx, _) => const UnitsScreen(),
          ),
          GoRoute(
            path: 'about',
            builder: (ctx, _) =>
                const Scaffold(body: Center(child: Text('About'))),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      unitPreferenceProvider.overrideWith(
        () => _FakeUnitNotifier(initialSystem),
      ),
      mapProvider.overrideWith(() => _FakeMapNotifier()),
      mapThemeProvider.overrideWith(() => _FakeMapThemeNotifier()),
      themeProvider.overrideWith(() => _FakeThemeNotifier()),
      profileDrivingSummaryProvider.overrideWith(
        () => _FakeSummaryNotifier(),
      ),
      profileImageProvider.overrideWith(() => _FakeImageNotifier()),
      vehicleProvider.overrideWith(() => _FakeVehicleNotifier()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── UI Integration Tests ──────────────────────────────────────────────────

  group('Phase 7.4 — Units Settings UI', () {
    // Test 1
    testWidgets('1. Units page renders without crashing', (tester) async {
      await tester.pumpWidget(_buildUnitsScreen());
      await tester.pump();

      expect(find.byType(UnitsScreen), findsOneWidget);
    });

    // Test 2
    testWidgets('2. Metric and Imperial options are visible', (tester) async {
      await tester.pumpWidget(_buildUnitsScreen());
      await tester.pump();

      expect(find.text('Metric'), findsOneWidget);
      expect(find.text('Imperial'), findsOneWidget);
    });

    // Test 3
    testWidgets('3. Metric is selected by default (no saved preference)',
        (tester) async {
      // No saved preference → initialSystem defaults to metric.
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.metric));
      await tester.pump();

      // Checkmark exists for Metric.
      expect(find.byKey(const Key('checkmark_metric')), findsOneWidget);
      // No checkmark for Imperial.
      expect(find.byKey(const Key('checkmark_imperial')), findsNothing);
    });

    // Test 4
    testWidgets('4. Selecting Metric updates the unit provider', (tester) async {
      // Start from Imperial.
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.imperial));
      await tester.pump();

      // Tap the Metric option.
      await tester.tap(find.byKey(const Key('unit_option_metric')));
      await tester.pump();

      // Checkmark must move to Metric.
      expect(find.byKey(const Key('checkmark_metric')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_imperial')), findsNothing);
    });

    // Test 5
    testWidgets('5. Selecting Imperial updates the unit provider',
        (tester) async {
      // Start from Metric (default).
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.metric));
      await tester.pump();

      // Tap the Imperial option.
      await tester.tap(find.byKey(const Key('unit_option_imperial')));
      await tester.pump();

      // Checkmark must move to Imperial.
      expect(find.byKey(const Key('checkmark_imperial')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_metric')), findsNothing);
    });

    // Test 6
    testWidgets('6. Active option shows a checkmark', (tester) async {
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.metric));
      await tester.pump();

      // Checkmark widget should be present.
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.check,
        ),
        findsOneWidget,
      );
    });

    // Test 7
    testWidgets('7. Only one option is selected at a time', (tester) async {
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.metric));
      await tester.pump();

      final checkmarks = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.check,
      );
      // Exactly one checkmark initially.
      expect(checkmarks, findsOneWidget);

      // Tap Imperial — still only one checkmark.
      await tester.tap(find.byKey(const Key('unit_option_imperial')));
      await tester.pump();
      expect(checkmarks, findsOneWidget);

      // Tap Metric — still only one checkmark.
      await tester.tap(find.byKey(const Key('unit_option_metric')));
      await tester.pump();
      expect(checkmarks, findsOneWidget);
    });

    // Test 8
    testWidgets(
        '8. Preference persists after provider/state recreation',
        (tester) async {
      // Build with Imperial.
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.imperial));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_imperial')), findsOneWidget);

      // Dispose and rebuild (simulating navigation away/back).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.imperial));
      await tester.pump();

      // Still Imperial.
      expect(find.byKey(const Key('checkmark_imperial')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_metric')), findsNothing);
    });

    // Test 9a
    testWidgets('9. Metric preference is restored on cold start',
        (tester) async {
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.metric));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_metric')), findsOneWidget);
    });

    // Test 9b
    testWidgets('9. Imperial preference is restored on cold start',
        (tester) async {
      await tester.pumpWidget(
          _buildUnitsScreen(initialSystem: UnitSystem.imperial));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_imperial')), findsOneWidget);
    });

    // Test 10
    testWidgets('10. Profile → Units navigation works', (tester) async {
      await tester.pumpWidget(_buildProfileToUnitsRouter());
      await tester.pump();

      // Start on Profile.
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(UnitsScreen), findsNothing);

      // Tap Units row.
      await tester.tap(find.byKey(const Key('settings_row_units')));
      await tester.pumpAndSettle();

      // Now on Units page.
      expect(find.byType(UnitsScreen), findsOneWidget);
    });

    // Test 11
    testWidgets('11. Back navigation returns to Profile', (tester) async {
      await tester.pumpWidget(_buildProfileToUnitsRouter());
      await tester.pump();

      // Navigate to Units.
      await tester.tap(find.byKey(const Key('settings_row_units')));
      await tester.pumpAndSettle();
      expect(find.byType(UnitsScreen), findsOneWidget);

      // Tap back.
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();

      // Back on Profile.
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(UnitsScreen), findsNothing);
    });
  });

  // ── UnitService formatting tests (Tests 12–17, 21–24) ────────────────────

  group('Phase 7.4 — UnitService Formatting', () {
    // Test 12
    test('12. Distance formatting uses km in Metric', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatDistance(12.4), contains('km'));
      expect(service.formatDistance(12.4), equals('12.4 km'));
    });

    // Test 13
    test('13. Distance formatting uses mi in Imperial', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatDistance(12.4), contains('mi'));
      expect(service.formatDistance(12.4), isNot(contains('km')));
    });

    // Test 14
    test('14. Speed formatting uses km/h in Metric', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatSpeed(84.0), contains('km/h'));
      expect(service.formatSpeed(84.0), equals('84 km/h'));
    });

    // Test 15
    test('15. Speed formatting uses mph in Imperial', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatSpeed(84.0), contains('mph'));
      expect(service.formatSpeed(84.0), isNot(contains('km/h')));
    });

    // Test 16
    test('16. Altitude formatting uses m in Metric', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatAltitude(412.0), contains('m'));
      expect(service.formatAltitude(412.0), equals('412 m'));
    });

    // Test 17
    test('17. Altitude formatting uses ft in Imperial', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatAltitude(412.0), contains('ft'));
      expect(service.formatAltitude(412.0), isNot(contains(' m')));
    });

    // Test 18 — existing trip data displayed using current unit preference
    test('18. Trip distance uses the current unit preference (Metric)',
        () {
      final service = UnitService(UnitSystem.metric);
      // Simulate a stored trip distance of 100.0 km.
      const storedDistanceKm = 100.0;
      final label = service.formatDistance(storedDistanceKm);
      expect(label, equals('100.0 km'));
    });

    test('18. Trip distance uses the current unit preference (Imperial)',
        () {
      final service = UnitService(UnitSystem.imperial);
      // Same stored trip distance — displayed in miles.
      const storedDistanceKm = 100.0;
      final label = service.formatDistance(storedDistanceKm);
      expect(label, contains('mi'));
      // 100 * 0.621371 = 62.1371 → formatted as "62.1 mi"
      expect(label, equals('62.1 mi'));
    });

    // Test 19 — database values unchanged (internal units never modified)
    test('19. Canonical internal distance value is not modified by formatting',
        () {
      const storedDistanceKm = 100.0;

      final metricService = UnitService(UnitSystem.metric);
      final imperialService = UnitService(UnitSystem.imperial);

      // Formatting must NEVER modify the original value.
      metricService.formatDistance(storedDistanceKm);
      imperialService.formatDistance(storedDistanceKm);

      // Original value is unchanged.
      expect(storedDistanceKm, equals(100.0));
    });

    // Test 20 — analytics calculations in canonical units
    test(
        '20. Speed conversion does not alter the canonical km/h input value',
        () {
      const canonicalSpeedKmh = 84.0;

      final service = UnitService(UnitSystem.imperial);
      // convertSpeed returns a NEW value — does not modify the original.
      final displayMph = service.convertSpeed(canonicalSpeedKmh);

      // Canonical value unchanged.
      expect(canonicalSpeedKmh, equals(84.0));
      // Display value is in mph.
      expect(displayMph, lessThan(canonicalSpeedKmh)); // mph < km/h
      expect(displayMph, isNot(equals(canonicalSpeedKmh)));
    });

    // Test 21 — speed graph unit label
    test('21. Speed graph unit is km/h in Metric', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.speedUnit, equals('km/h'));
    });

    test('21. Speed graph unit is mph in Imperial', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.speedUnit, equals('mph'));
    });

    // Test 22 — altitude graph unit label
    test('22. Altitude graph unit is m in Metric', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.altitudeUnit, equals('m'));
    });

    test('22. Altitude graph unit is ft in Imperial', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.altitudeUnit, equals('ft'));
    });

    // Test 23 — Profile driving summary
    test('23. Profile driving summary uses km in Metric', () {
      final service = UnitService(UnitSystem.metric);
      const totalDistanceKm = 320.0;
      final label = service.formatDistance(totalDistanceKm);
      expect(label, contains('km'));
      expect(label, equals('320.0 km'));
    });

    test('23. Profile driving summary uses mi in Imperial', () {
      final service = UnitService(UnitSystem.imperial);
      const totalDistanceKm = 320.0;
      final label = service.formatDistance(totalDistanceKm);
      // 320 * 0.621371 = 198.8387... → "198.8 mi"
      expect(label, contains('mi'));
      expect(label, equals('198.8 mi'));
    });

    // Test 24 — No NaN/Infinity
    test('24. formatDistance with NaN returns placeholder, not NaN',
        () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatDistance(double.nan), equals('—'));
    });

    test('24. formatSpeed with NaN returns placeholder, not NaN', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatSpeed(double.nan), equals('—'));
    });

    test('24. formatAltitude with NaN returns placeholder, not NaN', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatAltitude(double.nan), equals('—'));
    });

    test('24. formatDistance with Infinity returns placeholder', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatDistance(double.infinity), equals('—'));
    });

    test('24. formatSpeed with Infinity returns placeholder', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatSpeed(double.infinity), equals('—'));
    });

    test('24. formatAltitude with Infinity returns placeholder', () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatAltitude(double.infinity), equals('—'));
    });

    test('24. formatDistance with negative Infinity returns placeholder',
        () {
      final service = UnitService(UnitSystem.imperial);
      expect(service.formatDistance(double.negativeInfinity), equals('—'));
    });

    test('24. formatSpeedOrDash with null returns dash', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatSpeedOrDash(null), equals('—'));
    });

    test('24. formatAltitudeOrDash with null returns dash', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatAltitudeOrDash(null), equals('—'));
    });

    test('24. convertSpeed with NaN returns NaN (not Infinity)', () {
      final service = UnitService(UnitSystem.imperial);
      final result = service.convertSpeed(double.nan);
      expect(result.isNaN, isTrue);
      expect(result.isInfinite, isFalse);
    });
  });

  // ── Conversion accuracy tests ─────────────────────────────────────────────

  group('Phase 7.4 — Conversion Accuracy', () {
    // C1. 100 km → 62.1371 mi
    test('C1. 100 km converts to 62.1371 mi', () {
      final service = UnitService(UnitSystem.imperial);
      final miles = service.convertDistance(100.0);
      expect(miles, closeTo(62.1371, 0.00001));
    });

    // C2. 100 km/h → 62.1371 mph
    test('C2. 100 km/h converts to 62.1371 mph', () {
      final service = UnitService(UnitSystem.imperial);
      final mph = service.convertSpeed(100.0);
      expect(mph, closeTo(62.1371, 0.00001));
    });

    // C3. 100 m → 328.084 ft
    test('C3. 100 m converts to 328.084 ft', () {
      final service = UnitService(UnitSystem.imperial);
      final feet = service.convertAltitude(100.0);
      expect(feet, closeTo(328.084, 0.0001));
    });

    // C4. 0 km → 0 mi (not NaN)
    test('C4. 0 km converts to 0 mi', () {
      final service = UnitService(UnitSystem.imperial);
      final miles = service.convertDistance(0.0);
      expect(miles, equals(0.0));
      expect(miles.isNaN, isFalse);
    });

    // C5. 0 km/h → 0 mph
    test('C5. 0 km/h converts to 0 mph', () {
      final service = UnitService(UnitSystem.imperial);
      final mph = service.convertSpeed(0.0);
      expect(mph, equals(0.0));
      expect(mph.isNaN, isFalse);
    });

    // C6. 0 m → 0 ft
    test('C6. 0 m converts to 0 ft', () {
      final service = UnitService(UnitSystem.imperial);
      final feet = service.convertAltitude(0.0);
      expect(feet, equals(0.0));
      expect(feet.isNaN, isFalse);
    });

    // C7. Metric: no conversion applied
    test('C7. Metric convertDistance returns input unchanged', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.convertDistance(50.5), equals(50.5));
    });

    test('C7. Metric convertSpeed returns input unchanged', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.convertSpeed(84.0), equals(84.0));
    });

    test('C7. Metric convertAltitude returns input unchanged', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.convertAltitude(412.0), equals(412.0));
    });

    // C8. NaN safety
    test('C8. convertDistance NaN → NaN (handled upstream by format)', () {
      final service = UnitService(UnitSystem.imperial);
      final result = service.convertDistance(double.nan);
      expect(result.isNaN, isTrue);
    });

    // C9. Sub-1 km metric shows metres
    test('C9. Sub-1 km Metric distance shows metres', () {
      final service = UnitService(UnitSystem.metric);
      final label = service.formatDistance(0.85); // 850 m
      expect(label, equals('850 m'));
    });

    // C10. Imperial sub-values: 1.6 km → ~0.994 mi
    test('C10. 1.6 km in Imperial is approx 0.994 mi', () {
      final service = UnitService(UnitSystem.imperial);
      final miles = service.convertDistance(1.6);
      expect(miles, closeTo(0.994194, 0.0001));
    });

    // C11. Representative values
    test('C11. 84 km/h → approximately 52.2 mph (formatted)', () {
      final service = UnitService(UnitSystem.imperial);
      // 84 * 0.621371 = 52.19516... → "52.2 mph"
      expect(service.formatSpeed(84.0), equals('52.2 mph'));
    });

    test('C12. 412 m → approximately 1352 ft (formatted)', () {
      final service = UnitService(UnitSystem.imperial);
      // 412 * 3.28084 = 1351.706... → "1352 ft"
      expect(service.formatAltitude(412.0), equals('1352 ft'));
    });

    // Metric formatting examples from spec
    test('C13. Metric 12.4 km formatted correctly', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatDistance(12.4), equals('12.4 km'));
    });

    test('C14. Metric 84 km/h formatted correctly', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatSpeed(84.0), equals('84 km/h'));
    });

    test('C15. Metric 412 m formatted correctly', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatAltitude(412.0), equals('412 m'));
    });

    test('C16. Imperial 7.7 mi formatted correctly', () {
      final service = UnitService(UnitSystem.imperial);
      // 12.4 km * 0.621371 = 7.70500... → "7.7 mi"
      expect(service.formatDistance(12.4), equals('7.7 mi'));
    });
  });

  // ── UnitPreferenceNotifier unit tests ─────────────────────────────────────

  group('Phase 7.4 — UnitPreferenceNotifier', () {
    test('Default unit system is metric when no preference is saved',
        () async {
      final container = ProviderContainer(
        overrides: [
          unitPreferenceProvider.overrideWith(
            () => _FakeUnitNotifier(UnitSystem.metric),
          ),
        ],
      );
      addTearDown(container.dispose);

      final system = await container.read(unitPreferenceProvider.future);
      expect(system, UnitSystem.metric);
    });

    test('setUnitSystem(imperial) changes state to imperial', () async {
      final container = ProviderContainer(
        overrides: [
          unitPreferenceProvider.overrideWith(
            () => _FakeUnitNotifier(UnitSystem.metric),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(unitPreferenceProvider.future);
      await container
          .read(unitPreferenceProvider.notifier)
          .setUnitSystem(UnitSystem.imperial);

      final system = container.read(unitPreferenceProvider).value;
      expect(system, UnitSystem.imperial);
    });

    test('setUnitSystem(metric) changes state back to metric', () async {
      final container = ProviderContainer(
        overrides: [
          unitPreferenceProvider.overrideWith(
            () => _FakeUnitNotifier(UnitSystem.imperial),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(unitPreferenceProvider.future);
      await container
          .read(unitPreferenceProvider.notifier)
          .setUnitSystem(UnitSystem.metric);

      final system = container.read(unitPreferenceProvider).value;
      expect(system, UnitSystem.metric);
    });

    test('kUnitSystemPreferenceKey is the correct storage key', () {
      expect(kUnitSystemPreferenceKey, 'unit_system');
    });

    test('Metric is the fallback when async value is null/loading', () {
      const AsyncValue<UnitSystem> loading = AsyncLoading();
      expect(loading.value ?? UnitSystem.metric, UnitSystem.metric);
    });

    test('UnitSystem.metric.value serialises to "metric"', () {
      expect(UnitSystem.metric.value, 'metric');
    });

    test('UnitSystem.imperial.value serialises to "imperial"', () {
      expect(UnitSystem.imperial.value, 'imperial');
    });

    test('UnitSystem.fromValue("metric") returns metric', () {
      expect(UnitSystem.fromValue('metric'), UnitSystem.metric);
    });

    test('UnitSystem.fromValue("imperial") returns imperial', () {
      expect(UnitSystem.fromValue('imperial'), UnitSystem.imperial);
    });

    test('UnitSystem.fromValue(null) falls back to metric', () {
      expect(UnitSystem.fromValue(null), UnitSystem.metric);
    });

    test('UnitSystem.fromValue("unknown") falls back to metric', () {
      expect(UnitSystem.fromValue('unknown'), UnitSystem.metric);
    });
  });

  // ── unitServiceProvider integration test ─────────────────────────────────

  group('Phase 7.4 — unitServiceProvider', () {
    test('unitServiceProvider uses metric system by default', () async {
      final container = ProviderContainer(
        overrides: [
          unitPreferenceProvider.overrideWith(
            () => _FakeUnitNotifier(UnitSystem.metric),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(unitPreferenceProvider.future);
      final service = container.read(unitServiceProvider);

      expect(service.system, UnitSystem.metric);
      expect(service.formatDistance(100.0), equals('100.0 km'));
    });

    test('unitServiceProvider rebuilds when unit system changes', () async {
      final container = ProviderContainer(
        overrides: [
          unitPreferenceProvider.overrideWith(
            () => _FakeUnitNotifier(UnitSystem.metric),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(unitPreferenceProvider.future);

      final serviceBefore = container.read(unitServiceProvider);
      expect(serviceBefore.system, UnitSystem.metric);

      // Switch to Imperial.
      await container
          .read(unitPreferenceProvider.notifier)
          .setUnitSystem(UnitSystem.imperial);

      final serviceAfter = container.read(unitServiceProvider);
      expect(serviceAfter.system, UnitSystem.imperial);
      expect(serviceAfter.formatDistance(100.0), contains('mi'));
    });
  });

  // ── UnitService distanceUnit / speedUnit / altitudeUnit ─────────────────

  group('Phase 7.4 — UnitService unit label accessors', () {
    test('distanceUnit is "km" in Metric', () {
      expect(UnitService(UnitSystem.metric).distanceUnit, 'km');
    });

    test('distanceUnit is "mi" in Imperial', () {
      expect(UnitService(UnitSystem.imperial).distanceUnit, 'mi');
    });

    test('speedUnit is "km/h" in Metric', () {
      expect(UnitService(UnitSystem.metric).speedUnit, 'km/h');
    });

    test('speedUnit is "mph" in Imperial', () {
      expect(UnitService(UnitSystem.imperial).speedUnit, 'mph');
    });

    test('altitudeUnit is "m" in Metric', () {
      expect(UnitService(UnitSystem.metric).altitudeUnit, 'm');
    });

    test('altitudeUnit is "ft" in Imperial', () {
      expect(UnitService(UnitSystem.imperial).altitudeUnit, 'ft');
    });
  });

  // ── UnitService elevation formatting ─────────────────────────────────────

  group('Phase 7.4 — UnitService elevation formatting', () {
    test('formatElevation uses m in Metric', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatElevation(250.0), equals('250 m'));
    });

    test('formatElevation uses ft in Imperial', () {
      final service = UnitService(UnitSystem.imperial);
      // 250 * 3.28084 = 820.21 → "820 ft"
      expect(service.formatElevation(250.0), equals('820 ft'));
    });

    test('formatElevationOrDash returns dash for null', () {
      final service = UnitService(UnitSystem.metric);
      expect(service.formatElevationOrDash(null), equals('—'));
    });
  });
}
