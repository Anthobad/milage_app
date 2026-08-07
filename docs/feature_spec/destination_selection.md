Read `AGENTS.md`.

Implement Phase 4.2 only.

Feature:
Destination Selection System

IMPORTANT PRODUCT DECISION:

TripRank is NOT a navigation app.

TripRank responsibilities:
- Display map
- Let user choose destination
- Preview route later
- Track the actual drive
- Store trip analytics

External apps (Google Maps) handle:
- Turn-by-turn navigation
- Voice guidance
- Traffic
- Rerouting

Do not implement navigation logic.

--------------------------------------------------

CURRENT MAP UI:

Keep the existing Map screen design:

- Map is inside a rounded floating container.
- Map has spacing above the bottom navigation.
- Top floating bar:
    Left: "MILEAGE"
    Right: Search icon

Search behavior:
- Initially show app name + search icon.
- When search icon is pressed:
    - Animate into an expanded search field.
    - Search field replaces/covers the app name.
    - Allow destination text input.
    - Allow closing/collapsing search.

--------------------------------------------------

DESTINATION SEARCH:

Implement destination search.

Requirements:

- Use only free/open services.
- Do NOT use Google Places API.
- Do NOT add paid APIs.

Search flow:

User enters:
"Beirut Airport"

↓

Geocoding service

↓

Return:
- Place name
- Latitude
- Longitude

↓

Show search results.

When user selects a result:
- Close search mode.
- Move map camera to destination.
- Add destination marker.
- Save destination state.

--------------------------------------------------

MAP DESTINATION SELECTION:

Allow selecting a destination directly from the map.

Behavior:

- User long presses on the map.
- A destination marker appears.
- Save selected coordinates.
- Show selected location state.

The user should be able to use:
- Search destination
OR
- Select destination on map

Both produce the same destination object.

--------------------------------------------------

DATA MODEL:

Create Destination model:

Fields:

- id (optional)
- name
- latitude
- longitude

Create Riverpod provider for current selected destination.

The UI must not directly manage destination state.

Architecture:

UI
 |
 ↓
Destination Provider
 |
 ↓
Map State

--------------------------------------------------

AFTER DESTINATION SELECTED:

Show:
- Destination marker
- Current location marker

Prepare for future:

- Route preview
- Start Route button
- External navigation launch

Do not implement these yet.

--------------------------------------------------

DO NOT IMPLEMENT:

- Route calculation
- Route drawing
- Routing API
- Google Maps launching
- Trip recording
- GPS tracking
- Analytics
- Database
- Offline maps

--------------------------------------------------

Use:

- flutter_map
- geolocator
- Riverpod
- Free geocoding service

Follow:

- docs/ARCHITECTURE.md
- docs/UI_GUIDELINES.md
- docs/AI_RULES.md

### When Done
- there should be no errors.
- app run successfully.