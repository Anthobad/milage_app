import 'package:latlong2/latlong.dart';

import '../models/route_result.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Abstract routing service.
///
/// The interface is decoupled from any concrete provider so that the
/// implementation (currently OSRM) can be swapped later without touching
/// the UI or state layer.
///
/// Contract:
/// - Returns [RouteResult.ready] on success.
/// - Returns [RouteResult.error] on failure — never throws.
abstract class RoutingService {
  const RoutingService();

  /// Calculate a route from [origin] to [destination].
  ///
  /// Returns a [RouteResult] with status [RouteStatus.ready] on success,
  /// or [RouteStatus.error] with a message on failure.
  Future<RouteResult> getRoute({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
  });
}
