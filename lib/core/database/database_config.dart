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
// Version history:
//
//   Version 1 — Phase 5.1: Foundation (db_metadata table only).
//   Version 2 — Phase 5.2: vehicles table + selected_vehicle_id metadata key.
//   Version 3 — Phase 5.3: trips table (vehicle_id ON DELETE SET NULL).
//   Version 4 — Phase 5.4: trip_track_points table.
//   Version 5 — Feature:   trips.vehicle_id changed to ON DELETE CASCADE
//                           (deleting a vehicle now deletes its trips).

/// Name of the SQLite database file stored on-device.
///
/// Do not hard-code any platform-specific path here — path resolution
/// is handled by [AppDatabase].
const String kDatabaseName = 'triprank.db';

/// Current schema version.
///
/// Increment this by 1 each time the schema changes and add the matching
/// migration step in [AppDatabase._migrate].
const int kDatabaseVersion = 5;

// ---------------------------------------------------------------------------
// Table name constants
// ---------------------------------------------------------------------------

/// Metadata key-value table — used for schema version, app preferences, etc.
const String kMetadataTable = 'db_metadata';

/// Vehicles table name.
const String kVehiclesTable = 'vehicles';

/// Trips table name.
const String kTripsTable = 'trips';

/// GPS track-point table name.
///
/// Each row is one GPS coordinate recorded during an active drive.
/// Linked to [kTripsTable] via [trip_id] with ON DELETE CASCADE — deleting a
/// Trip removes all its GPS points automatically.
const String kTrackPointsTable = 'trip_track_points';

// ---------------------------------------------------------------------------
// db_metadata key constants
// ---------------------------------------------------------------------------

/// Key storing the current schema version in [kMetadataTable].
const String kMetaKeySchemaVersion = 'schema_version';

/// Key storing the ID of the currently selected vehicle.
///
/// The value is the vehicle's UUID string, or absent/empty when nothing is
/// selected.  Stored in [kMetadataTable] rather than as a flag on each
/// vehicle row so there is exactly one authoritative source of selection.
const String kMetaKeySelectedVehicleId = 'selected_vehicle_id';
