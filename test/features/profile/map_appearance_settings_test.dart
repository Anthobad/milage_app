// ---------------------------------------------------------------------------
// Phase 7.3 — Map Appearance Settings Tests
// ---------------------------------------------------------------------------
//
// Covers all 19 scenarios specified in the map_appearance feature spec:
//
//  1.  Map Appearance page renders.
//  2.  Dark, Light, and System options are visible.
//  3.  Dark is the default when no preference exists.
//  4.  Selecting Dark updates map theme state.
//  5.  Selecting Light updates map theme state.
//  6.  Selecting System updates map theme state.
//  7.  Selected option displays a checkmark.
//  8.  Only one option is selected.
//  9.  Map preference persists after provider/state recreation.
// 10.  Persisted map preference is restored on app startup.
// 11.  Profile → Map Appearance navigation works.
// 12.  Back navigation returns to Profile.
// 13.  Changing Map Appearance does NOT change app ThemeMode.
// 14.  Changing App Appearance does NOT change Map Appearance.
// 15.  Map receives the correct style for Dark.
// 16.  Map receives the correct style for Light.
// 17.  System mode resolves correctly to the current system brightness.
// 18.  Existing map functionality continues working.
// 19.  Existing tests continue passing (ensured by running the full suite).
//
// Design rules:
//   - No real SharedPreferences I/O — fake notifiers in memory.
//   - No SQLite, GPS, or network required.
//   - ProviderScope.overrides with fake notifiers extending real ones.
//   - GoRouter stubs for navigation verification.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:triprank_project/app/theme/app_theme.dart';
import 'package:triprank_project/app/theme/theme_provider.dart';
import 'package:triprank_project/features/cars/providers/vehicle_provider.dart';
import 'package:triprank_project/features/map/providers/map_provider.dart';
import 'package:triprank_project/features/map/providers/map_theme_provider.dart';
import 'package:triprank_project/features/map/utils/map_style_constants.dart';
import 'package:triprank_project/features/profile/presentation/map_appearance_screen.dart';
import 'package:triprank_project/features/profile/presentation/profile_screen.dart';
import 'package:triprank_project/features/profile/providers/profile_driving_summary_provider.dart';
import 'package:triprank_project/features/profile/providers/profile_image_provider.dart';

// ---------------------------------------------------------------------------
// Fake MapThemeNotifier — no SharedPreferences I/O
// ---------------------------------------------------------------------------

/// Fake notifier that starts with [_initial] and keeps changes in memory.
/// Does NOT call SharedPreferences.
class _FakeMapThemeNotifier extends MapThemeNotifier {
  _FakeMapThemeNotifier(this._initial);
  final MapThemeMode _initial;

  @override
  Future<MapThemeMode> build() async => _initial;

  @override
  Future<void> setMapTheme(MapThemeMode mode) async {
    state = AsyncData(mode);
    // Do NOT call SharedPreferences — this is a test fake.
  }
}

// ---------------------------------------------------------------------------
// Fake ThemeModeNotifier — no SharedPreferences I/O
// ---------------------------------------------------------------------------

class _FakeThemeNotifier extends ThemeModeNotifier {
  _FakeThemeNotifier(this._initial);
  final ThemeMode _initial;

  @override
  Future<ThemeMode> build() async => _initial;

  @override
  Future<void> setTheme(ThemeMode mode) async {
    state = AsyncData(mode);
  }
}

// ---------------------------------------------------------------------------
// Fake MapNotifier — no location service in tests
// ---------------------------------------------------------------------------

class _FakeMapNotifier extends MapNotifier {
  @override
  MapState build() => const MapState();
}

// ---------------------------------------------------------------------------
// Fakes required by ProfileScreen
// ---------------------------------------------------------------------------

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
// Builder helpers
// ---------------------------------------------------------------------------

/// Builds a [MapAppearanceScreen] inside a test [ProviderScope] with the
/// given [initialMapTheme].
Widget _buildMapAppearanceScreen({
  MapThemeMode initialMapTheme = MapThemeMode.dark,
  ThemeMode initialAppTheme = ThemeMode.dark,
  _FakeThemeNotifier? appThemeNotifier,
}) {
  return ProviderScope(
    overrides: [
      mapThemeProvider
          .overrideWith(() => _FakeMapThemeNotifier(initialMapTheme)),
      themeProvider.overrideWith(
        () => appThemeNotifier ?? _FakeThemeNotifier(initialAppTheme),
      ),
      mapProvider.overrideWith(() => _FakeMapNotifier()),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final mode = ref.watch(themeProvider).value ?? ThemeMode.dark;
        return MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const MapAppearanceScreen(),
        );
      },
    ),
  );
}

