import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_config.dart';
import '../models/track_point_record.dart';

// ---------------------------------------------------------------------------
// TrackPointRepository
// ---------------------------------------------------------------------------

/// Data-access layer for the [kTrackPointsTable] table.
///
/// All SQL is encapsulated here.  No widget, provider, or service executes
/// raw SQL against the track-point table directly.
///
/// ## Testability
///
/// Accepts a raw [Database] connection so unit tests can inject an in-memory
/// database without the [AppDatabase] singleton.
///
/// ## Ordering
///
/// [getTrackPointsForTrip] always returns points ordered by [timestamp] ASC
/// (chronological) so callers can reconstruct the driven route in the correct
/// order without additional sorting.
///
/// ## Performance
///
/// - [addTrackPoint] inserts a single row per GPS fix.  SQLite write latency
///   on modern devices is typically < 1 ms, so per-point inserts do not block
///   the UI thread when called from the data layer.
/// - [addTrackPoints] wraps multiple inserts in a single transaction —
///   preferred for bulk inserts such as recovering a persisted drive.
/// - [getTrackPointsForTrip] relies on the composite index
///   [idx_track_points_trip_time] for O(log n) retrieval.
///
/// ## Cascade deletion
///
/// Track points are removed automatically when their parent trip is deleted
/// (ON DELETE CASCADE enforced at the database level).
/// [deleteTrackPointsForTrip] is provided for explicit cleanup if needed.
class TrackPointRepository {
  const TrackPointRepository(this._db);

  final Database _db;

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Inserts a single [TrackPointRecord] row.
  ///
  /// Called once per GPS fix during an active drive.
  /// Duplicate [id] values are ignored via [ConflictAlgorithm.ignore] to
  /// provide idempotent behaviour during drive recovery.
  Future<void> addTrackPoint(TrackPointRecord record) async {
    await _db.insert(
      kTrackPointsTable,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Inserts multiple [TrackPointRecord] rows in a single transaction.
  ///
  /// Used for bulk imports (e.g. flushing a batch or recovering points from
  /// SharedPreferences after a process restart).
  ///
  /// No-op if [records] is empty.
  Future<void> addTrackPoints(List<TrackPointRecord> records) async {
    if (records.isEmpty) return;

    await _db.transaction((txn) async {
      for (final record in records) {
        await txn.insert(
          kTrackPointsTable,
          record.toRow(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns all GPS track points for [tripId] in chronological order.
  ///
  /// Returns an empty list if the trip has no recorded points.
  Future<List<TrackPointRecord>> getTrackPointsForTrip(String tripId) async {
    final rows = await _db.query(
      kTrackPointsTable,
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(TrackPointRecord.fromRow).toList();
  }

  /// Returns the count of track points for [tripId].
  ///
  /// Cheaper than loading all points when only the count is needed.
  Future<int> getTrackPointCount(String tripId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $kTrackPointsTable WHERE trip_id = ?',
      [tripId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Deletes all track points for [tripId].
  ///
  /// Note: track points are also removed automatically by ON DELETE CASCADE
  /// when the parent trip row is deleted.  This method provides an explicit
  /// cleanup path when needed independently of trip deletion.
  Future<void> deleteTrackPointsForTrip(String tripId) async {
    await _db.delete(
      kTrackPointsTable,
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );
  }

  /// Deletes a single track point by [id].
  ///
  /// Prefer [deleteTrackPointsForTrip] for bulk removal.
  Future<void> deleteTrackPoint(String id) async {
    await _db.delete(
      kTrackPointsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
