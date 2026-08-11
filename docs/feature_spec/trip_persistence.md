Read AGENTS.md.

Implement Phase 5.3 only: Trip Persistence.

IMPORTANT:
Phase 5.1 — Local Database Foundation — is complete.
Phase 5.2 — Vehicle Persistence — is complete.

The existing SQLite database is version 2.

Implement the Trip persistence foundation now.

Do NOT implement GPS track-point persistence yet.
GPS points will be implemented in Phase 5.4.

--------------------------------------------------
GOAL
--------------------------------------------------

Persist completed TripRank drives in SQLite.

A completed Trip must contain:

1. Core trip information
2. Start location
3. Destination information when applicable
4. Finalized summary statistics

Raw GPS points will be stored separately in Phase 5.4.

The design must support fully offline access to previously completed trips.

--------------------------------------------------
IMPORTANT PRODUCT REQUIREMENT
--------------------------------------------------

Trip Details will eventually show:

- Start location
- Destination
- Date/time
- Duration
- Distance
- Average speed
- Minimum speed
- Maximum speed
- Altitude information
- Stops
- Route taken on the map
- Speed-over-time graph
- Other detailed driving statistics

Therefore, do NOT design the Trip table as only:

id
vehicleId
mode
startTime
endTime
distance

It must also contain the finalized summary data necessary for fast Trip Details loading.

The raw GPS track will remain available separately for detailed route/graph visualization.

--------------------------------------------------
OFFLINE REQUIREMENT
--------------------------------------------------

TripRank's core trip history is local-first.

A completed trip must remain viewable without internet access.

Trip Details must NOT require:

- Internet
- Online geocoding
- Online routing
- Map tile downloads

to display the stored trip metadata and summary statistics.

Store coordinates locally.

If a human-readable location/destination name is available at trip creation time, store it locally as well.

Do NOT attempt to reverse-geocode coordinates every time an old trip is opened.

If a name/address is unavailable, coordinates must still be stored.

Example:

Start:
latitude = ...
longitude = ...
name = "Beirut"

Destination:
latitude = ...
longitude = ...
name = "Jounieh"

The name fields may be nullable.

--------------------------------------------------
TRIP MODEL
--------------------------------------------------

Inspect existing drive/trip models first.

Reuse existing models where appropriate.

Do not create unnecessary duplicate models.

The persistent Trip model should contain the following.

CORE:

- id
- vehicleId
- mode
- startTime
- endTime
- distance

START LOCATION:

- startLatitude
- startLongitude
- startName (nullable)

DESTINATION:

- destinationLatitude (nullable)
- destinationLongitude (nullable)
- destinationName (nullable)

Destination fields are nullable because Reckless Mode has no destination.

SUMMARY STATISTICS:

- duration
- averageSpeed
- minimumSpeed
- maximumSpeed
- minimumAltitude
- maximumAltitude
- stops

Use appropriate numeric types.

Do not add speculative statistics that are not currently supported by the product specification.

--------------------------------------------------
STATISTICS DESIGN
--------------------------------------------------

IMPORTANT:

Do NOT recalculate all statistics from thousands of GPS points every time an old Trip Details screen opens.

At trip completion, the existing drive/tracking system should provide the finalized statistics.

Persist those finalized summary values with the Trip.

This means:

Trip completion
    ↓
Finalize statistics
    ↓
Persist Trip summary
    ↓
Trip Details can load summary immediately

Raw GPS points will later be used for:

- Route visualization
- Speed-over-time graph
- Altitude graph
- Detailed analysis
- Future analytics

Do NOT create a second independent distance/speed calculation system.

Reuse the existing tracking/statistics calculations where they already exist.

If some requested summary statistic is not currently available in the drive system, do not invent a new calculation algorithm in this phase. Identify it clearly in the final report.

--------------------------------------------------
TIME / DURATION
--------------------------------------------------

Persist:

- startTime
- endTime
- duration

Use UTC timestamps for persistence.

Duration should be stored in a numeric representation appropriate for SQLite, such as seconds.

The UI can later format the duration for display.

--------------------------------------------------
SPEED
--------------------------------------------------

Persist:

- averageSpeed
- minimumSpeed
- maximumSpeed

Use the same internal speed unit already used by TripRank.

Do not silently change units.

Do not calculate these from the database when opening Trip Details.

--------------------------------------------------
ALTITUDE
--------------------------------------------------

Persist:

- minimumAltitude
- maximumAltitude

Use the existing altitude unit used by TripRank.

Do not invent an altitude calculation algorithm.

--------------------------------------------------
STOPS
--------------------------------------------------

