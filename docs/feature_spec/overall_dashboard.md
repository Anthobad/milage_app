Read AGENTS.md first.

Implement Phase 6.6 — Overall Driving Analytics Dashboard.

IMPORTANT:
Phases 5.1–5.5, 6.1–6.5, and 6.4.1 are COMPLETE.

Do NOT rewrite or replace completed analytics, persistence, or Trip Stats
functionality.

This is the FINAL phase of Phase 6.

When this phase is complete and verified, Phase 6 should be considered
fully complete and the project should be ready to begin Phase 7.

==================================================
CORE PRODUCT DECISION
==================================================

TripRank has two different statistics concepts:

1. TRIP STATS
   - Statistics for ONE specific trip.
   - Implemented in Phase 5.5 / 6.5.

2. ANALYTICS PAGE
   - Overall statistics across ALL trips belonging to the CURRENTLY SELECTED
     VEHICLE.
   - This is the page being implemented in Phase 6.6.

The Analytics page MUST NOT aggregate trips from other vehicles.

Example:

Selected vehicle = Car A

Analytics page:
→ only trips where vehicle_id = Car A

If the user switches to Car B:

Analytics page:
→ only trips where vehicle_id = Car B

The selected vehicle is the single scope/filter for the entire Analytics page.

==================================================
EXISTING ANALYTICS PAGE
==================================================

There is already an Analytics page/screen placeholder in the application.

Use the existing Analytics route/navigation entry.

Do NOT create a second analytics page.

Do NOT remove the existing bottom navigation Analytics entry.

Replace the placeholder with the real Analytics dashboard.

Read:

docs/ARCHITECTURE.md
docs/UI_GUIDELINES.md
docs/AI_RULES.md

before modifying the UI.

Follow the existing TripRank visual language:

- dark-first design
- Inter font
- blue accent
- rounded cards
- clean spacing
- phone-first layout
- vertical scrolling
- no horizontal overflow

==================================================
DATA SCOPE
==================================================

The Analytics page must use the currently selected vehicle from the existing
vehicle persistence/provider system.

Use the existing authoritative selected-vehicle state.

Do NOT create another selected-vehicle state.

If no vehicle is selected:

show an appropriate empty state such as:

"No vehicle selected"

Do not show statistics belonging to another vehicle.

If the selected vehicle has no completed trips:

show:

"No trips yet"

Do not display fake zero statistics unless zero is actually meaningful.

==================================================
DATA SOURCES
==================================================

Prefer the persisted Trip summary table for aggregate statistics.

Do NOT load every GPS track point for every trip just to calculate statistics
that are already persisted in the trips table.

The trips table already contains:

- distance_km
- duration_seconds
- average_speed_kmh
- minimum_speed_kmh
- maximum_speed_kmh
- minimum_altitude_m
- maximum_altitude_m
- stops
- start_time
- end_time
- vehicle_id
- mode

Use TripRepository.getTripsForVehicle(vehicleId) where appropriate.

For statistics that require detailed GPS-derived analytics, use the existing
analytics architecture and persisted track points.

Do NOT create a new GPS tracking system.

Do NOT calculate analytics during widget build().

==================================================
OVERALL ANALYTICS MODEL
==================================================

Create a dedicated overall analytics model.

Use naming consistent with the project, for example:

OverallDrivingAnalytics

It should contain the aggregate statistics needed by the Analytics page.

At minimum include:

TRIP / USAGE:

- tripCount
- totalDistanceKm
- totalDurationSeconds

SPEED:

- averageSpeedKmh
- minimumSpeedKmh
- maximumSpeedKmh

STOPS:

- totalStops

TURNS:

- totalLeftTurns
- totalRightTurns
- totalUTurns

SAFETY:

- totalHardBraking
- totalSuddenStops

ALTITUDE:

- minimumAltitudeM
- maximumAltitudeM
- totalElevationGainM
- totalElevationLossM

MOVEMENT:

- movingDurationSeconds
- stoppedDurationSeconds

Only include statistics that can be calculated reliably from the existing data.

Do NOT invent metrics.

==================================================
AGGREGATION RULES
==================================================

Be mathematically correct.

DO NOT calculate an overall average speed by simply averaging the average
speed of each trip.

