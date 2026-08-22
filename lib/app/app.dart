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
    // Watches the global theme provider — persisted via SharedPreferences.
    // Falls back to ThemeMode.dark while the async load is in progress
    // (typically imperceptible — prefs load in < 1 ms).
    final ThemeMode themeMode =
        ref.watch(themeProvider).value ?? ThemeMode.dark;

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
