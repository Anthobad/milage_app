# Phase 5.5 — Trips Page & Trip Stats UI

Read `AGENTS.md` first.

Implement **Phase 5.5 only**.

Phases 5.1–5.4 are complete and must be treated as the existing foundation.

Do NOT redesign the database architecture.

Do NOT add new database tables unless an existing UI requirement absolutely cannot be fulfilled with the data already persisted.

The goal of this phase is to build the **Trips page and Trip Stats experience** using the persisted Trip and GPS track data.

Follow:

- `docs/ARCHITECTURE.md`
- `docs/UI_GUIDELINES.md`
- `docs/AI_RULES.md`

Inspect the existing implementation before changing anything and reuse existing components/providers/models where appropriate.

---

# 1. TRIPS PAGE

The Trips page must show **only trips belonging to the currently selected vehicle**.

Use the existing selected-vehicle state from the vehicle system.

Do NOT show trips belonging to other vehicles.

When the selected vehicle changes, the Trips page must refresh to show only that vehicle's trips.

If no vehicle is selected, show an appropriate empty state rather than displaying trips from all vehicles.

---

# 2. TRIPS PAGE TOP BAR

At the top:

```text
Trips                              🔍  📅
```

Left:

- Title: `Trips`

Right:

- Search icon
- Calendar icon

Use the existing app typography, spacing, icon style, dark theme, and UI guidelines.

Do not introduce a new visual language.

---

# 3. DESTINATION SEARCH

The search interaction must behave similarly to the destination search on the Map page.

Initially:

```text
Trips                              🔍
```

When the search icon is pressed:

- Animate/expand the search field.
- The search field expands horizontally across the top bar.
- It covers/replaces the `Trips` title area.
- Keep the search icon/action available as appropriate.
- Do not push the entire page downward.
- Do not open a separate full-screen search page.

The expanded state should resemble the Map destination search interaction.

When search is dismissed or completed:

- Collapse the search bar.
- Restore the `Trips` title.

Search behavior:

Search trips by **destination**.

For Destination Mode trips:

- Search the stored `destinationName`.

For trips without a destination:

- They should not match a destination search unless the search is empty.

Search should be case-insensitive.

Do not perform network searches.

This is a local trip-history filter.

---

# 4. CALENDAR FILTER

When the calendar icon is pressed:

- Show a calendar/date-filter popup.
- The popup should appear from the top area and cover the top bar rather than behaving like a full-screen page.
- Use rounded corners consistent with the rest of the application.
- Keep the underlying Trips page visible behind/around it where appropriate.

The user must be able to filter trips by date.

Support:

- Specific date
- Date range if practical with the existing calendar component
- Clear/remove date filter

The exact calendar interaction should follow the existing app visual language.

The filter must work entirely against locally persisted trip dates.

No internet is required.

When a date filter is active, make the active state visually clear.

---

# 5. FILTER COMBINATION

Search and calendar filters must work together.

Example:

```text
Selected vehicle
    +
Destination search = "Jounieh"
    +
Date filter = August 2026
```

Only trips satisfying all active filters should appear.

Clearing one filter must leave the others active.

---

# 6. TRIP ORDER

Trips must always be displayed:

**Newest → oldest**

The newest completed trip appears at the top.

The oldest appears at the bottom.

Use the persisted trip start/completion timestamp consistently.

Do not sort by list insertion order.

---

# 7. EMPTY STATES

If the selected vehicle has no trips:

Show a clean empty state explaining that no trips have been recorded for the selected vehicle yet.

If filters produce no results:

Show a different empty state indicating that no trips match the current filters.

Do not make the two situations look like the same problem.

---

# 8. TRIP LIST ITEM

Each Trip should be displayed as a visually compact card/list item.

The layout is:

```text
┌───────────────────────────────────────────────────┐
│ ┌──────────────┐                                  │
│ │              │   Date + time              🗑    │
│ │   POLYLINE   │   Destination                    │
│ │   THUMBNAIL  │   Vehicle                        │
│ │              │   Avg speed   Time   Distance    │
│ └──────────────┘                                  │
└───────────────────────────────────────────────────┘
```

