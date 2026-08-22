// ---------------------------------------------------------------------------
// Phase 7.1 — Profile Page Widget Tests (updated)
// ---------------------------------------------------------------------------
//
// Tests all spec scenarios after the gear-icon removal refactor.
// No real SQLite, GPS, or network required — providers are overridden with
// fixed test states via ProviderScope.overrides.
//
// Test scenarios:
//  1.  Profile page renders
//  2.  Driver label is present
//  3.  Generic profile icon appears when no image exists
//  4.  No My Cars section
//  5.  Driving summary section exists
//  6.  Driving summary is all-vehicle (uses profileDrivingSummaryProvider)
//  7.  Settings section contains Appearance, Map Appearance, Units, Permissions
//  8.  Voice is NOT present
//  9.  Export Data is NOT present
// 10.  About TripRank is present
// 11.  Appearance row navigates to its own dedicated page
// 12.  Driving summary navigates to the Analytics page
// 13.  Narrow screen (320 px) does not overflow
// 14.  No gear icon is present (removed — settings are listed directly)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:triprank_project/app/theme/app_theme.dart';
import 'package:triprank_project/features/cars/providers/vehicle_provider.dart';
import 'package:triprank_project/features/profile/presentation/profile_screen.dart';
import 'package:triprank_project/features/profile/presentation/settings_screen.dart';
import 'package:triprank_project/features/profile/providers/profile_driving_summary_provider.dart';
import 'package:triprank_project/features/profile/providers/profile_image_provider.dart';

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

class _FakeSummaryNotifier extends ProfileDrivingSummaryNotifier {
  _FakeSummaryNotifier(this._fixedState);
  final ProfileDrivingSummaryState _fixedState;

  @override
  ProfileDrivingSummaryState build() => _fixedState;
}

class _FakeImageNotifier extends ProfileImageNotifier {
  _FakeImageNotifier(this._path);
  final String? _path;

  @override
  String? build() => _path;
}

class _FakeVehicleNotifier extends VehicleListNotifier {
  @override
  Future<VehicleState> build() async => const VehicleState();
}

// ---------------------------------------------------------------------------
// Helper: stub GoRouter
// ---------------------------------------------------------------------------