Persist the finalized stop count if the current drive system already calculates it.

If stop detection is not yet implemented, leave the field nullable or use the project's existing representation rather than inventing stop-detection logic.

Do not implement advanced stop detection in Phase 5.3.

--------------------------------------------------
TRIP MODE
--------------------------------------------------

There are exactly two drive modes:

- destination
- reckless

Persist the mode consistently.

Do not infer mode from other fields.

--------------------------------------------------
VEHICLE RELATIONSHIP
--------------------------------------------------

Trips reference the vehicle by:

vehicleId

Do NOT duplicate:

- brand
- model
- year
- type

inside the Trip record.

Relationship:

vehicles
    ↓
trips.vehicle_id

A vehicle can have many trips.

A trip belongs to the vehicle that was selected when the drive started.

--------------------------------------------------
VEHICLE DELETION
--------------------------------------------------

Historical trips must survive vehicle deletion.

Deleting a vehicle must NOT delete its historical trips.

Do NOT use CASCADE DELETE.

Use an appropriate nullable relationship strategy such as:

ON DELETE SET NULL

if compatible with the existing schema.

After the vehicle is deleted:

- Trip remains.
- vehicleId may become null.
- Future Trip Details can indicate that the original vehicle is no longer available.

Do not copy vehicle information into Trip merely to solve this.

--------------------------------------------------
DATABASE MIGRATION
--------------------------------------------------

Current database version:

2

Increase to:

3

Use the existing migration system from Phase 5.1.

Do NOT:

- Delete the database
- Recreate the database
- Delete existing vehicles

Fresh database creation at v3 must create:

- db_metadata
- vehicles
- trips

Migration v2 → v3 must preserve all existing vehicle data.

--------------------------------------------------
TRIPS TABLE
--------------------------------------------------

Create an appropriate trips table.

Suggested structure:

id TEXT PRIMARY KEY
vehicle_id TEXT NULL
mode TEXT NOT NULL
start_time TEXT NOT NULL
end_time TEXT NOT NULL
duration INTEGER NOT NULL
distance REAL NOT NULL

start_latitude REAL NOT NULL
start_longitude REAL NOT NULL
start_name TEXT NULL

destination_latitude REAL NULL
destination_longitude REAL NULL
destination_name TEXT NULL

average_speed REAL NULL
minimum_speed REAL NULL
maximum_speed REAL NULL

minimum_altitude REAL NULL
maximum_altitude REAL NULL

stops INTEGER NULL

created_at TEXT

Use appropriate SQLite types and constraints.

Do not blindly copy this schema if an existing domain model requires a better equivalent.

Use UTC timestamps.

Add sensible indexes, particularly:

- vehicle_id
- start_time

Do not over-index.

--------------------------------------------------
TRIP ID
--------------------------------------------------

Every Trip requires a stable unique ID.

Do NOT use:

- list indexes
- array positions
- timestamps alone

Reuse the project's existing ID strategy if available.

If no strategy exists, use a stable UUID/string approach with the minimum necessary dependency.

--------------------------------------------------
DESTINATION MODE
--------------------------------------------------

When a Destination Mode drive starts:

The active drive already knows the selected destination.

At trip completion, persist:

- destination latitude
- destination longitude
- destination name if available

Do not perform new routing or geocoding during trip persistence.

--------------------------------------------------
RECKLESS MODE
--------------------------------------------------

When a Reckless Mode drive completes:

Persist:

- start location
- no destination
- mode = reckless
- finalized statistics

Destination fields remain null.

--------------------------------------------------
START LOCATION
--------------------------------------------------

Persist the starting GPS position captured by the existing drive system.

Do NOT request a separate GPS fix solely for database persistence if the active drive already has the starting location.

Reuse the existing starting position.

--------------------------------------------------
TRIP REPOSITORY
--------------------------------------------------

Create a TripRepository if one does not already exist.

The repository owns all Trip SQL operations.

Provide operations equivalent to:

- createTrip
- getTripById
- getAllTrips
- getTripsForVehicle
- getRecentTrips
- deleteTrip

Newest trips should be returned first using start_time.

Do not implement pagination yet unless the existing architecture requires it.

Do not put SQL in widgets.

Do not put SQL directly inside UI Riverpod providers.

--------------------------------------------------
RIVERPOD
--------------------------------------------------

Keep Riverpod.

Create a TripRepository provider using the existing Riverpod/database architecture.

The Drive Controller remains responsible for active drive state.

The TripRepository is responsible for persistence.

Architecture:

Drive UI
    ↓
Drive Controller / Riverpod
    ↓
TripRepository
    ↓