The item must have rounded corners consistent with the rest of the app.

---

# 9. POLYLINE THUMBNAIL

The left side of every Trip item contains a **square thumbnail** showing the actual route taken.

The thumbnail is NOT a real interactive map.

It is a compact visualization of the stored GPS track.

Use:

- Dark background
- Subtle grid lines
- Grid should visually resemble a simplified map/grid
- Bright/high-contrast polyline
- Rounded corners/clipping

The polyline must be clearly visible.

Use a color that fits the existing blue-focused application theme.

Do not use an overly bright background.

---

# 10. POLYLINE THUMBNAIL FITTING

The entire actual route must fit inside the square thumbnail.

For long trips:

- Scale the complete polyline down.
- Preserve the overall shape.
- Keep the start and end visible.
- Do not simply crop the middle of the route.

The goal is:

```text
Long route:

START ────────────────╮
                      │
                      └──────────── END

        ↓ scale to fit ↓

┌──────────────┐
│ •───────╮    │
│         │    │
│         ╰──• │
└──────────────┘
```

Maintain aspect ratio.

Add sensible padding around the route so it does not touch the edges.

If start/end markers are visually useful, they may be included, but do not clutter the thumbnail.

The thumbnail should use the **actual stored GPS track**, not a newly requested routing result.

---

# 11. TRIP ITEM TEXT

To the right of the thumbnail:

Top:

- Date
- Time

Below:

For Destination Mode:

- Destination

For Reckless Mode:

- Show a clear indication that there was no destination, or omit the destination line while maintaining clean spacing.

Below destination:

- Vehicle used

Below vehicle:

Display these three values horizontally:

- Average speed
- Total time
- Distance

Use compact labels/values that remain readable on small phone screens.

Do not allow text to overflow into the delete-button area.

---

# 12. DELETE TRIP

At the far right of the Trip item:

- Show a bin/delete icon.

When pressed:

Show a confirmation dialog.

The dialog must clearly state that deleting the trip removes the saved trip history.

Use the existing dialog visual style.

Actions:

- Cancel
- Delete

Delete must:

- Delete the persisted Trip.
- Delete its associated GPS track through the existing persistence relationship.
- Refresh the Trips page.

Do not delete the vehicle.

Do not delete other trips.

Do not use a swipe-to-delete interaction unless already established elsewhere in the application.

---

# 13. OPEN TRIP

Tapping the Trip item, except when tapping the delete button, should open the Trip Stats page for that Trip.

Pass/load the Trip ID.

Do not create a temporary copy of the Trip.

Trip Stats must load the persisted Trip through the existing repository/provider architecture.

---

# 14. TRIP STATS PAGE

The Trip Stats page is a vertically scrollable page.

The user should scroll vertically through the complete trip information.

Do NOT make the entire page horizontally pannable.

At the top:

```text
TIME + DATE
FROM → DESTINATION
```

For Reckless Mode:

Show the time/date and clearly indicate that the trip was Reckless Mode / had no destination.

---

# 15. TRIP ROUTE MAP

Below the date/time and destination information:

Show the actual route taken on a map.

This is the persisted GPS track converted into a polyline.

Use `flutter_map` and the existing map architecture.

The map must:

- Have rounded corners.
- Show the actual polyline.
- Automatically fit the viewport to the entire recorded route initially.
- Allow the user to zoom in.
- Allow the user to zoom out.
- Allow the user to pan.
- Keep the polyline visible while navigating the map.

IMPORTANT:

Do not show the entire world/map unnecessarily.

Initially load/display the map region needed to show the trip's actual route.

The initial camera/viewport should be fitted around the polyline with reasonable padding.

Do not request a new route from an online routing service.

The displayed route must come from the persisted GPS points.

If map tiles are unavailable/offline:

