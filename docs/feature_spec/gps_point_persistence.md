Read AGENTS.md.

Implement Phase 5.4 only.

IMPORTANT:
Phase 5.1 — Local Database Foundation — is complete.
Phase 5.2 — Vehicle Persistence — is complete.
Phase 5.3 — Trip Persistence — is complete.

Do not redo or replace the existing database, vehicle persistence, or Trip persistence architecture.

Phase 5.4 has TWO responsibilities:

1. Persist the raw GPS track points incrementally during an active drive.
2. Complete the post-drive flow so the newly completed Trip is immediately available and the user is automatically taken to its Trip Stats screen.

--------------------------------------------------
PRODUCT GOAL
--------------------------------------------------

TripRank records the ACTUAL route the user drove.

The actual route is the sequence of GPS coordinates recorded during the drive.

When displayed later on a map, these GPS points are connected into a polyline.

Do NOT confuse this with the planned destination route.

PLANNED ROUTE:
Destination → routing service → preview route

ACTUAL ROUTE:
GPS point 1 → GPS point 2 → GPS point 3 → ... → GPS point N
                         ↓
                     polyline
                         ↓
                  road actually taken

The raw GPS track must survive:

- App restarts
- Leaving TripRank
- Returning from Google Maps
- Completed drive
- Later opening the Trip

--------------------------------------------------
CRITICAL PERSISTENCE REQUIREMENT
--------------------------------------------------

GPS points MUST be persisted incrementally while an active drive is running.

Do NOT wait until FINISH to save the entire track.

Current architecture:

GPS
 ↓
Location Service
 ↓
Drive Controller
 ↓
DriveState.trackPoints
 ↓
TripBuilder
 ↓
Trip summary

Phase 5.4 must add persistent GPS storage:

GPS
 ↓
Location Service
 ↓
Drive Controller
 ├── DriveState.trackPoints
 │
 └── TrackPointRepository
        ↓
      SQLite

The UI must NOT be responsible for GPS persistence.

Riverpod state alone must NOT be the only copy of active-drive GPS data.

--------------------------------------------------
DATABASE VERSION
--------------------------------------------------

Current database version:

3

Increase to:

4

Implement a v3 → v4 migration.

Do NOT delete or recreate the database.

Existing data must survive migration:

- vehicles
- trips

Fresh v4 installs must create:

- db_metadata
- vehicles
- trips
- trip_track_points

Use the existing database migration architecture.

--------------------------------------------------
TRACK POINT DATA
--------------------------------------------------

Inspect the existing GPS/TrackPoint model before creating a new model.

Reuse existing abstractions and field names where appropriate.

Persist all GPS information that the current location system already provides and that can be useful for reconstructing the trip.

At minimum persist:

- id
- tripId
- timestamp
- latitude
- longitude
- altitude
- speed
- accuracy
- heading

If the existing TrackPoint model contains additional meaningful GPS fields that are already available and useful for future analysis, evaluate whether they should also be persisted.

Do NOT invent fake values for fields that the location provider does not provide.

Nullable fields should remain nullable where appropriate.

Use sufficient numeric precision for latitude/longitude.

Do not round GPS coordinates before persistence.

--------------------------------------------------
TRACK POINT TABLE
--------------------------------------------------

Create a dedicated relational table.

Do NOT store all GPS points as:

- JSON inside the Trip
- one giant text field
- one blob
- an in-memory-only list

Use one database row per GPS point.

Suggested structure:

trip_track_points

id TEXT PRIMARY KEY
trip_id TEXT NOT NULL
timestamp TEXT NOT NULL
latitude REAL NOT NULL
longitude REAL NOT NULL
altitude REAL
speed_kmh REAL
accuracy_m REAL
heading_degrees REAL

Foreign key:

trip_id → trips(id)

ON DELETE CASCADE

Reason:

If a user explicitly deletes a completed Trip, its GPS track should also be deleted.

This is different from vehicle deletion.

Vehicle deletion:
Trip survives.

Trip deletion:
Its GPS points should be removed.

Add an index on:

trip_id

Also add an index that supports ordered retrieval by trip/time, for example:

(trip_id, timestamp)

Do not over-index.

--------------------------------------------------
ACTIVE DRIVE TRACK PERSISTENCE
--------------------------------------------------

IMPORTANT:

The Trip ID must exist before track points can be persisted.

Because the completed Trip is currently created on FINISH, Phase 5.4 must adapt the lifecycle carefully.

Do NOT create an invalid completed Trip merely because a drive started.

