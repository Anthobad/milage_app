Read AGENTS.md first.

Implement Phase 6.4 only.

Phases 6.1, 6.2, and 6.3 are complete.

Phase 6.1:
- Speed analysis
- Altitude analysis
- GPS-derived movement calculations

Phase 6.2:
- Left turns
- Right turns
- U-turns

Phase 6.3:
- Hard braking
- Sudden stops

Do NOT replace or rewrite those implementations.

==================================================
GOAL
==================================================

Create the final consolidated analytics result that the Trip Stats UI can consume in Phase 6.5.

This phase is about ORGANIZING AND EXPOSING the analytics already implemented.

Do not build new UI.

Do not create new detection algorithms unless required to complete a missing overall statistic explicitly listed below.

==================================================
FINAL ANALYTICS
==================================================

The consolidated analytics should expose, where available:

TRIP BASICS

- Distance
- Duration
- Start time
- End time
- Start location
- Destination
- Vehicle

SPEED

- Average speed
- Minimum speed
- Maximum speed
- Speed analysis data needed by the existing speed graph

ALTITUDE

- Minimum altitude
- Maximum altitude
- Altitude change
- Altitude analysis data needed by the existing altitude graph

DRIVING EVENTS

- Left turns
- Right turns
- U-turns
- Hard braking events
- Sudden stops
- Stops

Do not invent statistics that cannot be reliably derived from the available data.

==================================================
ARCHITECTURE
==================================================

Reuse the existing:

DrivingAnalytics
SpeedAnalysis
AltitudeAnalysis
TurnAnalysis
BrakingAnalysis
DrivingAnalyticsService
TripRepository
TrackPointRepository
TripAnalyticsProvider

The final result should have one clear authoritative analytics object.

Conceptually:

DrivingAnalytics
|
├── trip information
├── speedAnalysis
├── altitudeAnalysis
├── turnAnalysis
└── brakingAnalysis

Follow the existing project naming and architecture instead of blindly copying this structure.

Do not duplicate the same statistic in multiple places unless there is a clear reason.

==================================================
SINGLE SOURCE OF TRUTH
==================================================

Do not independently recalculate:

- average speed
- minimum speed
- maximum speed
- altitude values
- turn counts
- braking counts

inside the UI.

The UI must consume the analytics result.

For derived counts such as:

leftTurns
rightTurns
uTurns
hardBrakingCount
suddenStopCount

prefer deriving them from their event collections if the existing models already use that approach.

Do not create conflicting cached values.

==================================================
TRIP SUMMARY
==================================================

Make sure the analytics result can expose the summary values required by Trip Stats:

- Distance
- Duration
- Average speed
- Minimum speed
- Maximum speed
- Minimum altitude
- Maximum altitude
- Stops
- Left turns
- Right turns
- U-turns
- Hard braking count
- Sudden stop count

Use the existing Trip model as the authoritative source for persisted trip summary values where appropriate.

Do not unnecessarily recalculate values already persisted in the trips table.

==================================================
GRAPH DATA
==================================================

The existing Trip Stats page already has speed/altitude graph infrastructure.

Do NOT redesign the graphs.

Make sure the analytics layer exposes the chronological analyzed track data required for:

- Speed over time
- Altitude over time

The data must preserve chronological order.

Do not downsample or discard data unless the existing implementation already requires it.

If graph-specific transformations are needed, keep them in the analytics layer rather than the UI.

==================================================
TIME REPRESENTATION
==================================================

Use the existing project time conventions.

Do not introduce multiple competing representations.

Analytics should preserve the original timestamps so the UI can determine:

- elapsed time
- event time
- graph position

Do not convert timestamps into display strings inside the analytics service.

Formatting belongs to the presentation layer.

==================================================
STOP COUNT
==================================================

Review the existing stop calculation from Phase 6.1.

Make sure it is exposed consistently through the final analytics result.

A stop should not simply mean:

speed == 0 for one noisy GPS sample.

Reuse the existing Phase 6.1 stop logic.

Do not implement a second stop detector.

==================================================
DATA AVAILABILITY

