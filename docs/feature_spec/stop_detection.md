Read AGENTS.md first.

Implement Phase 6.4.1 — Stop Detection.

IMPORTANT:
Phase 6.1–6.4 are already complete and must NOT be rewritten.

During verification of Phase 6.4, we discovered that the Trip model contains a
"stops" field, but it is currently always null because an actual stop detector
was never implemented.

Fix this before Phase 6.5.

==================================================
GOAL
==================================================

Implement reliable GPS-based stop detection so TripRank can determine the number
of meaningful stops during a completed trip.

The result must become available through the existing analytics architecture and
Trip Stats provider.

Do NOT implement Phase 6.5 UI.

==================================================
WHAT COUNTS AS A STOP
==================================================

A stop should represent a meaningful period where the vehicle has stopped or
nearly stopped during a trip.

Do NOT count a stop simply because one GPS point has:

speed == 0

GPS data contains noise and occasional inaccurate speed readings.

Use multiple consecutive points and/or elapsed time to determine that the
vehicle actually stopped.

The detector must tolerate:

- GPS speed jitter
- Small position changes while stationary
- Occasional inaccurate GPS fixes
- Missing speed values
- Duplicate timestamps
- Duplicate coordinates
- Large timestamp gaps

==================================================
STOP DETECTOR
==================================================

Create a dedicated stop detector following the same architecture style as:

- TurnDetector
- BrakingDetector

Prefer a dedicated model + detector + analysis result.

For example, conceptually:

StopEvent
StopAnalysis
StopDetector
StopDetectorConfig

Use the project's existing naming conventions if they differ.

The detector should:

1. Detect when vehicle speed falls below a configurable near-zero threshold.
2. Require the condition to persist for a meaningful amount of time.
3. Avoid counting normal GPS jitter as a stop.
4. Detect when the vehicle begins moving again.
5. Emit ONE stop event per physical stop.
6. Avoid duplicate events for the same stop.
7. Handle a trip ending while the vehicle is still stopped correctly.
8. Ignore invalid/unusable GPS segments.

Do NOT use accelerometer data.

Do NOT require internet.

Do NOT use Google Maps.

Do NOT depend on UI state.

==================================================
CONFIGURATION
==================================================

Create a tunable configuration object.

Do not scatter magic numbers throughout the detector.

Use sensible GPS-oriented defaults for:

- nearZeroSpeedKmh
- minimumStopDurationSeconds
- minimumMovementDistanceMeters
- maximumTimeGapSeconds
- any debounce/recovery threshold required

Document why each threshold exists.

Keep all thresholds configurable so they can be adjusted after real phone testing.

Do not blindly use car/accelerometer thresholds from unrelated systems.

==================================================
STOP EVENT
==================================================

The stop event should contain enough information for future Trip Stats UI.

At minimum consider:

- timestamp
- latitude
- longitude
- duration
- index/start index/end index if useful

Use the existing project's model conventions.

Do not add unnecessary fields.

==================================================
STOP ANALYSIS
==================================================

Create an aggregated StopAnalysis result.

It should expose:

- events
- stopCount

Prefer deriving stopCount from events so there is one source of truth.

Handle empty results safely.

==================================================
INTEGRATION
==================================================

Integrate the detector into the existing:

DrivingAnalyticsService

Do NOT create a second analytics pipeline.

The pipeline should conceptually become:

Track points
    ↓
DrivingAnalyticsService
    ├── Speed analysis
    ├── Altitude analysis
    ├── Turn analysis
    ├── Braking analysis
    └── Stop analysis
             ↓
      DrivingAnalytics.stopAnalysis

Add the stop analysis field to DrivingAnalytics using the existing project
patterns.

Do not change existing Phase 6.1–6.3 behavior.

==================================================
TRIP PERSISTENCE
==================================================

This is important.

The existing Trip model/database already contains:

stops

Make the completed trip store the detected stop count.

When TripBuilder/builds the final Trip:

- use the calculated stop count
- store it in trips.stops

Do NOT create a new database column.

Do NOT change the database version.