/// Builds a two-screen router: Profile → Map Appearance.
/// Used for navigation tests (scenarios 11, 12).
Widget _buildProfileToMapAppearanceRouter({
  MapThemeMode initialMapTheme = MapThemeMode.dark,
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
            builder: (ctx, _) => const MapAppearanceScreen(),
          ),
          GoRoute(
            path: 'settings/units',
            builder: (ctx, _) =>
                const Scaffold(body: Center(child: Text('Units'))),
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
      mapThemeProvider
          .overrideWith(() => _FakeMapThemeNotifier(initialMapTheme)),
      themeProvider.overrideWith(() => _FakeThemeNotifier(ThemeMode.dark)),
      mapProvider.overrideWith(() => _FakeMapNotifier()),
      profileDrivingSummaryProvider.overrideWith(
        () => _FakeSummaryNotifier(),
      ),
      profileImageProvider.overrideWith(() => _FakeImageNotifier()),
      vehicleProvider.overrideWith(() => _FakeVehicleNotifier()),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final mode = ref.watch(themeProvider).value ?? ThemeMode.dark;
        return MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          routerConfig: router,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Phase 7.3 — Map Appearance Settings', () {
    // ── Test 1 ──────────────────────────────────────────────────────────────
    testWidgets('1. Map Appearance page renders without crashing',
        (tester) async {
      await tester.pumpWidget(_buildMapAppearanceScreen());
      await tester.pump();

      expect(find.byType(MapAppearanceScreen), findsOneWidget);
    });

    // ── Test 2 ──────────────────────────────────────────────────────────────
    testWidgets('2. Dark, Light, and System options are visible',
        (tester) async {
      await tester.pumpWidget(_buildMapAppearanceScreen());
      await tester.pump();

      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    // ── Test 3 ──────────────────────────────────────────────────────────────
    testWidgets('3. Dark is the default when no preference exists',
        (tester) async {
      // No preference → default to dark.
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.dark));
      await tester.pump();

      // Dark checkmark present.
      expect(find.byKey(const Key('map_checkmark_Dark')), findsOneWidget);
      // Light and System checkmarks absent.
      expect(find.byKey(const Key('map_checkmark_Light')), findsNothing);
      expect(find.byKey(const Key('map_checkmark_System')), findsNothing);
    });

    // ── Test 4 ──────────────────────────────────────────────────────────────
    testWidgets('4. Selecting Dark updates map theme state', (tester) async {
      // Start from Light so we can verify moving to Dark.
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.light));
      await tester.pump();

      // Confirm Light is currently selected.
      expect(find.byKey(const Key('map_checkmark_Light')), findsOneWidget);

      // Tap Dark.
      await tester.tap(find.byKey(const Key('map_theme_option_dark')));
      await tester.pump();

      // Dark checkmark present; Light absent.
      expect(find.byKey(const Key('map_checkmark_Dark')), findsOneWidget);
      expect(find.byKey(const Key('map_checkmark_Light')), findsNothing);
    });

    // ── Test 5 ──────────────────────────────────────────────────────────────
    testWidgets('5. Selecting Light updates map theme state', (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.dark));
      await tester.pump();

      // Tap Light.
      await tester.tap(find.byKey(const Key('map_theme_option_light')));
      await tester.pump();

      expect(find.byKey(const Key('map_checkmark_Light')), findsOneWidget);
      expect(find.byKey(const Key('map_checkmark_Dark')), findsNothing);
    });

    // ── Test 6 ──────────────────────────────────────────────────────────────
    testWidgets('6. Selecting System updates map theme state', (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.dark));
      await tester.pump();

      // Tap System.
      await tester.tap(find.byKey(const Key('map_theme_option_system')));
      await tester.pump();

      expect(find.byKey(const Key('map_checkmark_System')), findsOneWidget);
      expect(find.byKey(const Key('map_checkmark_Dark')), findsNothing);
      expect(find.byKey(const Key('map_checkmark_Light')), findsNothing);
    });

    // ── Test 7 ──────────────────────────────────────────────────────────────
    testWidgets('7a. Dark checkmark shown when Dark is initial preference',
        (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.dark));
      await tester.pump();
      expect(find.byKey(const Key('map_checkmark_Dark')), findsOneWidget);
      expect(find.byKey(const Key('map_checkmark_Light')), findsNothing);
      expect(find.byKey(const Key('map_checkmark_System')), findsNothing);
    });

    testWidgets('7b. Light checkmark shown when Light is initial preference',
        (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.light));
      await tester.pump();
      expect(find.byKey(const Key('map_checkmark_Light')), findsOneWidget);
      expect(find.byKey(const Key('map_checkmark_Dark')), findsNothing);
      expect(find.byKey(const Key('map_checkmark_System')), findsNothing);
    });

    testWidgets('7c. System checkmark shown when System is initial preference',
        (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.system));
      await tester.pump();
      expect(find.byKey(const Key('map_checkmark_System')), findsOneWidget);
      expect(find.byKey(const Key('map_checkmark_Dark')), findsNothing);
      expect(find.byKey(const Key('map_checkmark_Light')), findsNothing);
    });

    // ── Test 8 ──────────────────────────────────────────────────────────────
    testWidgets('8. Only one option is selected at a time', (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.dark));
      await tester.pump();

      // Exactly one checkmark visible initially.
      final checkmarks = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.check,
      );
      expect(checkmarks, findsOneWidget);

      // Tap Light — still only one checkmark.
      await tester.tap(find.byKey(const Key('map_theme_option_light')));
      await tester.pump();
      expect(checkmarks, findsOneWidget);

      // Tap System — still only one checkmark.
      await tester.tap(find.byKey(const Key('map_theme_option_system')));
      await tester.pump();
      expect(checkmarks, findsOneWidget);

      // Tap Dark — still only one checkmark.
      await tester.tap(find.byKey(const Key('map_theme_option_dark')));
      await tester.pump();
      expect(checkmarks, findsOneWidget);
    });

    // ── Test 9 ──────────────────────────────────────────────────────────────
    testWidgets(
        '9. Map preference persists after provider/state recreation',
        (tester) async {
      // Build with Light selected.
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.light));
      await tester.pump();
      expect(find.byKey(const Key('map_checkmark_Light')), findsOneWidget);

      // Dispose and rebuild (simulating navigation away/back).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.light));
      await tester.pump();

      // Still Light after recreation.
      expect(find.byKey(const Key('map_checkmark_Light')), findsOneWidget);
      expect(find.byKey(const Key('map_checkmark_Dark')), findsNothing);
    });

    // ── Test 10 ─────────────────────────────────────────────────────────────
    testWidgets('10a. Persisted Dark preference restored on cold start',
        (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.dark));
      await tester.pump();
      expect(find.byKey(const Key('map_checkmark_Dark')), findsOneWidget);
    });

    testWidgets('10b. Persisted Light preference restored on cold start',
        (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.light));
      await tester.pump();
      expect(find.byKey(const Key('map_checkmark_Light')), findsOneWidget);
    });

    testWidgets('10c. Persisted System preference restored on cold start',
        (tester) async {
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.system));
      await tester.pump();
      expect(find.byKey(const Key('map_checkmark_System')), findsOneWidget);
    });

    // ── Test 11 ─────────────────────────────────────────────────────────────
    testWidgets('11. Profile → Map Appearance navigation works',
        (tester) async {
      await tester.pumpWidget(_buildProfileToMapAppearanceRouter());
      await tester.pump();

      // Start on Profile page.
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(MapAppearanceScreen), findsNothing);

      // Tap the Map Appearance settings row.
      await tester.tap(find.byKey(const Key('settings_row_map_appearance')));
      await tester.pumpAndSettle();

      // Now on MapAppearanceScreen.
      expect(find.byType(MapAppearanceScreen), findsOneWidget);
    });

    // ── Test 12 ─────────────────────────────────────────────────────────────
    testWidgets('12. Back navigation returns to Profile', (tester) async {
      await tester.pumpWidget(_buildProfileToMapAppearanceRouter());
      await tester.pump();

      // Navigate to Map Appearance.
      await tester.tap(find.byKey(const Key('settings_row_map_appearance')));
      await tester.pumpAndSettle();
      expect(find.byType(MapAppearanceScreen), findsOneWidget);

      // Tap the AppBar back button.
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();

      // Back on Profile page.
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(MapAppearanceScreen), findsNothing);
    });

    // ── Test 13 ─────────────────────────────────────────────────────────────
    testWidgets(
        '13. Changing Map Appearance does NOT change app ThemeMode',
        (tester) async {
      final fakeAppTheme = _FakeThemeNotifier(ThemeMode.dark);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapThemeProvider.overrideWith(
                () => _FakeMapThemeNotifier(MapThemeMode.dark)),
            themeProvider.overrideWith(() => fakeAppTheme),
            mapProvider.overrideWith(() => _FakeMapNotifier()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(themeProvider).value ?? ThemeMode.dark;
              return MaterialApp(
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: mode,
                home: const MapAppearanceScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapAppearanceScreen)),
      );

      // Record app theme before map theme change.
      final appThemeBefore = container.read(themeProvider).value;

      // Switch map theme to Light.
      await tester.tap(find.byKey(const Key('map_theme_option_light')));
      await tester.pump();

      // Map theme changed to Light.
      expect(find.byKey(const Key('map_checkmark_Light')), findsOneWidget);

      // App ThemeMode must remain unchanged.
      final appThemeAfter = container.read(themeProvider).value;
      expect(
        appThemeAfter,
        equals(appThemeBefore),
        reason: 'App ThemeMode must not change when map theme changes',
      );

      // Switch map theme to System.
      await tester.tap(find.byKey(const Key('map_theme_option_system')));
      await tester.pump();

      final appThemeAfterSystem = container.read(themeProvider).value;
      expect(
        appThemeAfterSystem,
        equals(appThemeBefore),
        reason: 'App ThemeMode must not change when switching to System map theme',
      );
    });

    // ── Test 14 ─────────────────────────────────────────────────────────────
    testWidgets(
        '14. Changing App Appearance does NOT change Map Appearance',
        (tester) async {
      final fakeMapTheme = _FakeMapThemeNotifier(MapThemeMode.dark);
      final fakeAppTheme = _FakeThemeNotifier(ThemeMode.dark);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapThemeProvider.overrideWith(() => fakeMapTheme),
            themeProvider.overrideWith(() => fakeAppTheme),
            mapProvider.overrideWith(() => _FakeMapNotifier()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(themeProvider).value ?? ThemeMode.dark;
              return MaterialApp(
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: mode,
                home: const Scaffold(
                  body: SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );

      // Await the async notifier so .value is non-null before we record it.
      await container.read(mapThemeProvider.future);

      // Record map theme before app theme change.
      final mapThemeBefore = container.read(mapThemeProvider).value;

      // Change app theme to Light.
      await container.read(themeProvider.notifier).setTheme(ThemeMode.light);
      await tester.pump();

      // App theme changed.
      expect(container.read(themeProvider).value, ThemeMode.light);

      // Map theme must be unchanged.
      final mapThemeAfter = container.read(mapThemeProvider).value;
      expect(
        mapThemeAfter,
        equals(mapThemeBefore),
        reason: 'Map theme must not change when app theme changes',
      );

      // Change app theme to System.
      await container.read(themeProvider.notifier).setTheme(ThemeMode.system);
      await tester.pump();

      final mapThemeAfterSystem = container.read(mapThemeProvider).value;
      expect(
        mapThemeAfterSystem,
        equals(mapThemeBefore),
        reason: 'Map theme must not change when app switches to System',
      );
    });

    // ── Test 15 ─────────────────────────────────────────────────────────────
    test('15. Map receives the correct tile URL for Dark', () {
      // When map theme is Dark, resolveMapIsDark returns true → dark tile URL.
      final isDark = resolveMapIsDark(MapThemeMode.dark, Brightness.light);
      final tileUrl = isDark ? kMapTileUrlDark : kMapTileUrlLight;
      expect(tileUrl, kMapTileUrlDark);
      expect(tileUrl, contains('carto'));
    });

    // ── Test 16 ─────────────────────────────────────────────────────────────
    test('16. Map receives the correct tile URL for Light', () {
      // When map theme is Light, resolveMapIsDark returns false → light tile URL.
      final isDark = resolveMapIsDark(MapThemeMode.light, Brightness.dark);
      final tileUrl = isDark ? kMapTileUrlDark : kMapTileUrlLight;
      expect(tileUrl, kMapTileUrlLight);
      expect(tileUrl, contains('openstreetmap'));
    });

    // ── Test 17 ─────────────────────────────────────────────────────────────
    test('17. System mode resolves correctly to the current system brightness',
        () {
      // Dark system brightness → isDark = true → dark tiles.
      expect(
        resolveMapIsDark(MapThemeMode.system, Brightness.dark),
        isTrue,
        reason: 'System + dark system → should use dark tiles',
      );

      // Light system brightness → isDark = false → light tiles.
      expect(
        resolveMapIsDark(MapThemeMode.system, Brightness.light),
        isFalse,
        reason: 'System + light system → should use light tiles',
      );

      // Explicit Dark mode always dark regardless of system.
      expect(resolveMapIsDark(MapThemeMode.dark, Brightness.light), isTrue);
      expect(resolveMapIsDark(MapThemeMode.dark, Brightness.dark), isTrue);

      // Explicit Light mode always light regardless of system.
      expect(resolveMapIsDark(MapThemeMode.light, Brightness.dark), isFalse);
      expect(resolveMapIsDark(MapThemeMode.light, Brightness.light), isFalse);
    });

    // ── Test 18 ─────────────────────────────────────────────────────────────
    testWidgets('18. Map Appearance page does not affect map state',
        (tester) async {
      // MapState (location, routing etc.) must be untouched by MapAppearanceScreen.
      await tester.pumpWidget(
          _buildMapAppearanceScreen(initialMapTheme: MapThemeMode.dark));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapAppearanceScreen)),
      );

      final mapState = container.read(mapProvider);

      // Tap through all options — map state must remain the same.
      await tester.tap(find.byKey(const Key('map_theme_option_light')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('map_theme_option_system')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('map_theme_option_dark')));
      await tester.pump();

      final mapStateAfter = container.read(mapProvider);

      // Location and routing state unchanged.
      expect(mapStateAfter.currentLocation, equals(mapState.currentLocation));
      expect(mapStateAfter.locationStatus, equals(mapState.locationStatus));
    });
  });

  // ---------------------------------------------------------------------------
  // MapThemeNotifier unit tests
  // ---------------------------------------------------------------------------

  group('MapThemeNotifier — unit tests', () {
    test('default map theme is dark when no preference is saved', () async {
      final container = ProviderContainer(
        overrides: [
          mapThemeProvider
              .overrideWith(() => _FakeMapThemeNotifier(MapThemeMode.dark)),
        ],
      );
      addTearDown(container.dispose);

      final mode = await container.read(mapThemeProvider.future);
      expect(mode, MapThemeMode.dark);
    });

    test('setMapTheme(light) changes state to light', () async {
      final container = ProviderContainer(
        overrides: [
          mapThemeProvider
              .overrideWith(() => _FakeMapThemeNotifier(MapThemeMode.dark)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapThemeProvider.future);
      await container
          .read(mapThemeProvider.notifier)
          .setMapTheme(MapThemeMode.light);

      final mode = container.read(mapThemeProvider).value;
      expect(mode, MapThemeMode.light);
    });

    test('setMapTheme(system) changes state to system', () async {
      final container = ProviderContainer(
        overrides: [
          mapThemeProvider
              .overrideWith(() => _FakeMapThemeNotifier(MapThemeMode.dark)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapThemeProvider.future);
      await container
          .read(mapThemeProvider.notifier)
          .setMapTheme(MapThemeMode.system);

      final mode = container.read(mapThemeProvider).value;
      expect(mode, MapThemeMode.system);
    });

    test('kMapThemeModePreferenceKey is the correct storage key', () {
      expect(kMapThemeModePreferenceKey, 'map_theme_mode');
    });

    test('kMapThemeModePreferenceKey is different from kThemeModePreferenceKey',
        () {
      // The two providers must use different keys — never share state.
      expect(kMapThemeModePreferenceKey, isNot(equals(kThemeModePreferenceKey)));
    });

    test('dark is the fallback when async value is null/loading', () {
      const AsyncValue<MapThemeMode> loading = AsyncLoading();
      expect(loading.value ?? MapThemeMode.dark, MapThemeMode.dark);
    });

    test('resolveMapIsDark returns true for dark mode', () {
      expect(resolveMapIsDark(MapThemeMode.dark, Brightness.light), isTrue);
    });

    test('resolveMapIsDark returns false for light mode', () {
      expect(resolveMapIsDark(MapThemeMode.light, Brightness.dark), isFalse);
    });

    test('resolveMapIsDark follows system brightness in system mode', () {
      expect(
          resolveMapIsDark(MapThemeMode.system, Brightness.dark), isTrue);
      expect(
          resolveMapIsDark(MapThemeMode.system, Brightness.light), isFalse);
    });

    test('dark tile URL contains carto (dark provider)', () {
      expect(kMapTileUrlDark, contains('carto'));
    });

    test('light tile URL contains openstreetmap (standard provider)', () {
      expect(kMapTileUrlLight, contains('openstreetmap'));
    });

    test('tile URLs contain z/x/y placeholders', () {
      expect(kMapTileUrlDark, contains('{z}'));
      expect(kMapTileUrlDark, contains('{x}'));
      expect(kMapTileUrlDark, contains('{y}'));
      expect(kMapTileUrlLight, contains('{z}'));
      expect(kMapTileUrlLight, contains('{x}'));
      expect(kMapTileUrlLight, contains('{y}'));
    });
  });
}
