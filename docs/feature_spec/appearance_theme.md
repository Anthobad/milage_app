Implement Phase 7.2 — Appearance Settings for TripRank.

GOAL
Implement the dedicated Appearance settings page that is opened when the user taps
"Appearance" from the Profile page.

IMPORTANT EXISTING ARCHITECTURE
- Profile is the main hub for settings.
- Each setting opens its own dedicated page.
- Do NOT create a generic Settings hub page.
- Do NOT add a gear icon to Profile.
- Do NOT modify the bottom navigation.
- The Profile → Appearance navigation already exists or should be wired to the
  dedicated Appearance page.

APPEARANCE PAGE

The page should contain:

APPEARANCE

Theme

┌─────────────────────────────┐
│ 🌙 Dark                 ✓   │
│ ☀️ Light                    │
│ ⚙️ System                   │
└─────────────────────────────┘

OPTIONS
1. Dark
2. Light
3. System

BEHAVIOR

- Dark is the default TripRank app theme.
- Selecting Dark immediately switches the entire TripRank UI to dark mode.
- Selecting Light immediately switches the entire TripRank UI to light mode.
- Selecting System follows the Android system's current light/dark setting.
- The selected option must visibly show a checkmark.
- Only one option can be selected at a time.
- Changing the setting should apply immediately without requiring an app restart.

PERSISTENCE

Persist the selected appearance preference locally.

The preference must survive:
- Widget rebuilds
- Navigation away from Appearance
- Closing the app
- Reopening the app
- Phone restart

Use an appropriate lightweight local preference mechanism.
Do NOT store this in the trip/vehicle SQLite tables because this is an app preference,
not structured trip data.

DEFAULT

If no saved preference exists:
- Use Dark.

THEME ARCHITECTURE

Use the existing Flutter theme architecture.

Do NOT create a second independent theme system.

The app should have a single authoritative source for the selected app theme.

If the project already has ThemeMode/theme providers/settings architecture:
- Reuse and extend it rather than creating duplicate providers.

The setting must control the existing MaterialApp/MaterialApp.router theme.

Preserve the existing TripRank visual identity:
- Existing blue accent color
- Existing Inter typography
- Existing component styling
- Existing dark theme styling

Do not redesign the application's colors or typography as part of this phase.

IMPORTANT MAP RULE

The Appearance setting controls ONLY the TripRank application UI.

It must NOT change the Google Maps/map theme.

Map Appearance will be implemented separately in Phase 7.3.

Do not couple the app ThemeMode to the map theme.

UI REQUIREMENTS

- Follow the existing TripRank design language.
- Dark mode should remain the primary/default experience.
- Use rounded containers/cards consistent with existing TripRank UI.
- Make the three choices easy to understand and tap.
- The active option must have a clear checkmark/selected state.
- The page must work correctly on narrow Android phone screens.
- No overflow or clipping.
- Keep the page simple; do not add previews or unnecessary controls.

NAVIGATION

Profile:
    Appearance row
        ↓
Appearance Screen

The Appearance screen should have a normal back button so the user can return to Profile.

Do not create another Settings page between Profile and Appearance.

TESTING

Add/update tests covering at minimum:

1. Appearance page renders.
2. Dark, Light, and System options are visible.
3. Dark is selected when no preference has been saved.
4. Selecting Light updates the application ThemeMode.
5. Selecting Dark updates the application ThemeMode.
6. Selecting System updates the application ThemeMode.
7. The selected option displays the correct checkmark.
8. Only one option is selected at a time.
9. The selected preference persists after provider/state recreation.
10. The persisted preference is restored when the app starts.
11. Profile → Appearance navigation works.
12. The Appearance page can be exited and returned to Profile.
13. Changing app appearance does NOT modify the map theme setting.
14. Existing tests continue to pass.

ARCHITECTURE / CODE QUALITY

- Keep UI, state, and persistence responsibilities separated.
- Do not access SharedPreferences/local storage directly from UI widgets if the
  existing architecture supports a provider/service abstraction.
- Use Riverpod consistently with the existing project architecture.
- Avoid duplicate sources of truth.
- Avoid unnecessary dependencies.
- Do not modify unrelated features.

DOCUMENTATION

Update:
docs/PROGRESS_TRACKER.md

Document:
- Phase 7.2 completion
- Appearance settings behavior
- Default theme
- Persistence mechanism
- Theme architecture
- Map-theme separation
- Files created/modified
- Tests performed
- Any deferred work

VERIFICATION

Run:

flutter pub get
flutter analyze
flutter test

The phase is only complete when:
- flutter analyze reports no issues
- all tests pass
- no regressions are introduced

FINAL REPORT

After implementation, provide a concise report containing:

- Files created
- Files modified
- Theme architecture used
- Persistence mechanism
- Default behavior
- Navigation changes
- Test count/results
- flutter analyze result
- Any limitations or deferred work

SCOPE CONTROL

Do NOT implement:
- Map Appearance
- Units
- Permissions
- Voice settings
- Export Data
- Profile name
- Cloud synchronization
- Account/login
- Any unrelated UI changes

Those belong to later Phase 7 tasks.