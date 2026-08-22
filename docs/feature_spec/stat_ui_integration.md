Read AGENTS.md first.

Implement Phase 6.5 — Trip Statistics & Analytics UI Integration.

IMPORTANT:
Phases 5.1–5.5, 6.1–6.4, and 6.4.1 are COMPLETE.

Do NOT rewrite those phases.

The analytics backend is complete and provides:

- Speed analysis
- Altitude analysis
- Turn analysis
- Hard braking analysis
- Sudden stop analysis
- Stop detection
- Chronological analyzed track points
- Persisted trip summary
- Persisted GPS track points

The existing Trip Stats screen was created in Phase 5.5.

This phase connects the existing Trip Stats UI to the completed analytics system.

==================================================
GOAL
==================================================

Make the Trip Stats page fully functional using the existing persisted trip
data and analytics provider.

Do NOT create a separate analytics screen.

Do NOT create a second Trip Stats screen.

Use the existing Trip Stats route and screen.

==================================================
TRIP STATS PAGE
==================================================

The page should display, in this general order:

1. Trip header
2. Route/map
3. Main trip statistics
4. Speed graph
5. Altitude graph
6. Additional driving statistics
7. Turn visualization at the end

Keep the map and statistics visually clean and consistent with the existing
TripRank design.

Use the existing:

- dark theme
- Inter font
- blue accent
- rounded components
- existing spacing conventions
- existing UI guidelines

Read:

docs/ARCHITECTURE.md
docs/UI_GUIDELINES.md
docs/AI_RULES.md

before modifying UI.

==================================================
TRIP HEADER
==================================================

At the top show:

- Date
- Time

For DESTINATION MODE:

Show:

FROM
[start location]

TO
[destination]

For RECKLESS MODE:

Show the trip as a route without pretending there was a destination.

Use persisted trip information.

Do not reverse geocode here.

Do not make network requests.

==================================================
ROUTE MAP
==================================================

Show the recorded route/polyline.

Use the persisted GPS track points.

The map section must:

- have rounded corners
- show the route clearly
- allow zooming
- allow panning
- automatically fit the route when opened
- keep the route visible

IMPORTANT:

Do NOT load an entire map/world view.

The map should be focused on the geographic area containing the recorded
polyline.

Use the existing flutter_map implementation.

Do NOT introduce Google Maps SDK.

Do NOT introduce online routing.

Do NOT calculate a new route.

The polyline represents the route ACTUALLY TAKEN.

==================================================
OFFLINE MAP BEHAVIOR
==================================================

The statistics and polyline must still work completely offline.

If map tiles are unavailable:

- do NOT fail the Trip Stats page
- do NOT hide the recorded polyline
- do NOT make statistics dependent on map tiles

The polyline is based on stored latitude/longitude points and must remain
available even if no map tiles can be loaded.

Follow the existing map architecture.

==================================================
MAIN STATISTICS
==================================================

Display the important statistics using clean cards/rows with icons.

At minimum:

- Average speed
- Minimum speed
- Maximum speed
- Distance
- Duration
- Minimum altitude
- Maximum altitude
- Stops

Use the completed analytics provider.

Do NOT recalculate these values inside widgets.

Prefer persisted Trip summary values where they are already authoritative.

Use analytics-derived values where appropriate.

Handle null values gracefully.

Never display:

NaN
Infinity

Do not turn unavailable values into fake 0 values.

==================================================
SPEED GRAPH
==================================================

Display the speed-over-time graph.

Requirements:

- Must fit completely within the screen width.
- User must NOT need to horizontally pan the page to see the graph.
- User must NOT need to zoom the graph to understand it.
- Keep the graph readable on phone screens.
- Preserve chronological ordering.
- X-axis represents elapsed time.
- Y-axis represents speed.

Use:

analytics.analyzedPoints

as the source.

Do not perform new GPS calculations in the widget.

==================================================
GRAPH INTERACTION
==================================================

The user must be able to press/tap a point on the speed graph.

When a point is selected, show information for that moment.

At minimum:

- elapsed time
- speed

If timestamp is available, use it appropriately.

Do NOT require the user to pan or zoom the entire page.

Use the existing graph package/infrastructure if possible.

Do NOT add a new graph library unless absolutely necessary.

==================================================
ALTITUDE GRAPH
==================================================

Below the speed graph show altitude over time.

Requirements:

- Fit within the screen.
- No manual horizontal page panning required.
- No unnecessary zooming.
- Chronological data.
- Clear axis labels.

Use:

analytics.analyzedPoints

as the source.

When the user taps a point:

show:

- elapsed time
- altitude

Use the same interaction style as the speed graph.

==================================================
LOADING STATE
==================================================

Every major analytics section must support loading.

When analytics are still loading:

- show a loading indicator
- preserve the page structure where possible
- do not display fake statistics

When analytics finish:

- replace loading state with actual values

If analytics fail:

- show a clear non-crashing error state
- allow the rest of the trip information to remain visible when possible

==================================================
TURN STATISTICS
==================================================

At the END of the page show left/right turn statistics.

Use:

analytics.turnAnalysis

Do NOT implement a new turn detector.

Display:

- Left turns
- Right turns

Use the horizontal split-bar design discussed previously.

Concept:

             LEFT          RIGHT
          <--------|-------->
             left     right

There should be a central 0% point.

The left side represents left turns.

The right side represents right turns.

Bar lengths should be proportional to the number of turns.

Use visually distinct colors that still fit the TripRank theme.

Do not use harsh/random colors.

The number of turns should appear INSIDE the corresponding bar when there is
enough room.

