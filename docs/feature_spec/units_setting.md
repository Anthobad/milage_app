Implement Phase 7.4 — Units Settings for TripRank.

GOAL

Implement the dedicated Units settings page opened from:

Profile → Units

The Units setting controls how TripRank displays distance, speed, and altitude.

IMPORTANT:
The unit preference is DISPLAY-ONLY.

Do NOT change how GPS data, trips, analytics, or database values are stored.

INTERNAL CANONICAL UNITS

TripRank must continue storing and calculating using:

- Distance: kilometers (km)
- Speed: kilometers per hour (km/h)
- Altitude: meters (m)
- Duration: seconds internally

The Units setting only converts these values when displaying them to the user.

UNIT OPTIONS

Provide two unit systems:

1. Metric
2. Imperial

PAGE DESIGN

UNITS

Unit System

┌─────────────────────────────┐
│ 🌍 Metric               ✓   │
│ 🇺🇸 Imperial                 │
└─────────────────────────────┘

DEFAULT

If no preference exists:

Metric

The default must preserve the current TripRank behavior.

DISPLAY RULES

METRIC:

Distance:
- kilometers (km)

Speed:
- kilometers per hour (km/h)

Altitude:
- meters (m)

IMPERIAL:

Distance:
- miles (mi)

Speed:
- miles per hour (mph)

Altitude:
- feet (ft)

CONVERSION

Use the standard conversions:

1 km = 0.621371 mi

1 km/h = 0.621371 mph

1 m = 3.28084 ft

Do not round values internally.

Convert first, then format for display.

CENTRALIZED UNIT SYSTEM

Create/reuse a single authoritative unit preference provider.

Do NOT implement conversions independently inside individual widgets.

Create appropriate formatting/conversion utilities/services if they do not already exist.

For example, the architecture should allow code such as:

formatDistance(distanceKm)
formatSpeed(speedKmh)
formatAltitude(altitudeM)

to automatically use the currently selected unit system.

The exact API/naming can follow the project's existing architecture.

IMPORTANT:
Widgets should not contain raw conversion formulas.

They should ask the unit service/provider for the correctly formatted value.

AREAS THAT MUST RESPECT THE UNIT SETTING

Update existing user-facing displays where appropriate, including:

- Trip cards
- Trip Stats screen
- Profile driving summary
- Overall Analytics screen
- Speed statistics
- Altitude statistics
- Speed graph labels/tooltips
- Altitude graph labels/tooltips
- Distance displays
- Map/drive information bars where TripRank controls the displayed value
- Driving analytics cards
- Driving event/stat displays where a distance/speed/altitude value is shown

Do NOT change:

- Google Maps' own UI/labels
- Raw GPS data
- SQLite values
- Trip model internal values
- Analytics calculations
- GPS tracking calculations

GRAPHS

Graphs must respect the selected unit system in their DISPLAYED values and labels.

For example:

Metric:
    Speed graph → km/h

Imperial:
    Speed graph → mph

Metric:
    Altitude graph → m

Imperial:
    Altitude graph → ft

The underlying graph data should remain in the canonical internal units.

Graph calculations must not be performed using converted values unless required only for display.

TRIP DATA

Existing trips must immediately display using the selected unit system.

Changing:

Metric → Imperial

must update old trips as well as new trips.

Do NOT migrate or rewrite existing database records.

PROFILE DRIVING SUMMARY

The Profile driving summary must also respect Units.

Example:

Metric:
    320 km

Imperial:
    198.8 mi

The underlying total distance remains stored in kilometers.

DURATION

Do NOT create Metric/Imperial duration units.

Duration remains time-based:

- seconds internally
- formatted as seconds/minutes/hours as already appropriate

Do not change duration behavior unnecessarily.

PERSISTENCE

Use SharedPreferences.

Use a dedicated key, for example:

"unit_system"

Possible stored values:

"metric"
"imperial"

Default:

"metric"

The preference must survive:

- widget rebuilds
- navigation
- app restart
- phone restart

