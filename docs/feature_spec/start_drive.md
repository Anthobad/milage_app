Read `AGENTS.md`.

Implement Phase 4.4 and Phase 4.5 together.

Feature:
Start Drive / Google Maps Integration / Continuous Background Tracking

IMPORTANT PRODUCT DECISION:

TripRank is NOT a navigation app.

TripRank is responsible for:
- Destination selection
- Route preview
- GPS trip recording
- Driving statistics
- Trip history

Google Maps is responsible for:
- Turn-by-turn navigation
- Voice directions
- Traffic
- Rerouting

Do NOT implement navigation functionality inside TripRank.

--------------------------------------------------
DRIVE MODES
--------------------------------------------------

TripRank has exactly two drive modes.

1. DESTINATION MODE

Used when a destination has been selected.

Flow:

Map
→ START ROUTE
→ Verify Google Maps is installed
→ Start TripRank tracking
→ Launch Google Maps with selected destination
→ User navigates using Google Maps
→ TripRank continues tracking in background
→ User may return to TripRank at any time
→ FINISH DRIVE
→ Tracking stops

The user does NOT need to return to TripRank for tracking to continue.

2. RECKLESS MODE

Used when no destination has been selected.

Flow:

Map
→ START DRIVE
→ Start TripRank tracking
→ Remain inside TripRank
→ Record GPS path
→ FINISH DRIVE
→ Tracking stops

--------------------------------------------------
GOOGLE MAPS REQUIREMENT
--------------------------------------------------

Destination Mode MUST use Google Maps only.

Do NOT:
- Fall back to Apple Maps
- Fall back to Waze
- Fall back to another maps application
- Show an Android app chooser

Use an Android external navigation intent/deep link that specifically targets Google Maps.

Before starting Destination Mode:

1. Check whether Google Maps is installed.
2. If Google Maps is installed:
   - Start the TripRank active-drive tracking.
   - Launch Google Maps with the selected destination.

3. If Google Maps is NOT installed:
   - Do NOT start the drive.
   - Do NOT start GPS tracking.
   - Do NOT launch another maps application.
   - Show a clear message:

     "Google Maps not found. Please install Google Maps to start a route."

The user remains on the TripRank map screen.

--------------------------------------------------
DRIVE STATE
--------------------------------------------------

Use Riverpod for drive state.

Create a clear state model.

DriveStatus:
- idle
- starting
- active
- finishing
- completed

DriveMode:
- destination
- reckless

Both modes must use the same active-drive architecture.

Do not create two separate tracking systems.

--------------------------------------------------
START BUTTON
--------------------------------------------------

There is currently no implementation to start button.

Implement it now.

If NO destination is selected:

Action:
- Start Reckless Mode.

If a destination IS selected:

Action:
- Verify Google Maps exists.
- Start Destination Mode only if Google Maps is available.

--------------------------------------------------
CONTINUOUS BACKGROUND TRACKING
--------------------------------------------------

THIS IS A HARD REQUIREMENT.

TripRank MUST continue recording an active drive while the application UI is in the background.

This is particularly important for Destination Mode.

Example:

TripRank
→ START ROUTE
→ Google Maps opens
→ User stays in Google Maps for the entire drive
→ TripRank remains in the background
→ TripRank continues recording GPS data
→ User eventually returns to TripRank
→ FINISH DRIVE

The user MUST NOT have to periodically reopen TripRank.

The user MUST NOT have to return to TripRank for tracking to continue.

Use Android's proper FOREGROUND LOCATION SERVICE architecture.

The tracking service must:

- Continue when TripRank's Activity is paused/stopped.
- Continue while Google Maps is in the foreground.
- Continue while the phone screen is locked.
- Continue while the screen is off during an active drive.
- Continue recording with the screen off/phone locked.
- Support arbitrarily long active drives rather than using an artificial time limit.
- Continue without requiring internet access.
- Persist collected GPS points incrementally rather than keeping the entire trip only in memory.
- Stop when the user explicitly finishes/cancels the drive.
- Handle Android lifecycle events correctly.

Do NOT implement:
- Timers to keep the app alive
- Reopening TripRank periodically
- Fake background loops
- UI-dependent GPS tracking
- Any workaround intended to bypass Android's background restrictions

Use Android's official foreground-service mechanism and the appropriate location permissions/configuration.

A persistent foreground-service notification should be displayed while an active drive is being recorded.

--------------------------------------------------
LOCATION TRACKING ARCHITECTURE
--------------------------------------------------

Do NOT connect GPS tracking directly to the Map widget.

Use a structure similar to:

Drive UI
    ↓
Drive Provider
    ↓
Drive Controller
    ↓
Location Service
    ↓
Android Foreground Location Service
    ↓
GPS

The UI may disappear while tracking continues.

The location service must remain independent of the Map screen.

