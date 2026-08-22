import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// MapThemeMode — Phase 7.3
// ---------------------------------------------------------------------------
//
// Controls the visual appearance of the Google Maps / flutter_map tile layer.
//
// IMPORTANT: This is completely independent from the TripRank app ThemeMode
// (managed by ThemeModeNotifier in theme_provider.dart).
//
// The two settings have different purposes and different persistence keys:
//   App theme:  key = 'theme_mode'      (controls TripRank UI)
//   Map theme:  key = 'map_theme_mode'  (controls map tiles only)
//
// Default: [MapThemeMode.dark]

// ---------------------------------------------------------------------------
// MapThemeMode enum
// ---------------------------------------------------------------------------

/// The visual theme of the map tile layer.
///
/// Completely independent from [ThemeMode] — does NOT affect TripRank UI.
enum MapThemeMode {
  /// Dark map tiles.  Default.
  dark,

  /// Light / standard map tiles.
  light,

  /// Follow the Android system dark/light setting.
  /// The TripRank app ThemeMode remains completely independent.
  system,
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// SharedPreferences key for the persisted map theme mode.
///
/// Intentionally different from [kThemeModePreferenceKey] ('theme_mode')
/// used by the app theme to prevent any cross-contamination.
const String kMapThemeModePreferenceKey = 'map_theme_mode';

const Map<MapThemeMode, String> _kMapThemeModeToString = {
  MapThemeMode.dark: 'dark',
  MapThemeMode.light: 'light',
  MapThemeMode.system: 'system',
};

const Map<String, MapThemeMode> _kStringToMapThemeMode = {
  'dark': MapThemeMode.dark,
  'light': MapThemeMode.light,
  'system': MapThemeMode.system,
};

// ---------------------------------------------------------------------------
// MapThemeNotifier
// ---------------------------------------------------------------------------

/// Holds the currently selected [MapThemeMode] and persists it via
/// SharedPreferences.
///
/// Default (no saved preference): [MapThemeMode.dark].
///
/// Usage — read:
/// ```dart
/// final mode = ref.watch(mapThemeProvider).value ?? MapThemeMode.dark;
/// ```
///
/// Usage — write:
/// ```dart
/// ref.read(mapThemeProvider.notifier).setMapTheme(MapThemeMode.light);
/// ```
///
/// App ThemeMode is NEVER read or written here.
class MapThemeNotifier extends AsyncNotifier<MapThemeMode> {
  @override
  Future<MapThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kMapThemeModePreferenceKey);
    return _kStringToMapThemeMode[stored] ?? MapThemeMode.dark;
  }

  /// Switch to [mode] and persist the choice immediately.
  ///
  /// The state is updated optimistically — the UI reacts before the
  /// SharedPreferences write completes.  If the write fails the error
  /// is logged but the in-memory state is kept (best-effort persistence).
  Future<void> setMapTheme(MapThemeMode mode) async {
    // Update state immediately so the map responds without delay.
    state = AsyncData(mode);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kMapThemeModePreferenceKey,
        _kMapThemeModeToString[mode]!,
      );
    } catch (e) {
      debugPrint('[MapThemeNotifier] Failed to persist map theme mode: $e');
    }
  }
}

/// Global map theme mode provider.
///
/// Backed by SharedPreferences (key: 'map_theme_mode').
///
/// Does NOT interact with [themeProvider] — the two providers are fully
/// independent.
final AsyncNotifierProvider<MapThemeNotifier, MapThemeMode> mapThemeProvider =
    AsyncNotifierProvider<MapThemeNotifier, MapThemeMode>(
  MapThemeNotifier.new,
);

// ---------------------------------------------------------------------------
// Helper — resolve MapThemeMode to a concrete dark/light decision
// ---------------------------------------------------------------------------

/// Resolves [mode] to a concrete boolean [isDark] based on the current
/// system brightness when [MapThemeMode.system] is selected.
///
/// [systemBrightness] should be obtained from
/// `MediaQuery.of(context).platformBrightness` or
/// `WidgetsBinding.instance.platformDispatcher.platformBrightness`.
///
/// Returns `true` if dark tiles should be used, `false` for light tiles.
bool resolveMapIsDark(MapThemeMode mode, Brightness systemBrightness) {
  return switch (mode) {
    MapThemeMode.dark => true,
    MapThemeMode.light => false,
    MapThemeMode.system => systemBrightness == Brightness.dark,
  };
}
