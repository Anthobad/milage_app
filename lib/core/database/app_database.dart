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
/// ## Usage
///
/// ```dart
/// final db = AppDatabase.instance;
/// await db.initialize();          // call once at app startup
/// final conn = db.database;       // use in repositories
/// ```
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

  // ── onCreate — full schema for a brand-new install ─────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    // Always create every table that exists at the current [kDatabaseVersion].
    // This is a fresh install — no migration steps needed.
    await _createMetadataTable(db);
    await _createVehiclesTable(db);
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
      // Version 1 schema is created by _onCreate on a fresh install.
      // For users upgrading from an older build that somehow had v1,
      // there is nothing to do here (metadata table already exists).
      case 1:
        break;

      // ── Version 2 — Phase 5.2: vehicles table ────────────────────────────
      case 2:
        await _createVehiclesTable(db);
        break;

      // ── Version 3 — Phase 5.3: trips table  (not yet) ───────────────────
      // case 3:
      //   await db.execute('''
      //     CREATE TABLE trips (
      //       id          TEXT PRIMARY KEY,
      //       vehicle_id  TEXT NOT NULL,
      //       mode        TEXT NOT NULL,
      //       start_time  TEXT NOT NULL,
      //       end_time    TEXT,
      //       distance_km REAL NOT NULL DEFAULT 0,
      //       created_at  TEXT NOT NULL
      //     )
      //   ''');
      //   break;

      default:
        // ignore: avoid_print
        print('[AppDatabase] Unknown migration target version: $targetVersion');
    }
  }

  // ── Schema helpers ─────────────────────────────────────────────────────────

  /// Creates the [kMetadataTable] key-value table.
  ///
  /// Also seeds [kMetaKeySchemaVersion] with the current version so it can
  /// be verified independently of sqflite's internal version mechanism.
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

  /// Creates the [kVehiclesTable] table.
  ///
  /// Columns match [Vehicle.toMap] / [Vehicle.fromMap]:
  /// - id         — UUID primary key
  /// - brand      — manufacturer name (NOT NULL)
  /// - model      — model name (NOT NULL)
  /// - year       — integer year (NOT NULL)
  /// - type       — VehicleType.value string (NOT NULL)
  /// - created_at — ISO-8601 timestamp (NOT NULL)
  /// - updated_at — ISO-8601 timestamp, updated on every edit (NOT NULL)
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
}