For example:

Trip A:
10 km at 100 km/h

Trip B:
1 km at 20 km/h

The overall average must be based on the combined distance/time rather than:

(100 + 20) / 2

Use:

overall average speed =
total distance / total moving time

or the most appropriate existing definition supported by the project's data.

Clearly document the chosen definition.

For maximum speed:

overall maximum speed =
maximum maximum_speed_kmh across all selected-vehicle trips.

For minimum speed:

Use the minimum meaningful recorded trip speed, not an arbitrary database
default.

Do not treat null as zero.

For total distance:

sum trip distances.

For total duration:

sum trip durations.

For stops:

sum persisted trip stop counts.

For turns, U-turns, hard braking, and sudden stops:

Use the completed analytics associated with the selected vehicle's trips.

Do not double-count events.

==================================================
MOVING VS STOPPED TIME
==================================================

If reliable moving/stopped duration is available from existing analyzed
track data, aggregate it.

If it cannot be reliably calculated from persisted data without loading
track points, do NOT invent a value.

Use null/unavailable state where appropriate.

Do not pretend:

total duration = moving duration + stopped duration

unless the data supports that calculation.

==================================================
ELEVATION
==================================================

For minimum and maximum altitude:

Use the meaningful minimum/maximum altitude across the selected vehicle's
trips.

For elevation gain/loss:

Use the existing AltitudeAnalysis from the completed analytics engine.

Do NOT simply calculate:

max altitude - min altitude

and call that elevation gain.

Elevation gain/loss must represent cumulative positive/negative elevation
change according to the existing altitude analysis.

==================================================
DETAILED ANALYTICS
==================================================

The following are already implemented and MUST be reused:

- DrivingAnalyticsService
- SpeedAnalysis
- AltitudeAnalysis
- TurnAnalysis
- BrakingAnalysis
- StopAnalysis

Do NOT duplicate their algorithms.

Do NOT create:

- another turn detector
- another braking detector
- another stop detector
- another speed calculator
- another altitude calculator

The Analytics dashboard consumes their results.

==================================================
PERFORMANCE ARCHITECTURE
==================================================

This is important.

Do NOT do this:

Analytics UI
  ↓
load every trip
  ↓
load every GPS point
  ↓
run every detector
  ↓
recalculate everything on every rebuild

Instead:

Analytics page
    ↓
OverallAnalyticsProvider(selectedVehicleId)
    ↓
TripRepository.getTripsForVehicle()
    ↓
aggregate persisted summary statistics
    ↓
load detailed analytics ONLY where genuinely required
    ↓
OverallDrivingAnalytics

The provider must cache its result for the selected vehicle.

Changing the selected vehicle should invalidate/rebuild the analytics for the
new vehicle.

Returning to the same vehicle should not unnecessarily rerun expensive work
on every widget rebuild.

==================================================
ANALYTICS PROVIDER
==================================================

Create a dedicated Riverpod provider for the overall analytics page.

Follow the existing project provider architecture.

Conceptually:

overallAnalyticsProvider(vehicleId)

The state should support:

- loading
- loaded
- empty
- error

Do not expose raw database implementation details to widgets.

The UI consumes the overall analytics model.

==================================================
AUTOMATIC REFRESH
==================================================

The Analytics page must update after a new trip is completed.

When FINISH persists a new trip, the existing trip invalidation mechanism
should cause the overall analytics provider to refresh when appropriate.

Do not create a second unrelated global refresh mechanism.

If the selected vehicle's trip list changes:

→ Analytics must reflect the new trip.

==================================================
ANALYTICS PAGE UI
==================================================

Build the existing Analytics page.

At the top:

- "Analytics" title
- selected vehicle information

Make it obvious that the statistics belong to the selected vehicle.

Example:

Analytics
[Car Name / Model]

Do not create a vehicle selector inside Analytics if the application already
has the global selected-car mechanism.

The bottom navigation / existing car selector remains the source of selection.

==================================================
CORE OVERVIEW
==================================================

Create a prominent overview section.

Show:

- Total trips
- Total distance
- Total driving time
- Average speed
- Top speed

These are the most important overall statistics.

Use clean cards.

Do not make the page visually overcrowded.

