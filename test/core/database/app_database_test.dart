// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:triprank_project/core/database/app_database.dart';
import 'package:triprank_project/core/database/database_config.dart';

// ---------------------------------------------------------------------------
// Test setup helpers
// ---------------------------------------------------------------------------

/// Overrides the sqflite factory with the FFI implementation so tests can
/// run on the Dart VM (CI, desktop, `flutter test`) without a physical device.
void _initFfiForTests() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Resolves the path that [AppDatabase] will use for the test DB file.
///
/// sqflite_common_ffi writes to a real directory, so we must delete the file
/// between tests to guarantee a fresh schema on every open.
Future<String> _testDbPath() async {
  final baseDir = await databaseFactoryFfi.getDatabasesPath();
  return p.join(baseDir, kDatabaseName);
}

/// Deletes the test database file if it exists.
Future<void> _deleteTestDb() async {
  final path = await _testDbPath();
  await databaseFactoryFfi.deleteDatabase(path);
}

/// Opens a fresh [AppDatabase] backed by a new on-disk (ffi) file.
Future<AppDatabase> _openTestDatabase() async {
  await AppDatabase.instance.initialize();
  return AppDatabase.instance;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_initFfiForTests);

  // Delete the DB file and close the singleton before each test so every
  // test begins with a guaranteed fresh schema.
  setUp(() async {
    if (AppDatabase.instance.isOpen) {
      await AppDatabase.instance.close();
    }
    await _deleteTestDb();
  });

  tearDown(() async {
    if (AppDatabase.instance.isOpen) {
      await AppDatabase.instance.close();
    }
  });

  // ── Test 1: Database initialization succeeds ─────────────────────────────

  test('1. Database initialization succeeds', () async {
    final db = await _openTestDatabase();
    expect(db.isOpen, isTrue);
  });

  // ── Test 2: Database can be opened ───────────────────────────────────────

  test('2. Database can be opened and database accessor is available',
      () async {
    await _openTestDatabase();
    // Accessing .database must not throw when the DB is open.
    expect(() => AppDatabase.instance.database, returnsNormally);
  });

  // ── Test 3: Database version is correct ──────────────────────────────────

  test('3. Database version matches kDatabaseVersion', () async {
    await _openTestDatabase();
    final version = await AppDatabase.instance.database.getVersion();
    expect(version, equals(kDatabaseVersion));
  });

  // ── Test 4: Multiple accesses do not create conflicting connections ───────

  test('4. Multiple calls to initialize() do not open duplicate connections',
      () async {
    // First open.
    await AppDatabase.instance.initialize();
    final db1 = AppDatabase.instance.database;

    // Second call — must be a no-op.
    await AppDatabase.instance.initialize();
    final db2 = AppDatabase.instance.database;

    // Same underlying connection object.
    expect(identical(db1, db2), isTrue);
    expect(AppDatabase.instance.isOpen, isTrue);
  });

  // ── Test 5: Migration mechanism is wired correctly ────────────────────────

  test('5. Metadata table exists and contains the correct schema_version',
      () async {
    await _openTestDatabase();
    final rows = await AppDatabase.instance.database.query(
      kMetadataTable,
      where: 'key = ?',
      whereArgs: [kMetaKeySchemaVersion],
    );

    // The seed insert in _createMetadataTable must have produced exactly one row.
    expect(rows.length, equals(1));
    expect(rows.first['value'], equals('$kDatabaseVersion'));
  });

  // ── Test 6: Close and reopen does not cause errors ────────────────────────

  test('6. Close then re-initialize works without errors', () async {
    // Open.
    await _openTestDatabase();
    expect(AppDatabase.instance.isOpen, isTrue);

    // Close.
    await AppDatabase.instance.close();
    expect(AppDatabase.instance.isOpen, isFalse);

    // Accessing .database after close must throw.
    expect(
      () => AppDatabase.instance.database,
      throwsA(isA<StateError>()),
    );

    // Reopen.
    await AppDatabase.instance.initialize();
    expect(AppDatabase.instance.isOpen, isTrue);

    // Version is still correct after reopen.
    final version = await AppDatabase.instance.database.getVersion();
    expect(version, equals(kDatabaseVersion));
  });
}
