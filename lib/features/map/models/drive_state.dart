import 'package:latlong2/latlong.dart';

import 'destination.dart';

// ---------------------------------------------------------------------------
// DriveStatus
// ---------------------------------------------------------------------------

/// Lifecycle state of an active drive session.
///
/// Transitions:
///   idle → starting → active → finishing → completed
///
/// The [error] state is a terminal/recoverable state used when the service
/// fails to start or an unrecoverable error occurs during tracking.
enum DriveStatus {
  /// No active drive. Default state.
  idle,

  /// Service is being started (permission checks, service launch).
  starting,

  /// Drive is active — GPS is being recorded.
  active,

  /// User pressed FINISH — recording is stopping.
  finishing,

  /// Drive has ended — data is available for trip creation.
  completed,

  /// An error occurred — drive could not be started or was interrupted.
  error,
}

// ---------------------------------------------------------------------------
// DriveMode
// ---------------------------------------------------------------------------

/// Which mode the active drive is running in.
enum DriveMode {
  /// No destination selected — user stays in TripRank.
  reckless,

  /// Destination selected — Google Maps launched for navigation.
  destination,
}

// ---------------------------------------------------------------------------
// TrackPoint
// ---------------------------------------------------------------------------

/// A single recorded GPS point during a drive.
///
/// Stored incrementally by the persistence service so that data is not lost
/// if the process is interrupted.
class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speedKmh,
    required this.timestamp,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;

  /// Altitude in metres above sea level.
  final double altitude;

  /// Speed in km/h (converted from m/s).
  final double speedKmh;

  final DateTime timestamp;

  /// GPS accuracy in metres — used for filtering low-quality points.
  final double accuracyMeters;

  // ---------------------------------------------------------------------------
  // Derived
  // ---------------------------------------------------------------------------

  LatLng get latLng => LatLng(latitude, longitude);

  // ---------------------------------------------------------------------------
  // Serialisation — stored as JSON in shared_preferences
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'alt': altitude,
        'spd': speedKmh,
        'ts': timestamp.millisecondsSinceEpoch,
        'acc': accuracyMeters,
      };

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        altitude: (json['alt'] as num).toDouble(),
        speedKmh: (json['spd'] as num).toDouble(),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['ts'] as int, isUtc: true),
        accuracyMeters: (json['acc'] as num).toDouble(),
      );

  @override
  String toString() =>
      'TrackPoint(lat: $latitude, lng: $longitude, spd: ${speedKmh.toStringAsFixed(1)} km/h, '
      'alt: ${altitude.toStringAsFixed(0)} m, ts: $timestamp)';
}

// ---------------------------------------------------------------------------
// DriveState
// ---------------------------------------------------------------------------

/// Immutable state held by [DriveNotifier].
///
/// Represents the complete state of an active (or recently completed) drive.
class DriveState {
  const DriveState({
    this.status = DriveStatus.idle,
    this.mode,
    this.trackPoints = const [],
    this.currentSpeedKmh = 0.0,
    this.currentAltitudeM = 0.0,
    this.distanceKm = 0.0,
    this.startedAt,
    this.finishedAt,
    this.errorMessage,
    this.vehicleId,
    this.destination,
  });

  /// Current lifecycle status.
  final DriveStatus status;

  /// Drive mode — non-null when status is [DriveStatus.active] or later.
  final DriveMode? mode;

  /// All recorded track points for this drive (in order).
  final List<TrackPoint> trackPoints;

  /// Most recently recorded speed in km/h.
  final double currentSpeedKmh;

  /// Most recently recorded altitude in metres.
  final double currentAltitudeM;

  /// Total distance driven so far in kilometres.
  final double distanceKm;

  /// When the drive was started.
  final DateTime? startedAt;

  /// When the drive was finished (non-null after [DriveStatus.completed]).
  final DateTime? finishedAt;

  /// Non-null when [status] is [DriveStatus.error].
  final String? errorMessage;

  /// ID of the vehicle selected when this drive started.
  ///
  /// Captured at [DriveStatus.active] onset and passed to [TripRepository]
  /// at completion so the trip record references the correct vehicle.
  final String? vehicleId;

  /// Destination selected for Destination Mode drives.
  ///
  /// Null for Reckless Mode.  Captured at drive start so the trip record
  /// stores the destination coordinates/name without a second network call.
  final Destination? destination;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  bool get isIdle => status == DriveStatus.idle;
  bool get isStarting => status == DriveStatus.starting;
  bool get isActive => status == DriveStatus.active;
  bool get isFinishing => status == DriveStatus.finishing;
  bool get isCompleted => status == DriveStatus.completed;
  bool get isError => status == DriveStatus.error;

  /// True when GPS should be actively tracked — used to determine polyline
  /// visibility and info bar data.
  bool get isDriving => status == DriveStatus.active;

  /// Polyline coordinates for the recorded path.
  List<LatLng> get path => trackPoints.map((p) => p.latLng).toList();

  /// Formatted speed string for display.
  String get speedLabel {
    if (!isDriving) return '— km/h';
    return '${currentSpeedKmh.toStringAsFixed(0)} km/h';
  }

  /// Formatted altitude string for display.
  String get altitudeLabel {
    if (!isDriving) return '— m';
    return '${currentAltitudeM.toStringAsFixed(0)} m';
  }

  /// Formatted distance string for display.
  ///
  /// Only shows a real value while a drive is actively in progress ([isDriving]).
  /// After a drive completes (or when idle) the display resets to the placeholder
  /// so the previous drive's distance is never shown in the info bar.
  String get distanceLabel {
    if (!isDriving) return '— km';
    if (distanceKm < 1.0) return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    return '${distanceKm.toStringAsFixed(2)} km';
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  DriveState copyWith({
    DriveStatus? status,
    DriveMode? mode,
    List<TrackPoint>? trackPoints,
    double? currentSpeedKmh,
    double? currentAltitudeM,
    double? distanceKm,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? errorMessage,
    Object? vehicleId = _keepSentinel,
    Object? destination = _keepSentinel,
  }) {
    return DriveState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      trackPoints: trackPoints ?? this.trackPoints,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      currentAltitudeM: currentAltitudeM ?? this.currentAltitudeM,
      distanceKm: distanceKm ?? this.distanceKm,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      vehicleId: identical(vehicleId, _keepSentinel)
          ? this.vehicleId
          : vehicleId as String?,
      destination: identical(destination, _keepSentinel)
          ? this.destination
          : destination as Destination?,
    );
  }

  @override
  String toString() =>
      'DriveState(status: $status, mode: $mode, points: ${trackPoints.length}, '
      'dist: ${distanceKm.toStringAsFixed(2)} km, spd: ${currentSpeedKmh.toStringAsFixed(1)} km/h)';
}

// Sentinel used by copyWith to distinguish "not provided" from explicit null.
const Object _keepSentinel = Object();
