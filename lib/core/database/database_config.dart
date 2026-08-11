// ---------------------------------------------------------------------------
// DatabaseConfig
// ---------------------------------------------------------------------------
//
// Central place for all database-level constants.
//
// Rules:
// - Bump [kDatabaseVersion] when the schema changes.
// - Add a corresponding migration in AppDatabase._migrate().
// - Never lower the version number.
// - Never use destructive recreation as the normal migration strategy.
//
// Future version history (document here as versions are added):
//
//   Version 1 — Phase 5.1: Foundation (metadata table only).
//   Version 2 — Phase 5.2: vehicles table.         (not yet)
//   Version 3 — Phase 5.3: trips table.             (not yet)
//   Version 4 — Phase 5.4: track_points table.      (not yet)
//   Version 5 — Phase 5.5: driving_events table.    (not yet)
//   Version 6 — Phase 5.6: user_preferences table.  (not yet)

/// Name of the SQLite database file stored on-device.
///
/// This string becomes part of the file path resolved by [AppDatabase].
/// Do not hard-code any platform-specific path here — path resolution
/// is handled by the service.
const String kDatabaseName = 'triprank.db';

/// Current schema version.
///
/// Increment this by 1 each time the schema changes and add the matching
/// migration step in [AppDatabase._migrate].
const int kDatabaseVersion = 1;
