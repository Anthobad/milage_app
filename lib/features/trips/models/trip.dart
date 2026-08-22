import '../../../features/map/models/drive_state.dart';

// ---------------------------------------------------------------------------
// TripMode
// ---------------------------------------------------------------------------

/// Which mode this trip was recorded in.
///
/// Mirrors [DriveMode] exactly — stored as a string in SQLite.
enum TripMode {
  /// No destination — user stayed in TripRank.
  reckless,

  /// Destination selected — Google Maps was launched.
  destination;

  /// Serialised string stored in the database (e.g. 'reckless').
  String get value => name;

  /// Deserialise from a stored string. Falls back to [reckless].
  static TripMode fromValue(String value) {
    return TripMode.values.firstWhere(
      (m) => m.value == value,
      orElse: () => TripMode.reckless,
    );
  }

  /// Convert from [DriveMode].
  static TripMode fromDriveMode(DriveMode mode) {
    return switch (mode) {
      DriveMode.reckless => TripMode.reckless,
      DriveMode.destination => TripMode.destination,
    };
  }
}

// ---------------------------------------------------------------------------
// Trip
// ---------------------------------------------------------------------------

/// A completed driving session — the persistent record stored in SQLite.
///
/// ## Design goals
///
/// 1. **Offline-first**: all fields needed for Trip Details are stored at
///    creation time so no geocoding, routing, or network access is needed
///    to display a historical trip.
///
/// 2. **Pre-computed summary**: [averageSpeed], [minimumSpeed], [maximumSpeed],
///    [minimumAltitude], [maximumAltitude] are calculated from the GPS track at
///    drive completion and stored here.  Trip Details never recalculates them
///    from raw points.
///
/// 3. **Nullable destination**: Reckless Mode trips have no destination — all
///    `destination*` fields are null.
///
/// 4. **Vehicle relationship via nullable FK**: [vehicleId] is nullable so that
///    trips are deleted when the vehicle is deleted (`ON DELETE CASCADE`).
///
/// ## Statistics not yet available
///
/// - [stops]: stop detection is not implemented in Phase 5.3.  Field is stored
///   as null and will be populated in a future phase.
class Trip {
  const Trip({
    required this.id,
    required this.vehicleId,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceKm,
    required this.startLatitude,
    required this.startLongitude,
    this.startName,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationName,
    this.averageSpeedKmh,
    this.minimumSpeedKmh,
    this.maximumSpeedKmh,
    this.minimumAltitudeM,
    this.maximumAltitudeM,
    this.stops,
    required this.createdAt,
  });

  // ── Core ──────────────────────────────────────────────────────────────────

  /// Unique stable identifier (UUID v4).
  final String id;

  /// ID of the vehicle used for this trip.
  ///
  /// Nullable: the vehicle may have been deleted.  When the referenced vehicle
  /// is deleted the trip itself is also deleted (ON DELETE CASCADE), but this
  /// field is nullable so trips recorded without a selected vehicle are still
  /// valid.
  final String? vehicleId;

  /// Drive mode this trip was recorded in.
  final TripMode mode;

  /// UTC timestamp when the drive started.
  final DateTime startTime;

  /// UTC timestamp when the drive finished.
  final DateTime endTime;

  /// Duration of the drive in whole seconds.
  final int durationSeconds;

  /// Total distance driven in kilometres.
  final double distanceKm;

  // ── Start location ────────────────────────────────────────────────────────

  /// Latitude of the first recorded GPS point.
  final double startLatitude;

  /// Longitude of the first recorded GPS point.
  final double startLongitude;

  /// Human-readable name for the start location (reverse-geocoded at drive
  /// start if available; may be null).
  final String? startName;

  // ── Destination (null for Reckless Mode) ──────────────────────────────────

  /// Latitude of the selected destination, or null for Reckless Mode.
  final double? destinationLatitude;

  /// Longitude of the selected destination, or null for Reckless Mode.
  final double? destinationLongitude;

  /// Human-readable destination name stored at trip creation time so Trip
  /// Details can display it without network access.  May be null for
  /// Reckless Mode or when no reverse-geocoding result was available.
  final String? destinationName;

  // ── Summary statistics (nullable — not all are available in every phase) ──

  /// Average speed in km/h, or null if fewer than two track points exist.
  final double? averageSpeedKmh;

  /// Minimum recorded speed in km/h, or null if unavailable.
  final double? minimumSpeedKmh;

  /// Maximum recorded speed in km/h, or null if unavailable.
  final double? maximumSpeedKmh;

  /// Minimum recorded altitude in metres, or null if unavailable.
  final double? minimumAltitudeM;

  /// Maximum recorded altitude in metres, or null if unavailable.
  final double? maximumAltitudeM;

  /// Number of stops detected during the drive.
  ///
  /// Null until stop detection is implemented (Phase 5.5+).
  final int? stops;

  // ── Metadata ──────────────────────────────────────────────────────────────

