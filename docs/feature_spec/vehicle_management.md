Read `AGENTS.md`.

Implement Phase 3.4 only.

Feature:
Vehicle Management System

Context:
The Cars navigation item is a global vehicle selector, not a normal page.

The vehicle selector bottom sheet already exists from Phase 3.3.

This phase adds the management actions:
- Create vehicle
- Edit vehicle
- Delete vehicle

Do not change the existing navigation structure.

--------------------------------------------------

ARCHITECTURE RULES:

The UI must never directly modify vehicle data.

Required flow:

Dialog / Bottom Sheet UI
        |
        ↓
Vehicle Provider (Riverpod)
        |
        ↓
Vehicle State

The provider remains the single source of truth.

Do not add:
- Database
- Shared preferences
- Persistence
- Repository layer
- API calls

Use current in-memory Riverpod state.

--------------------------------------------------

1. ADD VEHICLE DIALOG

Entry points:

The dialog must open from:

A) Plus (+) button inside the vehicle selector bottom sheet.

B) Empty vehicle state:

When the user has no vehicles, the selector should show:

"No vehicles yet"

with:

"Create your first vehicle"

button.

Pressing it opens the same Add Vehicle dialog.

--------------------------------------------------

Dialog UI:

Use a centered modal dialog.

Requirements:

- Rounded corners.
- Follow the current app theme.
- Dark mode support.
- Clear title:

"Add Vehicle"

Layout:

Title

Brand field

Model field

Year field

Type selector

Cancel button

Save button

--------------------------------------------------

Fields:

Brand:
- Text input
- Required

Model:
- Text input
- Required

Year:
- Numeric input
- Required

Type:
Dropdown/select field.

Initial options:

- Sedan
- Hatchback
- SUV
- Coupe
- Pickup
- Van
- Other

The type list should be easy to expand later.

--------------------------------------------------

Validation:

Before saving:

- Brand cannot be empty.
- Model cannot be empty.
- Year cannot be empty.
- Year must be numeric.

If validation fails:
- Show appropriate error messages.
- Do not close the dialog.
- Do not create the vehicle.

--------------------------------------------------

Save behavior:

When the user saves:

1. Create a Vehicle object.
2. Generate a unique ID.
3. Add it through Vehicle Provider.
4. Automatically make the new vehicle the selected vehicle.
5. Close the dialog.
6. Update the selector state.

Example:

Before:

Vehicles:
[]

Selected:
null


After:

Vehicles:
[
Toyota Corolla
]

Selected:
Toyota Corolla

--------------------------------------------------

2. EDIT VEHICLE DIALOG

Entry point:

Each vehicle row in the selector has an edit icon.

Example:

Toyota Corolla                         ✏

Pressing the icon opens Edit Vehicle dialog.

--------------------------------------------------

Dialog UI:

Same structure as Add Vehicle.

Difference:

Title:

"Edit Vehicle"

All fields should already contain existing values.

Example:

Brand:
Toyota

Model:
Corolla

Year:
2020

Type:
Sedan

--------------------------------------------------

Save behavior:

When saving:

1. Validate fields.
2. Update the existing vehicle.
3. Keep the same vehicle ID.
4. Do not create a duplicate.
5. Update provider state.
6. Close dialog.

If the edited vehicle is currently selected:
- The selected vehicle should immediately reflect the changes.

--------------------------------------------------

3. DELETE VEHICLE CONFIRMATION

Entry point:

Delete button in the vehicle selector header.

The delete button deletes the currently selected vehicle.

--------------------------------------------------

Before deleting:

Show centered confirmation dialog.

Example:

Title:

"Delete Vehicle?"

Message:

"Are you sure you want to delete Toyota Corolla?"

Buttons:

Cancel

Delete

--------------------------------------------------

Delete behavior:

If user presses Cancel:

- Close dialog.
- No changes.

If user presses Delete:

1. Remove vehicle through Vehicle Provider.
2. Close confirmation dialog.
3. Update selected vehicle.

Selection rules after deletion:

Case 1:

Multiple vehicles exist:

Before:

Toyota Corolla ✓
Honda Civic


Delete Toyota:

Honda Civic becomes selected.

Case 2:

No vehicles remain:

Vehicles:
[]

Selected:
null

The selector should show:

"No vehicles yet"

"Create your first vehicle"

--------------------------------------------------

UI STRUCTURE:

Keep widgets separated.

Suggested structure:

features/cars/

presentation/

widgets/
- car_selector_sheet.dart
- vehicle_tile.dart

dialogs/
- add_vehicle_dialog.dart
- edit_vehicle_dialog.dart
- delete_vehicle_dialog.dart


models/
- vehicle.dart


providers/
- vehicle_provider.dart

--------------------------------------------------

IMPORTANT:

Do not implement:
- Database
- Local storage
- Trip linking
- GPS
- Analytics
- Maps

Only complete the vehicle management system.

Before finishing:
Run flutter analyze and fix any errors.

Follow:
- docs/ARCHITECTURE.md
- docs/UI_GUIDELINES.md
- docs/AI_RULES.md

### When Done
- there should be no errors.
- app run successfully.