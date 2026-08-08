import 'package:latlong2/latlong.dart';

import 'destination.dart';

// ---------------------------------------------------------------------------
// RouteStatus
// ---------------------------------------------------------------------------

/// Lifecycle states for a route calculation request.
enum RouteStatus {
  /// No destination selected — no route exists.
  idle,

  /// Route is being fetched from the routing service.
  calculating,

  /// Route successfully calculated and ready to display.
  ready,

  /// Route calculation failed.
  error,
}

// ---------------------------------------------------------------------------
// RouteResult  (the state held by RouteNotifier)
// ---------------------------------------------------------------------------

/// Immutable state representing the result of a route calculation.
///
/// When [status] is [RouteStatus.ready], [coordinates], [distanceMeters],
/// and [durationSeconds] are guaranteed non-null.
///
/// When [status] is [RouteStatus.error], [errorMessage] is non-null.
class RouteResult {
  const RouteResult({
    this.status = RouteStatus.idle,
    this.destination,
    this.coordinates = const [],
    this.distanceMeters,
    this.durationSeconds,
    this.errorMessage,
  });

  /// Current status of this route.
  final RouteStatus status;

  /// The destination this route leads to.
  ///
  /// Present for [RouteStatus.calculating], [RouteStatus.ready],
  /// and [RouteStatus.error] (allows retry with same destination).
  final Destination? destination;

  /// Ordered list of [LatLng] points that form the polyline.
  ///
  /// Non-empty only when [status] == [RouteStatus.ready].
  final List<LatLng> coordinates;

  /// Total route distance in metres.
  final double? distanceMeters;

  /// Estimated travel duration in seconds.
  final int? durationSeconds;

  /// Human-readable error description.
  ///
  /// Non-null only when [status] == [RouteStatus.error].
  final String? errorMessage;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  bool get isIdle => status == RouteStatus.idle;
  bool get isCalculating => status == RouteStatus.calculating;
  bool get isReady => status == RouteStatus.ready;
  bool get isError => status == RouteStatus.error;

  /// Human-readable distance string (e.g. "1.4 km" or "340 m").
  String get distanceLabel {
    final m = distanceMeters;
    if (m == null) return '—';
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  /// Human-readable duration string (e.g. "5 min" or "1 h 12 min").
  String get durationLabel {
    final s = durationSeconds;
    if (s == null) return '—';
    final minutes = (s / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  RouteResult copyWith({
    RouteStatus? status,
    Destination? destination,
    List<LatLng>? coordinates,
    double? distanceMeters,
    int? durationSeconds,
    String? errorMessage,
  }) {
    return RouteResult(
      status: status ?? this.status,
      destination: destination ?? this.destination,
      coordinates: coordinates ?? this.coordinates,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // ---------------------------------------------------------------------------
  // Named constructors for common transitions
  // ---------------------------------------------------------------------------

  /// Start calculating for the given [destination].
  factory RouteResult.calculating(Destination destination) => RouteResult(
        status: RouteStatus.calculating,
        destination: destination,
      );

  /// Route successfully calculated.
  factory RouteResult.ready({
    required Destination destination,
    required List<LatLng> coordinates,
    required double distanceMeters,
    required int durationSeconds,
  }) =>
      RouteResult(
        status: RouteStatus.ready,
        destination: destination,
        coordinates: coordinates,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );

  /// Route calculation failed.
  factory RouteResult.error({
    required Destination destination,
    required String message,
  }) =>
      RouteResult(
        status: RouteStatus.error,
        destination: destination,
        errorMessage: message,
      );

  @override
  String toString() => 'RouteResult('
      'status: $status, '
      'destination: ${destination?.name}, '
      'points: ${coordinates.length}, '
      'distance: $distanceLabel, '
      'duration: $durationLabel'
      ')';
}