- Keep the route data available.
- Do not crash.
- The polyline should still be handled correctly when map tiles become available.

---

# 16. MAP TILE SCOPE

The map should initially display only the geographic area around the trip.

Do NOT zoom out to a country/world-level view.

Fit:

```text
START
  ↓
all GPS points
  ↓
END
```

with sensible padding.

If the trip is very short, avoid zooming so far in that the map becomes unusable.

Use reasonable min/max zoom constraints.

---

# 17. IMMEDIATE TRIP DETAILS

Below the route map, show the statistics that are already persisted and therefore should be available immediately.

At minimum:

- Vehicle
- Average speed
- Minimum speed
- Maximum speed
- Minimum altitude
- Maximum altitude
- Duration
- Distance
- Stops

Use a clean card/grid layout.

Use icons for the statistics.

Do not make the user horizontally scroll to see the statistics.

The layout must fit naturally on a phone screen.

---

# 18. LOADING PLACEHOLDERS

Every statistic/section that requires additional calculation or GPS-track processing must have a placeholder.

Before the result is ready:

- Show an appropriate loading placeholder.
- Show a loading indicator/spinner where appropriate.

When the result becomes available:

- Replace the placeholder with the real result.

Do NOT block the entire Trip Stats page while one calculation is loading.

Persisted summary statistics should display immediately.

GPS-derived details may load independently.

---

# 19. SPEED GRAPH

Below the main trip statistics:

Show a **speed-over-time graph**.

Requirements:

- Full width of the available content area.
- Fits completely within the screen width.
- No horizontal scrolling.
- No manual zooming required.
- No horizontal panning required.
- User can vertically scroll the page normally.
- Graph must have readable axis labels.
- Show appropriate units.
- Clearly distinguish the plotted speed data.

The graph should use the stored GPS track points.

Do not recalculate the basic persisted average/min/max values unnecessarily.

---

# 20. INTERACTIVE SPEED GRAPH

The user must be able to press/touch the speed graph.

When the user touches a location on the graph:

- Find the nearest recorded timestamp/data point.
- Show a visible marker/crosshair at that point.
- Display the corresponding:
  - Time
  - Speed

The selected value should be shown in a small tooltip/overlay that does not obscure the graph unnecessarily.

As the user moves their finger along the graph:

- Update the selected point.
- Update the displayed time.
- Update the displayed speed.

When the user releases/taps elsewhere:

- Keep the last selected point or dismiss it according to the cleanest UX.

Do not make the graph itself zoomable or horizontally pannable.

Flutter's gesture system can be used for this interaction.

---

# 21. ALTITUDE GRAPH

Below the speed graph:

Show an altitude-over-time graph.

Requirements:

- Full available width.
- Fits completely on screen.
- No horizontal scrolling.
- No manual zooming.
- No graph panning required.

Use the persisted GPS altitude values.

Show appropriate units.

---

# 22. INTERACTIVE ALTITUDE GRAPH

The altitude graph must have the same touch interaction model as the speed graph.

When touched:

- Find the nearest timestamp.
- Show a marker/crosshair.
- Show:
  - Time
  - Altitude

Moving across the graph updates the selected point.

Do not require graph zooming.

---

# 23. GRAPH DESIGN

Graphs should visually match the rest of TripRank.

Use the existing app color palette.

The graphs should be clean and readable in dark mode.

Avoid excessive decoration.

The graph's content should remain visible against the dark background.

Do not use tiny labels that are unreadable on a phone.

If custom drawing is needed, Flutter supports `CustomPaint`/`CustomPainter` for this type of visualization.

If the existing project already contains a suitable graph implementation/package, reuse it rather than adding a new dependency unnecessarily.

---

# 24. REMAINING STATISTICS

After the graphs, show the remaining trip information using icon-based statistic rows/cards.

Use the data that is actually available.

Examples may include:

- Start location
- Destination
- Vehicle
- Duration
- Distance
- Average speed
- Maximum speed
- Minimum speed
- Minimum altitude
- Maximum altitude
- Stops
- Other already-supported trip statistics

