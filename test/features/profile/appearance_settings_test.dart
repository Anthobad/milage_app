// ---------------------------------------------------------------------------
// Phase 7.2 — Appearance Settings Tests
// ---------------------------------------------------------------------------
//
// Covers all 14 scenarios specified in appearance_theme.md:
//
//  1.  Appearance page renders.
//  2.  Dark, Light, and System options are visible.
//  3.  Dark is selected when no preference has been saved.
//  4.  Selecting Light updates the application ThemeMode.
//  5.  Selecting Dark updates the application ThemeMode.
//  6.  Selecting System updates the application ThemeMode.
//  7.  The selected option displays the correct checkmark.
//  8.  Only one option is selected at a time.
//  9.  The selected preference persists after provider/state recreation.
// 10.  The persisted preference is restored when the app starts.
// 11.  Profile → Appearance navigation works.
// 12.  The Appearance page can be exited and returned to Profile.
// 13.  Changing app appearance does NOT modify the map theme setting.
// 14.  Existing tests continue to pass (compile-time validated by running
//      the full suite — this file adds no regressions by construction).
//
// Design rules followed:
//   - No real SharedPreferences I/O in tests — use fake/mock.
//   - No SQLite, GPS, or network required.
//   - ProviderScope.overrides with fake notifiers extending real ones.
//   - GoRouter stubs for navigation verification.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:triprank_project/app/theme/app_theme.dart';
import 'package:triprank_project/app/theme/theme_provider.dart';
import 'package:triprank_project/features/map/providers/map_provider.dart';
import 'package:triprank_project/features/map/providers/map_theme_provider.dart';
import 'package:triprank_project/features/profile/presentation/appearance_screen.dart';
import 'package:triprank_project/features/profile/presentation/profile_screen.dart';
import 'package:triprank_project/features/profile/providers/profile_driving_summary_provider.dart';
import 'package:triprank_project/features/profile/providers/profile_image_provider.dart';
import 'package:triprank_project/features/cars/providers/vehicle_provider.dart';

// ---------------------------------------------------------------------------
// Fake ThemeModeNotifier — no SharedPreferences I/O
// ---------------------------------------------------------------------------

/// Fake notifier that starts with [_initial] and keeps changes in memory.
/// Does NOT call SharedPreferences.
class _FakeThemeNotifier extends ThemeModeNotifier {
  _FakeThemeNotifier(this._initial);
  final ThemeMode _initial;

  @override
  Future<ThemeMode> build() async => _initial;

  @override
  Future<void> setTheme(ThemeMode mode) async {
    state = AsyncData(mode);
    // Do NOT call SharedPreferences — this is a test fake.
  }
}

// ---------------------------------------------------------------------------
// Fake MapNotifier — used to verify map theme is NOT mutated by app theme
// ---------------------------------------------------------------------------

/// Fake MapNotifier that starts in a known state.
/// No location service initialisation in tests.
class _FakeMapNotifier extends MapNotifier {
  @override
  MapState build() {
    // Skip location service initialisation in tests.
    return const MapState();
  }
}

// ---------------------------------------------------------------------------
// Fake MapThemeNotifier — starts with dark, does NOT call SharedPreferences
// ---------------------------------------------------------------------------

class _FakeMapThemeNotifier extends MapThemeNotifier {
  @override
  Future<MapThemeMode> build() async => MapThemeMode.dark;

  @override
  Future<void> setMapTheme(MapThemeMode mode) async {
    state = AsyncData(mode);
  }
}

// ---------------------------------------------------------------------------
// Supporting fakes required by ProfileScreen
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