==================================================
DRIVING STATISTICS
==================================================

Show:

- Average speed
- Minimum speed
- Maximum speed
- Total distance
- Total duration
- Stops

Use icons where appropriate.

==================================================
DRIVING EVENTS
==================================================

Show aggregate event counts:

- Left turns
- Right turns
- U-turns
- Hard braking
- Sudden stops
- Stops

Keep the design compact.

Use the same visual language established on Trip Stats.

==================================================
ALTITUDE STATISTICS
==================================================

Show:

- Minimum altitude
- Maximum altitude
- Elevation gained
- Elevation lost

Only display values when meaningful data exists.

Do not display fake zeros for unavailable altitude data.

==================================================
TRENDS / GRAPHS
==================================================

The Analytics page should include useful cross-trip trends.

At minimum provide:

1. Distance over time
2. Average speed over time

If the existing graph infrastructure supports it cleanly, also provide:

3. Maximum speed over time

The graphs represent TRIPS, not individual GPS points.

For example:

X-axis:
trip date/time

Y-axis:
distance / speed

Each point represents one completed trip for the selected vehicle.

Graphs must:

- fit phone width
- not require page-level horizontal scrolling
- remain readable
- support tapping a point where practical
- show the relevant trip value at that point
- use chronological ordering

Do NOT load all GPS points to create these graphs.

Use persisted trip summary values.

==================================================
GRAPH INTERACTION
==================================================

When the user taps a graph point:

show useful information for that trip.

For example:

Distance graph:
- date/time
- distance

Average speed graph:
- date/time
- average speed

Maximum speed graph:
- date/time
- maximum speed

If the graph infrastructure supports navigation safely, allow the user to
open the corresponding Trip Stats page.

Do not introduce a complicated navigation system.

==================================================
DATE RANGE / FILTERING
==================================================

Do NOT introduce a complex date-filter UI in Phase 6.6 unless the existing
Analytics page already has one.

The primary filter is:

CURRENTLY SELECTED VEHICLE.

A future phase may add additional analytics filters.

==================================================
EMPTY STATE
==================================================

If the selected vehicle has no trips:

Show a proper empty state.

Example:

"No trips yet"

Explain that completed trips will appear here after driving.

Do not show misleading statistics.

==================================================
LOADING STATE
==================================================

While analytics are loading:

- show loading indicators/placeholders
- keep layout stable where possible
- do not display fake values

The page must not freeze.

==================================================
ERROR STATE
==================================================

If analytics fail:

- do not crash
- show a clear error message
- allow retry if appropriate

Do not expose raw SQLite exceptions to the user.

==================================================
OFFLINE REQUIREMENT
==================================================

The entire Analytics page must work without internet access.

No:

- HTTP
- reverse geocoding
- Google Maps
- map tile requests
- cloud database
- online analytics service

All aggregate statistics come from local SQLite data.

==================================================
VEHICLE DELETION
==================================================

Existing database behavior is:

vehicle_id → ON DELETE SET NULL.

Therefore:

If the selected vehicle is deleted:

- the selected vehicle state should be handled safely by the existing vehicle
  system
- Analytics must not crash
- do not silently combine those orphaned trips into another vehicle's
  analytics

Trips whose vehicle_id becomes NULL are not part of a selected vehicle's
analytics.

==================================================
TRIP ORDER
==================================================

When constructing time-series graphs:

- chronological order from oldest to newest

The newest trip may appear at the right side of the graph.

==================================================
NO DATABASE MIGRATION
==================================================

Do NOT change the database schema.

Do NOT add tables.

Do NOT add columns.

Do NOT change the database version.

Use existing persisted trip data.

==================================================
NO CHANGES TO TRACKING
==================================================

Do NOT modify:

- GPS tracking
- foreground service
- DriveController
- DriveProvider tracking behavior
- Google Maps launcher
- destination mode
- reckless mode

This phase is analytics aggregation + Analytics page UI only.

==================================================
NO CHANGES TO TRIP STATS
==================================================

Do NOT redesign or replace the completed Trip Stats page.

Trip Stats remains the detailed view for ONE trip.

Analytics is the aggregate view for the SELECTED VEHICLE.