Do NOT create a new table.

The existing "stops" column must become functional.

==================================================
PROVIDER
==================================================

Update the existing TripAnalyticsProvider/TripAnalyticsState so:

stopCount

returns the actual detected/persisted stop count when available.

Do not create a new unrelated provider.

The Trip Stats UI should eventually be able to consume:

analytics.stopAnalysis.stopCount

or the equivalent existing architecture.

Do not modify the Trip Stats UI yet.

==================================================
PERSISTENCE RULE
==================================================

The GPS track remains the source of truth.

Do not persist individual stop events in a new database table.

The stop count is persisted as part of the existing Trip summary.

The complete GPS track remains available for future analysis.

==================================================
EDGE CASES
==================================================

Handle all of these safely:

1. Empty track
2. One-point track
3. Entire trip stationary
4. Vehicle starts stationary then moves
5. Vehicle stops once
6. Vehicle stops multiple times
7. Vehicle stops for a very short period
8. Vehicle stops for a long period
9. Vehicle remains stopped when FINISH is pressed
10. Missing speed values
11. Duplicate timestamps
12. Duplicate coordinates
13. Large timestamp gaps
14. GPS jitter around zero speed
15. Normal slow driving that should NOT become a stop
16. Multiple consecutive GPS fixes during one stop must produce ONE event

No NaN.

No Infinity.

No crashes.

==================================================
TESTING
==================================================

Create deterministic unit tests.

At minimum test:

- no stops
- one stop
- multiple stops
- short stop rejected
- valid stop accepted
- long stop
- stop at beginning
- stop at end
- stationary entire trip
- slow driving is not classified as a stop
- GPS jitter
- missing speed
- duplicate timestamps
- duplicate coordinates
- large time gaps
- multiple GPS points during one stop produce one event
- stop count derived from event list
- TripBuilder stores stop count
- TripAnalyticsProvider exposes stop count
- existing analytics remain unchanged

Use synthetic GPS points.

Do NOT use physical-device GPS in unit tests.

==================================================
PERFORMANCE
==================================================

Keep the detector O(n).

It must work efficiently with large trips.

Do not repeatedly query SQLite for every GPS point.

The existing analytics pipeline should load the track once.

==================================================
OFFLINE
==================================================

The detector must work completely offline.

No:

- HTTP requests
- reverse geocoding
- Google Maps
- map tiles
- network dependencies

==================================================
NO UI

DO NOT modify:

- Trip Stats layout
- Trip list UI
- graphs
- turn visualization
- loading indicators
- icons
- analytics screen

Phase 6.5 will handle the UI.

==================================================
NO NEW PACKAGES

Do not add dependencies.

Use the existing project dependencies.

==================================================
REGRESSION

All existing tests must continue passing.

Pay particular attention to:

- Phase 5 trip persistence
- Phase 5.4 track-point persistence
- Phase 5.5 Trip Stats
- Phase 6.1 analytics
- Phase 6.2 turn detection
- Phase 6.3 braking detection
- Phase 6.4 consolidated analytics

==================================================
DOCUMENTATION

Update:

docs/PROGRESS_TRACKER.md

Document this as:

Phase 6.4.1 — Stop Detection

Include:

- detection approach
- thresholds
- noise handling
- event model
- persistence behavior
- provider integration
- known limitations

Do NOT mark Phase 6.5 complete.

==================================================
VERIFICATION

Run:

flutter pub get

flutter analyze

flutter test

Confirm the COMPLETE test suite passes.

==================================================
FINAL REPORT

When finished, report:

1. Files created
2. Files modified
3. Stop detection algorithm
4. Default thresholds and reasoning
5. StopEvent structure
6. StopAnalysis structure
7. DrivingAnalytics integration
8. Trip persistence integration
9. Provider changes
10. Tests added
11. Total tests passed
12. flutter analyze result
13. Dependencies added
14. Known limitations

IMPORTANT:

This is a corrective phase for the missing stop detection discovered during
Phase 6.4 verification.

Do NOT implement Phase 6.5.

STOP after Phase 6.4.1.