Do not invent values.

If a statistic is not yet implemented:

- Show its placeholder/loading state if it is planned.
- Do not fabricate a value.

---

# 25. LEFT / RIGHT TURNS

The **left/right turn statistic must be at the end of the Trip Stats page**.

Do not place it near the basic summary.

Display it as a horizontal split bar.

Conceptually:

```text
LEFT                          RIGHT
██████████░░░░░░░░░░░░░░░░░░████████████
```

The bar represents the distribution of left and right turns.

The two sides should have visually distinct colors that fit the existing dark/blue design.

Do NOT choose random neon colors.

Choose two complementary, readable colors that clearly distinguish left from right.

Each side should contain the corresponding number of turns.

Example:

```text
←  8                         5  →
████████████░░░░░░░░░░░░░░███████
```

The bar length should represent the relative number of turns.

If one side is too narrow to comfortably contain its number:

- Place the number immediately outside that section.
- Keep it visually associated with the correct side.

If total turns = 0:

- Show an appropriate zero-turn state.
- Do not display misleading percentages.

If percentages are shown, calculate them from:

leftTurns / totalTurns
rightTurns / totalTurns

The two percentages must total 100% when totalTurns > 0.

IMPORTANT:

Only use turn data if the current persisted GPS data/analytics system actually provides it.

Do not invent turn counts in this phase.

If turn detection is not yet implemented:

- Create the UI component/state placeholder.
- Show a loading/not-yet-available state rather than fake numbers.

---

# 26. RESPONSIVE PHONE LAYOUT

The Trip Stats page must be designed for phone screens.

IMPORTANT:

Graphs must fit the available screen width.

The user must NOT have to:

- pinch-to-zoom graphs
- horizontally pan graphs
- zoom the entire page
- rotate the phone

The page itself may vertically scroll because it contains many sections.

Use flexible layouts rather than hard-coded widths.

Avoid `RenderFlex overflow` errors.

Test at the project's available phone/emulator dimensions.

---

# 27. PERFORMANCE

Trip histories can contain thousands of GPS points.

Do not unnecessarily rebuild the entire Trip Stats page whenever one statistic loads.

Keep:

- Trip summary loading
- GPS track loading
- Graph calculations

appropriately separated.

Do not perform expensive GPS calculations directly inside `build()`.

Use the existing Riverpod architecture.

Do not load all trips from all vehicles just to filter them in the UI if the repository can query by vehicle.

Prefer:

```text
getTripsForVehicle(vehicleId)
```

and then apply local search/date filters to that selected vehicle's trips.

---

# 28. STATE MANAGEMENT

Use Riverpod.

Do not introduce a second state-management system.

Keep responsibilities separated:

Trips UI
 ↓
Trips Provider
 ↓
TripRepository

Trip Stats UI
 ↓
Trip Stats Provider
 ├── TripRepository
 └── TrackPointRepository

Search/date filter state may remain local to the Trips page if it does not need to be shared elsewhere.

---

# 29. DATABASE

Do NOT change the database schema in this phase unless absolutely required.

The existing Phase 5.3 and 5.4 schema already contains the data needed for this UI:

- trips
- trip_track_points
- vehicle relationship
- summary statistics
- GPS coordinates
- timestamps
- speed
- altitude

Do not add duplicate fields just to make the UI easier.

---

# 30. DEPENDENCIES

Use existing dependencies.

Do NOT add a graph package automatically.

First inspect whether the existing project can implement the graphs using:

- Flutter widgets
- CustomPaint/CustomPainter
- existing dependencies

Only add a dependency if it provides a meaningful advantage and cannot reasonably be implemented with what is already available.

If adding a dependency is genuinely necessary, explain why before adding it.

---

# 31. NAVIGATION

Trips page:

```text
Trip item
   ↓
Trip Stats
```

Trip Stats:

- Back returns to Trips.
- Do not create duplicate navigation stacks.
- Preserve the existing bottom navigation behavior.

