import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/destination.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the currently selected destination.
///
/// A destination can come from:
/// - Geocoding search (user types a place name)
/// - Map long-press (user taps a point on the map)
///
/// Both flows call [setDestination] with a [Destination] object.
/// The UI reacts purely to state changes — no direct state mutation in widgets.
///
/// Prepared for future phases:
/// - Route preview (Phase 4.3) reads [state] from this provider.
/// - Trip recording (Phase 5) clears destination on trip end.
class DestinationNotifier extends Notifier<Destination?> {
  @override
  Destination? build() => null;

  /// Set or replace the current destination.
  ///
  /// Called after the user selects a geocoding result or long-presses the map.
  void setDestination(Destination destination) {
    state = destination;
  }

  /// Clear the current destination (e.g. user cancels or new trip starts).
  void clearDestination() {
    state = null;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// The single source of truth for the currently selected [Destination].
///
/// Widgets that need to read the destination: `ref.watch(destinationProvider)`
/// Widgets that need to change it:            `ref.read(destinationProvider.notifier).setDestination(...)`
final NotifierProvider<DestinationNotifier, Destination?> destinationProvider =
    NotifierProvider<DestinationNotifier, Destination?>(
  DestinationNotifier.new,
);
