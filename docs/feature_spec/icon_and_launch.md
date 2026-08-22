# Phase 8.1 — Milage App Icon & Launch Screen

Implement the final Milage application branding.

## GOAL

Replace the default Flutter branding with the Milage branding in two places:

1. Android launcher/application icon
2. Android launch/splash screen

The existing Milage icon asset is already stored in the project.

Before making changes, inspect the project and locate the existing Milage icon asset.

Do NOT create a new icon.

Do NOT modify the icon artwork.

---

# 1. ANDROID APPLICATION / LAUNCHER ICON

Configure the existing Milage icon as the Android application launcher icon.

The installed application should display the Milage icon instead of the default Flutter icon.

Requirements:

* Use the existing Milage icon.
* Generate the required Android icon resources from that asset if necessary.
* Support Android launcher requirements appropriately.
* Preserve the icon's aspect ratio.
* Do not stretch or distort the icon.
* Ensure the icon looks correct on Android launchers.
* Ensure the app label is `Milage`.

IMPORTANT:

The launcher icon configuration must not affect the icon displayed inside the About Milage page.

The About page should continue using its existing asset.

---

# 2. ANDROID LAUNCH / SPLASH SCREEN

Replace the default Flutter launch screen/logo with Milage branding.

The initial Android launch screen should show:

* Milage icon centered
* Appropriate simple background matching the Milage app branding
* No Flutter logo
* No Flutter text
* No unnecessary animation
* No additional UI

The launch screen should appear while Flutter is initializing.

IMPORTANT:

Use the platform/native Android launch-screen mechanism rather than creating a normal Flutter widget that attempts to imitate the launch screen.

The user must see the Milage branding BEFORE the Flutter UI is ready.

---

# 3. DARK-FIRST BRANDING

Milage's default appearance is dark.

Use a dark background for the launch screen unless the existing Android configuration requires another approach.

The Milage icon must remain clearly visible against the background.

Do not redesign the icon.

Do not introduce unnecessary colors or visual effects.

---

# 4. EXISTING APPLICATION

Do not change unrelated application functionality.

Do NOT modify:

* GPS tracking
* Foreground location service
* Trip persistence
* Analytics
* Trip Stats
* Overall Analytics
* Profile
* Settings
* Units
* Map appearance
* Database schema
* Database migrations
* Routing
* Navigation
* Google Maps behavior

This phase is strictly branding/startup integration.

---

# 5. ABOUT PAGE

The existing About Milage page already displays:

* Milage icon
* Milage
* Personal Driving Tracker
* Version
* Description

Do not replace or duplicate this implementation.

Only verify that the same source asset is being used appropriately.

---

# 6. APP NAME

The Android application label must be:

Milage

Check the Android manifest/resources and make sure the launcher displays:

Milage

Do not display:

TripRank
TripRank Project
Flutter

---

# 7. ASSET HANDLING

Locate the existing icon asset first.

If the icon is currently:

`assets/images/mileage_icon.png`

verify it before using it.

Do not assume the path if the project structure differs.

If Android requires different resource sizes/densities, generate the required resources from the existing source asset.

Do not manually create different artwork for each density.

---

# 8. FLUTTER DEFAULT BRANDING

After implementation, verify that the default Flutter logo is no longer shown during:

* Application launch
* Android launcher
* Any native startup screen

Search the Android project for remaining default Flutter launch branding if necessary.

Do not remove or modify unrelated Flutter framework resources.

---

# 9. TESTING

Verify:

1. `flutter pub get` succeeds.
2. `flutter analyze` has no issues.
3. `flutter test` passes.
4. Android debug build succeeds.
5. Application installs successfully.
6. Launcher displays the Milage icon.
7. Application label is Milage.
8. Launch screen displays the Milage icon.
9. Flutter logo is not visible during startup.
10. About page still displays the Milage icon.
11. Existing app functionality is unaffected.

IMPORTANT:

Automated tests cannot fully verify the visual Android launch screen.

Therefore explicitly mark physical-device verification as required.

---

# 10. PHYSICAL DEVICE TEST

Install the new APK on the physical Android phone.

Verify:

### Launcher

* Milage icon appears correctly.
* Icon is not cropped unexpectedly.
* Icon is not stretched.
* App name is Milage.

### Startup

* Launch Milage from the launcher.
* Confirm the first visible branding is Milage.
* Confirm there is no Flutter logo.
* Confirm the icon is centered correctly.
* Confirm there is no visible white/incorrect default Flutter splash.

### Existing data

Installing the new APK over the existing Milage installation must not delete existing local data.

Do NOT uninstall the application for this test unless absolutely necessary.

---

# 11. DOCUMENTATION

Update:

`docs/PROGRESS_TRACKER.md`

Add Phase 8.1 documenting:

* Launcher icon implementation
* Launch/splash screen implementation
* Source icon asset
* Android configuration
* App label
* Tests
* Physical-device verification status

Clearly distinguish:

`Automated verification`

from:

`Physical-device verification`

---

# FINAL REPORT

After implementation provide:

* Icon source asset path
* Android launcher resources/configuration
* Launch screen implementation
* Android app label
* Files created
* Files modified
* Dependencies added, if any
* `flutter analyze` result
* `flutter test` result
* APK build result
* Physical-device verification status
* Any remaining issues

Do not claim physical-device verification succeeded unless it was actually performed.

---

# SCOPE CONTROL

This is Phase 8.1 only.

Do NOT implement other Phase 8 work yet.

Do NOT perform broad UI redesigns.

Do NOT change GPS behavior.

Do NOT change analytics.

Do NOT change database behavior.

Do NOT change settings.

Only implement:

* Milage launcher icon
* Milage Android launch/splash branding
* App label verification
