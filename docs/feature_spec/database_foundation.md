Read AGENTS.md.

Implement Phase 5.1 only: Local Database Foundation.

IMPORTANT:
Do not implement vehicle persistence, trip persistence, GPS track persistence, analytics persistence, or database-backed Riverpod providers yet.

Phase 5.1 is ONLY the database infrastructure that later phases will build on.

--------------------------------------------------
GOAL
--------------------------------------------------

Introduce a proper local SQLite database for TripRank.

The database will eventually become the persistent source of truth for:

- Vehicles
- Trips
- GPS track points
- Trip statistics
- Other persistent application data

Riverpod MUST NOT be removed.

Riverpod will continue to manage reactive/in-memory application state.

The future architecture should be:

UI
 ↓
Riverpod / Controllers
 ↓
Repositories
 ↓
SQLite Database Service
 ↓
SQLite

Do not implement the repositories yet unless a minimal interface is required by the database architecture.

--------------------------------------------------
DATABASE TECHNOLOGY
--------------------------------------------------

Use SQLite through:

- sqflite
- path

Add these dependencies only if they are not already present.

Do NOT introduce:

- Firebase
- Supabase
- Hive
- Isar
- SharedPreferences as the main database
- Any cloud database

TripRank is intended to work locally and offline.

--------------------------------------------------
DATABASE LOCATION
--------------------------------------------------

Create a proper platform-safe local database location using the path package and the appropriate application documents/database directory.

Do NOT hard-code:

- Windows paths
- Android-specific absolute paths
- User home directories
- Project-relative database paths

The database must eventually work on Android and remain architecturally portable to iOS.

--------------------------------------------------
DATABASE SERVICE
--------------------------------------------------

Create a dedicated database service responsible for:

- Opening the database
- Creating the database
- Database version management
- Running migrations
- Providing the database connection to future repositories
- Closing the database when appropriate

Do NOT put SQL/database initialization directly inside UI widgets or Riverpod UI providers.

Use a singleton or equivalent controlled database instance so the application does not unnecessarily create multiple database connections.

--------------------------------------------------
DATABASE VERSIONING
--------------------------------------------------

Initialize the database with an explicit version number.

Implement the structure so future phases can safely migrate the database.

For example:

Database version:
1

The exact version number can be chosen according to the existing project state.

Implement the migration mechanism even though Phase 5.1 does not yet contain the final application tables.

Future phases must be able to do something like:

Version 1
→ Version 2
→ Version 3

without deleting existing user data.

Do NOT use destructive database recreation as the normal migration strategy.

--------------------------------------------------
SCHEMA
--------------------------------------------------

Do NOT create the complete TripRank schema yet.

For Phase 5.1, only establish the database foundation.

If sqflite requires an onCreate callback, initialize the database cleanly without prematurely creating vehicle/trip/GPS tables.

If a minimal metadata table is useful for testing database initialization/versioning, it may be created, but do not create application tables that belong to later phases.

--------------------------------------------------
ARCHITECTURE
--------------------------------------------------

Use a structure compatible with the existing project architecture.

Before creating files:

1. Read AGENTS.md.
2. Inspect the current lib/ structure.
3. Inspect docs/ARCHITECTURE.md.
4. Inspect existing Riverpod setup.
5. Reuse existing core/shared architecture where appropriate.

Prefer something conceptually similar to:

lib/
  core/
    database/
      app_database.dart
      database_config.dart

However, follow the project's existing architecture if it already has an appropriate location.

Do NOT reorganize the entire project.

Do NOT move existing features unnecessarily.

--------------------------------------------------
INITIALIZATION
--------------------------------------------------

The application should initialize the database safely during startup.

Database initialization must:

- Complete before code that requires the database attempts to use it.
- Avoid blocking the UI unnecessarily.
- Handle initialization failures cleanly.
- Avoid opening multiple independent database instances.

Do not make the application crash silently if database initialization fails.

Provide appropriate error handling.

--------------------------------------------------
TESTING
--------------------------------------------------

Create tests for the database foundation.

At minimum verify:

1. Database initialization succeeds.
2. Database can be opened.
3. Database version is correct.
4. Database can be accessed more than once without creating conflicting connections.
5. Database migration mechanism is wired correctly.
6. Closing/reopening the database does not cause errors.

If the test environment requires a test-specific database configuration, keep that isolated from the production database.

--------------------------------------------------
IMPORTANT: RIVERPOD
--------------------------------------------------

Do NOT replace Riverpod.

Current architecture uses flutter_riverpod and it is working.

Riverpod will remain responsible for reactive application state.

The database will be responsible for persistence.

Do not convert every existing provider to database-backed providers in Phase 5.1.

That will happen gradually in later Phase 5 steps.

--------------------------------------------------
IMPORTANT: EXISTING DRIVE SYSTEM
--------------------------------------------------

Do NOT modify the existing working GPS/background tracking implementation except where absolutely necessary to initialize the database infrastructure.

Do NOT change:

- Drive lifecycle
- Reckless Mode
- Destination Mode
- Google Maps integration
- Foreground location service
- GPS tracking
- Current-location pointer
- Distance calculation

Those are already working and must remain working.

GPS point persistence will be implemented later.

--------------------------------------------------
DO NOT IMPLEMENT
--------------------------------------------------

Phase 5.1 must NOT implement:

- Vehicle database tables
- Vehicle CRUD
- Trip database tables
- Trip CRUD
- GPS track-point tables
- GPS persistence
- Trip history database integration
- Analytics database integration
- Database-backed vehicle selection
- Database-backed Riverpod providers
- Trip Details database integration
- Cloud synchronization
- User accounts
- Authentication

These belong to later phases.

--------------------------------------------------
DEPENDENCIES
--------------------------------------------------

Run dependency inspection before adding anything.

If sqflite and path are not already present, add the appropriate current stable versions compatible with the project's Flutter/Dart version.

Do not blindly upgrade unrelated dependencies.

Do not modify flutter_foreground_task.

Do not modify the existing map/GPS packages unless required.

--------------------------------------------------
VALIDATION
--------------------------------------------------

After implementation:

1. Run flutter pub get.
2. Run flutter analyze.
3. Run all relevant tests.
4. Run the application.
5. Verify the application still launches normally.
6. Verify existing Map functionality still works.
7. Verify existing Drive functionality still works.
8. Verify the database initializes successfully.

Do not claim vehicle/trip/GPS persistence has been implemented.

At the end, report:

- Files created
- Files modified
- Dependencies added
- Database version
- Database location/initialization approach
- Tests performed
- Any issues or limitations