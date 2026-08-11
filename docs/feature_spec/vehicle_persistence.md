Read AGENTS.md.

Implement Phase 5.2 only: Vehicle Persistence.

IMPORTANT:
Phase 5.1 is complete and provides the SQLite database foundation.

Do NOT implement trip persistence, GPS persistence, analytics persistence, or the final trip database schema yet.

--------------------------------------------------
GOAL
--------------------------------------------------

Move vehicle data from the current temporary/in-memory Riverpod-only implementation to persistent SQLite storage.

The existing vehicle UI and behavior should remain intact.

After this phase:

- Vehicles survive app restarts.
- Creating a vehicle saves it to SQLite.
- Editing a vehicle updates SQLite.
- Deleting a vehicle removes it from SQLite.
- The selected vehicle survives app restarts.
- The existing vehicle popup continues to work.
- Riverpod remains responsible for reactive UI state.

The architecture should become:

Vehicle UI
    ↓
Riverpod / Vehicle Controller
    ↓
Vehicle Repository
    ↓
SQLite Database Service

The repository should be the source of truth for vehicle data.

--------------------------------------------------
IMPORTANT EXISTING UI
--------------------------------------------------

DO NOT redesign the vehicle UI.

The existing product decision is:

The car button remains in the bottom navigation bar.

Clicking the car button opens a popup/bottom sheet above the navigation bar.

The popup:

- Has rounded corners.
- Appears above the navbar.
- Shows the user's vehicles.
- Shows each vehicle using BRAND + MODEL only.
- The currently selected vehicle has a check mark.
- Has a plus button in the top-right.
- Has a delete/bin button in the top-right.
- Each vehicle row has an edit/pencil button on the right.

Plus:
- Opens a centered popup for creating a vehicle.

Edit:
- Opens a centered popup for editing that vehicle.

Delete:
- Deletes the selected vehicle only after confirmation through a centered confirmation popup.

If there are no vehicles:

Show the existing "Create your first vehicle" empty state.

Do not change these UI decisions.

--------------------------------------------------
VEHICLE MODEL
--------------------------------------------------

Inspect the existing Vehicle model first.

Reuse the existing model if one already exists.

The persistent vehicle record must contain the information currently supported by the application:

- id
- brand
- model
- year
- type

Use the existing type representation where possible.

Do not duplicate the vehicle model unnecessarily.

If the current model is unsuitable for persistence, make the smallest architectural adjustment necessary.

--------------------------------------------------
DATABASE TABLE
--------------------------------------------------

Add a vehicles table through a database migration.

The database version must be incremented from the Phase 5.1 version.

For example:

Phase 5.1:
version 1

Phase 5.2:
version 2

Do NOT delete or recreate the database.

Use the existing migration system from Phase 5.1.

The vehicles table should have:

- stable primary key
- brand
- model
- year
- type
- created_at if useful for persistence
- updated_at if useful for persistence

Choose appropriate SQLite types.

Use a stable ID rather than relying on list indexes.

Do NOT use the list position as the vehicle ID.

--------------------------------------------------
SELECTED VEHICLE
--------------------------------------------------

The selected vehicle must also persist across application restarts.

Do NOT store the selected vehicle only in Riverpod.

Use the existing database architecture to persist the selected vehicle ID.

Prefer a small application/settings persistence mechanism rather than duplicating a selected flag across every vehicle row unless the existing architecture strongly favors another approach.

There must be only one selected vehicle.

Required behavior:

If a selected vehicle exists:
- restore it when the application starts.

If no vehicle is selected:
- no vehicle is selected.

If the selected vehicle is deleted:
- clear the selected vehicle state.
- do not automatically select another vehicle unless the existing product specification explicitly requires it.

If a new vehicle is created:
- do not automatically select it unless that is already the defined product behavior.

If the user explicitly selects a vehicle:
- persist the selected vehicle ID immediately.

--------------------------------------------------
REPOSITORY
--------------------------------------------------

Create a VehicleRepository if one does not already exist.

The repository should provide operations equivalent to:

- get all vehicles
- get vehicle by ID
- create vehicle
- update vehicle
- delete vehicle
- get selected vehicle
- set selected vehicle
- clear selected vehicle

Use the project's existing database provider from Phase 5.1.

Do not let UI widgets execute SQL directly.

Do not put SQL queries inside widgets.

Do not put SQL queries directly inside Riverpod UI state unless the architecture already explicitly defines the provider as the data-access layer.

The repository should encapsulate database access.

--------------------------------------------------
RIVERPOD INTEGRATION
--------------------------------------------------

