# Phase 7.5 — About Milage

Implement the final About page for the Profile section.

## GOAL

Create a clean, simple About page accessible from:

Profile → About Milage

The application name is:

**Milage**

IMPORTANT:

The Milage app icon has already been stored in the project and should be displayed on this About page.

However:

**DO NOT configure or replace the actual Android application/launcher icon in this phase.**

App icon integration belongs to **Phase 8 — Testing & Polish**.

---

# ABOUT PAGE

The page should follow the existing TripRank/Milage UI style:

* Dark-first design
* Existing blue accent
* Existing Inter typography
* Rounded cards
* Clean spacing
* No unnecessary functionality
* Fully scrollable on narrow screens
* Normal back button

Suggested layout:

```text
ABOUT MILAGE

          [Milage Icon]

             Milage
       Personal Driving Tracker

──────────────────────────────

Version
1.0.0

──────────────────────────────

ABOUT

Milage is a personal driving tracker
that records trips and provides driving
statistics and analytics.

──────────────────────────────

Built for personal use.
```

Use the actual stored icon asset in place of `[Milage Icon]`.

---

# APP ICON

Use the existing stored icon asset for the About page.

First inspect the existing project/assets to determine the correct path.

Do NOT:

* create a new icon
* modify the icon
* generate an icon
* configure Android launcher icons
* change adaptive icons
* change splash-screen icons
* modify Android manifest icon configuration

Those tasks are deferred to Phase 8.

If the icon asset is not located where expected, do not invent a replacement. Report the missing asset/path instead.

---

# APP NAME

Display:

**Milage**

Do not display:

* TripRank
* Driver
* TripRank Project
* TripRank Project App

The user-facing application name for this page is Milage.

Do not rename the internal project/folder/package unless required by a separate phase.

---

# DESCRIPTION

Display this short description:

"Milage is a personal driving tracker that records trips and provides driving statistics and analytics."

Keep it concise.

Do not add:

* marketing text
* account information
* cloud information
* developer biography
* social links
* unnecessary feature lists

---

# VERSION

Display the actual installed application version dynamically.

Do NOT hardcode:

`1.0.0`

Use the project's existing dependency if one already provides application package information.

If no suitable dependency exists, use the current `package_info_plus` package rather than manually reading platform-specific files. The package provides application name, version, and build number information.

Only display the user-facing version.

Preferred format:

```text
Version
1.0.0
```

Do not display the build number unless the existing project design clearly benefits from it.

If package information is temporarily unavailable, display a graceful fallback rather than crashing.

---

# NAVIGATION

The existing Profile → About Milage route should open this page.

Use the existing router architecture.

Do not create a second Profile/settings hub.

The flow should remain:

```text
Profile
   ↓
About Milage
   ↓
Back
   ↓
Profile
```

Do not modify the bottom navigation.

---

# UI DETAILS

## Header

Use a standard page header with:

* Back button
* Title: `About Milage`

## Icon

Place the stored Milage icon prominently near the top.

Use a reasonable fixed display size.

The icon should:

* maintain its aspect ratio
* not be stretched
* have appropriate spacing
* work correctly in both light and dark app themes

Do not use it as the launcher icon yet.

## App name

Below the icon:

**Milage**

Use a visually prominent text style consistent with the existing app.

Below that:

**Personal Driving Tracker**

Use a smaller secondary text style.

## Version card

Create a simple rounded section containing:

```text
Version
1.0.0
```

The version should be dynamically loaded.

## About card

Create a rounded section containing the description.

## Footer

At the bottom:

**Built for personal use.**

Keep it subtle.

---

# NO EXTRA FEATURES

Do NOT implement:

* Developer information
* User name
* Profile information
* Accounts
* Cloud sync
* Export data
* Privacy policy
* Terms of service
* Permissions
* Voice settings
* Contact/support
* Website links
* Social media
* Update checking
* App store links
* Analytics/telemetry

These are outside the scope of this phase.

---

# ARCHITECTURE

Follow the existing project architecture.

Reuse the existing:

* theme system
* typography
* spacing
* card components
* routing architecture

Do not duplicate existing theme/settings logic.

Keep package metadata loading separate from the UI where appropriate.

The About screen should not directly contain unnecessary business logic.

---

# TESTING

Add tests covering at minimum:

1. About page renders.
2. Page title displays "About Milage".
3. "Milage" app name is displayed.
4. "Personal Driving Tracker" is displayed.
5. Description is displayed.
6. "Built for personal use." is displayed.
7. Stored Milage icon is displayed.
8. Version information loads successfully.
9. Version is not hardcoded in the UI.
10. Version-loading failure does not crash the page.
11. Back button works.
12. Profile → About navigation works.
13. About → Profile navigation works.
14. Page works in dark theme.
15. Page works in light theme.
16. Page does not overflow on narrow screens.
17. Existing tests continue passing.

If a test needs package information, use the package's test-friendly mechanisms rather than depending on a real device installation.

---

# APP ICON SCOPE REMINDER

This is extremely important:

The icon is only being used as an image **inside the About page** in Phase 7.5.

Do NOT perform launcher/app-icon configuration.

Phase 8 will handle:

* Android launcher icon
* adaptive icon
* final icon sizing
* icon background
* splash/app branding if needed
* final visual polish

---

# DOCUMENTATION

Update:

`docs/PROGRESS_TRACKER.md`

Document:

* Phase 7.5 completion
* About Milage page
* Icon asset used for About page
* Dynamic version handling
* Navigation
* Tests
* Verification results
* Explicitly note that launcher/app icon integration is deferred to Phase 8

---

# VERIFICATION

Run:

```text
flutter pub get
flutter analyze
flutter test
```

Phase 7.5 is complete only when:

* `flutter analyze` has no issues
* all tests pass
* no existing functionality regresses
* About Milage navigation works
* icon displays correctly
* version displays correctly
* no launcher icon changes were introduced

---

# FINAL REPORT

Provide:

* Files created
* Files modified
* About page structure
* Icon asset path used
* Version implementation
* Navigation changes
* Tests passed
* `flutter analyze` result
* Any limitations/deferred work

Clearly state:

**Launcher/app icon integration remains deferred to Phase 8.**

---

# SCOPE CONTROL

Do NOT implement anything from Phase 8.

Do NOT redesign the Profile page.

Do NOT modify Appearance settings.

Do NOT modify Map Appearance settings.

Do NOT modify Units.

Do NOT add Permissions.

Do NOT add Export Data.

Do NOT add user names/accounts.

Only implement the About Milage page.