The analytics layer must handle:

- Empty track
- One-point track
- Very short trip
- Missing speed
- Missing altitude
- Missing heading
- Duplicate coordinates
- Duplicate timestamps
- GPS noise
- Incomplete data

It must never crash.

It must not produce:

- NaN
- Infinity
- invalid statistics

Use nullable values where a statistic genuinely cannot be calculated.

Do not replace unavailable values with fake zeroes.

==================================================
OFFLINE

Analytics must remain completely offline.

Do not:

- make network requests
- reverse geocode
- request map data
- depend on Google Maps
- depend on internet connectivity

All analytics must operate from the persisted Trip and GPS track data.

==================================================
PERFORMANCE

Keep the analytics pipeline O(n).

Do not repeatedly query SQLite for every GPS point.

The existing analytics service should load the track once and process it.

Do not perform expensive recalculations every time a UI widget rebuilds.

Riverpod should be used to cache/combine the analytics result where appropriate.

==================================================
PROVIDER

Review the existing trip analytics provider.

Make sure it exposes the complete consolidated DrivingAnalytics result.

Do not create unnecessary providers.

Do not put business calculations inside widgets.

The provider should:

1. Load the trip.
2. Load its track points.
3. Run the analytics service.
4. Expose the resulting DrivingAnalytics.

Follow the existing Riverpod architecture.

==================================================
NO UI CHANGES

Do NOT implement Phase 6.5.

Do NOT modify the visual design of Trip Stats.

Do NOT add:

- new cards
- turn bars
- braking cards
- new graphs
- icons
- loading animations
- graph interaction
- UI placeholders

Phase 6.5 will connect the already-designed UI to this analytics result.

==================================================
NO DATABASE CHANGES

Do NOT modify the database schema.

Do not create analytics tables.

Do not persist calculated analytics yet.

The persisted GPS track remains the source data.

==================================================
TESTS

Add deterministic tests for the consolidated analytics result.

Test at minimum:

1. Complete normal trip
   - speed
   - altitude
   - turns
   - braking
   - stops
   - distance
   - duration

2. Trip with no turns

3. Trip with left and right turns

4. Trip with U-turn

5. Trip with hard braking

6. Trip with sudden stop

7. Trip with multiple event types

8. Empty track

9. One-point track

10. Missing speed

11. Missing altitude

12. Duplicate timestamps

13. Duplicate coordinates

14. Offline-compatible analysis

15. Existing analytics behavior remains unchanged

Do not rely on physical GPS for these tests.

==================================================
REGRESSION

All existing tests from:

- Phase 5
- Phase 6.1
- Phase 6.2
- Phase 6.3

must continue passing.

Do not break:

- Trip persistence
- Track-point persistence
- Trip Stats loading
- Vehicle filtering
- Background tracking
- Reckless Mode
- Destination Mode
- Google Maps integration
- Speed analytics
- Altitude analytics
- Turn analytics
- Braking analytics

==================================================
DEPENDENCIES

Do not add packages.

Use the existing project dependencies.

==================================================
DOCUMENTATION

Update:

docs/PROGRESS_TRACKER.md

Mark Phase 6.4 complete only when:

- implementation is complete
- tests pass
- flutter analyze passes

Document:

- Final analytics structure
- Which values come from Trip persistence
- Which values are calculated from GPS points
- How turn/braking/stop results are exposed
- Graph data availability
- Handling of missing data
- Performance characteristics
- Known limitations

Do NOT mark Phase 6.5 complete.

==================================================
VERIFICATION

Run:

flutter pub get

flutter analyze

flutter test

Confirm the full test suite passes.

==================================================
FINAL REPORT

When finished, report:

- Files created
- Files modified
- Final DrivingAnalytics structure
- Statistics exposed
- How existing 6.1–6.3 results are integrated
- Provider changes
- Graph data handling
- Missing-data handling
- Tests added
- Total tests passed
- flutter analyze result
- Dependencies added
- Known limitations

IMPORTANT:

STOP AFTER PHASE 6.4.

Do NOT implement Phase 6.5.