--------------------------------------------------
PERSISTENCE
--------------------------------------------------

GPS points must be persisted incrementally while a drive is active.

Do not rely on:
- Widget state
- Riverpod state alone
- In-memory lists alone

If the application process is interrupted, previously recorded points should not simply disappear.

Use the project's existing storage architecture where appropriate.

Do NOT implement the complete final trip database/schema yet unless required for reliable active-drive persistence.

--------------------------------------------------
ACTIVE DRIVE UI
--------------------------------------------------

When a drive is active:

- Replace START with FINISH.
- Keep the map visible when TripRank is in the foreground.
- Continue showing minimal driving information:
  - Current speed
  - Altitude
  - Distance
- Show the user's current location.
- Show the path recorded so far.

Do NOT introduce a large bottom sheet.

The map remains the primary visual element.

--------------------------------------------------
RECKLESS MODE
--------------------------------------------------

When START is pressed without a destination:

- Start the foreground location service.
- Set DriveMode = reckless.
- Begin recording GPS points.
- Remain inside TripRank.
- Do not launch Google Maps.
- Continue until the user presses FINISH.

--------------------------------------------------
DESTINATION MODE
--------------------------------------------------

When START is pressed:

1. Verify a valid destination exists.
2. Verify Google Maps is installed.
3. If Google Maps is unavailable, do not start.
4. Start the active drive.
5. Start the foreground location service.
6. Set DriveMode = destination.
7. Launch Google Maps with the destination coordinates.
8. Continue recording while Google Maps is in the foreground.
9. Do not automatically finish when TripRank returns to foreground.
10. Wait for explicit FINISH.

--------------------------------------------------
RETURNING TO TRIPRANK
--------------------------------------------------

When the user returns from Google Maps:

- The active drive remains active.
- Location tracking remains active.
- The recorded path remains available.
- The map updates to the current location.
- The user can continue driving.
- Do NOT automatically finish the trip.

Only FINISH should end the active drive, except for unavoidable OS-level termination.

--------------------------------------------------
FINISH
--------------------------------------------------

When the user presses FINISH:

1. Stop location recording.
2. Stop the foreground location service.
3. Finalize the active drive state.
4. Preserve the collected GPS data.
5. Transition the drive to completed.
6. Prepare the data for the future Trip Details/database implementation.

Do NOT implement the complete Trip Details screen yet.

--------------------------------------------------
ERROR HANDLING
--------------------------------------------------

Handle:

- Location permission denied
- Location services disabled
- Google Maps not installed
- Invalid destination
- Failure to start location service
- Failure to launch Google Maps
- Location stream errors

Do not crash the application.

If Google Maps cannot be launched after tracking has started, handle the failure safely and keep the user informed.

--------------------------------------------------
OFFLINE REQUIREMENT
--------------------------------------------------

GPS recording must NOT require internet access.

An active drive must be able to continue recording GPS data when:

- Mobile data is unavailable
- Wi-Fi is unavailable
- Google Maps is unavailable for network reasons after navigation has started

Do not make the TripRank tracking system dependent on an internet connection.

--------------------------------------------------
DO NOT IMPLEMENT
--------------------------------------------------

Do NOT implement:

- Turn-by-turn navigation
- Voice navigation
- Traffic
- Rerouting
- Google Maps SDK
- google_maps_flutter
- Other navigation apps
- App chooser
- Alternative navigation fallback
- Crash detection
- Hard braking detection
- Advanced analytics
- Final Trip Details UI
- Full trip database
- Offline map tiles
- Offline route calculation

--------------------------------------------------
DEPENDENCIES
--------------------------------------------------

Use the existing project dependencies where possible.

Current relevant dependencies include:

- flutter_map
- geolocator
- latlong2
- flutter_riverpod
- http

Do not add packages unless they are genuinely required.

If a package is required for reliable Android foreground location tracking, explain why it is needed before adding it.

--------------------------------------------------
ARCHITECTURE
--------------------------------------------------

Keep responsibilities separated:

Map UI
    ↓
Drive Provider
    ↓
Drive Controller
    ├── Location Service
    │       ↓
    │   Foreground Location Service
    │
    └── Google Maps Launcher
            ↓
       Google Maps

Do not put:
- GPS logic
- foreground-service logic
- Google Maps intent logic
- drive-state logic

directly inside UI widgets.

Follow:

- docs/ARCHITECTURE.md
- docs/UI_GUIDELINES.md
- docs/AI_RULES.md

Before modifying existing architecture, inspect the current implementation and reuse existing abstractions where appropriate.

After implementation:
- Run flutter analyze.
- Run relevant tests.
- Run the application.
- Report exactly what was implemented.
- Report any limitations or Android configuration that still needs physical-device testing.

### When Done
- there should be no errors.
- app run successfully.