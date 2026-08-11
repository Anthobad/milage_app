import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_config.dart';

// ---------------------------------------------------------------------------
// AppDatabase
// ---------------------------------------------------------------------------

/// Singleton SQLite database service.
///
/// Responsibilities:
/// - Resolve the on-device database path in a platform-safe way.
/// - Open / create the database exactly once.
/// - Run [_onCreate] to establish the full schema for fresh installs.
/// - Dispatch incremental [_onUpgrade] migrations so user data is never lost.
/// - Expose the live [Database] connection to repositories.
/// - Close the connection cleanly.
///
/// ## Extension points (future phases)
///
/// When a new table or schema change is needed:
/// 1. Bump [kDatabaseVersion] in [database_config.dart].
/// 2. Add a `case N:` block in [_migrate] that runs the ALTER / CREATE SQL.
/// 3. Also add the same CREATE TABLE call to [_onCreate] so fresh installs
///    get the full schema in one shot.
/// 4. Document the version in the history comment in [database_config.dart].
///
/// Do NOT recreate the database to apply changes — always migrate.
class AppDatabase {
  AppDatabase._();

  // ── Singleton ──────────────────────────────────────────────────────────────

  static final AppDatabase instance = AppDatabase._();

  // ── Internal state ─────────────────────────────────────────────────────────

  Database? _db;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// The live database connection.
  ///
  /// Throws [StateError] if [initialize] has not been called yet.
  Database get database {
    final db = _db;
    if (db == null) {
      throw StateError(
        'AppDatabase has not been initialized. '
        'Call AppDatabase.instance.initialize() before accessing the database.',
      );
    }
    return db;
  }

  /// Returns true if the database has been successfully opened.
  bool get isOpen => _db?.isOpen == true;

  /// Opens the database, running [_onCreate] or [_onUpgrade] as appropriate.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops if the
  /// database is already open.
  Future<void> initialize() async {
    if (_db?.isOpen == true) return;

    final dbPath = await _resolvePath();

    _db = await openDatabase(
      dbPath,
      version: kDatabaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: onDatabaseDowngradeDelete, // safety fallback only
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── Path resolution ────────────────────────────────────────────────────────

  Future<String> _resolvePath() async {
    final baseDir = await getDatabasesPath();
    return p.join(baseDir, kDatabaseName);
  }

  // ── onConfigure — called before onCreate/onUpgrade ────────────────────────

  /// Enables foreign key constraint enforcement.
  ///
  /// SQLite disables foreign key constraints by default. Enabling them here
  /// ensures that ON DELETE SET NULL (trips → vehicles) is applied correctly.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // ── onCreate — full schema for a brand-new install ─────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    // Create every table that exists at [kDatabaseVersion].
    // Fresh install — no migration steps needed.
    await _createMetadataTable(db);
    await _createVehiclesTable(db);
    await _createTripsTable(db);
  }

  // ── onUpgrade — incremental migration for existing users ──────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      await _migrate(db, v);
    }
  }

  // ── Migration dispatch ─────────────────────────────────────────────────────

  Future<void> _migrate(Database db, int targetVersion) async {
    switch (targetVersion) {
      // Version 1 schema is applied by _onCreate on a fresh install.
      case 1:
        break;

      // ── Version 2 — Phase 5.2: vehicles table ────────────────────────────
      case 2:
        await _createVehiclesTable(db);
        break;

      // ── Version 3 — Phase 5.3: trips table ──────────────────────────────
      case 3:
        await _createTripsTable(db);
        break;

      // ── Version 4 — Phase 5.4: track_points table  (not yet) ─────────────
      // case 4:
      //   await db.execute('''
      //     CREATE TABLE IF NOT EXISTS track_points (
      //       id         INTEGER PRIMARY KEY AUTOINCREMENT,
      //       trip_id    TEXT    NOT NULL,
      //       latitude   REAL    NOT NULL,
      //       longitude  REAL    NOT NULL,
      //       altitude   REAL    NOT NULL,
      //       speed_kmh  REAL    NOT NULL,
      //       heading    REAL,
      //       accuracy_m REAL,
      //       timestamp  TEXT    NOT NULL,
      //       FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
      //     )
      //   ''');
      //   break;

      default:
        // ignore: avoid_print
        print('[AppDatabase] Unknown migration target version: $targetVersion');
    }
  }

  // ── Schema helpers ─────────────────────────────────────────────────────────

  Future<void> _createMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kMetadataTable (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.insert(
      kMetadataTable,
      {
        'key': kMetaKeySchemaVersion,
        'value': '$kDatabaseVersion',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _createVehiclesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kVehiclesTable (
        id          TEXT    PRIMARY KEY,
        brand       TEXT    NOT NULL,
        model       TEXT    NOT NULL,
        year        INTEGER NOT NULL,
        type        TEXT    NOT NULL,
        created_at  TEXT    NOT NULL,
        updated_at  TEXT    NOT NULL
      )
    ''');
  }

  /// Creates the [kTripsTable] table.
  ///
  /// Schema notes:
  /// - [vehicle_id] is nullable with ON DELETE SET NULL so historical trips
  ///   survive vehicle deletion.
  /// - Speed and altitude fields are REAL NULL — computed from track points
  ///   at completion.  Null when fewer than one point was recorded.
  /// - [stops] is INTEGER NULL — stop detection is not yet implemented.
  /// - Timestamps are stored as ISO-8601 UTC strings.
  /// - [duration_seconds] is an integer (whole seconds).
  /// - Indexes on [vehicle_id] and [start_time] for efficient queries.
  Future<void> _createTripsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kTripsTable (
        id                      TEXT    PRIMARY KEY,
        vehicle_id              TEXT    REFERENCES $kVehiclesTable(id) ON DELETE SET NULL,
        mode                    TEXT    NOT NULL,
        start_time              TEXT    NOT NULL,
        end_time                TEXT    NOT NULL,
        duration_seconds        INTEGER NOT NULL,
        distance_km             REAL    NOT NULL,

        start_latitude          REAL    NOT NULL,
        start_longitude         REAL    NOT NULL,
        start_name              TEXT,

        destination_latitude    REAL,
        destination_longitude   REAL,
        destination_name        TEXT,

        average_speed_kmh       REAL,
        minimum_speed_kmh       REAL,
        maximum_speed_kmh       REAL,

        minimum_altitude_m      REAL,
        maximum_altitude_m      REAL,

        stops                   INTEGER,

        created_at              TEXT    NOT NULL
      )
    ''');

    // Index for fast per-vehicle trip history queries.
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_trips_vehicle_id
        ON $kTripsTable (vehicle_id)
    ''');

    // Index for chronological sorting.
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_trips_start_time
        ON $kTripsTable (start_time DESC)
    ''');
  }
}
