import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// UnitSystem — Phase 7.4
// ---------------------------------------------------------------------------
//
// Controls how TripRank displays distance, speed, and altitude values.
//
// IMPORTANT: The unit preference is DISPLAY-ONLY.
//
// Internal canonical units are always:
//   Distance:  kilometres (km)
//   Speed:     kilometres per hour (km/h)
//   Altitude:  metres (m)
//   Duration:  seconds (unchanged — no metric/imperial for time)
//
// Conversions happen only when formatting values for display.
//
// SharedPreferences key:  'unit_system'
// Stored values:          'metric' | 'imperial'
// Default:                metric  (preserves existing TripRank behavior)
//
// Usage — read current system:
// ```dart
// final system = ref.watch(unitPreferenceProvider).value ?? UnitSystem.metric;
// ```
//
// Usage — change system:
// ```dart
// ref.read(unitPreferenceProvider.notifier).setUnitSystem(UnitSystem.imperial);
// ```
//
// DO NOT access SharedPreferences directly from UI widgets.
// DO NOT perform unit conversions inside widgets.
// Use [UnitService] for all formatting and conversion.

// ---------------------------------------------------------------------------
// UnitSystem enum
// ---------------------------------------------------------------------------

/// The unit system used for displaying distance, speed, and altitude.
///
/// [metric]   — km, km/h, m   (default — preserves existing TripRank behavior)
/// [imperial] — mi, mph, ft
enum UnitSystem {
  /// Metric units: km, km/h, m.  Default.
  metric,

  /// Imperial units: mi, mph, ft.
  imperial;

  /// Serialised string stored in SharedPreferences.
  String get value => name; // 'metric' | 'imperial'

  /// Deserialise from a stored string.  Falls back to [metric].
  static UnitSystem fromValue(String? value) {
    return UnitSystem.values.firstWhere(
      (s) => s.value == value,
      orElse: () => UnitSystem.metric,
    );
  }
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// SharedPreferences key for the persisted unit system preference.
const String kUnitSystemPreferenceKey = 'unit_system';

// ---------------------------------------------------------------------------
// UnitPreferenceNotifier
// ---------------------------------------------------------------------------

/// Holds the currently selected [UnitSystem] and persists it via
/// SharedPreferences.
///
/// Default (no saved preference): [UnitSystem.metric].
///
/// The state is updated optimistically — the UI reacts before the
/// SharedPreferences write completes.
class UnitPreferenceNotifier extends AsyncNotifier<UnitSystem> {
  @override
  Future<UnitSystem> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kUnitSystemPreferenceKey);
    return UnitSystem.fromValue(stored);
  }

  /// Switch to [system] and persist the choice immediately.
  ///
  /// The state is updated optimistically — the UI reacts before the
  /// SharedPreferences write completes.  If the write fails the error
  /// is logged but the in-memory state is kept (best-effort persistence).
  Future<void> setUnitSystem(UnitSystem system) async {
    // Update state immediately so the UI responds without delay.
    state = AsyncData(system);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kUnitSystemPreferenceKey, system.value);
    } catch (e) {
      // Persistence failure is non-fatal — the change already applied in-memory.
      // On next cold start the previous value will be restored from prefs.
      // ignore: avoid_print
      print('[UnitPreferenceNotifier] Failed to persist unit system: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global unit preference provider.
///
/// Backed by SharedPreferences (key: 'unit_system').
///
/// Usage — read (synchronous convenience with fallback to metric):
/// ```dart
/// final system = ref.watch(unitPreferenceProvider).value ?? UnitSystem.metric;
/// ```
///
/// Usage — write:
/// ```dart
/// ref.read(unitPreferenceProvider.notifier).setUnitSystem(UnitSystem.imperial);
/// ```
final AsyncNotifierProvider<UnitPreferenceNotifier, UnitSystem>
    unitPreferenceProvider =
    AsyncNotifierProvider<UnitPreferenceNotifier, UnitSystem>(
  UnitPreferenceNotifier.new,
);
