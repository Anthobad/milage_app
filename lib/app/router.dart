import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/analytics_screen.dart';
import '../features/cars/presentation/cars_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/profile/presentation/about_screen.dart';
import '../features/profile/presentation/appearance_screen.dart';
import '../features/profile/presentation/map_appearance_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/units_screen.dart';
import '../features/trips/presentation/trip_screen.dart';
import '../features/trips/presentation/trip_stats_screen.dart';
import 'main_navigation.dart';

/// Route path constants.
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String map = '/map';
  static const String trips = '/trips';
  static const String cars = '/cars';
  static const String analytics = '/analytics';
  static const String profile = '/profile';

  // ── Profile sub-routes ─────────────────────────────────────────────────────

  /// Appearance settings — accessed from the Profile page.
  static const String profileAppearance = '/profile/settings/appearance';

  /// Map Appearance settings — accessed from the Profile page.
  static const String profileMapAppearance = '/profile/settings/map-appearance';

  /// Units settings — accessed from the Profile page.
  static const String profileUnits = '/profile/settings/units';

  /// About Milage page — accessed from the Profile page.
  static const String profileAbout = '/profile/about';

  // ── Trip routes ────────────────────────────────────────────────────────────

  /// Trip Stats screen — [tripId] is a UUID path parameter.
  ///
  /// Example: `/trips/3f2a1b0c-…`
  static const String tripStats = '/trips/:id';

  /// Builds a concrete Trip Stats path for a given [tripId].
  static String tripStatsPath(String tripId) => '/trips/$tripId';
}

/// Application router.
///
/// Uses a [StatefulShellRoute] to render [MainNavigation] as the persistent
/// bottom-nav shell.  Each branch keeps its own navigation stack.
///
/// The Trip Stats screen (`/trips/:id`) lives inside the Trips branch so the
/// bottom nav remains visible and the back-stack returns to the Trips list.
///
/// Profile sub-routes (settings, about) live inside the Profile branch so the
/// bottom nav remains visible and the back button returns to Profile.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.map,
  debugLogDiagnostics: false,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state,
          StatefulNavigationShell navigationShell) {
        return MainNavigation(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0 — Map
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.map,
              builder: (context, state) => const MapScreen(),
            ),
          ],
        ),

        // Branch 1 — Trips
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.trips,
              builder: (context, state) => const TripsScreen(),
              routes: [
                // Nested route: /trips/:id
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final tripId = state.pathParameters['id']!;
                    return TripStatsScreen(tripId: tripId);
                  },
                ),
              ],
            ),
          ],
        ),

        // Branch 2 — Cars
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.cars,
              builder: (context, state) => const CarsScreen(),
            ),
          ],
        ),

        // Branch 3 — Analytics
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.analytics,
              builder: (context, state) => const AnalyticsScreen(),
            ),
          ],
        ),

        // Branch 4 — Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
              routes: [
                // Individual settings sub-pages — each row on the Profile
                // page navigates directly here, not to a shared settings hub.
                GoRoute(
                  path: 'settings/appearance',
                  builder: (context, state) => const AppearanceScreen(),
                ),
                GoRoute(
                  path: 'settings/map-appearance',
                  builder: (context, state) => const MapAppearanceScreen(),
                ),
                GoRoute(
                  path: 'settings/units',
                  builder: (context, state) => const UnitsScreen(),
                ),
                // About Milage
                GoRoute(
                  path: 'about',
                  builder: (context, state) => const AboutScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