Use an active-drive identifier / pending-trip identity as appropriate.

The architecture must allow:

START
 ↓
Active drive receives stable trip ID
 ↓
GPS points persist incrementally
 ↓
FINISH
 ↓
Finalize Trip summary
 ↓
Mark/create completed Trip
 ↓
Track points belong to completed Trip

Inspect the existing Phase 5.3 architecture and choose the cleanest implementation.

Do not create duplicate trip records.

Do not leave orphan GPS points.

If the existing architecture requires creating a pending trip record at START, clearly distinguish its state from a completed Trip.

Do not expose incomplete trips in the normal Trips history unless explicitly intended.

--------------------------------------------------
ATOMICITY / DATA SAFETY
--------------------------------------------------

When a GPS point is received:

1. Add/update the active in-memory tracking state as currently implemented.
2. Persist the point through the repository/data layer.
3. Continue tracking even if an individual persistence operation fails.

A temporary database write failure must NOT crash the drive.

Log persistence errors appropriately.

Do not silently discard the entire drive because one point failed.

If a robust retry mechanism is already supported by the architecture, reuse it.

Do not build a complicated synchronization queue unless necessary for correctness.

--------------------------------------------------
GPS TRACKING MUST REMAIN INDEPENDENT
--------------------------------------------------

Do NOT connect GPS persistence to the Map widget.

The existing architecture must remain:

Drive UI
 ↓
Drive Provider / Controller
 ↓
Location Service
 ↓
Android Foreground Location Service
 ↓
GPS

Persistence is another consumer of the recorded location data.

The map is only a visualization.

GPS tracking must continue when:

- TripRank is backgrounded
- Google Maps is foregrounded
- screen is locked
- screen is off
- internet is unavailable

Do not introduce any network requirement.

--------------------------------------------------
OFFLINE REQUIREMENT
--------------------------------------------------

GPS track persistence must work completely offline.

An active drive must be able to record GPS points when:

- Wi-Fi is unavailable
- Mobile data is unavailable
- Map tiles cannot load

The GPS coordinates are authoritative.

The map is only the visual layer.

Do NOT implement:

- offline map tiles
- offline routing
- offline geocoding

These are separate concerns.

--------------------------------------------------
TRIP REPOSITORY
--------------------------------------------------

Extend the existing TripRepository or create a separate TrackPointRepository where appropriate.

Prefer separation of responsibilities:

TripRepository
    ↓
Trip metadata and summary

TrackPointRepository
    ↓
Raw GPS track points

Do not put large track-point operations directly inside UI providers.

Provide operations equivalent to:

- addTrackPoint
- addTrackPoints if batching is useful
- getTrackPointsForTrip
- deleteTrackPointsForTrip
- deleteTrackPoint if actually needed

Track points must be returned in chronological order.

Do not load the entire GPS track into memory unnecessarily when only a small portion is needed.

--------------------------------------------------
BATCHING / PERFORMANCE
--------------------------------------------------

GPS points may become numerous on long drives.

Do not perform expensive full-database operations for every point.

Inspect the current location update frequency.

Use a reasonable persistence strategy that does not cause unnecessary database overhead.

If batching is appropriate:

- points may be accumulated briefly
- then inserted in a transaction

BUT:

Do not introduce a large delay that risks losing many points if the process is killed.

The priority is:

1. Data safety
2. Reasonable database performance
3. Battery efficiency

Do not arbitrarily increase GPS frequency just to create more points.

Do not change the existing GPS sampling configuration unless required.

--------------------------------------------------
TRIP FINALIZATION
--------------------------------------------------

When FINISH is pressed:

1. Stop location recording.
2. Stop the foreground location service.
3. Ensure pending GPS points are flushed to SQLite.
4. Finalize the Trip summary using the existing Phase 5.3 TripBuilder/statistics architecture.
5. Persist/finalize the completed Trip.
6. Ensure all track points are associated with the final Trip ID.
7. Clear active-drive state.
8. Obtain the completed Trip ID.
9. Navigate to Trip Stats for that Trip.

Do not lose the final GPS point.

Do not navigate before persistence is successfully completed.

--------------------------------------------------
POST-FINISH NAVIGATION
--------------------------------------------------

THIS IS A HARD PRODUCT REQUIREMENT.

After a successful FINISH:

FINISH
 ↓
Persist/finalize Trip
 ↓
Get completed Trip ID
 ↓
Open Trip Stats screen for that Trip

The user should NOT have to manually open the Trips page first.