SQLite

Do not move GPS tracking into the repository.

--------------------------------------------------
WHEN TO PERSIST
--------------------------------------------------

Persist the Trip when the drive successfully finishes.

Flow:

START
    ↓
Active Drive in Riverpod
    ↓
GPS tracking
    ↓
FINISH
    ↓
Finalize trip information/statistics
    ↓
TripRepository.createTrip()
    ↓
SQLite
    ↓
Clear active-drive state

Do not create a completed historical Trip merely because START was pressed.

If the user cancels/abandons a drive, do not create a completed trip unless the existing product specification explicitly requires it.

--------------------------------------------------
ERROR HANDLING
--------------------------------------------------

If Trip persistence fails:

- Do not crash the app.
- Do not falsely report that the trip was saved.
- Log the persistence error.
- Preserve the finalized trip data in memory as safely as the existing architecture permits.

Do not build a full recovery queue in this phase.

--------------------------------------------------
IMPORTANT: GPS DATA
--------------------------------------------------

Do NOT implement the GPS track-point table yet.

The final architecture will eventually be:

TRIP
  │
  └── GPS TRACK POINTS
          ├── point 1
          ├── point 2
          ├── point 3
          └── ...

Phase 5.4 will implement this.

The GPS points must eventually remain available for:

- Drawing the actual route
- Speed-over-time graphs
- Altitude graphs
- Detailed analytics

Do not attempt to store the entire GPS track as one large JSON field inside the Trip table.

Use a separate relational table in Phase 5.4.

--------------------------------------------------
OFFLINE TRACKING
--------------------------------------------------

Do not modify the existing GPS/background tracking architecture.

The existing implementation has already been physically tested offline:

- GPS continues working without internet.
- User location continues updating.
- Traversal/polyline coordinates continue being recorded.
- The recorded path aligns correctly when map tiles load after reconnecting.

Preserve this behavior.

The network/map layer must remain independent from GPS recording.

Do NOT add internet requirements to trip persistence.

--------------------------------------------------
DO NOT IMPLEMENT
--------------------------------------------------

Do NOT implement:

- GPS track-point persistence
- Trip Details UI
- Trip History UI redesign
- Speed graph UI
- Altitude graph UI
- Advanced analytics
- Turn statistics
- Crash detection
- Hard braking detection
- Offline map tiles
- Offline route calculation
- Offline geocoding
- Cloud synchronization
- Authentication

These belong to later phases.

--------------------------------------------------
TESTING
--------------------------------------------------

Add repository/database tests covering:

1. Create a trip.
2. Retrieve a trip by ID.
3. Retrieve all trips.
4. Retrieve trips for a vehicle.
5. Newest trips appear first.
6. Trip mode persists correctly.
7. Start/end timestamps persist correctly.
8. Duration persists correctly.
9. Distance persists correctly.
10. Start coordinates persist correctly.
11. Start name persists correctly.
12. Destination coordinates persist correctly.
13. Destination name persists correctly.
14. Reckless trips can have null destination fields.
15. Summary statistics persist correctly.
16. Multiple trips can reference the same vehicle.
17. Trips survive database close/reopen.
18. v2 → v3 migration preserves existing vehicles.
19. Deleting a vehicle does NOT delete its historical trips.
20. Historical trip remains accessible after vehicle deletion.
21. Deleting a trip removes only that trip.

Integration testing where practical:

Start drive
→ Finish drive
→ Trip is persisted

Also verify:

- Existing vehicle persistence still works.
- Existing GPS/background tracking still works.
- Existing Reckless Mode still works.
- Existing Destination Mode still works.

--------------------------------------------------
VALIDATION
--------------------------------------------------

After implementation:

1. Run flutter pub get if necessary.
2. Run flutter analyze.
3. Run all relevant tests.
4. Run the application.
5. Verify vehicle persistence still works.
6. Start a Reckless Mode drive.
7. Finish it.
8. Verify the Trip is persisted.
9. Restart the application.
10. Verify the Trip remains available in the database.
11. Start a Destination Mode drive if practical.
12. Finish it.
13. Verify destination coordinates/name are persisted.
14. Verify mode is destination.
15. Verify summary statistics are persisted.
16. Verify existing map/GPS functionality is unchanged.

Do NOT claim GPS track persistence is complete.

At the end report:

- Files created
- Files modified
- Database version change
- Final trips table schema
- Vehicle/trip relationship
- Destination storage approach
- Summary statistics stored
- TripRepository operations
- Drive completion integration
- Tests performed
- flutter analyze result
- Any statistics not currently available from the drive system
- Any limitations