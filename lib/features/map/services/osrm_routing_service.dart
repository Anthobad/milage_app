import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/destination.dart';
import '../models/route_result.dart';
import 'routing_service.dart';

// ---------------------------------------------------------------------------
// OSRM Routing Service
// ---------------------------------------------------------------------------

/// Routing service backed by the free public OSRM demo server.
///
/// OSRM (Open Source Routing Machine) uses OpenStreetMap data and is
/// completely free — no API key required.
///
/// Demo server: https://router.project-osrm.org
/// API docs:    http://project-osrm.org/docs/v5.5.1/api/
///
/// The route geometry is encoded as a GeoJSON LineString via the
/// `geometries=geojson` parameter, which avoids the need for a polyline
/// decoder dependency.
class OsrmRoutingService extends RoutingService {
  const OsrmRoutingService({this._client});

  final http.Client? _client;

  static const String _baseUrl = 'https://router.project-osrm.org';
  static const String _userAgent = 'TripRank/1.0 (triprank.app)';

  // OSRM route endpoint: /route/v1/{profile}/{coordinates}
  // profile: driving | walking | cycling
  static const String _profile = 'driving';

  @override
  Future<RouteResult> getRoute({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
  }) async {
    // Create a temporary Destination for error/result objects.
    final dest = Destination(
      name: destinationName,
      latitude: destination.latitude,
      longitude: destination.longitude,
    );

    // OSRM coordinate format: longitude,latitude (note: lon first!)
    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';

    final uri = Uri.parse('$_baseUrl/route/v1/$_profile/$coordinates')
        .replace(queryParameters: {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'false',
      'annotations': 'false',
    });

    try {
      final client = _client ?? http.Client();
      final response = await client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return RouteResult.error(
          destination: dest,
          message: 'Routing service unavailable (HTTP ${response.statusCode}).',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final osrmCode = data['code'] as String?;
      if (osrmCode != 'Ok') {
        return RouteResult.error(
          destination: dest,
          message: _osrmErrorMessage(osrmCode),
        );
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return RouteResult.error(
          destination: dest,
          message: 'No route found between the two points.',
        );
      }

      final route = routes.first as Map<String, dynamic>;

      // Distance in metres, duration in seconds.
      final distanceMeters = (route['distance'] as num).toDouble();
      final durationSeconds = (route['duration'] as num).round();

      // GeoJSON coordinates: [[lon, lat], [lon, lat], ...]
      final geometry = route['geometry'] as Map<String, dynamic>;
      final rawCoords = geometry['coordinates'] as List<dynamic>;

      final polylinePoints = rawCoords.map((c) {
        final pair = c as List<dynamic>;
        // GeoJSON is [longitude, latitude]
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();

      if (polylinePoints.isEmpty) {
        return RouteResult.error(
          destination: dest,
          message: 'Route found but contains no path coordinates.',
        );
      }

      return RouteResult.ready(
        destination: dest,
        coordinates: polylinePoints,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } on FormatException {
      return RouteResult.error(
        destination: dest,
        message: 'Unexpected response from routing service.',
      );
    } catch (e) {
      // Catches SocketException, TimeoutException, etc.
      return RouteResult.error(
        destination: dest,
        message: 'Could not reach routing service. Check your connection.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _osrmErrorMessage(String? code) {
    return switch (code) {
      'NoRoute' => 'No route could be found for these locations.',
      'NoSegment' => 'One of the locations could not be matched to a road.',
      'TooBig' => 'The route is too long to calculate.',
      _ => 'Route calculation failed. Please try again.',
    };
  }
}
