import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// ThemeModeNotifier — Phase 7.2
// ---------------------------------------------------------------------------
//
// Holds the current [ThemeMode] and persists the selection to
// SharedPreferences so the preference survives:
//   • Widget rebuilds
//   • Navigation away from the Appearance page
//   • App close / reopen
//   • Phone restart
//
// Default: [ThemeMode.dark]  (TripRank primary experience)
//
// SharedPreferences key: 'theme_mode'
// Stored values:  'dark' | 'light' | 'system'
//
// The provider is an AsyncNotifier<ThemeMode> so the initial load from
// SharedPreferences is properly awaited before the first frame.
//
// Usage — read current mode:
// ```dart
// final mode = ref.watch(themeProvider);          // AsyncValue<ThemeMode>
// final mode = ref.watch(themeProvider).value     // ThemeMode? (may be null while loading)
// ```
//
// Usage — change mode:
// ```dart
// ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
// ```
//
// Map theme is NOT controlled by this provider — see Phase 7.3.

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// SharedPreferences key for the persisted theme mode.
const String kThemeModePreferenceKey = 'theme_mode';

/// Mapping of [ThemeMode] → stored string value.
const Map<ThemeMode, String> _kThemeModeToString = {
  ThemeMode.dark: 'dark',
  ThemeMode.light: 'light',
  ThemeMode.system: 'system',
};

/// Mapping of stored string value → [ThemeMode].
const Map<String, ThemeMode> _kStringToThemeMode = {
  'dark': ThemeMode.dark,
  'light': ThemeMode.light,
  'system': ThemeMode.system,
};

// ---------------------------------------------------------------------------
// ThemeModeNotifier
// ---------------------------------------------------------------------------

/// Notifier that holds the current [ThemeMode] and persists it via
/// SharedPreferences.
///
/// Defaults to [ThemeMode.dark] if no saved preference exists.
///
/// Exposes [setTheme] to change and persist the selection.
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kThemeModePreferenceKey);
    return _kStringToThemeMode[stored] ?? ThemeMode.dark;
  }

  /// Switch to [mode] and persist the choice immediately.
  ///
  /// The state is updated optimistically — the UI reacts before the
  /// SharedPreferences write completes.  If the write fails the error
  /// is logged but the in-memory state is kept (best-effort persistence).
  Future<void> setTheme(ThemeMode mode) async {
    // Update state immediately so the UI responds without delay.
    state = AsyncData(mode);

    // Persist in the background.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kThemeModePreferenceKey,
        _kThemeModeToString[mode]!,
      );
    } catch (e) {
      // Persistence failure is non-fatal — the theme change already applied.
      // On next cold start the previous value will be restored from prefs.
      debugPrint('[ThemeModeNotifier] Failed to persist theme mode: $e');
    }
  }
}

/// Global theme mode provider.
///
/// Backed by SharedPreferences for cross-session persistence.
///
/// Usage — read (synchronous convenience with fallback to dark):
/// ```dart
/// final mode = ref.watch(themeProvider).value ?? ThemeMode.dark;
/// ```
///
/// Usage — write:
/// ```dart
/// ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
/// ```
final AsyncNotifierProvider<ThemeModeNotifier, ThemeMode> themeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
