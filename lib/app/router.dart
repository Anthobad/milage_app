import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/analytics_screen.dart';
import '../features/cars/presentation/cars_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/trips/presentation/trip_screen.dart';
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
}

/// Application router.
///
/// Uses a [StatefulShellRoute] to render [MainNavigation] as the persistent
/// bottom-nav shell.  Each branch keeps its own navigation stack.
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
            ),
          ],
        ),
      ],
    ),
  ],
);
