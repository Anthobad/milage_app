import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/destination.dart';
import '../models/route_result.dart';
import '../services/osrm_routing_service.dart';
import '../services/routing_service.dart';
import 'destination_provider.dart';
import 'map_provider.dart';

// ---------------------------------------------------------------------------
// RouteNotifier
// ---------------------------------------------------------------------------

/// Manages route calculation state.
///
/// Watches [destinationProvider]:
/// - When a destination is selected → automatically triggers a route fetch.
/// - When destination is cleared → resets state to [RouteStatus.idle].
///
/// Guards against stale results: if the destination changes while a request
/// is in-flight, the older result is discarded.
///
/// Architecture (per AI_RULES.md R5):
/// - All routing business logic lives here — not in any widget.
/// - The [RoutingService] is injected and abstracted for easy replacement.
class RouteNotifier extends Notifier<RouteResult> {
  late final RoutingService _routingService;

  @override
  RouteResult build() {
    _routingService = const OsrmRoutingService();

    // React to destination changes.
    ref.listen<Destination?>(
      destinationProvider,
      (previous, next) {
        if (next == null) {
          _reset();
        } else if (next != previous) {
          _calculateRoute(next);
        }
      },
    );

    // If a destination is already selected when this provider is first built
    // (e.g. hot restart), kick off calculation immediately.
    final currentDest = ref.read(destinationProvider);
    if (currentDest != null) {
      Future.microtask(() => _calculateRoute(currentDest));
    }

    return const RouteResult();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Retry the last failed route calculation.
  ///
  /// No-op if the current status is not [RouteStatus.error] or if there is
  /// no stored destination.
  void retry() {
    final dest = state.destination;
    if (dest != null && state.isError) {
      _calculateRoute(dest);
    }
  }

  /// Manually clear the route (called e.g. when destination is cleared).
  void clearRoute() => _reset();

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _reset() {
    state = const RouteResult();
  }

  Future<void> _calculateRoute(Destination destination) async {
    // Snapshot the destination we're calculating for.
    final targetDest = destination;

    // Optimistic state → calculating.
    state = RouteResult.calculating(targetDest);

    // Fetch current location from mapProvider.
    final origin = ref.read(mapProvider).currentLocation;
    if (origin == null) {
      state = RouteResult.error(
        destination: targetDest,
        message: 'Current location is not available. Please wait and try again.',
      );
      return;
    }

    final result = await _routingService.getRoute(
      destinationName: targetDest.name,
      origin: origin,
      destination: targetDest.latLng,
    );

    // Discard stale result: if the destination changed while we were fetching,
    // this result is no longer relevant.
    final currentDest = ref.read(destinationProvider);
    if (currentDest != targetDest) return;

    state = result;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Single source of truth for the current route.
///
/// Widgets read: `ref.watch(routeProvider)`
/// Notifier:     `ref.read(routeProvider.notifier).retry()`
final NotifierProvider<RouteNotifier, RouteResult> routeProvider =
    NotifierProvider<RouteNotifier, RouteResult>(RouteNotifier.new);