If shared widgets are needed, extract/reuse them carefully without changing
existing behavior.

==================================================
DEPENDENCIES
==================================================

Do NOT add new packages unless genuinely required.

Prefer existing:

- flutter_riverpod
- flutter_map
- existing graph infrastructure
- existing repositories

If a package appears necessary:

STOP before adding it and explain why it is genuinely required.

==================================================
TESTING
==================================================

Create comprehensive tests.

At minimum test:

DATA SCOPE:

1. Selected vehicle with no trips → empty state
2. Selected vehicle with one trip
3. Selected vehicle with multiple trips
4. Other vehicles' trips are excluded
5. Changing selected vehicle changes analytics
6. Null vehicle_id trips are excluded

AGGREGATION:

7. Total trip count
8. Total distance
9. Total duration
10. Correct weighted overall average speed
11. Maximum speed across trips
12. Minimum meaningful speed
13. Total stops
14. Total left turns
15. Total right turns
16. Total U-turns
17. Total hard braking
18. Total sudden stops
19. Elevation gain
20. Elevation loss
21. Minimum altitude
22. Maximum altitude

GRAPH DATA:

23. Distance trend chronological
24. Average-speed trend chronological
25. Maximum-speed trend chronological
26. Graph data excludes invalid/null values safely
27. Graph point maps to correct trip

STATE:

28. Loading state
29. Empty state
30. Error state
31. Successful refresh after new trip
32. Provider caching/rebuild behavior

UI:

33. Analytics title renders
34. Selected vehicle renders
35. Overview statistics render
36. Driving event statistics render
37. Altitude statistics render
38. Graphs render
39. No horizontal overflow
40. Long vehicle names do not break layout

Use deterministic fake repositories/providers where appropriate.

Do NOT rely on real GPS.

==================================================
REGRESSION TESTING
==================================================

ALL existing tests must continue passing.

Especially verify:

- Phase 5.1 database
- Phase 5.2 vehicles
- Phase 5.3 trips
- Phase 5.4 track points
- Phase 5.5 Trip Stats
- Phase 6.1 analytics
- Phase 6.2 turns
- Phase 6.3 braking
- Phase 6.4 consolidated analytics
- Phase 6.4.1 stops
- Phase 6.5 Trip Stats UI

Do not break existing behavior.

==================================================
PHYSICAL DEVICE
==================================================

After implementation:

Run:

flutter analyze
flutter test

Then run the application.

Verify the Analytics page on a realistic phone-sized layout.

Test with:

- no trips
- one trip
- multiple trips
- multiple vehicles

Confirm that switching the selected vehicle changes the Analytics page.

==================================================
DOCUMENTATION
==================================================

Update:

docs/PROGRESS_TRACKER.md

Mark:

Phase 6.6 — Overall Driving Analytics Dashboard

as COMPLETE only after all verification passes.

Then mark:

Phase 6 — Driving Analytics

as COMPLETE.

Document:

- selected vehicle scope
- aggregation rules
- weighted average speed calculation
- event aggregation
- trend graphs
- provider architecture
- loading/error/empty states
- offline behavior
- performance decisions
- tests

Do NOT begin Phase 7.

==================================================
FINAL VERIFICATION
==================================================

Run:

flutter pub get

flutter analyze

flutter test

Confirm:

- zero analyzer issues
- zero test failures
- no database migration
- no new tracking behavior
- no regression to Trip Stats
- Analytics only shows selected vehicle data

==================================================
FINAL REPORT
==================================================

When complete, provide a full report containing:

1. Phase 6.6 status
2. Files created
3. Files modified
4. OverallDrivingAnalytics model
5. Aggregation rules
6. Weighted average speed calculation
7. Selected-vehicle filtering
8. Provider architecture
9. Analytics page UI
10. Overview statistics
11. Event statistics
12. Altitude statistics
13. Trend graphs
14. Graph interaction
15. Loading state
16. Empty state
17. Error handling
18. Offline behavior
19. Performance considerations
20. Tests added
21. Total tests passed
22. flutter analyze result
23. Dependencies added
24. Physical-device testing still required
25. Known limitations

IMPORTANT:

This is the FINAL task of Phase 6.

Do NOT implement Phase 7.

STOP after Phase 6.6.