Keep Riverpod.

Refactor the existing vehicle state/controller so that:

Loading:
Riverpod/controller
    ↓
VehicleRepository
    ↓
SQLite

Create:
UI
    ↓
Riverpod/controller
    ↓
VehicleRepository
    ↓
SQLite
    ↓
refresh/update Riverpod state

Edit:
UI
    ↓
Riverpod/controller
    ↓
Repository
    ↓
SQLite
    ↓
update Riverpod state

Delete:
UI
    ↓
Riverpod/controller
    ↓
Repository
    ↓
SQLite
    ↓
update Riverpod state

Select:
UI
    ↓
Riverpod/controller
    ↓
Repository
    ↓
persist selected ID
    ↓
update Riverpod state

The UI should continue reacting immediately through Riverpod.

Do not make the UI wait for an application restart to reflect database changes.

--------------------------------------------------
APPLICATION STARTUP
--------------------------------------------------

When TripRank starts:

1. Database is initialized.
2. Vehicle repository becomes available.
3. Existing vehicles are loaded.
4. Selected vehicle is loaded.
5. Riverpod vehicle state is populated.
6. UI displays the persisted vehicles/selection.

Do not block the application unnecessarily.

Handle database errors without crashing the application.

--------------------------------------------------
EMPTY STATE
--------------------------------------------------

If the database contains zero vehicles:

Show:

"Create your first vehicle"

Use the existing UI design.

Do not insert a fake/default vehicle into the database.

--------------------------------------------------
DELETE BEHAVIOR
--------------------------------------------------

When deleting the selected vehicle:

1. Show the existing confirmation dialog.
2. If cancelled:
   - nothing changes.

3. If confirmed:
   - delete the vehicle from SQLite.
   - clear the persisted selected vehicle ID.
   - update Riverpod state.
   - update the UI immediately.

Do not leave a dangling selected vehicle ID.

--------------------------------------------------
DATA INTEGRITY
--------------------------------------------------

Prevent invalid vehicle records where practical.

At minimum:

- brand must not be empty.
- model must not be empty.
- year must use the existing valid year rules.
- type must use the existing vehicle type values.

Reuse existing validation rather than creating a second incompatible validation system.

--------------------------------------------------
TESTING
--------------------------------------------------

Add repository/database tests for:

1. Create vehicle.
2. Retrieve vehicle.
3. Retrieve all vehicles.
4. Update vehicle.
5. Delete vehicle.
6. Selected vehicle persistence.
7. Clear selected vehicle.
8. Delete selected vehicle clears selection.
9. Multiple vehicles can coexist.
10. Vehicles survive database close/reopen.
11. Database migration from version 1 to version 2 works.

Also test the existing UI behavior where practical.

--------------------------------------------------
IMPORTANT: DO NOT BREAK CURRENT FEATURES
--------------------------------------------------

Do NOT modify:

- Map
- GPS tracking
- Background location service
- Reckless Mode
- Destination Mode
- Google Maps integration
- Drive state
- Current-location pointer
- Trip recording behavior

Unless a change is absolutely required for dependency injection or architecture.

The vehicle persistence work must be isolated.

--------------------------------------------------
DO NOT IMPLEMENT
--------------------------------------------------

Do NOT implement:

- Trip table
- GPS track-point table
- Trip persistence
- Trip history persistence
- Analytics persistence
- Trip Details persistence
- Cloud synchronization
- User accounts
- Authentication
- Offline map tiles
- New vehicle UI design

Those belong to later phases.

--------------------------------------------------
DEPENDENCIES
--------------------------------------------------

Use the existing:

- sqflite
- path
- flutter_riverpod

Do not add another persistence package.

Do not replace sqflite.

Do not add SharedPreferences for vehicle storage.

--------------------------------------------------
VALIDATION
--------------------------------------------------

After implementation:

1. Run flutter pub get if necessary.
2. Run flutter analyze.
3. Run all relevant tests.
4. Run the application.
5. Create a vehicle.
6. Verify it appears immediately.
7. Close the application completely.
8. Reopen it.
9. Verify the vehicle is still there.
10. Select a vehicle.
11. Close/reopen the application.
12. Verify the selected vehicle is restored.
13. Edit a vehicle and verify the change persists.
14. Delete a vehicle and verify the deletion persists.
15. Test the zero-vehicle empty state.

Report:

- Files created
- Files modified
- Database migration/version change
- Vehicle table schema
- Repository operations
- Riverpod integration
- Selected vehicle persistence approach
- Tests performed
- flutter analyze result
- Any limitations