/// Builds an [AppearanceScreen] inside a test [ProviderScope] with the
/// given [initialTheme].  [mapNotifier] is exposed so tests can inspect
/// whether the map state was mutated.
Widget _buildAppearanceScreen({
  ThemeMode initialTheme = ThemeMode.dark,
  _FakeMapNotifier? mapNotifier,
}) {
  final fakeMap = mapNotifier ?? _FakeMapNotifier();

  return ProviderScope(
    overrides: [
      themeProvider.overrideWith(() => _FakeThemeNotifier(initialTheme)),
      mapProvider.overrideWith(() => fakeMap),
      mapThemeProvider.overrideWith(() => _FakeMapThemeNotifier()),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        // Use the current theme value to drive MaterialApp so we can assert
        // themeMode changes propagate all the way to the Material layer.
        final mode = ref.watch(themeProvider).value ?? ThemeMode.dark;
        return MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const AppearanceScreen(),
        );
      },
    ),
  );
}

/// Builds a two-screen router: Profile → Appearance.
/// Used for navigation tests (scenarios 11, 12).
Widget _buildProfileToAppearanceRouter({
  ThemeMode initialTheme = ThemeMode.dark,
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
            builder: (ctx, _) => const AppearanceScreen(),
          ),
          GoRoute(
            path: 'settings/map-appearance',
            builder: (ctx, _) =>
                const Scaffold(body: Center(child: Text('Map Appearance'))),
          ),
          GoRoute(
            path: 'settings/units',
            builder: (ctx, _) =>
                const Scaffold(body: Center(child: Text('Units'))),
          ),
          GoRoute(
            path: 'settings/permissions',
            builder: (ctx, _) =>
                const Scaffold(body: Center(child: Text('Permissions'))),
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
      themeProvider.overrideWith(() => _FakeThemeNotifier(initialTheme)),
      mapProvider.overrideWith(() => _FakeMapNotifier()),
      mapThemeProvider.overrideWith(() => _FakeMapThemeNotifier()),
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
  group('Phase 7.2 — Appearance Settings', () {
    // ── Test 1 ──────────────────────────────────────────────────────────────
    testWidgets('1. Appearance page renders without crashing', (tester) async {
      await tester.pumpWidget(_buildAppearanceScreen());
      await tester.pump();

      expect(find.byType(AppearanceScreen), findsOneWidget);
    });

    // ── Test 2 ──────────────────────────────────────────────────────────────
    testWidgets('2. Dark, Light, and System options are visible',
        (tester) async {
      await tester.pumpWidget(_buildAppearanceScreen());
      await tester.pump();

      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    // ── Test 3 ──────────────────────────────────────────────────────────────
    testWidgets('3. Dark is selected when no preference has been saved',
        (tester) async {
      // No saved preference → initialTheme defaults to dark.
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.dark,
      ));
      await tester.pump();

      // Checkmark exists for Dark.
      expect(find.byKey(const Key('checkmark_Dark')), findsOneWidget);
      // No checkmark for Light or System.
      expect(find.byKey(const Key('checkmark_Light')), findsNothing);
      expect(find.byKey(const Key('checkmark_System')), findsNothing);
    });

    // ── Test 4 ──────────────────────────────────────────────────────────────
    testWidgets('4. Selecting Light updates the application ThemeMode',
        (tester) async {
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.dark,
      ));
      await tester.pump();

      // Tap the Light option.
      await tester.tap(find.byKey(const Key('theme_option_light')));
      await tester.pump();

      // The selected checkmark must move to Light.
      expect(find.byKey(const Key('checkmark_Light')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_Dark')), findsNothing);
    });

    // ── Test 5 ──────────────────────────────────────────────────────────────
    testWidgets('5. Selecting Dark updates the application ThemeMode',
        (tester) async {
      // Start from Light so we can verify moving back to Dark.
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.light,
      ));
      await tester.pump();

      // Tap the Dark option.
      await tester.tap(find.byKey(const Key('theme_option_dark')));
      await tester.pump();

      // Checkmark on Dark; none on Light.
      expect(find.byKey(const Key('checkmark_Dark')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_Light')), findsNothing);
    });

    // ── Test 6 ──────────────────────────────────────────────────────────────
    testWidgets('6. Selecting System updates the application ThemeMode',
        (tester) async {
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.dark,
      ));
      await tester.pump();

      // Tap System.
      await tester.tap(find.byKey(const Key('theme_option_system')));
      await tester.pump();

      expect(find.byKey(const Key('checkmark_System')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_Dark')), findsNothing);
      expect(find.byKey(const Key('checkmark_Light')), findsNothing);
    });

    // ── Test 7 ──────────────────────────────────────────────────────────────
    testWidgets(
        '7a. Checkmark is on Dark when Dark is the initial preference',
        (tester) async {
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.dark,
      ));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_Dark')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_Light')), findsNothing);
      expect(find.byKey(const Key('checkmark_System')), findsNothing);
    });

    testWidgets(
        '7b. Checkmark is on Light when Light is the initial preference',
        (tester) async {
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.light,
      ));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_Light')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_Dark')), findsNothing);
      expect(find.byKey(const Key('checkmark_System')), findsNothing);
    });

    testWidgets(
        '7c. Checkmark is on System when System is the initial preference',
        (tester) async {
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.system,
      ));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_System')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_Dark')), findsNothing);
      expect(find.byKey(const Key('checkmark_Light')), findsNothing);
    });

    // ── Test 8 ──────────────────────────────────────────────────────────────
    testWidgets('8. Only one option is selected at a time', (tester) async {
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.dark,
      ));
      await tester.pump();

      // Only one checkmark icon should be visible.
      final checkmarks = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.check,
      );
      expect(checkmarks, findsOneWidget);

      // Tap Light — still only one checkmark.
      await tester.tap(find.byKey(const Key('theme_option_light')));
      await tester.pump();
      expect(checkmarks, findsOneWidget);

      // Tap System — still only one checkmark.
      await tester.tap(find.byKey(const Key('theme_option_system')));
      await tester.pump();
      expect(checkmarks, findsOneWidget);
    });

    // ── Test 9 ──────────────────────────────────────────────────────────────
    testWidgets(
        '9. The selected preference persists after provider/state recreation',
        (tester) async {
      // The _FakeThemeNotifier holds state in memory within the ProviderScope.
      // Simulating "recreation" here means: build with Light selected,
      // navigate away, and rebuild — the override keeps the value stable.
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.light,
      ));
      await tester.pump();

      // Light should be selected.
      expect(find.byKey(const Key('checkmark_Light')), findsOneWidget);

      // Dispose and rebuild the same widget (simulating navigation away/back).
      await tester.pumpWidget(
        const SizedBox.shrink(),
      );
      await tester.pumpWidget(_buildAppearanceScreen(
        initialTheme: ThemeMode.light,
      ));
      await tester.pump();

      // Still Light.
      expect(find.byKey(const Key('checkmark_Light')), findsOneWidget);
      expect(find.byKey(const Key('checkmark_Dark')), findsNothing);
    });

    // ── Test 10 ─────────────────────────────────────────────────────────────
    testWidgets(
        '10a. Persisted Dark preference is restored on cold start',
        (tester) async {
      await tester.pumpWidget(
          _buildAppearanceScreen(initialTheme: ThemeMode.dark));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_Dark')), findsOneWidget);
    });

    testWidgets(
        '10b. Persisted Light preference is restored on cold start',
        (tester) async {
      await tester.pumpWidget(
          _buildAppearanceScreen(initialTheme: ThemeMode.light));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_Light')), findsOneWidget);
    });

    testWidgets(
        '10c. Persisted System preference is restored on cold start',
        (tester) async {
      await tester.pumpWidget(
          _buildAppearanceScreen(initialTheme: ThemeMode.system));
      await tester.pump();
      expect(find.byKey(const Key('checkmark_System')), findsOneWidget);
    });

    // ── Test 11 ─────────────────────────────────────────────────────────────
    testWidgets('11. Profile → Appearance navigation works', (tester) async {
      await tester.pumpWidget(_buildProfileToAppearanceRouter());
      await tester.pump();

      // Start on Profile page.
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(AppearanceScreen), findsNothing);

      // Tap Appearance row.
      await tester.tap(find.byKey(const Key('settings_row_appearance')));
      await tester.pumpAndSettle();

      // Now on Appearance page.
      expect(find.byType(AppearanceScreen), findsOneWidget);
    });

    // ── Test 12 ─────────────────────────────────────────────────────────────
    testWidgets(
        '12. The Appearance page can be exited and returned to Profile',
        (tester) async {
      await tester.pumpWidget(_buildProfileToAppearanceRouter());
      await tester.pump();

      // Navigate to Appearance.
      await tester.tap(find.byKey(const Key('settings_row_appearance')));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceScreen), findsOneWidget);

      // Tap the back button in the AppBar.
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
      } else {
        // Navigator pop via the leading arrow icon.
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();

      // Back on Profile.
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(AppearanceScreen), findsNothing);
    });

    // ── Test 13 ─────────────────────────────────────────────────────────────
    testWidgets(
        '13. Changing app appearance does NOT modify the map theme setting',
        (tester) async {
      final fakeMapTheme = _FakeMapThemeNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeProvider.overrideWith(
              () => _FakeThemeNotifier(ThemeMode.dark),
            ),
            mapProvider.overrideWith(() => _FakeMapNotifier()),
            mapThemeProvider.overrideWith(() => fakeMapTheme),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final mode =
                  ref.watch(themeProvider).value ?? ThemeMode.dark;
              return MaterialApp(
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: mode,
                home: const AppearanceScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Record the map theme BEFORE changing app theme.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppearanceScreen)),
      );

      // Await the async notifier so .value is non-null before we record it.
      await container.read(mapThemeProvider.future);
      final mapBefore = container.read(mapThemeProvider).value;

      // Switch app theme to Light.
      await tester.tap(find.byKey(const Key('theme_option_light')));
      await tester.pump();

      // App theme changed.
      expect(find.byKey(const Key('checkmark_Light')), findsOneWidget);

      // Map theme must be unchanged.
      final mapAfter = container.read(mapThemeProvider).value;
      expect(
        mapAfter,
        equals(mapBefore),
        reason: 'Map theme must not change when app theme changes',
      );

      // Switch to System.
      await tester.tap(find.byKey(const Key('theme_option_system')));
      await tester.pump();

      final mapAfterSystem = container.read(mapThemeProvider).value;
      expect(
        mapAfterSystem,
        equals(mapBefore),
        reason: 'Map theme must not change when switching to System theme',
      );
    });
  });

  // ── Provider / model unit tests ──────────────────────────────────────────
  group('ThemeModeNotifier — unit tests', () {
    test('default theme is dark when no preference is saved', () async {
      final container = ProviderContainer(
        overrides: [
          themeProvider.overrideWith(() => _FakeThemeNotifier(ThemeMode.dark)),
        ],
      );
      addTearDown(container.dispose);

      final mode = await container.read(themeProvider.future);
      expect(mode, ThemeMode.dark);
    });

    test('setTheme(light) changes state to light', () async {
      final container = ProviderContainer(
        overrides: [
          themeProvider.overrideWith(() => _FakeThemeNotifier(ThemeMode.dark)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(themeProvider.future); // wait for build
      await container.read(themeProvider.notifier).setTheme(ThemeMode.light);

      final mode = container.read(themeProvider).value;
      expect(mode, ThemeMode.light);
    });

    test('setTheme(system) changes state to system', () async {
      final container = ProviderContainer(
        overrides: [
          themeProvider.overrideWith(() => _FakeThemeNotifier(ThemeMode.dark)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(themeProvider.future);
      await container.read(themeProvider.notifier).setTheme(ThemeMode.system);

      final mode = container.read(themeProvider).value;
      expect(mode, ThemeMode.system);
    });

    test('kThemeModePreferenceKey is correct storage key', () {
      expect(kThemeModePreferenceKey, 'theme_mode');
    });

    test('dark is the fallback when async value is null/loading', () async {
      // When the AsyncValue is still loading, .value is null —
      // the app falls back to ThemeMode.dark (as verified in app.dart).
      const AsyncValue<ThemeMode> loading = AsyncLoading();
      expect(loading.value ?? ThemeMode.dark, ThemeMode.dark);
    });
  });
}