The Trip Stats screen must receive/load the newly created Trip by ID.

Do not navigate to a generic Trips screen.

Do not navigate before Trip persistence succeeds.

If persistence fails:

- do not pretend the Trip was saved
- do not navigate to a nonexistent Trip
- show an appropriate error
- preserve the safest available state

--------------------------------------------------
TRIP STATS SCREEN
--------------------------------------------------

Inspect the existing project to determine whether a Trip Stats/Trip Details screen already exists.

If it exists:

- reuse it
- connect it to the persisted Trip
- do not redesign it unnecessarily

If it does not exist:

Create the minimum screen/navigation foundation necessary for the post-finish flow.

IMPORTANT:

Do NOT spend this phase building the final polished Trip Stats UI.

The final Trip Stats design belongs to a later UI phase if it is not already implemented.

The screen must, however, be capable of displaying the immediately available Trip summary.

--------------------------------------------------
IMMEDIATE STATISTICS
--------------------------------------------------

When Trip Stats opens, the following persisted summary data should be immediately available from the Trip record:

- Distance
- Duration
- Average speed
- Minimum speed
- Maximum speed
- Minimum altitude
- Maximum altitude
- Stops where available
- Start location
- Destination when applicable
- Date/time
- Vehicle when available

These should NOT require recalculating the entire GPS track.

The Phase 5.3 summary values are the fast/ready statistics.

--------------------------------------------------
DETAILED GPS-DERIVED STATISTICS
--------------------------------------------------

The raw GPS points are the source for future detailed calculations.

Examples:

- Speed-over-time graph
- Altitude graph
- Detailed route visualization
- Route analysis
- Future driving analytics

When the Trip Stats screen needs these:

Trip Stats
 ↓
TrackPointRepository
 ↓
GPS points
 ↓
Calculate/render detailed information

If these calculations are not yet implemented, the screen should have a clean loading state rather than blocking the initial summary.

Example:

Immediately:

Distance: 14.2 km
Duration: 24:31
Average speed: 34 km/h
Maximum speed: 71 km/h

Then:

Speed graph → calculating/loading
Altitude graph → calculating/loading
Route → loading track

As soon as data is ready, update the UI.

If calculation is effectively instant, simply display the result immediately.

Do NOT show unnecessary loading indicators for already-persisted summary data.

--------------------------------------------------
TRIPS PAGE
--------------------------------------------------

The newly completed Trip must immediately be available through TripRepository.

The Trips page must be able to show it after completion.

Do NOT create a separate temporary "recent trip" list just for the UI.

The repository remains the source of truth.

Expected flow:

FINISH
 ↓
SQLite Trip created/finalized
 ↓
TripRepository contains Trip
 ↓
Navigate to Trip Stats
 ↓
User later opens Trips
 ↓
Same Trip appears in Trips list

The Trips page should show the existing summary information appropriate to the current UI design.

Do not redesign the Trips page unless necessary for integration.

--------------------------------------------------
TRIP HISTORY
--------------------------------------------------

A completed Trip must survive:

- App restart
- Device restart
- Being offline
- Leaving TripRank
- Returning from Google Maps

The track must remain available through:

getTrackPointsForTrip(tripId)

--------------------------------------------------
TRIP DELETION
--------------------------------------------------

When a Trip is deleted:

- Delete the Trip
- Delete all associated GPS track points

Use database-level ON DELETE CASCADE where appropriate.

Test that no orphan GPS points remain.

--------------------------------------------------
VEHICLE DELETION
--------------------------------------------------

Do NOT change Phase 5.3 behavior.

If a vehicle is deleted:

- Historical Trip survives.
- Trip.vehicle_id becomes NULL.
- GPS track remains.
- GPS points are NOT deleted.

--------------------------------------------------
DO NOT IMPLEMENT
--------------------------------------------------

Do NOT implement:

- Turn-by-turn navigation
- Voice navigation
- Traffic
- Rerouting
- Google Maps SDK
- Offline map tiles
- Offline routing
- Offline geocoding
- Cloud synchronization
- Authentication
- Crash detection
- Hard braking detection
- Advanced driving analytics
- Final polished Trip Stats UI
- Full Trip History redesign

Do NOT change the existing Google Maps integration.

Do NOT change the existing background location architecture unless required for persistence integration.

--------------------------------------------------
DEPENDENCIES
--------------------------------------------------

Use existing dependencies.

Current relevant dependencies include:

- flutter_map
- geolocator
- latlong2
- flutter_riverpod
- http
- sqflite
- path
- flutter_foreground_task

