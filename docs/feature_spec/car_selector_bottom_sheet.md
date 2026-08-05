Read `AGENTS.md`.

Implement Phase 3.3 only.

Feature:
Global Vehicle Selector Bottom Sheet

Important:
The Cars item in the bottom navigation is NOT a normal page.
It is a global action that opens a vehicle selection bottom sheet over the current screen.

The current screen underneath must remain visible.

Examples:
- User is on Map → taps Cars → vehicle selector opens.
- User is on Trips → taps Cars → vehicle selector opens.
- User is on Analytics → taps Cars → vehicle selector opens.

Do not navigate to a Cars page.

--------------------------------------------------

Bottom Sheet UI:

Position:
- Opens from the bottom of the screen.
- Appears above the bottom navigation bar.
- Does not cover the whole screen.
- Current page remains visible behind it.

Style:
- Rounded top corners.
- Follow app theme.
- Use dark theme styling first.
- Respect future light theme support.

--------------------------------------------------

Header:

Left:
"Select Vehicle"

Right:
"+" button
"Delete" button

Buttons are only UI placeholders in this phase.

Do not implement their actions yet.

--------------------------------------------------

Vehicle List:

Display all vehicles from the Riverpod vehicle provider.

Each item should display:

- Brand
- Model

Example:

Toyota Corolla

Do not display:
- Year
- Type
- Additional information

--------------------------------------------------

Selected Vehicle:

The currently selected vehicle must show:

- Check mark on the right side.

Example:

Toyota Corolla                 ✓

When the user taps another vehicle:

- Update selected vehicle through Riverpod.
- Close the bottom sheet.
- The rest of the app should receive the new selected vehicle state.

--------------------------------------------------

Vehicle Item Actions:

Each vehicle row has an edit icon on the right side.

For this phase:
- Show the icon.
- No edit functionality yet.

--------------------------------------------------

Architecture Rules:

The UI must not contain vehicle business logic.

Flow:

Car Selector Sheet
        |
        ↓
Vehicle Provider
        |
        ↓
Vehicle State

--------------------------------------------------

Create reusable widgets where appropriate.

Suggested structure:

features/cars/

presentation/

widgets/
- car_selector_sheet.dart
- vehicle_tile.dart

--------------------------------------------------

The selector should remain compact and optimized for quick switching.

Empty state:

If the vehicle list is empty:
- Do not show an empty list.
- Show a "Create your first vehicle" action.
- This action will later open the Add Vehicle dialog.

Keep the empty state simple and user-friendly.

Do not implement:
- Database
- Persistence
- Add vehicle dialog
- Edit vehicle dialog
- Delete confirmation dialog
- GPS
- Maps

Follow:
- docs/ARCHITECTURE.md
- docs/UI_GUIDELINES.md
- docs/AI_RULES.md

### When Done
- there should be no errors.
- app run successfully.