The post-finish flow from Phase 5.4 must remain intact:

```text
FINISH
 ↓
persist Trip
 ↓
Trip Stats
```

Do not break this.

---

# 32. DELETE FLOW

When deleting a Trip from the Trips page:

1. Show confirmation dialog.
2. User chooses Delete.
3. Delete the Trip through the existing repository.
4. Associated GPS track must also be deleted through the existing database relationship.
5. Refresh the Trips list.
6. If the deleted Trip is currently open in Trip Stats, handle navigation safely.

Do not delete vehicles.

---

# 33. TESTING

Add/update tests for:

### Trips filtering

1. Only selected vehicle's trips appear.
2. Changing selected vehicle refreshes the list.
3. Destination search filters correctly.
4. Search is case-insensitive.
5. Calendar/date filter works.
6. Search + date filter work together.
7. Clearing search works.
8. Clearing date filter works.
9. Newest trips appear first.
10. Empty vehicle history state works.
11. No-results filter state works.

### Trip item

12. Correct date/time.
13. Correct destination.
14. Correct vehicle.
15. Correct average speed.
16. Correct duration.
17. Correct distance.
18. Polyline thumbnail renders stored track.
19. Long tracks fit inside thumbnail.
20. Delete confirmation appears.
21. Deleting a trip refreshes the list.

### Trip Stats

22. Correct Trip loads by ID.
23. Summary statistics display.
24. Start/destination display correctly.
25. Reckless Mode displays correctly.
26. GPS track loads.
27. Route polyline renders.
28. Map fits route initially.
29. Map can pan.
30. Map can zoom.
31. Speed graph renders.
32. Speed graph fits screen width.
33. Speed graph touch selection works.
34. Speed graph shows selected time/speed.
35. Altitude graph renders.
36. Altitude graph fits screen width.
37. Altitude graph touch selection works.
38. Altitude graph shows selected time/altitude.
39. Loading states work.
40. Missing data does not crash the page.
41. Left/right turn placeholder works.
42. No-turn state works if data is available.
43. Existing post-finish navigation remains functional.

### Regression

44. All existing tests continue passing.
45. `flutter analyze` reports no issues.

Add additional tests if necessary.

---

# 34. VISUAL QUALITY

This is a UI phase.

Do not treat the requirements as placeholders only.

Implement the actual visual design described above.

Maintain:

- Dark-first design
- White/light text
- Blue-focused accent
- Inter font if already configured
- Rounded corners
- Clean spacing
- Consistent iconography
- Compact but readable information density

Do not introduce unnecessary gradients, excessive cards, or oversized UI.

The page should feel like one cohesive TripRank experience.

---

# 35. VALIDATION

After implementation:

1. Run `flutter analyze`.
2. Run all tests.
3. Run the application.
4. Verify Trips only shows the selected vehicle's trips.
5. Test destination search.
6. Test calendar filtering.
7. Test deleting a trip.
8. Open a completed Trip.
9. Verify route polyline.
10. Verify map zoom/pan.
11. Verify summary statistics.
12. Verify speed graph.
13. Touch speed graph and verify values update.
14. Verify altitude graph.
15. Touch altitude graph and verify values update.
16. Verify loading placeholders.
17. Verify turn section.
18. Verify the entire page works without horizontal overflow.
19. Verify graphs fit the phone screen without zoom/pan.
20. Verify FINISH → Trip Stats still works.
21. Verify Trips list refreshes after completing a new trip.

At completion, report:

- Files created
- Files modified
- Any dependencies added
- Trips filtering implementation
- Search implementation
- Calendar implementation
- Trip thumbnail implementation
- Trip Stats implementation
- Map/polyline implementation
- Speed graph implementation
- Altitude graph implementation
- Interactive graph behavior
- Loading states
- Turn section status
- Delete flow
- Tests passed
- `flutter analyze` result
- Any functionality that remains unavailable because the underlying data/analytics does not yet exist