If the bar is too narrow:

- display the number outside the bar next to it.

If both counts are zero:

- show an appropriate empty state rather than misleading bars.

U-turns should NOT be included in left/right counts.

Display U-turn count separately if appropriate.

==================================================
BRAKING / STOP STATISTICS
==================================================

Display:

- Hard braking count
- Sudden stop count
- Stop count

Use:

analytics.brakingAnalysis
analytics.stopAnalysis

Do not implement detection logic in the UI.

For braking events, use the existing severity/event information where useful.

Keep the presentation compact.

Do not create an enormous dashboard.

==================================================
OTHER DATA

Below the main statistics, show the remaining useful trip information
available from the completed analytics model.

Examples include:

- Elevation gain
- Elevation loss
- U-turns
- Hard braking
- Sudden stops
- Stops
- Trip mode

Only display statistics that actually have valid data.

Do not invent statistics.

==================================================
CAR INFORMATION

Show the vehicle used for the trip.

Use the persisted vehicleId.

If the vehicle still exists:

- display its relevant identifying information.

If the vehicle was deleted:

- do not crash
- display a sensible fallback such as "Vehicle unavailable"

Do not make the trip disappear because its vehicle was deleted.

==================================================
RESPONSIVE PHONE LAYOUT

This is important.

The entire Trip Stats screen is designed for a phone.

Ensure:

- no horizontal overflow
- no RenderFlex overflow
- graphs fit the available width
- cards fit narrow screens
- long destination names wrap correctly
- statistics don't get clipped
- turn bars remain usable on narrow screens
- map remains usable
- scrolling is vertical

The user should not need to zoom the entire page.

Run the app and check the screen at a realistic phone size.

==================================================
PERFORMANCE

Do not rerun analytics on every widget rebuild.

Use the existing:

tripAnalyticsProvider(tripId)

Riverpod provider.

The provider should be the source of truth.

Avoid:

- database queries inside build()
- analytics calculations inside build()
- repeated track-point loading
- repeated detector execution

Large trips must remain responsive.

==================================================
DATA SOURCE RULE

UI should follow:

TripStatsScreen
      ↓
tripAnalyticsProvider(tripId)
      ↓
TripAnalyticsState
      ├── Trip
      └── DrivingAnalytics
           ├── SpeedAnalysis
           ├── AltitudeAnalysis
           ├── TurnAnalysis
           ├── BrakingAnalysis
           └── StopAnalysis

Do not bypass the provider.

Do not access SQLite directly from widgets.

==================================================
DELETE

Do not change the existing trip deletion behavior unless required for the
Trip Stats page.

The existing delete confirmation flow must continue working.

==================================================
NO NEW ANALYTICS

Do NOT implement:

- new speed algorithms
- new altitude algorithms
- new turn detection
- new braking detection
- new stop detection
- new database schema
- new analytics provider

All of those are already complete.

This phase is UI integration only.

==================================================
DEPENDENCIES

Do NOT add packages unless absolutely necessary.

Prefer existing dependencies and existing graph/map infrastructure.

If a new package is genuinely required:

STOP and report why before adding it.

==================================================
TESTING

Add/update widget tests where practical.

At minimum test:

1. Trip header renders
2. Destination trip shows FROM/TO
3. Reckless trip does not show a fake destination
4. Main statistics render
5. Loading state renders
6. Analytics error state does not crash
7. Speed graph renders with data
8. Speed graph handles empty data
9. Altitude graph renders with data
10. Altitude graph handles missing altitude
11. Graph point interaction displays selected data
12. Left/right turn counts render
13. Zero turns render correctly
14. U-turns remain separate
15. Braking statistics render
16. Stop count renders
17. Deleted vehicle does not crash Trip Stats
18. Long destination names do not overflow
19. Narrow phone layout does not overflow

Use deterministic test data.

Do not rely on real GPS.

==================================================
REGRESSION

All existing tests must continue passing.

Especially:

- Phase 5.1
- Phase 5.2
- Phase 5.3
- Phase 5.4
- Phase 5.5
- Phase 6.1
- Phase 6.2
- Phase 6.3
- Phase 6.4
- Phase 6.4.1

Do not break:

- trip persistence
- vehicle persistence
- background tracking
- Google Maps integration
- reckless mode
- destination mode
- trip filtering
- trip deletion

==================================================
DOCUMENTATION

Update:

docs/PROGRESS_TRACKER.md

Mark Phase 6.5 complete only after:

- implementation complete
- tests pass
- flutter analyze passes
- application runs successfully

Document:

- Trip Stats UI integration
- graph interaction
- turn visualization
- braking/stop display
- loading/error handling
- responsive layout
- offline behavior
- known limitations

==================================================
VERIFICATION

Run:

flutter pub get

flutter analyze

flutter test

Then run the application.

Check the Trip Stats page using a realistic phone-sized layout.

Verify:

- no overflow
- graphs fit
- route displays
- statistics load
- graph interaction works
- turn bars work
- loading states work

==================================================
FINAL REPORT

When complete, report:

1. Files created
2. Files modified
3. Trip Stats UI changes
4. Route map behavior
5. Statistics displayed
6. Speed graph implementation
7. Altitude graph implementation
8. Graph interaction implementation
9. Turn visualization
10. Braking/stop visualization
11. Loading/error handling
12. Responsive-layout handling
13. Offline behavior
14. Tests added
15. Total tests passed
16. flutter analyze result
17. Dependencies added
18. Physical-device testing still required
19. Known limitations

IMPORTANT:

This is Phase 6.5 only.

Do not begin Phase 7.

STOP after Phase 6.5.