Do NOT store this preference in SQLite.

NAVIGATION

Profile:
    Units
        ↓
UnitsScreen

The Units page should have a normal back button.

Do NOT create another settings hub.

Do NOT modify the bottom navigation.

UI REQUIREMENTS

- Follow the existing TripRank UI.
- Dark-first design.
- Existing blue accent.
- Existing Inter typography.
- Rounded card/selection style matching Appearance and Map Appearance.
- Active option has a blue checkmark.
- Only one option can be selected.
- No overflow on narrow screens.
- Selection applies immediately.
- Keep the page simple.

RIVERPOD / ARCHITECTURE

- Follow the same architecture established by Phase 7.2 and 7.3.
- Use Riverpod for state.
- Use AsyncNotifier if appropriate for SharedPreferences persistence, consistent with the
  existing theme providers.
- Do not create duplicate sources of truth.
- Reuse existing providers/services if an appropriate unit system already exists.
- Do not access SharedPreferences directly from UI widgets.

IMPORTANT BACKWARD COMPATIBILITY

Existing trips must continue working exactly as before.

Changing Units must NOT:

- modify trip records
- modify GPS track points
- modify analytics results
- change calculations
- change sorting
- change filtering
- change route polylines
- change map positioning

Only presentation changes.

TESTING

Add/update tests covering at minimum:

1. Units page renders.
2. Metric and Imperial options are visible.
3. Metric is selected by default.
4. Selecting Metric updates the unit provider.
5. Selecting Imperial updates the unit provider.
6. Active option shows a checkmark.
7. Only one option is selected.
8. Preference persists after provider/state recreation.
9. Preference is restored after app startup.
10. Profile → Units navigation works.
11. Back navigation returns to Profile.
12. Distance formatting uses km in Metric.
13. Distance formatting uses mi in Imperial.
14. Speed formatting uses km/h in Metric.
15. Speed formatting uses mph in Imperial.
16. Altitude formatting uses m in Metric.
17. Altitude formatting uses ft in Imperial.
18. Existing trip data is displayed using the current unit preference.
19. Existing database values are unchanged when switching units.
20. Analytics calculations remain based on canonical units.
21. Speed graph displays the correct unit.
22. Altitude graph displays the correct unit.
23. Profile driving summary respects the unit setting.
24. No NaN/Infinity is introduced by conversion/formatting.
25. Existing tests continue passing.

CONVERSION TESTS

Include deterministic conversion tests for representative values.

Examples:

100 km → 62.1371 mi

100 km/h → 62.1371 mph

100 m → 328.084 ft

Also test zero and reasonable decimal values.

ROUNDING / FORMATTING

Do not hard-code excessive decimal places throughout the UI.

Use centralized formatting rules.

Choose formatting that is readable on a phone.

Examples:

Metric:
    12.4 km
    84 km/h
    412 m

Imperial:
    7.7 mi
    52.2 mph
    1352 ft

Use the project's existing formatting conventions where possible.

Do not alter the underlying precision.

DOCUMENTATION

Update:

docs/PROGRESS_TRACKER.md

Document:

- Phase 7.4 completion
- Supported unit systems
- Canonical internal units
- Display conversion rules
- Persistence mechanism
- Provider/service architecture
- Screens updated
- Tests
- Verification results
- Any deferred work

VERIFICATION

Run:

flutter pub get
flutter analyze
flutter test

Phase 7.4 is complete only when:

- flutter analyze has no issues
- all tests pass
- no regressions are introduced

FINAL REPORT

Provide:

- Files created
- Files modified
- Unit provider architecture
- Conversion/formatting architecture
- Persistence mechanism
- Default behavior
- Screens updated
- Tests passed
- flutter analyze result
- Any limitations/deferred work

SCOPE CONTROL

Do NOT implement:

- Permissions
- Voice settings
- Export Data
- Profile name
- Cloud/account functionality
- Map Appearance changes
- GPS tracking changes
- Database migrations
- Any unrelated UI redesign

Those belong to other phases.