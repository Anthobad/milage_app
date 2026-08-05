import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier that holds the current [ThemeMode].
///
/// Defaults to [ThemeMode.dark] per UI guidelines.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  /// Switch to the given [mode].
  void setTheme(ThemeMode mode) => state = mode;
}

/// Global theme mode provider.
///
/// Usage — read:
/// ```dart
/// final mode = ref.watch(themeProvider);
/// ```
///
/// Usage — write:
/// ```dart
/// ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
/// ```
final NotifierProvider<ThemeModeNotifier, ThemeMode> themeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
