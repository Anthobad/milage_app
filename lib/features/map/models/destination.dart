import 'package:latlong2/latlong.dart';

/// Represents a destination chosen by the user — either via search or
/// long-pressing directly on the map.
///
/// Both selection methods produce the same [Destination] object and are
/// stored in [destinationProvider].
class Destination {
  const Destination({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// Optional identifier (e.g. from geocoding result, future DB row id).
  final String? id;

  /// Human-readable place name.
  ///
  /// For geocoded results this is the address returned by Nominatim.
  /// For map long-press it is the formatted coordinate string.
  final String name;

  final double latitude;
  final double longitude;

  /// Convenience getter for use with flutter_map / latlong2.
  LatLng get latLng => LatLng(latitude, longitude);

  Destination copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
  }) {
    return Destination(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Destination &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() =>
      'Destination(id: $id, name: $name, lat: $latitude, lng: $longitude)';
}
