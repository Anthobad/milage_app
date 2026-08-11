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
/// - Run [onCreate] to establish the schema at version [kDatabaseVersion].
/// - Dispatch incremental [onUpgrade] migrations so user data is never lost.
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
/// 3. Add a comment entry in the version history in [database_config.dart].
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
  /// Repositories must call this only after the app has completed startup.
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
  ///
  /// Throws if the database cannot be opened (e.g. disk full, permissions).
  /// The caller ([main.dart]) is responsible for handling this gracefully.
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
  ///
  /// After calling this, [database] will throw until [initialize] is called
  /// again.  Repositories must stop using the connection before this returns.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── Path resolution ────────────────────────────────────────────────────────

  /// Resolves the full, platform-safe file path for the database.
  ///
  /// Uses [getDatabasesPath] from sqflite — on Android this returns the
  /// app's databases directory; on iOS/macOS it returns the Library directory;
  /// on desktop (via sqflite_common_ffi) it uses the process working directory
  /// or a test-supplied in-memory path.
  ///
  /// Never hard-codes a platform-specific path.
  Future<String> _resolvePath() async {
    final baseDir = await getDatabasesPath();
    return p.join(baseDir, kDatabaseName);
  }

  // ── onCreate — called once when the database file is first created ─────────

  Future<void> _onCreate(Database db, int version) async {
    // Phase 5.1: create only the foundation metadata table.
    // Application tables (vehicles, trips, track_points, etc.) are created
    // in their respective migration steps as later phases are implemented.
    await _createMetadataTable(db);
  }

  // ── onUpgrade — called when kDatabaseVersion is bumped ────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Run every migration step between oldVersion and newVersion in order.
    // This handles jumping multiple versions (e.g. fresh install of a later
    // app version that skips intermediate releases).
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      await _migrate(db, v);
    }
  }

  // ── Migration dispatch ─────────────────────────────────────────────────────

  /// Applies the schema changes required to reach [targetVersion].
  ///
  /// Add a new `case` for each version bump.  Each case must be additive —
  /// use ALTER TABLE, CREATE TABLE, or CREATE INDEX.  Never DROP TABLE or
  /// recreate existing tables in a migration.
  ///
  /// Version 1 changes are applied in [_onCreate], not here, because they
  /// represent the initial schema for a fresh install.
  Future<void> _migrate(Database db, int targetVersion) async {
    switch (targetVersion) {
      // Version 1 schema is created by _onCreate — nothing to do here.
      case 1:
        break;

      // ── Future migrations ──────────────────────────────────────────────
      // case 2:
      //   await db.execute('''
      //     CREATE TABLE vehicles (
      //       id TEXT PRIMARY KEY,
      //       ...
      //     )
      //   ''');
      //   break;
      //
      // case 3:
      //   await db.execute('''
      //     CREATE TABLE trips ( ... )
      //   ''');
      //   break;

      default:
        // Unknown target version — log and skip rather than crashing.
        // ignore: avoid_print
        print('[AppDatabase] Unknown migration target version: $targetVersion');
    }
  }

  // ── Schema helpers — used by _onCreate ────────────────────────────────────

  /// Creates a lightweight metadata table.
  ///
  /// Purpose:
  /// - Provides a concrete table for the test suite to query.
  /// - Can store arbitrary key-value pairs (e.g. migration timestamps,
  ///   schema checksums) without polluting application tables.
  /// - Has zero impact on existing features.
  ///
  /// This table is intentionally minimal and does not represent application
  /// domain data (vehicles, trips, etc.).
  Future<void> _createMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS db_metadata (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed the schema version so it can be verified independently of
    // sqflite's internal version mechanism.
    await db.insert(
      'db_metadata',
      {'key': 'schema_version', 'value': '$kDatabaseVersion'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
