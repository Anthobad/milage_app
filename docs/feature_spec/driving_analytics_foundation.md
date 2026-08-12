# Phase 6.1 — Driving Analytics Foundation

Read `AGENTS.md` first.

Implement **Phase 6.1 only**.

Phases 5.1–5.5 are complete.

The existing Trip system already provides:

* SQLite persistence
* Vehicle persistence
* Trip persistence
* GPS track-point persistence
* Trip Stats UI
* Speed statistics
* Speed graph
* Altitude graph
* Interactive graph selection
* Route/polyline display

Do NOT redo or replace any of those features.

---

## GOAL

Create the reusable **Driving Analytics Foundation** that future Phase 6 subphases will use.

This phase is about establishing the analytics architecture and reusable data-processing layer.

Do NOT implement the actual advanced driving-event algorithms yet.

Future phases will implement:

* 6.2 — Turn analysis
* 6.3 — Hard braking and sudden-stop detection
* 6.4 — Overall driving statistics
* 6.5 — Analytics UI integration

---

# 1. IMPORTANT SCOPE BOUNDARY

For Phase 6.1, do NOT implement:

* Left/right turn detection
* Hard braking detection
* Sudden stop detection
* Crash detection
* New analytics UI
* New graphs
* New Trip Stats sections
* Online analytics
* Server-side processing
* Navigation
* Routing

Do not create fake values for future analytics.

If the existing Trip Stats UI contains placeholders for future analytics, leave them as placeholders.

---

# 2. ARCHITECTURE

Create a dedicated analytics layer separate from:

* UI widgets
* Map widgets
* Drive state
* GPS foreground service
* Trip repository
* Database implementation

Use an architecture similar to:

```text
Trip Stats / Future UI
        ↓
Analytics Provider
        ↓
Analytics Service / Engine
        ↓
Persisted Track Points
        ↓
TrackPointRepository
        ↓
SQLite
```

The analytics engine must be usable independently of Flutter widgets.

Do not put analytics calculations inside widget `build()` methods.

Do not put analytics calculations directly inside the foreground location service.

Do not make Riverpod state itself responsible for the mathematical calculations.

---

# 3. INPUT

The analytics foundation must operate on persisted GPS track points.

The primary input should be the existing track-point model/data.

Each point may contain:

* id
* tripId
* timestamp
* latitude
* longitude
* altitude
* speedKmh
* accuracyM
* headingDegrees

Do not require every field to be populated.

The analytics engine must gracefully handle nullable:

* altitude
* speed
* accuracy
* heading

---

# 4. TRACK ORDER

Analytics must process track points chronologically.

Do not assume that the caller always provides points in the correct order.

If the repository already guarantees chronological ordering, preserve that behavior, but the analytics layer should still avoid producing incorrect results if input order is unexpected.

Timestamp must be treated as the authoritative ordering field.

---

# 5. DATA QUALITY

GPS data can contain:

* Duplicate timestamps
* Very small time intervals
* Missing speed
* Missing altitude
* Poor accuracy
* GPS jumps
* Stationary points
* Small GPS noise

The analytics foundation must not crash because of malformed or incomplete data.

Use defensive validation.

Avoid division by zero.

Avoid invalid numeric results such as:

* NaN
* Infinity

Do not silently invent missing GPS values.

---

# 6. ANALYTICS DOMAIN MODEL

Create a clean analytics result model that can eventually contain the results of all Phase 6 analytics.

It should be extensible.

The model should be capable of representing future categories such as:

```text
DrivingAnalytics
 ├── speed analysis
 ├── altitude analysis
 ├── turn analysis
 ├── braking analysis
 ├── stop analysis
 └── overall statistics
```

Do not implement all of these calculations yet.

For this phase, establish the structure necessary for future phases.

Prefer immutable models where consistent with the existing project architecture.

---

# 7. ANALYTICS SERVICE

Create a dedicated service/class responsible for processing a list of GPS track points.

Use a clear API similar to:

```dart
DrivingAnalytics analyze(List<TrackPoint> points)
```

The exact naming should follow the project's existing conventions.

The service should:

1. Accept track points.
2. Validate/sort the data.
3. Process the available information.
4. Return a structured analytics result.
5. Never depend on a UI widget.
6. Never depend on internet access.

---

# 8. EXISTING SPEED DATA

The project already calculates and persists:

* Average speed
* Minimum speed
* Maximum speed

