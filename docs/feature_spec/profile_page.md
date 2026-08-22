Implement Phase 7.1 — Profile Page for TripRank.

GOAL
Build the final Profile page according to the following locked design.

IMPORTANT PRODUCT DECISIONS
- The bottom navigation already contains Profile.
- Do NOT add a Settings item to the bottom navigation.
- Settings is accessed from the Profile page through the gear icon.
- Do NOT add a My Cars section.
- Do NOT add a user-name system.
- Do NOT ask the user for a name during first launch.
- Do NOT add a Voice setting. TripRank redirects navigation to Google Maps, so voice navigation is handled there.
- Do NOT add Export Data.
- The profile image is completely optional.
- By default, show a generic profile icon.
- The user may optionally choose a local profile image later.
- Do not show any first-launch prompt asking for a profile image.

FINAL PROFILE STRUCTURE

PROFILE
┌─────────────────────────────────────┐
│  PROFILE                         ⚙️ │
│                                     │
│       [ generic icon / photo ]      │
│              Driver                 │
└─────────────────────────────────────┘

DRIVING

┌─────────────────────────────────────┐
│  Overall Driving                    │
│                                     │
│  Trips       Distance       Time    │
│   ...          ...          ...     │
└─────────────────────────────────────┘

SETTINGS

┌─────────────────────────────────────┐
│  Appearance                     >  │
│  Map Appearance                  >  │
│  Units                           >  │
│  Permissions                     >  │
└─────────────────────────────────────┘

ABOUT

┌─────────────────────────────────────┐
│  About TripRank                  >  │
└─────────────────────────────────────┘

PROFILE HEADER
- Show a generic person/profile icon when no image has been selected.
- Show the user's selected local profile image if one exists.
- Display the static label "Driver".
- No stored user name.
- Add a gear IconButton in the top-right.
- Pressing the gear navigates to the Settings page.
- Do not implement detailed settings behavior in this phase unless minimal navigation wiring is required.

PROFILE IMAGE
- The image is optional.
- Do not request it on first launch.
- Do not add onboarding.
- If there is already an appropriate local image/profile architecture, reuse it.
- Otherwise create the smallest clean abstraction needed for a future profile-image implementation.
- Do not introduce cloud storage, accounts, authentication, or network dependencies.
- If implementing image selection in this phase requires a new package, only add it if genuinely necessary and document why.
- Prefer keeping this phase focused on the Profile page UI.

DRIVING SECTION
This is an OVERALL driving summary.

IMPORTANT:
- It must include trips from ALL vehicles.
- It must NOT depend on the currently selected vehicle.
- Do not reuse the selected-vehicle filtering used by the vehicle-specific Analytics page.
- Use the existing overall analytics architecture from Phase 6.6 where appropriate.
- The summary should show:
  - Total trips
  - Total distance
  - Total driving time
- Use real persisted data when available.
- Do not fabricate values.
- If there are no trips, show an appropriate empty state / zero summary consistent with the existing app.
- Tapping the Driving summary should navigate to the existing full Analytics page if that route already exists.
- Do not create a second analytics dashboard.

SETTINGS SECTION
Display these four entries only:
1. Appearance
2. Map Appearance
3. Units
4. Permissions

Each row should be visually consistent with the existing TripRank UI and have a trailing navigation indicator.

Do NOT include:
- Voice
- Export Data
- Cars
- Account
- Name
- Cloud backup

The individual settings pages/behavior will be implemented in later Phase 7 tasks. For this phase, add only the required navigation targets/placeholders if they do not already exist.

ABOUT SECTION
- Add "About TripRank".
- Tapping it should navigate to an About page if an appropriate route exists; otherwise create the minimal placeholder route required for future implementation.
- Do not add unnecessary content yet.

UI REQUIREMENTS
- Follow the existing TripRank design language.
- Dark mode remains the primary/default experience.
- Respect the existing blue accent color.
- Use the existing typography/theme/components instead of introducing a new visual system.
- Use rounded cards/containers consistent with the rest of the app.
- Keep spacing clean and compact.
- The page must be vertically scrollable on small phones.
- Ensure no clipping or overflow on narrow screens.
- Keep the profile page visually simple; it is a hub, not a dashboard containing every statistic.

ARCHITECTURE
- Reuse existing Riverpod providers and repository/services.
- Do not put database queries directly inside widgets.
- Do not calculate analytics inside widgets.
- Keep business/data logic in providers/services.
- Reuse Phase 6.6 overall analytics rather than creating another aggregation implementation.
- Do not modify the existing trip analytics architecture unless required for correct integration.

SETTINGS NAVIGATION
The Profile page is the entry point to Settings.

The gear icon should open the Settings page.

The Settings page itself should contain:
- Appearance
- Map Appearance
- Units
- Permissions

If a Settings route/page does not exist yet, create a clean minimal Settings page that can be expanded in later Phase 7 tasks.

TESTING
Add/update widget tests for:
1. Profile page renders.
2. Gear icon is present.
3. Driver label is present.
4. Generic profile icon appears when no image exists.
5. No My Cars section exists.
6. Driving summary exists.
7. Driving summary is based on overall/all-vehicle analytics rather than selected vehicle.
8. Settings section contains Appearance, Map Appearance, Units, Permissions.
9. Voice is NOT present.
10. Export Data is NOT present.
11. About TripRank is present.
12. Gear navigates to Settings.
13. Driving summary navigates to the existing Analytics page where applicable.
14. Narrow screen does not overflow.

VERIFICATION
Run:
- flutter pub get
- flutter analyze
- flutter test

Do not consider the phase complete if there are analyzer errors or test failures.

DOCUMENTATION
Update docs/PROGRESS_TRACKER.md with:
- Phase 7.1 status
- Files created/modified
- Profile structure
- Important product decisions
- Tests performed
- Verification results
- Any limitations or deferred work

SCOPE CONTROL
Do NOT implement the complete Appearance, Map Appearance, Units, or Permissions functionality yet.
Do NOT implement profile-name collection.
Do NOT implement cloud/account functionality.
Do NOT implement Export Data.
Do NOT redesign the bottom navigation.
Do NOT modify unrelated features.

At the end, provide a concise implementation report containing:
- Files created
- Files modified
- Navigation changes
- Data source used for Driving summary
- Profile image handling
- Tests passed
- flutter analyze result
- Any deferred work