Do NOT add a package unless genuinely required.

If a new package is required:

1. Explain why it is required.
2. Prefer an existing dependency if it can solve the problem.
3. Do not replace the current database architecture.

--------------------------------------------------
ARCHITECTURE
--------------------------------------------------

Follow the existing project architecture and:

docs/ARCHITECTURE.md
docs/UI_GUIDELINES.md
docs/AI_RULES.md

Keep responsibilities separated.

Preferred structure:

Map / Drive UI
       ↓
Drive Provider / Controller
       ↓
Location Service
       ↓
TrackPointRepository
       ↓
SQLite

Trip completion:

Drive Controller
       ↓
TripBuilder
       ↓
TripRepository
       ↓
SQLite

Trip Stats:

Trip Stats View
       ↓
Trip Stats Provider / ViewModel
       ↓
TripRepository
       +
TrackPointRepository

Repositories remain the source of truth for persisted data.

Do not put SQL inside widgets.

Do not put GPS persistence directly inside widgets.

Do not make the Map widget responsible for persistence.

This separation is consistent with Flutter's recommended architecture, where repositories are the source of truth for application data and database access is kept in the data layer. :contentReference[oaicite:1]{index=1}

--------------------------------------------------
TESTING
--------------------------------------------------

Add comprehensive tests.

DATABASE TESTS:

1. v3 → v4 migration succeeds.
2. Existing vehicles survive migration.
3. Existing Trips survive migration.
4. Track-point table exists.
5. Track points can be inserted.
6. Track points can be retrieved.
7. Track points are returned chronologically.
8. Track points persist after database close/reopen.
9. Multiple trips can have separate track points.
10. Deleting a Trip deletes its track points.
11. Deleting a Vehicle does not delete Trip track points.
12. No orphan track points remain.

REPOSITORY TESTS:

13. addTrackPoint works.
14. getTrackPointsForTrip works.
15. Empty track returns correctly.
16. Large track can be retrieved.
17. Multiple trips remain isolated.

DRIVE INTEGRATION TESTS:

18. Starting a drive creates/assigns a stable active trip identity.
19. GPS points are persisted during an active drive.
20. FINISH flushes pending track points.
21. FINISH persists the final Trip summary.
22. Final Trip contains the correct track points.
23. Final GPS point is not lost.
24. Failed individual point persistence does not crash the drive.
25. Successful FINISH returns/produces the completed Trip ID.
26. Completed Trip is retrievable by ID.

POST-FINISH FLOW TESTS:

27. FINISH navigates to Trip Stats after successful persistence.
28. Trip Stats receives the correct Trip ID.
29. Trip Stats immediately displays persisted summary data.
30. Newly completed Trip appears through TripRepository.
31. Trip Stats can load the GPS track independently.
32. Persistence failure does not navigate to a nonexistent Trip.

MIGRATION / REGRESSION:

33. All existing Phase 5.1 tests pass.
34. All existing Phase 5.2 tests pass.
35. All existing Phase 5.3 tests pass.
36. Existing Reckless Mode behavior remains functional.
37. Existing Destination Mode behavior remains functional.
38. Existing background tracking behavior remains functional.

Add additional tests where necessary.

--------------------------------------------------
VALIDATION
--------------------------------------------------

After implementation:

1. Run flutter pub get if necessary.
2. Run flutter analyze.
3. Run all relevant tests.
4. Run the application.
5. Verify existing vehicle persistence.
6. Verify existing Trip persistence.
7. Start a Reckless Mode drive.
8. Confirm GPS points are persisted during the drive.
9. Finish the drive.
10. Confirm the Trip is finalized.
11. Confirm the app automatically opens Trip Stats for that Trip.
12. Confirm summary statistics are immediately available.
13. Confirm the Trip is visible through the Trips repository/page.
14. Restart the application.
15. Confirm the Trip remains available.
16. Confirm its GPS track remains available.
17. Verify Destination Mode still works.
18. Verify returning from Google Maps does not interrupt tracking.
19. Verify offline tracking/persistence does not require network access.

Do NOT claim that the final polished Trip Stats UI is complete if it is not.

Do NOT claim advanced analytics are complete.

At the end provide a concise implementation report containing:

- Files created
- Files modified
- Database version change
- Final track-point schema
- Repository methods
- Active-drive persistence approach
- Trip finalization flow
- Post-finish navigation flow
- Trip Stats integration
- Trips page integration
- Tests passed
- flutter analyze result
- Any limitations
- Any physical-device testing still required