Do NOT create a second conflicting implementation of those persisted Trip summary statistics.

The analytics layer may expose speed-related information for future analysis, but the existing Trip summary remains authoritative for the already-persisted:

* averageSpeedKmh
* minimumSpeedKmh
* maximumSpeedKmh

Do not modify the existing TripBuilder calculation unless there is a demonstrated bug.

Do not change the meaning of the existing values.

---

# 9. TRACK-BASED DERIVED DATA

Prepare the analytics layer to work with sequential GPS points.

Future algorithms will need information such as:

* Time delta between points
* Distance between points
* Speed
* Speed change
* Acceleration/deceleration
* Direction/heading change
* Altitude change

Create reusable internal calculations/utilities where appropriate.

However:

**Do not implement turn detection or braking classification yet.**

The purpose here is to avoid every future analytics feature implementing its own slightly different GPS math.

---

# 10. DISTANCE CALCULATION

Create a reusable geographic distance calculation for two GPS coordinates.

Use the project's existing geographic dependencies/utilities where possible.

Do not add a new package if the existing project already provides what is needed.

The calculation must work offline.

Do not call a routing API.

Do not calculate road distance.

This is geographic GPS-point-to-GPS-point distance.

---

# 11. TIME DELTA

Create a reusable calculation for the elapsed time between consecutive track points.

Handle:

* Normal intervals
* Zero-duration intervals
* Negative/out-of-order timestamps

Do not divide by zero.

Invalid intervals should be handled safely rather than crashing.

---

# 12. SPEED / MOTION DATA

Prepare reusable calculations based on consecutive points.

The analytics foundation should be able to derive:

* Distance between points
* Time between points
* Speed between points when possible
* Speed change
* Approximate acceleration/deceleration when valid

Do not overwrite the original GPS `speedKmh`.

Keep raw GPS data separate from derived values.

Future phases may use both.

---

# 13. ACCELERATION

Prepare a reusable acceleration/deceleration calculation.

Conceptually:

```text
acceleration = change in speed / change in time
```

Use consistent units internally.

Prefer SI units internally where appropriate:

* distance → meters
* time → seconds
* speed → meters/second
* acceleration → meters/second²

Convert to display units only at the UI layer.

Do not expose a misleading acceleration value when the time delta is zero or invalid.

---

# 14. HEADING / DIRECTION

Prepare the foundation for directional analysis.

Track points may have `headingDegrees`, but it can currently be null.

Do not require heading to be present.

If heading is available, preserve it.

If heading is unavailable, future analytics should be able to derive directional change from coordinates where appropriate.

Do not implement turn classification in this phase.

---

# 15. ALTITUDE

Prepare the analytics model to handle altitude data.

Altitude can be null.

Do not treat a missing altitude as zero.

Do not fabricate altitude values.

Future analytics may use:

* altitude change
* elevation gain
* elevation loss
* altitude graph data

Do not implement additional elevation analytics unless already present in the existing system.

---

# 16. FILTERING GPS NOISE

Do not create an aggressive filtering algorithm in Phase 6.1.

The purpose of this phase is to provide a safe foundation.

Do, however:

* Ignore obviously invalid numerical values.
* Avoid calculations with invalid time intervals.
* Avoid division by zero.
* Avoid producing NaN/Infinity.
* Respect the existing accuracy field where appropriate.

Do not delete raw track points.

Do not modify the stored GPS data.

Analytics should operate on the raw persisted track.

---

# 17. PERFORMANCE

Trips may contain thousands or tens of thousands of track points.

The analytics engine must be efficient.

Prefer:

* One-pass processing where possible
* O(n) algorithms
* No unnecessary nested loops
* No repeated database queries for every point

Do not load the database separately for each GPS point.

The service should operate on a provided collection/list of track points.

---

# 18. RIVERPOD INTEGRATION

Create an analytics provider only if it fits the existing Riverpod architecture.

The provider should depend on:

* Trip ID
* TrackPointRepository
* DrivingAnalyticsService

Conceptually:

```text
tripId
 ↓
Analytics Provider
 ↓
TrackPointRepository
 ↓
DrivingAnalyticsService
 ↓
DrivingAnalytics
```

Do not make the analytics service itself dependent on Riverpod.

Keep the service a plain Dart class where possible.

---

# 19. CACHING

Do not implement a complex analytics cache in Phase 6.1.

