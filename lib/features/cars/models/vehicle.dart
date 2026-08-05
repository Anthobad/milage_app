/// Vehicle body type.
enum VehicleType {
  sedan,
  suv,
  hatchback,
  coupe,
  convertible,
  wagon,
  pickup,
  van,
  minivan,
  other;

  /// Human-readable label shown in the UI.
  String get label => switch (this) {
        VehicleType.sedan => 'Sedan',
        VehicleType.suv => 'SUV',
        VehicleType.hatchback => 'Hatchback',
        VehicleType.coupe => 'Coupe',
        VehicleType.convertible => 'Convertible',
        VehicleType.wagon => 'Wagon',
        VehicleType.pickup => 'Pickup',
        VehicleType.van => 'Van',
        VehicleType.minivan => 'Minivan',
        VehicleType.other => 'Other',
      };

  /// Serialised string stored in the database.
  String get value => name; // e.g. 'sedan', 'suv'

  /// Deserialise from a stored string. Falls back to [VehicleType.other].
  static VehicleType fromValue(String value) {
    return VehicleType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VehicleType.other,
    );
  }
}

/// Represents a user's vehicle.
///
/// This is a pure data class — no UI, no storage logic.
/// Serialisation methods (`toMap` / `fromMap`) are included for future
/// local database use (Phase 3).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.type,
    required this.createdAt,
  });

  /// Unique identifier (UUID).
  final String id;

  /// Vehicle manufacturer, e.g. "Toyota".
  final String brand;

  /// Vehicle model name, e.g. "Corolla".
  final String model;

  /// Manufacturing year, e.g. 2020.
  final int year;

  /// Body type.
  final VehicleType type;

  /// When this vehicle was added to the app.
  final DateTime createdAt;

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    int? year,
    VehicleType? type,
    DateTime? createdAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation — for future local database use
  // ---------------------------------------------------------------------------

  /// Serialise to a map suitable for database storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'year': year,
      'type': type.value,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Deserialise from a database map.
  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int,
      type: VehicleType.fromValue(map['type'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & debug
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          brand == other.brand &&
          model == other.model &&
          year == other.year &&
          type == other.type &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, brand, model, year, type, createdAt);

  @override
  String toString() =>
      'Vehicle(id: $id, brand: $brand, model: $model, '
      'year: $year, type: ${type.label}, createdAt: $createdAt)';
}
