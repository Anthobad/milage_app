import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/drive_state.dart';

// ---------------------------------------------------------------------------
// DrivePersistenceService
// ---------------------------------------------------------------------------

/// Persists GPS track points incrementally to [SharedPreferences].
///
/// Points are written one-by-one as they arrive so that even if the process
/// is killed, all points recorded up to that moment are preserved.
///
/// Key layout:
///   [_kDriveActiveKey]  — bool: whether a drive is currently active.
///   [_kDriveModeKey]    — string: 'reckless' | 'destination'.
///   [_kStartedAtKey]    — int: milliseconds since epoch (UTC).
///   [_kPointsKey]       — JSON array of serialised [TrackPoint] objects.
///
/// Usage:
///   // Start:
///   await service.beginDrive(mode: DriveMode.reckless);
///
///   // Each GPS point:
///   await service.appendPoint(trackPoint);
///
///   // On app restart while drive was active:
///   final recovered = await service.recoverActiveDrive();
///
///   // Finish:
///   final points = await service.finishDrive();
class DrivePersistenceService {
  static const String _kDriveActiveKey = 'triprank.drive.active';
  static const String _kDriveModeKey = 'triprank.drive.mode';
  static const String _kStartedAtKey = 'triprank.drive.startedAt';
  static const String _kPointsKey = 'triprank.drive.points';

  // ---------------------------------------------------------------------------
  // Start a new drive — wipes any stale previous data
  // ---------------------------------------------------------------------------

  Future<void> beginDrive({
    required DriveMode mode,
    required DateTime startedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDriveActiveKey, true);
    await prefs.setString(_kDriveModeKey, mode.name);
    await prefs.setInt(_kStartedAtKey, startedAt.millisecondsSinceEpoch);
    await prefs.setString(_kPointsKey, '[]');
  }

  // ---------------------------------------------------------------------------
  // Append a single point — called for every GPS update
  // ---------------------------------------------------------------------------

  /// Appends [point] to the persisted list.
  ///
  /// Reads the current list, appends, then writes back.
  /// This is safe because writes are serialised through SharedPreferences.
  Future<void> appendPoint(TrackPoint point) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPointsKey) ?? '[]';
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    list.add(point.toJson());
    await prefs.setString(_kPointsKey, jsonEncode(list));
  }

  // ---------------------------------------------------------------------------
  // Recovery — called on app launch to resume an interrupted drive
  // ---------------------------------------------------------------------------

  /// Returns the persisted drive data if a drive was active when the process
  /// was last killed, or [null] if no active drive was found.
  Future<PersistedDrive?> recoverActiveDrive() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_kDriveActiveKey) ?? false;
    if (!active) return null;

    final modeStr = prefs.getString(_kDriveModeKey);
    final startedAtMs = prefs.getInt(_kStartedAtKey);
    final raw = prefs.getString(_kPointsKey) ?? '[]';

    if (modeStr == null || startedAtMs == null) {
      // Corrupted state — clear it.
      await clearDrive();
      return null;
    }

    final mode = DriveMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => DriveMode.reckless,
    );

    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    final points = list
        .cast<Map<String, dynamic>>()
        .map(TrackPoint.fromJson)
        .toList();

    return PersistedDrive(
      mode: mode,
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs, isUtc: true),
      trackPoints: points,
    );
  }

  // ---------------------------------------------------------------------------
  // Finish — returns all points and clears storage
  // ---------------------------------------------------------------------------

  /// Reads all persisted points, clears the drive storage, and returns the
  /// points so they can be used to create the final trip record.
  Future<List<TrackPoint>> finishDrive() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPointsKey) ?? '[]';
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    final points = list
        .cast<Map<String, dynamic>>()
        .map(TrackPoint.fromJson)
        .toList();

    await clearDrive();
    return points;
  }

  // ---------------------------------------------------------------------------
  // Clear — used on finish or on explicit cancel
  // ---------------------------------------------------------------------------

  Future<void> clearDrive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDriveActiveKey);
    await prefs.remove(_kDriveModeKey);
    await prefs.remove(_kStartedAtKey);
    await prefs.remove(_kPointsKey);
  }

  // ---------------------------------------------------------------------------
  // Read current points without clearing (used for UI recovery)
  // ---------------------------------------------------------------------------

  Future<List<TrackPoint>> readPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPointsKey) ?? '[]';
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(TrackPoint.fromJson)
        .toList();
  }
}

// ---------------------------------------------------------------------------
// PersistedDrive — value object returned by recoverActiveDrive()
// ---------------------------------------------------------------------------

class PersistedDrive {
  const PersistedDrive({
    required this.mode,
    required this.startedAt,
    required this.trackPoints,
  });

  final DriveMode mode;
  final DateTime startedAt;
  final List<TrackPoint> trackPoints;
}