GoRouter _makeRouter({
  WidgetBuilder? appearanceBuilder,
  WidgetBuilder? aboutBuilder,
}) {
  return GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (ctx, _) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'settings/appearance',
            builder: (ctx, _) =>
                appearanceBuilder != null
                    ? appearanceBuilder(ctx)
                    : const SettingPlaceholderScreen(title: 'Appearance'),
          ),
          GoRoute(
            path: 'settings/map-appearance',
            builder: (ctx, _) =>
                const SettingPlaceholderScreen(title: 'Map Appearance'),
          ),
          GoRoute(
            path: 'settings/units',
            builder: (ctx, _) =>
                const SettingPlaceholderScreen(title: 'Units'),
          ),
          GoRoute(
            path: 'settings/permissions',
            builder: (ctx, _) =>
                const SettingPlaceholderScreen(title: 'Permissions'),
          ),
          GoRoute(
            path: 'about',
            builder: (ctx, _) =>
                aboutBuilder != null
                    ? aboutBuilder(ctx)
                    : const Scaffold(body: Center(child: Text('About'))),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Helper: build widget under test
// ---------------------------------------------------------------------------

Widget _buildProfileScreen({
  ProfileDrivingSummaryState? summaryState,
  String? imagePath,
  GoRouter? router,
}) {
  final state = summaryState ??
      const ProfileDrivingSummaryState(
        isLoading: false,
        summary: ProfileDrivingSummary(
          tripCount: 42,
          totalDistanceKm: 1234.5,
          totalDurationSeconds: 7200,
        ),
      );

  return ProviderScope(
    overrides: [
      profileDrivingSummaryProvider.overrideWith(
        () => _FakeSummaryNotifier(state),
      ),
      profileImageProvider.overrideWith(
        () => _FakeImageNotifier(imagePath),
      ),
      vehicleProvider.overrideWith(
        () => _FakeVehicleNotifier(),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.dark,
      routerConfig: router ?? _makeRouter(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProfileScreen — Phase 7.1 Widget Tests', () {
    // ── Test 1 ──────────────────────────────────────────────────────────────
    testWidgets('1. Profile page renders without crashing', (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    // ── Test 2 ──────────────────────────────────────────────────────────────
    testWidgets('2. Driver label is present', (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(find.text('Driver'), findsOneWidget);
    });

    // ── Test 3 ──────────────────────────────────────────────────────────────
    testWidgets('3. Generic profile icon shown when no image is set',
        (tester) async {
      await tester.pumpWidget(_buildProfileScreen(imagePath: null));
      await tester.pump();

      expect(find.byKey(const Key('profile_default_icon')), findsOneWidget);
    });

    // ── Test 4 ──────────────────────────────────────────────────────────────
    testWidgets('4. No "My Cars" section is present', (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(find.text('CARS'), findsNothing);
      expect(find.text('My Cars'), findsNothing);
    });

    // ── Test 5 ──────────────────────────────────────────────────────────────
    testWidgets('5. Driving summary section exists', (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(find.text('DRIVING'), findsOneWidget);
      expect(find.byKey(const Key('driving_summary_card')), findsOneWidget);
      expect(find.text('Overall Driving'), findsOneWidget);
    });

    // ── Test 6 ──────────────────────────────────────────────────────────────
    testWidgets(
        '6. Driving summary shows all-vehicle data '
        '(profileDrivingSummaryProvider — not vehicle-scoped)',
        (tester) async {
      const summary = ProfileDrivingSummary(
        tripCount: 99,
        totalDistanceKm: 5000,
        totalDurationSeconds: 180000,
      );
      await tester.pumpWidget(
        _buildProfileScreen(
          summaryState: const ProfileDrivingSummaryState(
            isLoading: false,
            summary: summary,
          ),
        ),
      );
      await tester.pump();

      // Trip count 99 comes from the all-vehicle provider.
      expect(find.text('99'), findsOneWidget);
    });

    // ── Test 7 ──────────────────────────────────────────────────────────────
    testWidgets(
        '7. Settings section contains Appearance, Map Appearance, Units, Permissions',
        (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Map Appearance'), findsOneWidget);
      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);
    });

    // ── Test 8 ──────────────────────────────────────────────────────────────
    testWidgets('8. Voice setting is NOT present', (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(find.text('Voice'), findsNothing);
      expect(find.textContaining('voice'), findsNothing);
    });

    // ── Test 9 ──────────────────────────────────────────────────────────────
    testWidgets('9. Export Data is NOT present', (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(find.text('Export Data'), findsNothing);
      expect(find.textContaining('Export'), findsNothing);
    });

    // ── Test 10 ─────────────────────────────────────────────────────────────
    testWidgets('10. About TripRank row is present', (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('About TripRank'), findsOneWidget);
    });

    // ── Test 11 ─────────────────────────────────────────────────────────────
    testWidgets(
        '11. Tapping Appearance row navigates to its own dedicated page '
        '(not a shared settings hub)', (tester) async {
      var appearanceBuilt = false;

      await tester.pumpWidget(
        _buildProfileScreen(
          summaryState: const ProfileDrivingSummaryState(
            isLoading: false,
            summary: ProfileDrivingSummary.zero,
          ),
          router: _makeRouter(
            appearanceBuilder: (_) {
              appearanceBuilt = true;
              return const SettingPlaceholderScreen(title: 'Appearance');
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('settings_row_appearance')));
      await tester.pumpAndSettle();

      expect(appearanceBuilt, isTrue);
      // The destination page shows its own dedicated title.
      expect(find.text('Appearance'), findsOneWidget);
    });

    // ── Test 12 ─────────────────────────────────────────────────────────────
    testWidgets('12. Tapping driving summary card does NOT navigate away',
        (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      // Tap the card — should not navigate since it is no longer a link.
      await tester.tap(find.byKey(const Key('driving_summary_card')));
      await tester.pumpAndSettle();

      // Still on the Profile page.
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    // ── Test 13 ─────────────────────────────────────────────────────────────
    testWidgets('13. Narrow screen (320 px wide) does not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Driver'), findsOneWidget);
      expect(find.text('DRIVING'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    // ── Test 14 ─────────────────────────────────────────────────────────────
    testWidgets('14. No gear icon is present on the Profile page',
        (tester) async {
      await tester.pumpWidget(_buildProfileScreen());
      await tester.pump();

      // The old gear key must be absent.
      expect(find.byKey(const Key('profile_settings_gear')), findsNothing);
      // No settings icon button in the app bar.
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.settings_outlined,
        ),
        findsNothing,
      );
    });
  });

  // ── Provider / model unit tests ─────────────────────────────────────────
  group('ProfileDrivingSummary model', () {
    test('distanceLabel formats km values correctly', () {
      const s = ProfileDrivingSummary(
        tripCount: 1,
        totalDistanceKm: 142.3,
        totalDurationSeconds: 3600,
      );
      expect(s.distanceLabel, '142.3 km');
    });

    test('distanceLabel formats sub-1 km values as metres', () {
      const s = ProfileDrivingSummary(
        tripCount: 1,
        totalDistanceKm: 0.85,
        totalDurationSeconds: 60,
      );
      expect(s.distanceLabel, '850 m');
    });

    test('durationLabel formats hours and minutes', () {
      const s = ProfileDrivingSummary(
        tripCount: 1,
        totalDistanceKm: 10,
        totalDurationSeconds: 7380,
      );
      expect(s.durationLabel, '2h 3m');
    });

    test('durationLabel formats minutes only', () {
      const s = ProfileDrivingSummary(
        tripCount: 1,
        totalDistanceKm: 5,
        totalDurationSeconds: 1500,
      );
      expect(s.durationLabel, '25m');
    });

    test('zero state has zero values', () {
      const z = ProfileDrivingSummary.zero;
      expect(z.tripCount, 0);
      expect(z.totalDistanceKm, 0.0);
      expect(z.totalDurationSeconds, 0);
    });
  });
}
