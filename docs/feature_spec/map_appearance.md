Read AGENTS.md.
Implement Phase 7.3 — Map Appearance Settings for TripRank.

GOAL
Implement the dedicated Map Appearance settings page opened from:

Profile → Map Appearance

The setting controls ONLY the appearance/theme of the Google Maps map.
It must have NO effect on the TripRank application UI theme.

PAGE DESIGN

MAP APPEARANCE

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

IMPORTANT THEME SEPARATION

There are two completely independent theme settings:

1. App Appearance
   - Controls TripRank UI
   - Implemented in Phase 7.2
   - Existing themeProvider
   - Existing "theme_mode" preference

2. Map Appearance
   - Controls Google Maps only
   - Must have its own state/provider and persistence
   - Must NOT modify themeProvider
   - Must NOT modify ThemeMode
   - Must NOT change the rest of the TripRank UI

Do NOT reuse the app ThemeMode preference for map appearance.

DEFAULT

If no map-theme preference exists:
- Default to Dark.

BEHAVIOR

Dark:
- Google Maps should use the existing/appropriate dark map styling.

Light:
- Google Maps should use the normal/appropriate light map styling.

System:
- Google Maps should follow the Android system's light/dark mode.

The map appearance must update appropriately when the setting changes.

IMPORTANT:
- Do not recreate or reload the entire application unnecessarily.
- If the map is currently visible, update its styling when practical.
- If the map is not currently mounted, the new preference must be applied when the map is next created.

MAP IMPLEMENTATION

Inspect the existing Google Maps implementation before making changes.

Reuse the existing map architecture and map controller.

If the project already has:
- MapState
- mapTheme
- MapProvider
- map styling utilities
- Google Maps configuration

reuse them instead of creating duplicate systems.

There must be ONE authoritative source for the selected map appearance.

The existing map theme state should be refactored/extended if necessary rather than creating
multiple competing sources of truth.

MAP STYLE

Use proper Google Maps styling for Dark and Light modes.

Do not use the TripRank UI theme colors to style the map.

The map should continue to use Google's normal geographic/map rendering, with only the map
appearance changing.

Do NOT introduce a custom map visual design unrelated to Google Maps.

SYSTEM MODE

When System is selected:
- Determine whether the Android system is currently light or dark.
- Apply the corresponding Google Maps style.
- The TripRank app ThemeMode remains completely independent.

If the system theme changes while the app is running, handle the change consistently with
the existing app lifecycle/theme architecture.

PERSISTENCE

Persist the selected map appearance locally.

Use SharedPreferences because this is a simple app preference.

Use a dedicated key, for example:

"map_theme_mode"

Do NOT reuse:

"theme_mode"

The preference must survive:
- widget rebuilds
- navigation away from the page
- app restart
- phone restart

NAVIGATION

Profile:
    Map Appearance
        ↓
Map Appearance Screen

The page should have a normal back button.

Do NOT create a generic Settings hub.

Do NOT modify the bottom navigation.

UI REQUIREMENTS

- Follow the existing TripRank visual language.
- Dark mode remains the default.
- Use the same rounded-card style as Appearance settings.
- Active selection should show a clear blue checkmark.
- Only one option can be selected.
- Must work correctly on narrow Android screens.
- No overflow or clipping.
- Keep the page simple.

TESTING

Add/update tests covering at minimum:

1. Map Appearance page renders.
2. Dark, Light, and System options are visible.
3. Dark is the default when no preference exists.
4. Selecting Dark updates map theme state.
5. Selecting Light updates map theme state.
6. Selecting System updates map theme state.
7. Selected option displays a checkmark.
8. Only one option is selected.
9. Map preference persists after provider/state recreation.
10. Persisted map preference is restored on app startup.
11. Profile → Map Appearance navigation works.
12. Back navigation returns to Profile.
13. Changing Map Appearance does NOT change app ThemeMode.
14. Changing App Appearance does NOT change Map Appearance.
15. Map receives the correct style for Dark.
16. Map receives the correct style for Light.
17. System mode resolves correctly to the current system brightness.
18. Existing map functionality continues working.
19. Existing tests continue passing.

ARCHITECTURE

- Keep UI, state, persistence, and map styling separated.
- Reuse Riverpod.
- Do not access SharedPreferences directly from widgets if an existing provider/service
  architecture can handle it.
- Avoid duplicate sources of truth.
- Avoid unnecessary packages.
- Do not modify unrelated features.

OFFLINE REQUIREMENT

Map Appearance selection itself must work completely offline.

The selected map style is local configuration and must not require a network request.

Do not add any online style-loading dependency.

DOCUMENTATION

Update:

docs/PROGRESS_TRACKER.md

Document:
- Phase 7.3 completion
- Map appearance options
- Default behavior
- Persistence key/mechanism
- Separation from App Appearance
- Map styling implementation
- Files created/modified
- Tests
- Verification results
- Any limitations

VERIFICATION

Run:

flutter pub get
flutter analyze
flutter test

Phase 7.3 is complete only when:
- flutter analyze has no issues
- all tests pass
- no regressions are introduced

FINAL REPORT

Provide:
- Files created
- Files modified
- Map theme architecture
- Persistence mechanism
- Default behavior
- App/map theme separation
- Navigation changes
- Test count/results
- flutter analyze result
- Any deferred work

SCOPE CONTROL

Do NOT implement:
- Units
- Permissions
- Voice settings
- Export Data
- Profile name
- Cloud/account functionality
- Any unrelated UI redesign

Those belong to later Phase 7 tasks.