import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

/// Root application widget.
///
/// Wires together:
/// - [ProviderScope] — Riverpod dependency injection
/// - [AppTheme] — dark / light ThemeData
/// - [appRouter] — GoRouter navigation
///
/// [main.dart] only calls [runApp] with [TripRankApp].
class TripRankApp extends StatelessWidget {
  const TripRankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _AppContent(),
    );
  }
}

/// Listens to the theme provider and builds [MaterialApp.router].
/// Separated from [TripRankApp] so the [ProviderScope] is an ancestor,
/// allowing [ConsumerWidget] usage here when the theme provider is added.
class _AppContent extends ConsumerWidget {
  const _AppContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme mode will be driven by a Riverpod provider in Phase 7 (Profile &
    // Settings). Dark mode is the default per UI guidelines.
    const ThemeMode themeMode = ThemeMode.dark;

    return MaterialApp.router(
      title: 'TripRank',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // Navigation
      routerConfig: appRouter,
    );
  }
}
