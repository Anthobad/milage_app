import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/destination.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// The result of a geocoding lookup.
sealed class GeocodingResult {
  const GeocodingResult();
}

/// Successful lookup — contains a (possibly empty) list of places.
final class GeocodingSuccess extends GeocodingResult {
  const GeocodingSuccess(this.places);
  final List<Destination> places;
}

/// Failed lookup — contains a user-facing message.
final class GeocodingError extends GeocodingResult {
  const GeocodingError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Geocoding service backed by the free Nominatim OpenStreetMap API.
///
/// No API key required. Per the Nominatim usage policy a valid
/// [User-Agent] header is required.
///
/// Docs: https://nominatim.org/release-docs/latest/api/Search/
class GeocodingService {
  // ignore: prefer_initializing_formals
  const GeocodingService({http.Client? client}) : _client = client;
  final http.Client? _client;

  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'TripRank/1.0 (triprank.app)';

  // Nominatim fair-use: max 1 request per second. The UI debounces the input
  // so this service itself does not add an artificial delay.

  /// Search for places matching [query].
  ///
  /// Returns up to [limit] results (default 5).
  /// On network/parse errors returns [GeocodingError].
  Future<GeocodingResult> search(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const GeocodingSuccess([]);

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '0',
    });

    try {
      final client = _client ?? http.Client();
      final response = await client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode != 200) {
        return GeocodingError(
          'Search failed (HTTP ${response.statusCode}). Please try again.',
        );
      }

      final List<dynamic> data =
          jsonDecode(response.body) as List<dynamic>;

      final places = data
          .map((item) => _parsePlace(item as Map<String, dynamic>))
          .whereType<Destination>()
          .toList();

      return GeocodingSuccess(places);
    } on FormatException {
      return const GeocodingError('Unexpected response from search service.');
    } catch (_) {
      return const GeocodingError(
        'Could not reach search service. Check your connection.',
      );
    }
  }

  /// Reverse-geocode [latitude]/[longitude] to a place name.
  ///
  /// Used when the user long-presses the map to get a readable name.
  /// Falls back to a coordinate string if reverse geocoding fails.
  Future<String> reverseLookup(double latitude, double longitude) async {
    final uri =
        Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
      'lat': '$latitude',
      'lon': '$longitude',
      'format': 'jsonv2',
      'zoom': '16',
      'addressdetails': '0',
    });

    try {
      final client = _client ?? http.Client();
      final response = await client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // Shorten the address: take the first two comma-separated parts.
          final parts = displayName.split(',');
          return parts.length > 2
              ? '${parts[0].trim()}, ${parts[1].trim()}'
              : displayName;
        }
      }
    } catch (_) {
      // Fall through to coordinate fallback.
    }

    // Fallback: formatted coordinate string.
    return _coordLabel(latitude, longitude);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Destination? _parsePlace(Map<String, dynamic> item) {
    try {
      final lat = double.parse(item['lat'] as String);
      final lon = double.parse(item['lon'] as String);
      final rawName = item['display_name'] as String? ?? '';

      // Shorten display name for list readability.
      final parts = rawName.split(',');
      final shortName = parts.length > 2
          ? '${parts[0].trim()}, ${parts[1].trim()}'
          : rawName;

      final id = item['place_id']?.toString();

      return Destination(
        id: id,
        name: shortName.isNotEmpty ? shortName : rawName,
        latitude: lat,
        longitude: lon,
      );
    } catch (_) {
      return null;
    }
  }

  static String _coordLabel(double lat, double lon) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lonDir = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(5)}°$latDir, '
        '${lon.abs().toStringAsFixed(5)}°$lonDir';
  }
}