  /// UTC timestamp when this record was inserted into the database.
  final DateTime createdAt;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// Duration formatted as "Xh Ym" or "Xm Ys".
  String get durationLabel {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// Distance formatted for display.
  String get distanceLabel {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(2)} km';
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  Trip copyWith({
    String? id,
    Object? vehicleId = _keep,
    TripMode? mode,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? distanceKm,
    double? startLatitude,
    double? startLongitude,
    Object? startName = _keep,
    Object? destinationLatitude = _keep,
    Object? destinationLongitude = _keep,
    Object? destinationName = _keep,
    Object? averageSpeedKmh = _keep,
    Object? minimumSpeedKmh = _keep,
    Object? maximumSpeedKmh = _keep,
    Object? minimumAltitudeM = _keep,
    Object? maximumAltitudeM = _keep,
    Object? stops = _keep,
    DateTime? createdAt,
  }) {
    return Trip(
      id: id ?? this.id,
      vehicleId:
          identical(vehicleId, _keep) ? this.vehicleId : vehicleId as String?,
      mode: mode ?? this.mode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceKm: distanceKm ?? this.distanceKm,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      startName:
          identical(startName, _keep) ? this.startName : startName as String?,
      destinationLatitude: identical(destinationLatitude, _keep)
          ? this.destinationLatitude
          : destinationLatitude as double?,
      destinationLongitude: identical(destinationLongitude, _keep)
          ? this.destinationLongitude
          : destinationLongitude as double?,
      destinationName: identical(destinationName, _keep)
          ? this.destinationName
          : destinationName as String?,
      averageSpeedKmh: identical(averageSpeedKmh, _keep)
          ? this.averageSpeedKmh
          : averageSpeedKmh as double?,
      minimumSpeedKmh: identical(minimumSpeedKmh, _keep)
          ? this.minimumSpeedKmh
          : minimumSpeedKmh as double?,
      maximumSpeedKmh: identical(maximumSpeedKmh, _keep)
          ? this.maximumSpeedKmh
          : maximumSpeedKmh as double?,
      minimumAltitudeM: identical(minimumAltitudeM, _keep)
          ? this.minimumAltitudeM
          : minimumAltitudeM as double?,
      maximumAltitudeM: identical(maximumAltitudeM, _keep)
          ? this.maximumAltitudeM
          : maximumAltitudeM as double?,
      stops: identical(stops, _keep) ? this.stops : stops as int?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & debug
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trip &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Trip(id: $id, mode: ${mode.value}, dist: ${distanceKm.toStringAsFixed(2)} km, '
      'start: $startTime, end: $endTime)';
}

// Sentinel used by copyWith to distinguish "not provided" from explicit null.
const Object _keep = Object();

// ---------------------------------------------------------------------------
// TripBuilder — helper for computing summary statistics at trip completion
// ---------------------------------------------------------------------------

/// Builds a [Trip] from a completed [DriveState] and optional destination.
///
/// Computes all summary statistics from the raw [DriveState.trackPoints] so
/// the repository stores pre-computed values and Trip Details never has to
/// recalculate them.
///
/// ## Statistics availability
///
/// | Statistic      | Source                          | Available? |
/// |----------------|---------------------------------|------------|
/// | distanceKm     | DriveState.distanceKm           | ✅         |
/// | durationSeconds| startTime → endTime             | ✅         |
/// | averageSpeedKmh| mean(trackPoints.speedKmh)      | ✅ (≥1 pt) |
/// | minimumSpeedKmh| min(trackPoints.speedKmh)       | ✅ (≥1 pt) |
/// | maximumSpeedKmh| max(trackPoints.speedKmh)       | ✅ (≥1 pt) |
/// | minimumAltM    | min(trackPoints.altitude)       | ✅ (≥1 pt) |
/// | maximumAltM    | max(trackPoints.altitude)       | ✅ (≥1 pt) |
/// | stops          | StopDetector result             | ✅ (Phase 6.4.1) |
class TripBuilder {
  /// Creates a [Trip] from a finalized drive.
  ///
  /// [tripId] — pre-generated UUID.
  /// [vehicleId] — ID of the selected vehicle when the drive started (may be null).
  /// [drive] — the completed [DriveState] (must have status completed or finishing).
  /// [destination] — the active [Destination] at drive end, or null for Reckless.
  /// [startName] — reverse-geocoded name for the start location, or null.
  /// [stops] — number of stops detected by [StopDetector], or null if not computed.
  static Trip build({
    required String tripId,
    required String? vehicleId,
    required DriveState drive,
    required String? startName,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationName,
    int? stops,
  }) {
    final startTime = drive.startedAt ?? DateTime.now().toUtc();
    final endTime = drive.finishedAt ?? DateTime.now().toUtc();
    final durationSeconds =
        endTime.difference(startTime).inSeconds.clamp(0, 86400 * 7);

    final points = drive.trackPoints;

    // Start coordinates — first track point, or 0,0 sentinel if no points.
    final startLat =
        points.isNotEmpty ? points.first.latitude : 0.0;
    final startLng =
        points.isNotEmpty ? points.first.longitude : 0.0;

    // Speed statistics.
    double? avgSpeed, minSpeed, maxSpeed;
    if (points.isNotEmpty) {
      final speeds = points.map((p) => p.speedKmh).toList();
      avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
      minSpeed = speeds.reduce((a, b) => a < b ? a : b);
      maxSpeed = speeds.reduce((a, b) => a > b ? a : b);
    }

    // Altitude statistics.
    double? minAlt, maxAlt;
    if (points.isNotEmpty) {
      final altitudes = points.map((p) => p.altitude).toList();
      minAlt = altitudes.reduce((a, b) => a < b ? a : b);
      maxAlt = altitudes.reduce((a, b) => a > b ? a : b);
    }

    return Trip(
      id: tripId,
      vehicleId: vehicleId,
      mode: TripMode.fromDriveMode(drive.mode ?? DriveMode.reckless),
      startTime: startTime,
      endTime: endTime,
      durationSeconds: durationSeconds,
      distanceKm: drive.distanceKm,
      startLatitude: startLat,
      startLongitude: startLng,
      startName: startName,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      destinationName: destinationName,
      averageSpeedKmh: avgSpeed,
      minimumSpeedKmh: minSpeed,
      maximumSpeedKmh: maxSpeed,
      minimumAltitudeM: minAlt,
      maximumAltitudeM: maxAlt,
      stops: stops,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
