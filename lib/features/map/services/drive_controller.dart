import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/destination.dart';
import '../models/drive_state.dart';
import 'drive_persistence_service.dart';
import 'google_maps_launcher.dart';
import 'location_tracking_task.dart';

// ---------------------------------------------------------------------------
// DriveStartResult
// ---------------------------------------------------------------------------

/// Returned by [DriveController.startDrive] to communicate what happened.
sealed class DriveStartResult {
  const DriveStartResult();
}

/// Drive started successfully.
class DriveStarted extends DriveStartResult {
  const DriveStarted({required this.mode});
  final DriveMode mode;
}

/// Drive could not start because Google Maps is not installed.
class DriveGoogleMapsNotInstalled extends DriveStartResult {
  const DriveGoogleMapsNotInstalled();
}

/// Google Maps failed to launch after the drive was already started.
/// Tracking remains active; the user is still in TripRank.
class DriveLaunchFailed extends DriveStartResult {
  const DriveLaunchFailed();
}

/// Drive failed to start for a non-Google-Maps reason.
class DriveStartFailed extends DriveStartResult {
  const DriveStartFailed({required this.message});
  final String message;
}

// ---------------------------------------------------------------------------
// DriveController
// ---------------------------------------------------------------------------

/// Orchestrates starting and stopping a drive.
///
/// Responsibilities:
/// - Initialise [FlutterForegroundTask] service configuration.
/// - Verify Google Maps installation when needed.
/// - Start / stop the foreground GPS service.
/// - Persist drive metadata via [DrivePersistenceService].
/// - Launch Google Maps for Destination Mode.
/// - Deliver live [DriveUpdate] events to [DriveNotifier] via [onUpdate].
///
/// The controller is free of Riverpod so it can be tested independently.
class DriveController {
  DriveController() {
    _initForegroundTask();
  }

  final DrivePersistenceService _persistence = DrivePersistenceService();

  // Callback injected by DriveNotifier to receive live updates.
  void Function(DriveUpdate)? onUpdate;

  // ---------------------------------------------------------------------------
  // Initialise the foreground task configuration (done once at creation)
  // ---------------------------------------------------------------------------

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'triprank_drive_channel',
        channelName: 'TripRank Drive Tracking',
        channelDescription:
            'Shows while TripRank is recording your drive in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // No repeat events — updates come from the geolocator stream.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Start drive
  // ---------------------------------------------------------------------------

  /// Starts a new drive.
  ///
  /// - [destination] null  → Reckless Mode.
  /// - [destination] set   → Destination Mode (Google Maps check + launch).
  Future<DriveStartResult> startDrive({Destination? destination}) async {
    final mode =
        destination == null ? DriveMode.reckless : DriveMode.destination;

    // --- Destination Mode: verify Google Maps ---
    if (mode == DriveMode.destination) {
      final installed = await GoogleMapsLauncher.isInstalled();
      if (!installed) return const DriveGoogleMapsNotInstalled();
    }

    // --- Request notification permission (Android 13+) ---
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // --- Persist drive metadata so it survives process death ---
    final now = DateTime.now().toUtc();
    await _persistence.beginDrive(mode: mode, startedAt: now);

    // --- Start the foreground service ---
    final started = await _startForegroundService(mode);
    if (!started) {
      await _persistence.clearDrive();
      return const DriveStartFailed(
          message: 'Failed to start location service.');
    }

    // --- Register callback for live GPS data from the task isolate ---
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

    // --- Destination Mode: launch Google Maps ---
    if (mode == DriveMode.destination && destination != null) {
      final launched = await GoogleMapsLauncher.launchNavigation(
        latitude: destination.latitude,
        longitude: destination.longitude,
        destinationName: destination.name,
      );
      if (!launched) {
        // Tracking IS running but Maps failed — keep drive active.
        return const DriveLaunchFailed();
      }
    }

    return DriveStarted(mode: mode);
  }

  // ---------------------------------------------------------------------------
  // Stop drive
  // ---------------------------------------------------------------------------

  /// Stops tracking, clears the foreground service, and returns all recorded
  /// track points for the caller to finalise.
  Future<List<TrackPoint>> stopDrive() async {
    // Signal the task isolate to stop its GPS stream cleanly.
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({'action': 'stop'}),
    );

    // Stop the foreground service.
    await FlutterForegroundTask.stopService();

    // Unregister data callback.
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);

    // Read + clear persisted points.
    return _persistence.finishDrive();
  }

  // ---------------------------------------------------------------------------
  // Recovery — called on app start to check for interrupted drives
  // ---------------------------------------------------------------------------

  Future<PersistedDrive?> recoverDrive() async {
    return _persistence.recoverActiveDrive();
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<bool> _startForegroundService(DriveMode mode) async {
    final modeLabel =
        mode == DriveMode.destination ? 'Destination' : 'Reckless';
    try {
      final result = await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.location],
        serviceId: 1001,
        notificationTitle: 'TripRank — $modeLabel Mode',
        notificationText: 'GPS recording active…',
        callback: locationTaskEntryPoint,
      );
      return result is ServiceRequestSuccess;
    } catch (_) {
      return false;
    }
  }

  void _onTaskData(Object data) {
    if (data is! String) return;
    try {
      final Map<String, dynamic> msg =
          jsonDecode(data) as Map<String, dynamic>;

      switch (msg['type'] as String?) {
        case 'point':
          final point =
              TrackPoint.fromJson(msg['data'] as Map<String, dynamic>);
          final distanceKm = (msg['distanceKm'] as num?)?.toDouble() ?? 0.0;
          onUpdate?.call(DriveUpdatePoint(point: point, distanceKm: distanceKm));

        case 'error':
          final message = msg['msg'] as String? ?? 'Unknown location error';
          onUpdate?.call(DriveUpdateError(message: message));

        default:
          break;
      }
    } catch (_) {
      // Malformed message — ignore.
    }
  }
}

// ---------------------------------------------------------------------------
// DriveUpdate — events sent from DriveController to DriveNotifier
// ---------------------------------------------------------------------------

sealed class DriveUpdate {
  const DriveUpdate();
}

/// A new GPS point arrived — also carries the updated total distance.
class DriveUpdatePoint extends DriveUpdate {
  const DriveUpdatePoint({required this.point, required this.distanceKm});
  final TrackPoint point;
  final double distanceKm;
}

/// A location stream error occurred.
class DriveUpdateError extends DriveUpdate {
  const DriveUpdateError({required this.message});
  final String message;
}
