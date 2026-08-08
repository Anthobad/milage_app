Read `AGENTS.md`.

Implement Phase 4.3 only.

Feature:
Route Preview

IMPORTANT PRODUCT DECISION:

TripRank is NOT a navigation app.

TripRank only:
- Selects destinations
- Calculates a route preview
- Displays the route
- Records the actual drive later

External navigation apps will handle:
- Turn-by-turn navigation
- Voice guidance
- Traffic
- Rerouting

Do not implement navigation.

--------------------------------------------------
CURRENT STATE
--------------------------------------------------

Phase 4.2 already provides:

- Destination search
- Destination selection from the map
- Destination model
- Riverpod destination state
- Current location

Use the existing implementation.
Do not recreate or duplicate destination functionality.

--------------------------------------------------
ROUTING
--------------------------------------------------

Add route calculation using a free/open routing service.

Use:
- OSRM

Do NOT use:
- Google Directions API
- Google Maps APIs
- Any paid routing service

The routing service should receive:

- Current location
- Selected destination

and return:

- Route coordinates
- Total distance
- Estimated duration

--------------------------------------------------
ROUTE MODEL
--------------------------------------------------

Create an appropriate route model/state containing:

- route coordinates
- distance
- estimated duration
- destination
- route status

Route status should support states such as:

- idle
- calculating
- ready
- error

Use Riverpod for route state.

Do not put routing/business logic directly inside widgets.

--------------------------------------------------
MAP DISPLAY
--------------------------------------------------

When a route is successfully calculated:

- Draw the route using a flutter_map Polyline.
- Display the destination marker.
- Keep the current-location marker.
- Fit the map camera so the route is visible.
- Ensure the entire route is reasonably visible.

The route must update when the selected destination changes.

--------------------------------------------------
ROUTE PREVIEW UI
--------------------------------------------------

After a route is available, show a minimal route information area.

Display:

- Route distance
- Estimated duration
- START ROUTE button

Do not add turn-by-turn instructions.

Do not add voice navigation controls.

The existing minimal map information area should remain consistent with the Map UI specification.

--------------------------------------------------
LOADING STATE
--------------------------------------------------

While calculating:

- Keep the map visible.
- Show a subtle loading indicator.
- Do not freeze or replace the entire map screen.

--------------------------------------------------
ERROR STATE
--------------------------------------------------

If route calculation fails:

- Keep the selected destination.
- Remove/avoid displaying an invalid route.
- Show a clear retry option/message.
- Do not crash the application.

--------------------------------------------------
ROUTE UPDATES
--------------------------------------------------

If the user selects a different destination:

1. Remove the previous route.
2. Calculate the new route.
3. Display the new route.

Do not allow stale route results to overwrite a newer destination selection.

START DRIVE / START ROUTE:

There is currently no implemented start button.
Implement the initial drive-start control as part of this phase.

The control should be positioned with the map controls near the recenter button.

Behavior:

NO DESTINATION:
- Button label/action: START
- Starting it will later enter Reckless Mode.

DESTINATION SELECTED:
- Button label/action: START
- Starting it will later enter Destination Mode.

For this phase, the button only needs to establish the correct UI/state.
Do not implement Google Maps launching or trip recording yet.

--------------------------------------------------

ROUTE PREVIEW UI:

When a destination is selected and a route is successfully calculated:

- Automatically fit the map camera to show:
  - current location
  - destination
  - complete route

- Draw the route on the map.

- Display estimated route distance in a small rounded bubble positioned near the route.

- The bubble should visually point toward the route.

- Keep the map visually clean and avoid covering important map content.

- Do not use a large bottom sheet for route information.

- Keep the existing minimal bottom information area.

MAP CONTROLS:

Provide:
- Recenter button
- Start Drive / Start Route button

The controls should be visually consistent with the existing map design.

--------------------------------------------------
DO NOT IMPLEMENT
--------------------------------------------------

Do NOT implement:

- Google Maps launching
- External navigation
- Turn-by-turn instructions
- Voice guidance
- Traffic
- Rerouting
- Trip recording
- Analytics
- Database
- Offline routing
- Multiple route alternatives

Those belong to later phases.

--------------------------------------------------
TECHNOLOGY
--------------------------------------------------

Use the existing:

- flutter_map
- geolocator
- Riverpod

Add only the packages actually required.

Keep the routing service abstracted so it can be replaced later without rewriting the Map UI.

Follow:

- docs/ARCHITECTURE.md
- docs/UI_GUIDELINES.md
- docs/AI_RULES.md

### When Done
- there should be no errors.
- app run successfully.