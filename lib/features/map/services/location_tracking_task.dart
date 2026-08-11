import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../models/drive_state.dart';
import 'drive_persistence_service.dart';

// ---------------------------------------------------------------------------
// Entry point — called by flutter_foreground_task in its own isolate
// ---------------------------------------------------------------------------

/// Top-level callback required by flutter_foreground_task.
///
/// Must be annotated with @pragma('vm:entry-point') and be a top-level
/// function so that the AOT compiler does not tree-shake it.
@pragma('vm:entry-point')
void locationTaskEntryPoint() {
  FlutterForegroundTask.setTaskHandler(LocationTrackingTaskHandler());
}

// ---------------------------------------------------------------------------
// LocationTrackingTaskHandler
// ---------------------------------------------------------------------------

/// Runs inside the foreground-service isolate.
///
/// Responsibilities:
/// - Open a geolocator position stream.
/// - Convert each [Position] to a [TrackPoint].
/// - Persist each point via [DrivePersistenceService].
/// - Send each point as JSON to the main isolate via
///   [FlutterForegroundTask.sendDataToMain] so the UI can update live.
/// - Update the foreground notification text with the latest speed.
///
/// Communication protocol (main ↔ task):
///   main → task: {"action": "stop"}        – stop tracking immediately.
///   task → main: {"type":"point", "data":{…TrackPoint.toJson()}}
///   task → main: {"type":"error", "msg":"…"}
class LocationTrackingTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionSub;
  final DrivePersistenceService _persistence = DrivePersistenceService();
  double _totalDistanceKm = 0.0;
  TrackPoint? _lastPoint;

  // ---------------------------------------------------------------------------
  // onStart — called when the foreground service starts
  // ---------------------------------------------------------------------------

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // metres — avoids redundant stationary points
      ),
    ).listen(
      _onPosition,
      onError: (Object error) {
        FlutterForegroundTask.sendDataToMain(
          jsonEncode({'type': 'error', 'msg': error.toString()}),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // onRepeatEvent — not used; we rely on the position stream instead
  // ---------------------------------------------------------------------------

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No repeat logic — updates come from the GPS stream in onStart.
  }

  // ---------------------------------------------------------------------------
  // onReceiveData — handles commands from the main isolate
  // ---------------------------------------------------------------------------

  @override
  void onReceiveData(Object data) {
    if (data is String) {
      try {
        final Map<String, dynamic> msg =
            jsonDecode(data) as Map<String, dynamic>;
        if (msg['action'] == 'stop') {
          _cleanup();
        }
      } catch (_) {
        // Malformed message — ignore.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // onDestroy — called when the service is stopped
  // ---------------------------------------------------------------------------

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _cleanup();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _onPosition(Position position) async {
    // Build track point.
    final point = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speedKmh: (position.speed * 3.6).clamp(0.0, double.infinity),
      timestamp: DateTime.now().toUtc(),
      accuracyMeters: position.accuracy,
    );

    // Accumulate distance using the haversine calculation from geolocator.
    if (_lastPoint != null) {
      final distM = Geolocator.distanceBetween(
        _lastPoint!.latitude,
        _lastPoint!.longitude,
        point.latitude,
        point.longitude,
      );
      _totalDistanceKm += distM / 1000.0;
    }
    _lastPoint = point;

    // Persist the point incrementally.
    await _persistence.appendPoint(point);

    // Update notification so the user can see progress without opening the app.
    final speed = point.speedKmh.toStringAsFixed(0);
    final dist = _totalDistanceKm >= 1.0
        ? '${_totalDistanceKm.toStringAsFixed(2)} km'
        : '${(_totalDistanceKm * 1000).toStringAsFixed(0)} m';
    FlutterForegroundTask.updateService(
      notificationText: '$speed km/h · $dist driven',
    );

    // Send to main isolate for live UI updates.
    FlutterForegroundTask.sendDataToMain(
      jsonEncode({
        'type': 'point',
        'distanceKm': _totalDistanceKm,
        'data': point.toJson(),
      }),
    );
  }

  Future<void> _cleanup() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }
}