If the existing architecture already has appropriate provider caching, reuse it.

Do not introduce a second persistence layer for analytics results yet.

Future phases can determine which analytics should be persisted.

---

# 20. DATABASE

Do NOT modify the database schema in Phase 6.1.

Do not add:

* analytics tables
* turn tables
* braking tables
* event tables
* cached analytics columns

unless a pre-existing architectural requirement absolutely requires it.

For now:

```text
SQLite
 ↓
TrackPointRepository
 ↓
Analytics Engine
 ↓
Analytics Result
```

Future phases will decide what, if anything, should be persisted.

---

# 21. TESTING

Create comprehensive unit tests for the analytics foundation.

Tests must not require:

* Physical device
* GPS
* Internet
* Map tiles

Test cases should include:

### Basic input

1. Empty track returns a valid empty analytics result.
2. One track point does not crash.
3. Two valid points process successfully.
4. Multiple chronological points process successfully.

### Ordering

5. Out-of-order timestamps are handled safely.
6. Duplicate timestamps do not cause division-by-zero.
7. Invalid intervals do not crash.

### Distance

8. Known coordinate pairs produce reasonable distances.
9. Identical coordinates produce zero distance.
10. Very small movements are handled safely.

### Time

11. Normal timestamp difference works.
12. Zero time difference is handled.
13. Negative time difference is handled.

### Speed

14. Valid speed data is processed.
15. Missing speed does not crash.
16. Zero speed is handled correctly.
17. Speed changes can be derived when valid.

### Acceleration

18. Positive acceleration is calculated correctly.
19. Negative acceleration is calculated correctly.
20. Zero time delta does not produce Infinity/NaN.

### Altitude

21. Valid altitude data is handled.
22. Missing altitude is handled.
23. Altitude is never silently converted from null to zero.

### Heading

24. Valid heading is preserved.
25. Null heading is handled.

### Data quality

26. Invalid numerical input does not crash the analyzer.
27. NaN/Infinity are not produced by the analytics result.

### Performance

28. A large synthetic track can be analyzed efficiently.

Add additional tests where appropriate.

---

# 22. DO NOT BREAK EXISTING FUNCTIONALITY

All existing tests must continue to pass.

Do not break:

* Map
* Reckless Mode
* Destination Mode
* Google Maps launch
* Background tracking
* FINISH
* Trip persistence
* Track-point persistence
* Trips page
* Trip Stats page
* Speed graph
* Altitude graph
* Vehicle filtering

The current physical-device behavior must remain unchanged.

---

# 23. FILE ORGANIZATION

Follow the existing project structure.

Prefer a structure similar to:

```text
lib/
└── features/
    └── analytics/
        ├── models/
        ├── services/
        ├── providers/
        └── ...
```

However, inspect the existing project first.

If an analytics-related structure already exists, reuse it rather than creating duplicates.

Do not reorganize unrelated features.

---

# 24. DEPENDENCIES

Do not add packages unless genuinely required.

The project already has the dependencies necessary for:

* GPS
* geographic coordinates
* Riverpod
* SQLite

Prefer the existing dependencies.

If a new dependency appears necessary, explain why before adding it.

---

# 25. UI

Do NOT modify the Trip Stats UI in this phase.

Do not add new visible statistics.

Do not add new graphs.

Do not add turn bars.

Do not add braking cards.

Do not add event lists.

The UI integration happens later.

---

# 26. DOCUMENTATION

Update:

`docs/PROGRESS_TRACKER.md`

Mark Phase 6.1 as complete only if:

* implementation is complete
* tests pass
* `flutter analyze` passes

Document any limitations or decisions made during implementation.

Do not mark future Phase 6 tasks complete.

---

# 27. VALIDATION

After implementation:

1. Run `flutter pub get`.
2. Run all relevant tests.
3. Run the full test suite.
4. Run `flutter analyze`.
5. Verify no existing functionality is broken.

Report:

* Files created
* Files modified
* Analytics architecture
* Analytics models
* Analytics service
* Riverpod integration
* Reusable GPS calculations
* Tests added
* Total tests passed
* `flutter analyze` result
* Dependencies added, if any
* Any limitations
* Confirmation that turn/braking/sudden-stop algorithms were NOT implemented yet

IMPORTANT:

Do not implement Phase 6.2, 6.3, 6.4, or 6.5 during this task.

Stop after Phase 6.1.
