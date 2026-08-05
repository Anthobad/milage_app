Read `AGENTS.md`.

Implement Phase 4.1 only.

Feature:
TripRank Map Foundation

Important architecture decision:

TripRank is NOT a navigation replacement.

The app:
- Displays maps
- Previews routes
- Records driving data

External navigation apps handle:
- Turn-by-turn directions
- Voice guidance
- Traffic
- Rerouting

Technology requirements:

Use:
- flutter_map
- OpenStreetMap tiles
- geolocator for location

Do NOT use:
- google_maps_flutter
- Google Maps SDK
- Paid APIs

Implement:

1. Replace the Map placeholder screen with a real map.

2. Add:
- OpenStreetMap map display
- User current location
- Location permission handling
- Basic map controls

3. Prepare architecture for:
- Destination selection
- Route preview
- Trip recording

Map requirements:
- Map theme must be independent from app theme.
- Support future light/dark map styles.

Keep the bottom information area minimal:
- Current speed placeholder
- Altitude placeholder
- Distance placeholder

Map UI requirements:

- Map should be displayed inside a rounded container.
- Leave spacing between map and bottom navigation.
- Add top floating map bar.
- Left side shows temporary title "MILEAGE".
- Right side has search icon.
- Search icon expands into a full-width search field covering the title.
- Search field should animate smoothly.
- Keep architecture ready for future offline maps.

Do not implement:
- Destination search
- Route drawing
- Google Maps launching
- Trip recording
- Analytics

Follow:
- docs/ARCHITECTURE.md
- docs/UI_GUIDELINES.md
- docs/AI_RULES.md

### When Done
- there should be no errors.
- app run successfully.