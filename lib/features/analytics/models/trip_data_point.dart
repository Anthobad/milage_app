// ---------------------------------------------------------------------------
// TripDataPoint — Phase 6.6 Overall Dashboard
// ---------------------------------------------------------------------------
//
// A single data point in a cross-trip trend graph.
//
// Each [TripDataPoint] represents one completed trip and carries the values
// needed to render the Analytics trend graphs without loading GPS track points.
// All values come from the persisted trips table (summary statistics).

/// A single trip represented as a graph data point.
///
/// Used by [OverallDrivingAnalytics.tripDataPoints] for trend graphs.
/// All source values come from persisted [Trip] summary fields — no GPS
/// track points are loaded to build these graphs.
class TripDataPoint {
  const TripDataPoint({
    required this.tripId,
    required this.startTime,
    required this.distanceKm,
    this.averageSpeedKmh,
    this.maximumSpeedKmh,
  });

  /// The trip ID — used for navigation to Trip Stats when a graph point is tapped.
  final String tripId;

  /// Start time of the trip (UTC).  Used as the X-axis value.
  final DateTime startTime;

  /// Total trip distance in kilometres.  Y-axis for the distance trend graph.
  final double distanceKm;

  /// Average speed in km/h from the persisted trip summary.
  ///
  /// Null when no GPS track points were recorded.
  final double? averageSpeedKmh;

  /// Maximum speed in km/h from the persisted trip summary.
  ///
  /// Null when no GPS track points were recorded.
  final double? maximumSpeedKmh;

  @override
  String toString() =>
      'TripDataPoint(trip: $tripId, time: $startTime, '
      'dist: ${distanceKm.toStringAsFixed(2)} km, '
      'avgSpd: ${averageSpeedKmh?.toStringAsFixed(1)} km/h)';
}
