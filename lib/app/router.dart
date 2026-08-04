import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
/// Feature screens will be wired in as features are implemented.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.root,
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: AppRoutes.root,
      builder: (BuildContext context, GoRouterState state) {
        // Temporary placeholder until the Map feature is implemented.
        return const _AppShellPlaceholder();
      },
    ),
  ],
);

/// Minimal placeholder screen shown before the Map feature is implemented.
/// Will be replaced in Phase 4 — Map System.
class _AppShellPlaceholder extends StatelessWidget {
  const _AppShellPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'TripRank',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'App shell ready.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
