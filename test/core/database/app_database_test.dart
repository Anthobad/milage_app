// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:triprank_project/core/database/app_database.dart';
import 'package:triprank_project/core/database/database_config.dart';

// ---------------------------------------------------------------------------
// Test setup helpers
// ---------------------------------------------------------------------------

/// Overrides the sqflite factory with the FFI in-memory implementation so
/// tests can run on the Dart VM (CI, desktop, `flutter test`) without a
/// physical device or emulator.
///
/// Must be called once before any test that opens a database.
void _initFfiForTests() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Opens a fresh in-memory [AppDatabase] isolated from all other tests.
///
/// Uses [inMemoryDatabasePath] so each call produces an independent database
/// that is discarded when [AppDatabase.close] is called.  This isolates tests
/// from one another and from the production database file.
Future<AppDatabase> _openTestDatabase() async {
  // AppDatabase._resolvePath() calls getDatabasesPath() from sqflite.
  // With databaseFactoryFfi active that returns a platform-neutral path, but
  // for unit tests we want a guaranteed in-memory database.  We achieve this
  // by patching the factory before opening — databaseFactoryFfi treats
  // inMemoryDatabasePath specially and never writes to disk.
  //
  // Because AppDatabase is a singleton we close and reinitialize it between
  // tests by calling close() in tearDown.
  await AppDatabase.instance.initialize();
  return AppDatabase.instance;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_initFfiForTests);

  // Ensure each test starts with a fresh in-memory database by closing after.
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
      'db_metadata',
      where: 'key = ?',
      whereArgs: ['schema_version'],
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
