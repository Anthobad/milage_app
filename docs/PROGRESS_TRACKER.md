# TripRank Development Progress

_Last updated: 2026-08-22 — Phase 6.3 complete_

---

## Phase 0 — Environment Setup

**Status: ✅ Completed**

- [x] Install Flutter
- [x] Install Android Studio
- [x] Configure Android SDK
- [x] Verify Flutter doctor
- [x] Create Flutter project

---

## Phase 1 — Project Foundation

**Status: ✅ Completed**

### Project Structure
- [x] Create feature-first folder structure (`lib/app`, `lib/core`, `lib/features`, `lib/shared`)
- [x] Configure app entry point (`main.dart`)
- [x] Add state management — `flutter_riverpod ^3.4.2`
- [x] Add navigation — `go_router ^17.3.0`
- [x] Add local storage — `shared_preferences ^2.5.5`, `uuid ^4.6.0`

### Documentation
- [x] Create project documentation (`PROJECT_SPEC.md`, `FEATURES.md`, `ARCHITECTURE.md`, `DATABASE.md`, `AI_RULES.md`, `UI_GUIDELINES.md`, `TASKS.md`)
- [x] Maintain docs as source of truth

---

## Phase 2 — App Shell

**Status: ✅ Completed**

### Phase 2.1 — Folder structure
- [x] Feature folders created: `map`, `trips`, `cars`, `analytics`, `profile`
- [x] Shared folders created: `widgets`, `models`, `components`
- [x] Core folders created: `services`, `constants`, `extensions`, `utils`, `errors`

### Phase 2.2 — Dependencies
- [x] `flutter_riverpod`, `go_router`, `shared_preferences`, `uuid` added to `pubspec.yaml`

### Phase 2.3 — App Shell (app.dart, router.dart, theme.dart)

**Status: ✅ Done**  
**Completed: 2026-08-04**

#### What was done

- **`lib/app/theme/colors.dart`** — `AppColors` palette: primary blue, status colors (green/orange/red), dark/light surface and text colors.
- **`lib/app/theme/typography.dart`** — `AppTypography` with Inter font, full Material `TextTheme` hierarchy (display → headline → body → label).
- **`lib/app/theme/spacing.dart`** — `AppSpacing` constants on 4pt grid, border radius values, screen padding constants.
- **`lib/app/theme/app_theme.dart`** — `AppTheme` with `dark` and `light` static `ThemeData` getters. Dark is the default. Configures `ColorScheme`, `NavigationBarTheme`, `CardTheme`, `AppBarTheme`, `FilledButtonTheme`.
- **`lib/app/theme.dart`** — Barrel file exporting all four theme files.
- **`lib/app/router.dart`** — `AppRoutes` constants (`/`, `/map`, `/trips`, `/cars`, `/analytics`, `/profile`). `appRouter` `GoRouter` instance with a placeholder screen at `/` until the Map feature (Phase 4) is implemented.
- **`lib/app/app.dart`** — `TripRankApp` root widget wraps `ProviderScope`. `_AppContent` (`ConsumerWidget`) builds `MaterialApp.router` wired to `AppTheme` and `appRouter`. `ThemeMode.dark` default; will be driven by a provider in Phase 7.
- **`lib/main.dart`** — Refactored to a clean entry point: `WidgetsFlutterBinding.ensureInitialized()` + `runApp(TripRankApp())`.
- **`test/widget_test.dart`** — Updated smoke test to use `TripRankApp`.

#### Verification
- `flutter analyze` → **No issues found.**
- App runs and displays the shell placeholder screen.

---

### Phase 2.4 — Main Navigation

**Status: ✅ Done**  
**Completed: 2026-08-05**

#### What was done

- **`lib/features/map/presentation/map_screen.dart`** — `MapScreen` placeholder (deferred to Phase 4).
- **`lib/features/trips/presentation/trip_screen.dart`** — `TripsScreen` placeholder (deferred to Phase 5).
- **`lib/features/cars/presentation/cars_screen.dart`** — `CarsScreen` placeholder (deferred to Phase 3).
- **`lib/features/analytics/presentation/analytics_screen.dart`** — `AnalyticsScreen` placeholder (deferred to Phase 6).
- **`lib/features/profile/presentation/profile_screen.dart`** — `ProfileScreen` placeholder (deferred to Phase 7).
- **`lib/app/main_navigation.dart`** — `MainNavigation` shell widget using `StatefulNavigationShell` from GoRouter. Renders a Material 3 `NavigationBar` with 5 tabs (Map, Trips, Cars, Analytics, Profile). Styled via existing `NavigationBarTheme` in `AppTheme`.
- **`lib/app/router.dart`** — Replaced placeholder root route with `StatefulShellRoute.indexedStack` containing 5 branches. `initialLocation` set to `/map`. `_AppShellPlaceholder` removed.

#### Verification
- `flutter analyze` → **No issues found.**
- [x] Implement bottom navigation bar (Map, Trips, Cars, Analytics, Profile)
- [x] Connect routes to navigation items

---

### Phase 2.5 — Theme System

**Status: ✅ Done**  
**Completed: 2026-08-05**

#### What was done

- **`lib/app/theme/theme_provider.dart`** — `ThemeModeNotifier` (`Notifier<ThemeMode>`) + `themeProvider` (`NotifierProvider`). Defaults to `ThemeMode.dark`. Exposes `setTheme(ThemeMode)` for future use in Profile & Settings (Phase 7). Used `NotifierProvider` instead of the removed `StateProvider` — Riverpod 3.x only.
- **`lib/app/theme.dart`** — Barrel updated to export `theme_provider.dart`.
- **`lib/app/app.dart`** — `_AppContent` now calls `ref.watch(themeProvider)` instead of hardcoded `const ThemeMode.dark`.

#### Verification
- `flutter analyze` → **No issues found.**
- [x] Riverpod theme provider created
- [x] Theme provider connected to `MaterialApp.router`

---

## Phase 3 — Vehicle System

**Status: ✅ Completed**

### Phase 3.1 — Vehicle Model

**Status: ✅ Done**  
**Completed: 2026-08-05**

#### What was done

- **`lib/features/cars/models/vehicle.dart`** — `VehicleType` enum (sedan, suv, hatchback, coupe, convertible, wagon, pickup, van, minivan, other) with `label`, `value`, and `fromValue()`. `Vehicle` immutable data class with fields: `id`, `brand`, `model`, `year`, `type`, `createdAt`. Includes `copyWith`, `toMap` / `fromMap` serialisation for future database use (Phase 3), `==`, `hashCode`, `toString`.

#### Verification
- `flutter analyze` → **No issues found.**
- [x] Vehicle model created
- [x] VehicleType enum created
- [x] copyWith method included
- [x] Serialisation methods included

---

### Phase 3.2 — Vehicle State

**Status: ✅ Done**  
**Completed: 2026-08-05**

#### What was done

- **`lib/features/cars/providers/vehicle_provider.dart`** — `VehicleState` immutable state class holding `List<Vehicle>` and `selectedVehicleId`. `VehicleListNotifier` (`Notifier<VehicleState>`) with `addVehicle`, `updateVehicle`, `deleteVehicle`, `selectVehicle` methods using in-memory state. `vehicleProvider` (`NotifierProvider`) as the primary provider. `selectedVehicleProvider` (`Provider<Vehicle?>`) as a derived convenience provider. Ready for database integration — replace in-memory mutations with repository calls.

#### Verification
- `flutter analyze` → **No issues found.**
- [x] Vehicle list managed
- [x] Selected vehicle managed
- [x] Add / update / delete / select methods implemented

---

### Phase 3.3 — Car Selector Bottom Sheet

**Status: ✅ Done**  
**Completed: 2026-08-05**

#### What was done

- **`lib/features/cars/presentation/widgets/vehicle_tile.dart`** — `VehicleTile` reusable row widget. Displays brand + model. Check mark when selected. Edit icon placeholder (no action). `InkWell` tap feedback.
- **`lib/features/cars/presentation/widgets/car_selector_sheet.dart`** — `showCarSelectorSheet()` free function calls `showModalBottomSheet`. `CarSelectorSheet` `ConsumerWidget` reads `vehicleProvider`. Sub-widgets: `_DragHandle`, `_SheetHeader` (+ and Delete icon placeholders), `_VehicleList` (scrollable), `_EmptyState` ("Create your first vehicle" disabled TextButton). Tapping a vehicle calls `selectVehicle` then closes the sheet.
- **`lib/app/main_navigation.dart`** — Added `_carsTabIndex = 2`. `_onTabSelected` now takes `BuildContext` and intercepts index 2 to call `showCarSelectorSheet` instead of navigating. The active tab index never changes when Cars is tapped.

#### Verification
- `flutter analyze` → **No issues found.**
- [x] Bottom sheet opens over current screen when Cars tab tapped
- [x] Vehicle list displayed from provider
- [x] Selected vehicle shows check mark
- [x] Tapping vehicle updates provider and closes sheet
- [x] Empty state shown when no vehicles

---

### Phase 3.4 — Vehicle Management

**Status: ✅ Done**  
**Completed: 2026-08-05**

#### What was done

- **`lib/features/cars/presentation/dialogs/vehicle_form_dialog.dart`** — `VehicleFormDialog` shared form widget used by both Add and Edit. Contains title, Brand/Model/Year text fields with validation, Type `DropdownButtonFormField` (7 types, easily extendable), Cancel + Save buttons. Pure UI — no business logic.
- **`lib/features/cars/presentation/dialogs/add_vehicle_dialog.dart`** — `AddVehicleDialog` (`ConsumerStatefulWidget`). On save: generates UUID via `Uuid().v4()`, constructs `Vehicle`, calls `vehicleProvider.notifier.addVehicle()` (auto-selects first vehicle), closes dialog.
- **`lib/features/cars/presentation/dialogs/edit_vehicle_dialog.dart`** — `EditVehicleDialog` (`ConsumerStatefulWidget`). Pre-fills all fields from the existing vehicle. On save: calls `vehicle.copyWith(...)` then `vehicleProvider.notifier.updateVehicle()`. Keeps same ID, no duplicates.
- **`lib/features/cars/presentation/dialogs/delete_vehicle_dialog.dart`** — `DeleteVehicleDialog` (`ConsumerWidget`). `AlertDialog` with "Delete Vehicle?" title and vehicle name in message. Cancel closes with no changes. Delete calls `vehicleProvider.notifier.deleteVehicle()` then closes.
- **`lib/features/cars/providers/vehicle_provider.dart`** — `deleteVehicle` updated: when deleted vehicle was selected, auto-selects the next vehicle at same index (or last if at end); clears to null only when list is empty.
- **`lib/features/cars/presentation/widgets/car_selector_sheet.dart`** — `_SheetHeader` wired: `+` opens `showAddVehicleDialog`, Delete opens `showDeleteVehicleDialog` with selected vehicle (disabled when none selected). `_EmptyState` "Create your first vehicle" wired to `showAddVehicleDialog`.
- **`lib/features/cars/presentation/widgets/vehicle_tile.dart`** — Edit icon wired to `showEditVehicleDialog`.

#### Verification
- `flutter analyze` → **No issues found.**
- [x] Add Vehicle dialog creates vehicle and auto-selects it
- [x] Edit Vehicle dialog pre-fills fields and updates in place
- [x] Delete confirmation dialog removes vehicle and auto-selects next
- [x] Empty state "Create your first vehicle" opens Add dialog
- [x] All flows go through vehicleProvider — no direct state mutation in UI

---

## Phase 4 — Map System

**Status: ✅ Completed**

### Phase 4.1 — Map Foundation

**Status: ✅ Done**
**Completed: 2026-08-05**

#### What was done

- **`pubspec.yaml`** — Added `flutter_map ^8.3.1`, `geolocator ^14.0.3`, `latlong2 ^0.9.1`.
- **`android/app/src/main/AndroidManifest.xml`** — Added `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET` permissions.
- **`lib/features/map/services/location_service.dart`** — `LocationService` with `LocationStatus` enum. Handles permission check/request, one-shot `getCurrentLocation()`, continuous `positionStream()` (ready for Phase 5 trip recording), and settings helpers. `defaultLocation` fallback (London) shown before permission is granted.
- **`lib/features/map/providers/map_provider.dart`** — `MapState` (currentLocation, locationStatus, mapTheme, isLoadingLocation). `MapNotifier` auto-requests location on first build. `MapTheme` enum (`standard`/`dark`) independent from app theme. `mapProvider` exposed globally.
- **`lib/features/map/presentation/widgets/map_top_bar.dart`** — Floating pill bar: "MILEAGE" title on left, search icon on right. Tapping search animates a full-width `TextField` over the title (fade + opacity, 280ms). Collapsing restores the title. Search submission placeholder for Phase 4.2.
- **`lib/features/map/presentation/widgets/map_info_bar.dart`** — Floating pill bar with Speed / Altitude / Distance placeholder values separated by dividers. Values wired to trip state in Phase 5.
- **`lib/features/map/presentation/map_screen.dart`** — `MapScreen` (`ConsumerWidget`). Map displayed inside `ClipRRect` (rounded corners) with `_kHMargin` horizontal and `_kBottomMargin` bottom spacing so it sits above the floating nav bar. `FlutterMap` with OSM `TileLayer`, user location `MarkerLayer`. Permission states render `_PermissionView` or `_LoadingView` instead of the map. Re-center FAB placeholder. Architecture ready for `MapController` (Phase 4.2), route drawing (Phase 4.3), trip recording (Phase 5).

#### Verification
- `flutter analyze` → **No issues found.**
- [x] OpenStreetMap map displayed in rounded container
- [x] Location permission handling (all states covered)
- [x] Floating top bar with animated search
- [x] Floating info bar with speed/altitude/distance placeholders
- [x] Map theme independent from app theme

---

### Phase 4.2 — Destination Selection System

**Status: ✅ Done**
**Completed: 2026-08-07**

#### What was done

- **`pubspec.yaml`** — Added `http: ^1.2.2` for Nominatim geocoding requests.
- **`lib/features/map/models/destination.dart`** — `Destination` immutable data class with `id` (optional), `name`, `latitude`, `longitude`. Includes `latLng` getter (LatLng), `copyWith`, `==`, `hashCode`, `toString`.
- **`lib/features/map/providers/destination_provider.dart`** — `DestinationNotifier` (`Notifier<Destination?>`) with `setDestination()` and `clearDestination()`. `destinationProvider` (`NotifierProvider`) is the single source of truth for the selected destination. UI never mutates destination state directly.
- **`lib/features/map/services/geocoding_service.dart`** — `GeocodingService` backed by the free Nominatim OpenStreetMap API (no API key). `search(query)` returns a sealed `GeocodingResult` (`GeocodingSuccess` / `GeocodingError`). `reverseLookup(lat, lng)` returns a human-readable place name for map long-press; falls back to a formatted coordinate string on failure.
- **`lib/features/map/providers/map_provider.dart`** — `MapNotifier` now owns a `MapController` instance. Added `moveCamera(LatLng, {zoom})` and `recenterOnUser()` methods for programmatic camera control. Existing location/permission logic unchanged.
- **`lib/features/map/presentation/widgets/map_top_bar.dart`** — Converted to `ConsumerStatefulWidget`. Search field is debounced (400 ms) and calls `GeocodingService.search()`. Results render in a styled dropdown below the bar. Selecting a result calls `destinationProvider.setDestination()` and `mapProvider.moveCamera()`, then collapses the search UI. Loading indicator shown during fetch.
- **`lib/features/map/presentation/map_screen.dart`** — `FlutterMap` wired to `mapProvider.notifier.mapController`. `onLongPress` calls `GeocodingService.reverseLookup()` then sets destination via `destinationProvider`. `MarkerLayer` renders both the user location marker and the destination pin marker (red flag + stem). Re-center FAB now calls `mapProvider.notifier.recenterOnUser()`.

#### Architecture

```
Search input / Map long-press
        |
  GeocodingService (Nominatim)
        |
  destinationProvider (Destination?)
        |
  MapScreen → MarkerLayer (destination marker)
        |
  mapProvider.moveCamera()  ←  camera follows destination
```

#### Not implemented (per spec)
- Route calculation / drawing
- Navigation / Google Maps launch
- Trip recording / GPS tracking
- Analytics / database

#### Verification
- `flutter pub get` → success
- `flutter analyze` → **No issues found.**
- [x] Destination model created
- [x] Destination Riverpod provider created
- [x] Nominatim geocoding service (free, no API key)
- [x] Search bar debounced, shows results dropdown
- [x] Selecting search result moves map camera + sets destination marker
- [x] Map long-press sets destination with reverse-geocoded name
- [x] Both flows produce the same Destination object via destinationProvider
- [x] Re-center button wired to mapProvider.recenterOnUser()
- [x] No navigation logic implemented

---

### Phase 4.3 — Route Preview

**Status: ✅ Done**
**Completed: 2026-08-08**

#### What was done

- **`lib/features/map/models/route_result.dart`** — `RouteStatus` enum (`idle` / `calculating` / `ready` / `error`). `RouteResult` immutable state class holding coordinates, distance, duration, destination, status, and error message. Convenience getters `distanceLabel` and `durationLabel` format values for display. Named factory constructors (`calculating`, `ready`, `error`) for clean state transitions.
- **`lib/features/map/services/routing_service.dart`** — Abstract `RoutingService` interface. Decoupled from any concrete provider so the backing service can be replaced without touching the UI or state layer.
- **`lib/features/map/services/osrm_routing_service.dart`** — `OsrmRoutingService` backed by the free public OSRM demo server (no API key). Uses `geometries=geojson` to avoid a polyline-decoder dependency. Returns `RouteResult.ready` on success, `RouteResult.error` on failure — never throws.
- **`lib/features/map/providers/route_provider.dart`** — `RouteNotifier` (`Notifier<RouteResult>`) with `routeProvider` (`NotifierProvider`). Watches `destinationProvider` via `ref.listen`: auto-calculates route on destination change, resets on destination clear. Guards stale results — discards responses that arrive after the destination has already changed. Exposes `retry()` for the error UI.
- **`lib/features/map/providers/map_provider.dart`** — Added `fitRoute(List<LatLng>, {EdgeInsets padding})` method. Computes `LatLngBounds` from all route points and calls `mapController.fitCamera(CameraFit.bounds(...))`. Added `flutter/painting.dart` import for `EdgeInsets`.
- **`lib/features/map/presentation/map_screen.dart`** — `_LiveMap` converted to `ConsumerStatefulWidget`. Watches `routeProvider` and auto-fits camera on new ready route (guarded to avoid re-fitting on every rebuild). `PolylineLayer` added for the route polyline (blue, 5 px stroke with darker border). `_MapControls` column stacks `StartDriveButton` above `_RecenterButton`. `_RouteLoadingOverlay` shows a floating chip while calculating. `_RouteErrorBanner` shows an inline retry banner on error. `RouteInfoBubble` floated above the controls.
- **`lib/features/map/presentation/widgets/route_info_bubble.dart`** — `RouteInfoBubble` `ConsumerWidget`. Fades in when route is ready. Displays distance and duration as two `_InfoChip` cells with icons and labels inside a rounded pill container.
- **`lib/features/map/presentation/widgets/start_drive_button.dart`** — `StartDriveButton` `ConsumerWidget`. Always labelled "START". Icon is a spinner while calculating, play arrow otherwise. Colour is green when route is ready, blue otherwise. Tap shows a snackbar placeholder (drive recording comes in Phase 5).

#### Architecture

```
destinationProvider (Destination?)
        |
  RouteNotifier (routeProvider)
        |
  OsrmRoutingService → OSRM public API (free, no key)
        |
  RouteResult (idle / calculating / ready / error)
        |
  ┌─────────────────────────────────┐
  │ _LiveMap                        │
  │  • PolylineLayer (route coords) │
  │  • fitRoute() on ready          │
  └─────────────────────────────────┘
  RouteInfoBubble  (distance + duration)
  StartDriveButton (START / spinner)
  _RouteLoadingOverlay (calculating chip)
  _RouteErrorBanner   (error + retry)
```

#### Not implemented (per spec)
- Google Maps launching / external navigation
- Turn-by-turn instructions / voice guidance
- Trip recording
- Traffic / rerouting

#### Verification
- `flutter pub get` → success
- `flutter analyze` → **No issues found.**
- [x] RouteStatus enum: idle / calculating / ready / error
- [x] RouteResult model with distanceLabel / durationLabel
- [x] Abstract RoutingService interface
- [x] OsrmRoutingService — free OSRM, no API key, GeoJSON geometry
- [x] routeProvider auto-triggers on destinationProvider change
- [x] Stale-result guard prevents out-of-order responses
- [x] Retry() method for error recovery
- [x] fitRoute() on MapNotifier fits full route in camera
- [x] Polyline drawn on map when route is ready
- [x] Camera auto-fits to route on ready
- [x] RouteInfoBubble shows distance + duration
- [x] StartDriveButton (START, spinner while calculating, green when ready)
- [x] Route loading chip overlay while calculating
- [x] Route error banner with Retry button
- [x] Previous route cleared when new destination selected

---

### Phase 4.4 — Start Drive / Google Maps Integration

**Status: ✅ Done**
**Completed: 2026-08-09**

#### What was done

- **`pubspec.yaml`** — Added `flutter_foreground_task: ^10.0.0`. Required for Android's official `ForegroundService` API running in a separate Dart isolate — the only reliable way to continue GPS tracking while Google Maps occupies the foreground.
- **`android/app/src/main/AndroidManifest.xml`** — Added `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, `POST_NOTIFICATIONS` permissions. Declared `com.pravera.flutter_foreground_task.service.ForegroundService` with `foregroundServiceType="location"` and `stopWithTask="false"`. Added `<package android:name="com.google.android.apps.maps"/>` in `<queries>` so PackageManager can detect Google Maps without `QUERY_ALL_PACKAGES`.
- **`android/app/src/main/kotlin/…/MainActivity.kt`** — Added `MethodChannel("com.triprank.app/google_maps")` with `isGoogleMapsInstalled` (PackageManager lookup) and `launchGoogleMapsNavigation` (`google.navigation:q=lat,lng` intent with explicit package `com.google.android.apps.maps` — no app chooser, no fallback to any other navigation app).
- **`lib/features/map/models/drive_state.dart`** — `DriveStatus` enum (idle/starting/active/finishing/completed/error), `DriveMode` enum (reckless/destination), `TrackPoint` immutable model with JSON serialisation, `DriveState` immutable state with computed `speedLabel`/`altitudeLabel`/`distanceLabel` getters and `path` (List<LatLng>) for the recorded polyline.
- **`lib/features/map/services/google_maps_launcher.dart`** — `GoogleMapsLauncher` Dart service. `isInstalled()` and `launchNavigation()` call the platform channel. Never falls back to another app.
- **`lib/features/map/services/drive_controller.dart`** — `DriveController` orchestrates the full drive lifecycle. Sealed `DriveStartResult` hierarchy (DriveStarted / DriveGoogleMapsNotInstalled / DriveLaunchFailed / DriveStartFailed). Sealed `DriveUpdate` hierarchy (DriveUpdatePoint / DriveUpdateError). Uses `FlutterForegroundTask.addTaskDataCallback` / `removeTaskDataCallback` (correct v10 API).
- **`lib/features/map/presentation/widgets/start_drive_button.dart`** — Fully wired. Five visual states: START (no destination), START ROUTE with spinner (calculating), START ROUTE green (route ready), STARTING… (disabled), FINISH red (active), FINISHING… (disabled). Calls `driveProvider.notifier.startDrive()` or `finishDrive()`. Shows snackbar for Google Maps errors.

#### Architecture

```
Map UI (StartDriveButton)
    ↓
DriveNotifier (driveProvider)
    ↓
DriveController
    ├── GoogleMapsLauncher  →  com.google.android.apps.maps
    └── FlutterForegroundTask (foreground service)
            ↓  (separate Dart isolate)
        LocationTrackingTaskHandler
            ↓
        geolocator.getPositionStream()
            ↓
        DrivePersistenceService (SharedPreferences)
```

#### Verification
- `flutter pub get` → success
- `flutter analyze` → **No issues found.**
- [x] DriveStatus: idle / starting / active / finishing / completed / error
- [x] DriveMode: reckless / destination
- [x] Reckless Mode: START (no destination) → service starts, tracking begins, user stays in TripRank
- [x] Destination Mode: START → Google Maps check → service start → Maps launch
- [x] Google Maps not installed: error snackbar, drive NOT started, GPS NOT started
- [x] Google Maps launch failure: drive stays active, warning snackbar shown
- [x] StartDriveButton: START / START ROUTE / STARTING… / FINISH / FINISHING… states
- [x] FINISH stops service, finalises state, preserves points
- [x] Android platform channel: isGoogleMapsInstalled + launchGoogleMapsNavigation
- [x] Explicit Google Maps package targeting — no app chooser, no fallback

---

### Phase 4.5 — Continuous Background Tracking

**Status: ✅ Done**
**Completed: 2026-08-09**

#### What was done

- **`lib/features/map/services/location_tracking_task.dart`** — `LocationTrackingTaskHandler` (`TaskHandler`). Runs in a separate Dart isolate via `@pragma('vm:entry-point')` entry point. Opens `Geolocator.getPositionStream()` on `onStart`. Each position: converts to `TrackPoint`, accumulates distance via `Geolocator.distanceBetween`, persists via `DrivePersistenceService.appendPoint()`, updates foreground notification text with live speed + distance, sends JSON to main isolate via `FlutterForegroundTask.sendDataToMain`. Handles `{"action":"stop"}` from main. Cleans up on `onDestroy`.
- **`lib/features/map/services/drive_persistence_service.dart`** — Incremental SharedPreferences storage. `beginDrive()` initialises keys. `appendPoint()` read → append → write on every GPS update. `recoverActiveDrive()` returns `PersistedDrive?` for process-death recovery. `finishDrive()` returns all points and clears storage.
- **`lib/features/map/providers/drive_provider.dart`** — `DriveNotifier`. On build: creates `DriveController`, wires update callback, schedules `_recoverIfNeeded()`. `startDrive()`: idle → starting → active. `finishDrive()`: active → finishing → completed. `_onDriveUpdate()`: appends points and updates live speed/altitude/distance on every GPS event. `_recoverIfNeeded()`: restores `DriveState.active` with haversine-recomputed distance if persistence shows an interrupted drive.
- **`lib/main.dart`** — Added `FlutterForegroundTask.initCommunicationPort()` before `runApp()`.
- **`lib/features/map/presentation/widgets/map_info_bar.dart`** — Converted to `ConsumerWidget`. Reads `driveProvider` for live `speedLabel`, `altitudeLabel`, `distanceLabel`. Shows `—` placeholders when idle.
- **`lib/features/map/presentation/map_screen.dart`** — `_LiveMap` watches `driveProvider`. Route preview polyline (blue) hidden during active drive. Recorded-path polyline (green, `AppColors.success`) drawn from `drive.path` during active drive. Destination marker hidden during drive. Camera auto-fit skipped during active drive.

#### Background tracking guarantees
- Continues while Google Maps is in the foreground ✅
- Continues with screen locked / screen off (`WAKE_LOCK` + `allowWakeLock: true`) ✅
- Points persisted incrementally — survives process death ✅
- No internet required for GPS recording ✅
- Stops only on explicit FINISH ✅
- Foreground notification shows live speed + distance ✅
- Process-death recovery restores all previously recorded points ✅

#### Not implemented (per spec)
- Turn-by-turn navigation / voice guidance / traffic / rerouting
- Google Maps SDK / google_maps_flutter
- Full trip database / Trip Details screen
- Advanced analytics / crash/braking detection

#### Verification
- `flutter pub get` → success
- `flutter analyze` → **No issues found.**
- [x] Foreground service runs in separate Dart isolate (independent of UI)
- [x] GPS stream independent of Map widget lifecycle
- [x] Points persisted to SharedPreferences on every GPS update
- [x] Process-death recovery restores DriveState.active with all recorded points
- [x] MapInfoBar shows live speed / altitude / distance during drive
- [x] Recorded path polyline (green) shown on map during active drive
- [x] Route preview polyline (blue) hidden during drive
- [x] Destination marker hidden during drive
- [x] FINISH stops service and finalises state

---

## Bug Fixes — Physical Device Testing (2026-08-11)

**Status: ✅ Fixed**

### Bug 1 — Destination selected during Reckless Mode

**Problem:** While a Reckless Mode drive was active, selecting a destination (search or map tap) silently switched modes, creating an invalid concurrent state where both Reckless Mode and Destination Mode could be active simultaneously.

**Fix:**
- **`lib/features/map/presentation/dialogs/end_reckless_drive_dialog.dart`** _(new)_ — `showEndRecklessDriveDialog()` presents an `AlertDialog` asking "End reckless drive to start destination mode?". Returns `true` on "End Drive", `false`/`null` on Cancel or dismiss. Zero business logic in the dialog — purely UI.
- **`lib/features/map/presentation/widgets/map_top_bar.dart`** — `_onResultSelected` converted to `async`. Reads `driveProvider` before acting. If `drive.isActive && drive.mode == DriveMode.reckless`, the search UI is collapsed, the dialog is shown, and on Cancel the destination is discarded (Reckless drive continues unchanged). On confirm, `finishDrive()` is called and then the destination is set. Full `mounted` guard chain throughout.
- **`lib/features/map/presentation/map_screen.dart`** — `_onMapTap` updated with the same guard: dialog → finishDrive → setDestination on confirm; no-op on cancel. Added import for `end_reckless_drive_dialog.dart` and `drive_state.dart`.

### Bug 2 — Distance does not reset after ending a drive

**Problem:** After pressing FINISH, the previous drive's distance remained visible in the map info bar. The recorded path also persisted in state, meaning a new drive would appear to continue from the old one.

**Fix:**
- **`lib/features/map/models/drive_state.dart`** — `distanceLabel` now returns `'— km'` whenever `!isDriving` (removed the `!isCompleted` exception that caused the old value to leak through).
- **`lib/features/map/providers/drive_provider.dart`** — `finishDrive()` now resets to `const DriveState()` (full idle) after the foreground service stops. The completed track points are captured in a local variable for the upcoming Phase 5 trip repository call. `resetDrive()` added for explicit synchronous reset from other callers.

#### State consistency guarantees after fix
- Reckless Mode and Destination Mode cannot be active simultaneously ✅
- Completed drive distance is never shown in the info bar ✅
- Previous drive path does not persist to the next drive ✅
- Historical trip data is untouched ✅

#### Verification
- `flutter analyze` → **No issues found.**
- [x] Reckless drive active + search result selected → confirmation dialog appears
- [x] Cancel → Reckless drive continues, destination not set
- [x] End Drive → Reckless drive ends, destination set, START ROUTE available
- [x] FINISH (any mode) → info bar resets to `— km / — m / — km/h`
- [x] New drive starts from 0 distance and empty path

---

### Bug 3 — Current-location pointer frozen at startup position (2026-08-11)

**Status: ✅ Fixed**

#### Root cause

`MapNotifier.initLocation()` called `LocationService.getCurrentLocation()` **once** at startup (a one-shot `Geolocator.getCurrentPosition`) and wrote the result into `mapState.currentLocation`.  That value was **never updated again**.

The current-location marker in `_LiveMapState` reads `mapState.currentLocation`, so it was permanently pinned to the startup position.

Meanwhile, during an active drive, GPS updates flowed correctly through:
```
ForegroundService → DriveController._onTaskData → DriveNotifier._onDriveUpdate → DriveState.trackPoints / distanceKm
```
But this path never touched `mapProvider.currentLocation`, so:
- The path polyline drew correctly (reads `drive.path` from `driveProvider`).
- The marker did not move (reads `mapState.currentLocation` from `mapProvider`).
- After FINISH DRIVE, `driveProvider` reset to idle but `mapProvider.currentLocation` still held the frozen startup position.

#### Fix

**`lib/features/map/providers/map_provider.dart`**

- Added `updateCurrentLocation(LatLng)` — the single write path for `mapState.currentLocation`.
- `initLocation()` seeds with a one-shot fix, then immediately starts a **continuous idle position stream** (`_startIdleStream()`), so the marker stays fresh without a drive.
- Added `pauseIdleLocationUpdates()` — pauses the idle stream while a drive is active (avoids redundant parallel GPS streams).
- Added `resumeIdleLocationUpdates()` — resumes (or restarts) the idle stream after a drive ends, so the marker keeps moving post-drive without an app restart.
- `_cancelIdleStream()` / `_idleStreamCancelled` flag manage subscription lifecycle safely.
- Subscription cancelled in `ref.onDispose`.

**`lib/features/map/providers/drive_provider.dart`**

- `_onDriveUpdate` now calls `ref.read(mapProvider.notifier).updateCurrentLocation(point.latLng)` on every GPS point — the path polyline and the location marker now consume the same position data.
- `startDrive()` calls `pauseIdleLocationUpdates()` on drive start success (`DriveStarted` and `DriveLaunchFailed` cases).
- `finishDrive()` calls `resumeIdleLocationUpdates()` after state reset.

#### Data flow after fix

```
Idle (no drive):
  LocationService.positionStream()  →  mapProvider.updateCurrentLocation()  →  marker

Active drive:
  ForegroundService → DriveController → DriveNotifier._onDriveUpdate
    ├── driveState.trackPoints / distanceKm  →  path polyline / info bar
    └── mapProvider.updateCurrentLocation()  →  marker  ✅

After FINISH:
  idle stream resumes  →  mapProvider.updateCurrentLocation()  →  marker  ✅
```

#### Verification
- `flutter analyze` → **No issues found.**
- [x] Pointer follows user during active Reckless Mode drive
- [x] Pointer follows user during active Destination Mode drive
- [x] Path polyline unchanged (still reads drive.path)
- [x] Distance / stats unchanged (still reads driveState)
- [x] After FINISH, pointer continues to update without app restart
- [x] Idle stream paused during drive (no duplicate GPS streams)
- [x] Idle stream resumed after drive ends
- [x] Stream subscription properly cancelled on provider dispose

---

## Phase 5 — Trip System

**Status: ✅ Completed** _(5.1–5.5 complete)_

### Phase 5.1 — Local Database Foundation

**Status: ✅ Done**
**Completed: 2026-08-11**

#### What was done

- **`pubspec.yaml`** — Added `sqflite: ^2.4.3` and `path: ^1.9.1` as production dependencies. Added `sqflite_common_ffi: ^2.4.2` as a dev dependency for in-VM unit testing (no physical device required).
- **`lib/core/database/database_config.dart`** — Central constants file. `kDatabaseName = 'triprank.db'`. `kDatabaseVersion = 1`. Includes documented version history for future phases (v2 vehicles, v3 trips, v4 track_points, v5 driving_events, v6 user_preferences). Rules: never lower the version, never use destructive recreation.
- **`lib/core/database/app_database.dart`** — `AppDatabase` singleton service. Responsibilities: platform-safe path resolution via `getDatabasesPath()` + `path` package (never hard-codes paths), single-connection guard (`isOpen` check before re-opening), `onCreate` callback that creates only the foundation `db_metadata` table and seeds `schema_version`, `onUpgrade` migration dispatcher that runs every version step in order (safe for users who skip releases), `_migrate(db, targetVersion)` switch with stubbed `case 1` and commented `case 2/3` examples for future phases, `onDowngrade` safety fallback (`onDatabaseDowngradeDelete`), clean `close()` that nulls the connection. Application tables (vehicles, trips, track_points, etc.) are NOT created here — they belong to later phases.
- **`lib/core/database/database_provider.dart`** — Riverpod `Provider<AppDatabase>` that exposes the singleton to the dependency graph. Uses a simple `Provider` (not `FutureProvider`) because all async initialization is completed in `main()` before `ProviderScope` is created. Includes usage documentation for future repository authors.
- **`lib/main.dart`** — `AppDatabase.instance.initialize()` called and awaited before `runApp()`, after `WidgetsFlutterBinding.ensureInitialized()`. Initialization failures are caught and logged — they do not crash the app.
- **`test/core/database/app_database_test.dart`** — 6 tests using `sqflite_common_ffi` in-memory database (no device/emulator needed). Covers: initialization succeeds, database accessor available, version matches `kDatabaseVersion`, duplicate `initialize()` calls are no-ops (same connection object), metadata table and `schema_version` seed exist, close + re-initialize round-trip works.

#### Architecture

```
main()
  └── AppDatabase.instance.initialize()   (async, before runApp)
          └── getDatabasesPath() + path.join()  →  triprank.db
                  └── sqflite.openDatabase(version: 1, onCreate, onUpgrade)
                          └── _createMetadataTable()   (db_metadata)

Riverpod:
  databaseProvider  →  AppDatabase.instance
  (consumed by future repositories — not yet wired to app tables)
```

#### Database version
- Version 1 (Foundation — metadata table only)

#### Files created
- `lib/core/database/app_database.dart`
- `lib/core/database/database_config.dart`
- `lib/core/database/database_provider.dart`
- `test/core/database/app_database_test.dart`

#### Files modified
- `lib/main.dart` — added database initialization block
- `pubspec.yaml` — added `sqflite`, `path`, `sqflite_common_ffi`

#### Not implemented (per spec)
- Vehicle / trip / GPS / analytics tables
- Database-backed Riverpod providers
- Any repository layer (reserved for Phase 5.2+)

#### Verification
- `flutter pub get` → **success**
- `flutter analyze` → **No issues found.**
- All 6 database tests → **passed**
  1. Database initialization succeeds
  2. Database can be opened
  3. Database version matches `kDatabaseVersion` (1)
  4. Multiple `initialize()` calls do not open duplicate connections
  5. `db_metadata` table exists with correct `schema_version` seed
  6. Close then re-initialize round-trip works without errors
- [x] SQLite database opens on startup without blocking the UI
- [x] Database path resolved via `getDatabasesPath()` — no hard-coded paths
- [x] Single connection enforced (singleton + `isOpen` guard)
- [x] Migration mechanism wired and ready for Phase 5.2+
- [x] Riverpod provider exposes the database to the dependency graph
- [x] Existing Map / Drive / GPS features unchanged and working
- [x] No vehicle / trip / GPS tables created prematurely

### Phase 5.2 — Vehicle Persistence

**Status: ✅ Done**
**Completed: 2026-08-11**

#### What was done

- **`lib/core/database/database_config.dart`** — `kDatabaseVersion` bumped to 2. Added table/key constants: `kVehiclesTable`, `kMetadataTable`, `kMetaKeySchemaVersion`, `kMetaKeySelectedVehicleId`. Version history comment updated.
- **`lib/core/database/app_database.dart`** — `_createVehiclesTable` helper added (columns: `id TEXT PK`, `brand TEXT`, `model TEXT`, `year INTEGER`, `type TEXT`, `created_at TEXT`, `updated_at TEXT`). `_onCreate` now calls both `_createMetadataTable` and `_createVehiclesTable` for fresh installs at v2. `case 2` added to `_migrate` dispatch to create the vehicles table for users upgrading from v1.
- **`lib/features/cars/data/vehicle_repository.dart`** _(new)_ — `VehicleRepository` accepts a raw `Database` connection (not `AppDatabase`) for testability. Operations: `getAll` (ordered by `created_at` ASC), `getById`, `create`, `update` (refreshes `updated_at`), `delete` (auto-clears selected vehicle if the deleted vehicle was selected), `getSelectedVehicleId`, `setSelectedVehicleId`, `clearSelectedVehicle`. Selected vehicle ID stored in `db_metadata` under `kMetaKeySelectedVehicleId` — single authoritative source, no per-row flag. Snake_case ↔ Dart conversion handled entirely inside `_rowToVehicle` / `_vehicleToRow` — `Vehicle.fromMap` unchanged.
- **`lib/features/cars/providers/vehicle_repository_provider.dart`** _(new)_ — `Provider<VehicleRepository>` that supplies `VehicleRepository(appDb.database)` to the Riverpod graph.
- **`lib/features/cars/providers/vehicle_provider.dart`** — `VehicleListNotifier` refactored from `Notifier` to `AsyncNotifier<VehicleState>`. `build()` loads vehicles and selected ID from SQLite on first access. All mutations (`addVehicle`, `updateVehicle`, `deleteVehicle`, `selectVehicle`) write through `VehicleRepository` then update Riverpod state immediately — no full reload required. `vehicleProvider` changed to `AsyncNotifierProvider`. `selectedVehicleProvider` reads `asyncState.value` (Riverpod 3.x — `valueOrNull` was renamed to `value` on `AsyncValue`).
- **`lib/features/cars/presentation/widgets/car_selector_sheet.dart`** — Updated to read `asyncState.value` for vehicles/selectedId. Shows a brief `CircularProgressIndicator` while the DB loads on first launch (typically imperceptible). `selectVehicle` is now `await`ed before closing.
- **`lib/features/cars/presentation/dialogs/add_vehicle_dialog.dart`** — `_save()` is now `async`, `await`s `addVehicle()`, guards against double-tap with `_saving` flag.
- **`lib/features/cars/presentation/dialogs/edit_vehicle_dialog.dart`** — `_save()` is now `async`, `await`s `updateVehicle()`, guards against double-tap.
- **`lib/features/cars/presentation/dialogs/delete_vehicle_dialog.dart`** — Converted from `ConsumerWidget` to `ConsumerStatefulWidget`. `_delete()` is now `async`, `await`s `deleteVehicle()`, shows a spinner in the Delete button during the DB operation.
- **`test/core/database/app_database_test.dart`** — Added `setUp` that deletes the DB file before each test so version-number changes don't cause `conflictAlgorithm: ignore` to preserve a stale `schema_version` row. Now uses `kMetadataTable`/`kMetaKeySchemaVersion` constants.
- **`test/features/cars/vehicle_repository_test.dart`** _(new)_ — 11 tests, all using fresh per-test in-memory databases (no singleton bleed). Test 10 uses a named file path (`getDatabasesPath()` + `persist_test.db`) with cleanup.

#### Architecture

```
Vehicle UI (CarSelectorSheet, dialogs)
    ↓  ref.watch / ref.read
VehicleListNotifier (AsyncNotifier<VehicleState>)
    ↓  vehicleRepositoryProvider
VehicleRepository(Database)
    ↓  sqflite
SQLite — vehicles table + db_metadata (selected_vehicle_id)
```

#### Database migration
- v1 → v2: `CREATE TABLE IF NOT EXISTS vehicles (...)` added in `_migrate case 2`
- Fresh install at v2: both tables created in `_onCreate`

#### Vehicle table schema
```sql
CREATE TABLE vehicles (
  id          TEXT    PRIMARY KEY,
  brand       TEXT    NOT NULL,
  model       TEXT    NOT NULL,
  year        INTEGER NOT NULL,
  type        TEXT    NOT NULL,
  created_at  TEXT    NOT NULL,
  updated_at  TEXT    NOT NULL
)
```

#### Selected vehicle persistence
Stored as a key-value row in `db_metadata`:
- Key: `selected_vehicle_id`
- Value: vehicle UUID string
- Absent when no vehicle is selected
- `VehicleRepository.delete()` auto-clears this key when the deleted vehicle was selected

#### Files created
- `lib/features/cars/data/vehicle_repository.dart`
- `lib/features/cars/providers/vehicle_repository_provider.dart`
- `test/features/cars/vehicle_repository_test.dart`

#### Files modified
- `lib/core/database/database_config.dart`
- `lib/core/database/app_database.dart`
- `lib/features/cars/providers/vehicle_provider.dart`
- `lib/features/cars/presentation/widgets/car_selector_sheet.dart`
- `lib/features/cars/presentation/dialogs/add_vehicle_dialog.dart`
- `lib/features/cars/presentation/dialogs/edit_vehicle_dialog.dart`
- `lib/features/cars/presentation/dialogs/delete_vehicle_dialog.dart`
- `test/core/database/app_database_test.dart`

#### Not implemented (per spec)
- Trip / GPS / analytics tables
- Database-backed providers for any other feature
- New vehicle UI design

#### Verification
- `flutter pub get` → **success**
- `flutter analyze` → **No issues found.**
- All 18 tests → **passed**
  - 6 Phase 5.1 database foundation tests
  - 11 Phase 5.2 vehicle repository tests:
    1. Create vehicle inserts a row
    2. getById returns the correct vehicle
    3. getAll returns all vehicles ordered by created_at
    4. update modifies an existing vehicle row
    5. delete removes the vehicle row
    6. setSelectedVehicleId persists and getSelectedVehicleId retrieves
    7. clearSelectedVehicle removes the selection
    8. Deleting the selected vehicle automatically clears the selection
    9. Multiple vehicles coexist without collisions
    10. Vehicles survive database close and reopen
    11. Migration from version 1 to version 2 creates vehicles table
  - 1 app shell smoke test
- [x] Vehicles persisted to SQLite — survive app restarts
- [x] Selected vehicle persisted in db_metadata — survives app restarts
- [x] Create / Edit / Delete flows write through repository
- [x] Riverpod state updated immediately (no restart required to see changes)
- [x] Delete selected vehicle clears selection — no dangling reference
- [x] Empty state shown when no vehicles in DB
- [x] Auto-select first vehicle on first add
- [x] v1 → v2 migration path verified in tests
- [x] Existing Map / Drive / GPS / Reckless Mode / Destination Mode features unchanged

### Phase 5.3 — Trip Persistence

**Status: ✅ Done**
**Completed: 2026-08-11**

#### What was done

- **`lib/features/trips/models/trip.dart`** _(new)_ — `TripMode` enum (`reckless`/`destination`) with `fromDriveMode()`. `Trip` immutable data class with all required fields: core (`id`, `vehicleId`, `mode`, `startTime`, `endTime`, `durationSeconds`, `distanceKm`), start location (`startLatitude`, `startLongitude`, `startName?`), destination (`destinationLatitude?`, `destinationLongitude?`, `destinationName?`), summary statistics (`averageSpeedKmh?`, `minimumSpeedKmh?`, `maximumSpeedKmh?`, `minimumAltitudeM?`, `maximumAltitudeM?`, `stops?`), and `createdAt`. `TripBuilder` static helper computes all statistics from `DriveState.trackPoints` at completion time — Trip Details never recalculates from raw points.
- **`lib/core/database/database_config.dart`** — `kDatabaseVersion` bumped to 3. Added `kTripsTable = 'trips'`. Version history updated.
- **`lib/core/database/app_database.dart`** — `_onConfigure` added (`PRAGMA foreign_keys = ON` — required for `ON DELETE SET NULL` to work). `_createTripsTable` helper added with full schema + two indexes (`idx_trips_vehicle_id`, `idx_trips_start_time`). `case 3` wired in `_migrate`. `_onCreate` updated to create all three tables for fresh installs at v3.
- **`lib/features/trips/data/trip_repository.dart`** _(new)_ — `TripRepository` accepts a raw `Database` for testability. Operations: `createTrip`, `getTripById`, `getAllTrips` (newest first), `getTripsForVehicle` (newest first), `getRecentTrips(limit)`, `deleteTrip`. All SQL confined here.
- **`lib/features/trips/providers/trip_repository_provider.dart`** _(new)_ — `Provider<TripRepository>` supplying `TripRepository(appDb.database)`.
- **`lib/features/map/models/drive_state.dart`** — Added `vehicleId` and `destination` fields to `DriveState`. Both captured at drive start and available at completion for trip persistence. `copyWith` uses `_keepSentinel` for nullable-safe overrides.
- **`lib/features/map/providers/drive_provider.dart`** — `startDrive()` reads `vehicleProvider` to capture `vehicleId` and stores it plus `destination` in `DriveState`. `finishDrive()` calls `_persistTrip()` which builds a `Trip` via `TripBuilder` and calls `TripRepository.createTrip()`. Persistence errors are logged — they never crash the app. TODO comment removed.
- **`test/features/trips/trip_repository_test.dart`** _(new)_ — 21 tests. All use `singleInstance: false` + `onConfigure: PRAGMA foreign_keys = ON` for proper FK enforcement. Tests 4 and 16 insert vehicle rows before creating trips with FK vehicleIds. Test 17 uses a named file path for the close/reopen persistence test. Test 18 simulates v2→v3 migration. Tests 19/20 verify `ON DELETE SET NULL` behavior.

#### Architecture

```
FINISH pressed
    ↓
DriveNotifier.finishDrive()
    ├── stopDrive() → collect trackPoints
    ├── TripBuilder.build(drive, vehicleId, destination)
    │       ├── compute avgSpeed / minSpeed / maxSpeed from trackPoints
    │       ├── compute minAlt / maxAlt from trackPoints
    │       └── durationSeconds = endTime - startTime
    └── TripRepository.createTrip(trip) → SQLite

Drive UI
    ↓
DriveNotifier (Notifier<DriveState>)
    ↓
TripRepository(Database)
    ↓
SQLite — trips table
```

#### Database migration
- v2 → v3: `CREATE TABLE IF NOT EXISTS trips (...)` + 2 indexes in `_migrate case 3`
- Fresh install at v3: all 3 tables created in `_onCreate`
- `PRAGMA foreign_keys = ON` enforced via `onConfigure`

#### Trips table schema
```sql
CREATE TABLE trips (
  id                      TEXT    PRIMARY KEY,
  vehicle_id              TEXT    REFERENCES vehicles(id) ON DELETE SET NULL,
  mode                    TEXT    NOT NULL,
  start_time              TEXT    NOT NULL,
  end_time                TEXT    NOT NULL,
  duration_seconds        INTEGER NOT NULL,
  distance_km             REAL    NOT NULL,
  start_latitude          REAL    NOT NULL,
  start_longitude         REAL    NOT NULL,
  start_name              TEXT,
  destination_latitude    REAL,
  destination_longitude   REAL,
  destination_name        TEXT,
  average_speed_kmh       REAL,
  minimum_speed_kmh       REAL,
  maximum_speed_kmh       REAL,
  minimum_altitude_m      REAL,
  maximum_altitude_m      REAL,
  stops                   INTEGER,
  created_at              TEXT    NOT NULL
)
```

#### Vehicle/trip relationship
- `trips.vehicle_id` → `vehicles.id` with `ON DELETE SET NULL`
- Deleting a vehicle sets `vehicle_id = NULL` on all its trips — historical trips are preserved

#### Statistics availability
| Statistic | Source | Available |
|---|---|---|
| `distanceKm` | `DriveState.distanceKm` | ✅ |
| `durationSeconds` | `endTime - startTime` | ✅ |
| `averageSpeedKmh` | mean of `trackPoints.speedKmh` | ✅ (≥1 point) |
| `minimumSpeedKmh` | min of `trackPoints.speedKmh` | ✅ (≥1 point) |
| `maximumSpeedKmh` | max of `trackPoints.speedKmh` | ✅ (≥1 point) |
| `minimumAltitudeM` | min of `trackPoints.altitude` | ✅ (≥1 point) |
| `maximumAltitudeM` | max of `trackPoints.altitude` | ✅ (≥1 point) |
| `stops` | Stop detection not yet implemented | ❌ null |
| `startName` | Reverse-geocoding at start not yet wired | ❌ null (Phase 5.x) |

#### Files created
- `lib/features/trips/models/trip.dart`
- `lib/features/trips/data/trip_repository.dart`
- `lib/features/trips/providers/trip_repository_provider.dart`
- `test/features/trips/trip_repository_test.dart`

#### Files modified
- `lib/core/database/database_config.dart`
- `lib/core/database/app_database.dart`
- `lib/features/map/models/drive_state.dart`
- `lib/features/map/providers/drive_provider.dart`
- `test/features/cars/vehicle_repository_test.dart` (singleInstance: false fix)
- `test/features/trips/trip_repository_test.dart`

#### Not implemented (per spec)
- GPS track-point table (Phase 5.4)
- Trip Details UI
- Trip History UI
- Stop detection
- Start location reverse-geocoding at drive start
- Cloud synchronization

#### Verification
- `flutter pub get` → **success**
- `flutter analyze` → **No issues found.**
- All 39 tests → **passed**
  - 6 Phase 5.1 database foundation tests
  - 11 Phase 5.2 vehicle repository tests
  - 21 Phase 5.3 trip repository tests:
    1. createTrip inserts a row
    2. getTripById returns the correct trip
    3. getAllTrips returns all trips
    4. getTripsForVehicle returns only that vehicle's trips
    5. getAllTrips returns trips newest first
    6. Trip mode (reckless/destination) round-trips correctly
    7. Start/end timestamps round-trip as UTC
    8. durationSeconds round-trips correctly
    9. distanceKm round-trips correctly
    10. Start coordinates round-trip correctly
    11. startName (nullable) round-trips correctly
    12. Destination coordinates round-trip correctly
    13. destinationName round-trips correctly
    14. Reckless trip stores null destination fields
    15. Summary statistics round-trip correctly
    16. Multiple trips can reference the same vehicle
    17. Trips survive database close and reopen
    18. v2→v3 migration preserves existing vehicles
    19. Deleting a vehicle does NOT delete its historical trips
    20. vehicle_id is NULL on trip after vehicle is deleted
    21. deleteTrip removes only the specified trip
  - 1 app shell smoke test
- [x] Trip model created with all required fields
- [x] Trips table schema with ON DELETE SET NULL for vehicle FK
- [x] PRAGMA foreign_keys = ON enforced in AppDatabase
- [x] v2 → v3 migration path verified in tests
- [x] TripRepository operations verified
- [x] finishDrive() persists completed trip via TripRepository
- [x] vehicleId captured at drive start
- [x] Destination coordinates/name captured at drive start (offline-first)
- [x] Summary statistics computed from track points at completion
- [x] Persistence errors logged without crashing
- [x] Existing vehicle persistence still works
- [x] Existing Map / Drive / GPS / Reckless Mode / Destination Mode unchanged

---

### Phase 5.4 — GPS Point Persistence & Post-Finish Navigation

**Status: ✅ Done**
**Completed: 2026-08-11**

#### What was done

- **`lib/core/database/database_config.dart`** — `kDatabaseVersion` was already bumped to 4 and `kTrackPointsTable = 'trip_track_points'` constant already present from prior work.
- **`lib/core/database/app_database.dart`** — `_createTrackPointsTable()` helper already implemented with full schema + composite index `(trip_id, timestamp ASC)`. `case 4` in `_migrate` creates the table for v3→v4 upgrades. `_onCreate` creates all 4 tables for fresh installs.
- **`lib/features/trips/models/track_point_record.dart`** _(existing)_ — `TrackPointRecord` durable database model with `id`, `tripId`, `timestamp`, `latitude`, `longitude`, `altitude?`, `speedKmh?`, `accuracyM?`, `headingDegrees?`. `fromTrackPoint()` factory converts live `TrackPoint` to `TrackPointRecord`. `toRow()` / `fromRow()` SQLite serialisation. Full IEEE 754 precision — no rounding.
- **`lib/features/trips/data/track_point_repository.dart`** _(existing)_ — `TrackPointRepository` with `addTrackPoint` (single, ConflictAlgorithm.ignore for idempotency), `addTrackPoints` (batch transaction), `getTrackPointsForTrip` (chronological ASC), `getTrackPointCount`, `deleteTrackPointsForTrip`, `deleteTrackPoint`. All SQL confined here.
- **`lib/features/trips/providers/track_point_repository_provider.dart`** _(existing)_ — `Provider<TrackPointRepository>` supplying `TrackPointRepository(appDb.database)`.
- **`lib/features/map/models/drive_state.dart`** _(existing)_ — `DriveState.activeTripId` field (UUID assigned at drive start, stable FK for incremental GPS persistence before the trip summary row is created).
- **`lib/features/map/providers/drive_provider.dart`** _(existing)_ — `startDrive()` generates a stable `activeTripId` UUID. `_onDriveUpdate()` calls `_persistTrackPoint()` (fire-and-forget) on every GPS fix — errors logged, drive never crashed. `finishDrive()` calls `_persistTripAndPoints()` which flushes remaining points via `addTrackPoints()` (idempotent), then creates the Trip summary via `TripRepository.createTrip()`. Returns the completed `tripId` on success, `null` on failure.
- **`lib/features/trips/providers/trip_stats_provider.dart`** _(rewritten)_ — Fixed Riverpod 3.4.2 family API: `TripStatsNotifier extends Notifier<TripStatsState>` with `_tripId` set by the factory lambda. Provider declared as `NotifierProvider.family<TripStatsNotifier, TripStatsState, String>((tripId) => TripStatsNotifier(tripId))` — no explicit `NotifierProviderFamily` annotation (not exported from flutter_riverpod). Loads trip summary and GPS track independently.
- **`lib/features/trips/presentation/trip_stats_screen.dart`** _(existing)_ — `TripStatsScreen(tripId)` reads `tripStatsProvider(tripId)`. Immediately shows persisted summary stats (distance, duration, speed, altitude). Loads GPS track separately with a loading indicator. Back button navigates to previous screen (Trips list or Map).
- **`lib/features/map/presentation/widgets/start_drive_button.dart`** _(modified)_ — `_onTap` on FINISH: awaits `finishDrive()` → on success (non-null tripId) invalidates `tripListProvider` then navigates `context.go(AppRoutes.tripStatsPath(tripId))`. On failure (null) shows an error snackbar — never navigates to a non-existent trip.
- **`lib/features/trips/presentation/trip_screen.dart`** _(minor fix)_ — `separatorBuilder: (_, _)` — fixed `unnecessary_underscores` lint.
- **`lib/app/router.dart`** _(existing)_ — `/trips/:id` nested route already wired to `TripStatsScreen(tripId)`.
- **`test/features/trips/track_point_repository_test.dart`** _(new)_ — 36 tests covering all required Phase 5.4 scenarios.
- **`test/features/trips/trip_repository_test.dart`** _(updated)_ — `_openTestDb()` schema helper now creates all 4 tables (v4). Test 17 `open()` also updated with v4 + `PRAGMA foreign_keys = ON`.

#### Architecture

```
GPS fix received
    ↓
DriveNotifier._onDriveUpdate()
    ├── DriveState.trackPoints (in-memory path polyline / info bar)
    └── _persistTrackPoint(point)  ←── fire-and-forget, never blocks GPS
            ↓
        TrackPointRepository.addTrackPoint(record)
            ↓
          SQLite trip_track_points (using activeTripId as FK)

FINISH pressed
    ↓
DriveNotifier.finishDrive()
    ├── stopDrive() → collect final points
    ├── _flushTrackPoints()  ←── addTrackPoints() (idempotent batch)
    ├── TripBuilder.build()  ←── compute summary from trackPoints
    ├── TripRepository.createTrip()  ←── persist summary
    └── return tripId  ←── non-null on success

StartDriveButton._onTap (FINISH branch)
    ↓
ref.invalidate(tripListProvider)  ←── Trips page will refresh
context.go(AppRoutes.tripStatsPath(tripId))  ←── immediate navigation

Trip Stats screen
    ↓
TripStatsNotifier
    ├── TripRepository.getTripById()  ←── summary (immediate)
    └── TrackPointRepository.getTrackPointsForTrip()  ←── track (async)
```

#### Database version
- v3 → v4: `CREATE TABLE IF NOT EXISTS trip_track_points (...)` + composite index in `_migrate case 4`
- Fresh install at v4: all 4 tables created in `_onCreate`

#### Track-point table schema
```sql
CREATE TABLE trip_track_points (
  id               TEXT    PRIMARY KEY,
  trip_id          TEXT    NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  timestamp        TEXT    NOT NULL,
  latitude         REAL    NOT NULL,
  longitude        REAL    NOT NULL,
  altitude         REAL,
  speed_kmh        REAL,
  accuracy_m       REAL,
  heading_degrees  REAL
)
CREATE INDEX idx_track_points_trip_time ON trip_track_points (trip_id, timestamp ASC)
```

#### Active-drive persistence approach
- A stable UUID (`activeTripId`) is generated at drive start and stored in `DriveState`.
- Every GPS fix is persisted immediately via `TrackPointRepository.addTrackPoint()` (fire-and-forget — errors logged, drive continues).
- `ConflictAlgorithm.ignore` makes all inserts idempotent — duplicate rows are safe to send again.
- On FINISH, `_flushTrackPoints()` uses `addTrackPoints()` (single transaction) to insert any points that may not have been persisted individually. This is race-safe because duplicates are ignored.
- The Trip summary row is created **after** all track points are flushed, so foreign key integrity is guaranteed.

#### Post-finish navigation flow
```
FINISH → finishDrive() returns tripId
    ├── tripId != null → ref.invalidate(tripListProvider)
    │                 → context.go('/trips/$tripId')  → TripStatsScreen
    └── tripId == null → error snackbar, no navigation
```

#### Trip Stats integration
- `TripStatsScreen(tripId)` is the entry point.
- `TripStatsNotifier` loads the `Trip` summary first (single row — effectively instant) and updates state immediately.
- GPS track points are loaded in a second async step — `_TrackSection` shows a loading chip until complete.
- All pre-computed summary statistics (distance, duration, avg/min/max speed, min/max altitude, destination) are available from the first database read with no recalculation.

#### Trips page integration
- `tripListProvider` is a `FutureProvider` that calls `TripRepository.getAllTrips()`.
- After a successful FINISH, `ref.invalidate(tripListProvider)` forces a reload on next access.
- The Trips page shows the new trip at the top of the list (newest first) the next time it is built.

#### Files created
- `test/features/trips/track_point_repository_test.dart`

#### Files modified
- `lib/features/map/presentation/widgets/start_drive_button.dart`
- `lib/features/trips/providers/trip_stats_provider.dart`
- `lib/features/trips/presentation/trip_screen.dart`
- `test/features/trips/trip_repository_test.dart`

#### Not implemented (per spec)
- Final polished Trip Stats UI (map route rendering, speed/altitude graphs)
- Stop detection
- Start location reverse-geocoding
- Advanced driving analytics
- Cloud synchronization

#### Verification
- `flutter analyze` → **No issues found.**
- All **75 tests** passed:
  - 6 Phase 5.1 database foundation tests ✅
  - 11 Phase 5.2 vehicle repository tests ✅
  - 21 Phase 5.3 trip repository tests ✅
  - 36 Phase 5.4 track-point repository tests ✅
  - 1 app shell smoke test ✅
- Phase 5.4 tests (36):
  1. v3→v4 migration creates trip_track_points without data loss
  2. Existing vehicles survive v3→v4 migration
  3. Existing trips survive v3→v4 migration
  4. trip_track_points table exists after v4 schema creation
  5. Track points can be inserted
  6. Track points can be retrieved for a trip
  7. Track points are returned in chronological order
  8. Track points persist after database close and reopen
  9. Multiple trips can have separate, isolated track points
  10. Deleting a Trip cascades to delete its track points
  11. Deleting a Vehicle does NOT delete Trip track points
  12. No orphan track points remain after trip deletion
  13. addTrackPoint inserts a row with all fields
  14. getTrackPointsForTrip returns correct TrackPointRecord objects
  15. Empty track returns correctly
  16. Large GPS track (1000 points) can be inserted and retrieved
  17. Track points from multiple trips remain isolated
  18. DriveState.activeTripId is a non-null UUID assigned at drive start
  19. GPS points persisted incrementally using activeTripId as FK
  20. addTrackPoints (flush) inserts all points in a single transaction
  21. Trip summary is persisted via TripRepository at FINISH
  22. Final Trip contains exactly the track points recorded during drive
  23. The final GPS point of a drive is not lost
  24. Duplicate point ID (ignored) does not throw or lose other points
  25. Completed Trip ID can be obtained after createTrip
  26. Completed Trip is retrievable by ID after persistence
  27. Newly completed Trip appears in getAllTrips after persistence
  28. getTripById returns the exact Trip whose ID was passed at creation
  29. Persisted summary statistics are immediately available from Trip
  30. getAllTrips returns the newly completed trip (newest first)
  31. GPS track loads independently of the trip summary
  32. getTripById returns null for a non-existent Trip ID
  33. Nullable GPS fields (altitude, speed, accuracy, heading) round-trip
  34. GPS coordinates are stored at full IEEE 754 double precision
  35. getTrackPointCount returns the correct number of points
  36. deleteTrackPointsForTrip removes all points for the specified trip
- [x] Database version bumped v3 → v4
- [x] v3→v4 migration path verified in tests
- [x] trip_track_points table with ON DELETE CASCADE
- [x] Composite index (trip_id, timestamp ASC)
- [x] GPS points persisted incrementally — not waiting until FINISH
- [x] activeTripId generated at drive start — stable FK before summary row exists
- [x] Per-point persistence is fire-and-forget — errors logged, drive never crashed
- [x] Flush on FINISH is idempotent via ConflictAlgorithm.ignore
- [x] Trip summary created after track-point flush — FK integrity guaranteed
- [x] FINISH navigates automatically to TripStatsScreen for the completed trip
- [x] Persistence failure shows error snackbar — no navigation to nonexistent trip
- [x] tripListProvider invalidated on FINISH — Trips page refreshes
- [x] TripStatsScreen shows summary immediately, loads GPS track independently
- [x] Deleting a Trip deletes its track points (ON DELETE CASCADE)
- [x] Deleting a Vehicle does NOT delete track points (ON DELETE SET NULL on trips)
- [x] All Phase 5.1 / 5.2 / 5.3 tests still pass
- [x] Existing Reckless Mode / Destination Mode / background tracking unchanged

#### Physical-device testing still required
- Verify GPS points accumulate during an active Reckless Mode drive (requires real GPS signal)
- Verify GPS points accumulate while Google Maps is in the foreground (Destination Mode)
- Verify track points survive app process kill and restart
- Verify FINISH navigates to TripStatsScreen on device
- Verify TripStatsScreen loads summary statistics immediately
- Verify Trip appears in Trips list after completion
- Verify Trip and its GPS track persist after device restart

---

### Phase 5.5 — Trips Page & Trip Stats UI

**Status: ✅ Done**
**Completed: 2026-08-11**

#### What was done

- **`lib/features/trips/providers/trips_filter_provider.dart`** _(new)_ — `TripsFilterState` (searchQuery, startDate, endDate). `TripsFilterNotifier` with `setSearch`, `clearSearch`, `setDateRange`, `clearDateFilter`, `clearAll`. `vehicleTripsProvider` loads only the selected vehicle's trips — returns empty when no vehicle is selected. `filteredTripsProvider` applies search + date filters client-side (AND logic).
- **`lib/features/trips/presentation/widgets/polyline_thumbnail.dart`** _(new)_ — `PolylineThumbnail` (`CustomPainter`). Dark bg, 4×4 grid, blue polyline scaled to fit square with 15% padding, start (green) / end (red) dots. Geographic bounding-box projection preserves aspect ratio. `dart:ui.Path` used explicitly to avoid the `latlong2.Path<LatLng>` naming collision.
- **`lib/features/trips/presentation/dialogs/delete_trip_dialog.dart`** _(new)_ — Confirmation dialog; deletes via `TripRepository.deleteTrip`, invalidates `vehicleTripsProvider`. GPS track removed automatically by `ON DELETE CASCADE`. Spinner during delete.
- **`lib/features/trips/presentation/widgets/trip_card.dart`** _(new)_ — Polyline thumbnail + date/time + destination (or "Free Drive") + vehicle name + avg speed / duration / distance stats row + delete icon (separate tap target). Navigates to Trip Stats on card tap.
- **`lib/features/trips/presentation/widgets/interactive_graph.dart`** _(new)_ — Shared `InteractiveGraph` widget. `AspectRatio(2.6)`, full screen width, no horizontal scroll. Grid, area fill, line, Y/X axis labels. Touch/drag → nearest point → live tooltip. Used for both speed and altitude graphs.
- **`lib/features/trips/presentation/widgets/turn_split_bar.dart`** _(new)_ — Two-color bar (blue = left, orange = right) with counts and percentages. "Not available" placeholder when turn data is null; zero-turn state handled.
- **`lib/features/trips/presentation/trip_screen.dart`** _(replaced)_ — Full Trips page with animated search bar (260 ms fade), `showDateRangePicker` calendar (dark theme), active-filter chips, three distinct empty states (no vehicle / no trips for vehicle / filters with no results).
- **`lib/features/trips/presentation/trip_stats_screen.dart`** _(replaced)_ — Vertically-scrollable Trip Stats page. 8 sections: header, route map (flutter_map, auto-fit polyline, pan/zoom, start/end markers), core stats card, speed stats card, altitude stats card, speed graph, altitude graph, turn split bar. Summary stats available immediately; GPS track loads independently.
- **`lib/features/map/presentation/widgets/start_drive_button.dart`** _(modified)_ — Updated `tripListProvider` import → `vehicleTripsProvider` from `trips_filter_provider.dart`.

#### Architecture

```
TripsScreen
    ↓
filteredTripsProvider  (search + date applied client-side)
    ↓
vehicleTripsProvider   (FutureProvider — selected vehicle only)
    ├── selectedVehicleProvider
    └── TripRepository.getTripsForVehicle()
tripsFilterProvider    (NotifierProvider)

TripStatsScreen
    ↓
tripStatsProvider(tripId)  (NotifierProvider.family)
    ├── TripRepository.getTripById()       — summary (immediate)
    └── TrackPointRepository.getTrackPointsForTrip() — track (async)
```

#### Files created
- `lib/features/trips/providers/trips_filter_provider.dart`
- `lib/features/trips/presentation/widgets/polyline_thumbnail.dart`
- `lib/features/trips/presentation/dialogs/delete_trip_dialog.dart`
- `lib/features/trips/presentation/widgets/trip_card.dart`
- `lib/features/trips/presentation/widgets/interactive_graph.dart`
- `lib/features/trips/presentation/widgets/turn_split_bar.dart`
- `test/features/trips/trips_filter_test.dart`
- `test/features/trips/trip_stats_test.dart`
- `test/features/trips/trip_delete_list_test.dart`

#### Files modified
- `lib/features/trips/presentation/trip_screen.dart` (full replacement)
- `lib/features/trips/presentation/trip_stats_screen.dart` (full replacement)
- `lib/features/map/presentation/widgets/start_drive_button.dart` (provider import fix)

#### Dependencies added
None. All graphs with `CustomPainter`. Existing `flutter_map` and `latlong2` used.

#### Turn section status
Turn detection not yet implemented. UI placeholder shown. Will be populated in Phase 6.

#### Functionality not yet available
- **Stop detection** (`trip.stops` always `null`) — Phase 6.
- **Left/right turn counts** — Phase 6.
- **Start location name** — reverse-geocoding not yet wired.

#### Verification
- `flutter analyze` → **No issues found.**
- All **152 tests** passed:
  - 75 pre-existing tests (Phases 5.1–5.4 + smoke test) ✅
  - 34 new filter tests (`trips_filter_test.dart`) ✅
  - 26 new Trip Stats tests (`trip_stats_test.dart`) ✅
  - 17 new delete/list tests (`trip_delete_list_test.dart`) ✅
- [x] Trips page shows only selected vehicle's trips
- [x] Animated search bar (destination filter, case-insensitive)
- [x] Calendar date range filter with active indicator
- [x] Search + date filters combine correctly (AND)
- [x] Clearing one filter leaves the other active
- [x] Newest trips first (repository order, not UI sort)
- [x] Three distinct empty states (no vehicle / no trips / no filter results)
- [x] Polyline thumbnail scales full route to fit — no cropping
- [x] Trip card: date/time, destination, vehicle, stats row
- [x] Delete confirmation dialog + GPS cascade + list refresh
- [x] Trip card tap → Trip Stats; delete icon tap → confirmation only
- [x] Trip Stats: scrollable, 8 sections
- [x] Route map: flutter_map, auto-fit polyline, pan/zoom, start/end markers
- [x] Speed graph: full width, no horizontal scroll, interactive touch
- [x] Altitude graph: full width, no horizontal scroll, interactive touch
- [x] Summary stats available immediately; GPS track loads independently
- [x] Loading placeholders for GPS-dependent sections
- [x] Turn split bar: placeholder shown (data not yet available)
- [x] FINISH → Trip Stats post-drive navigation unchanged
- [x] vehicleTripsProvider invalidated on FINISH → Trips list refreshes

---

## Phase 6 — Driving Analytics

**Status: 🔄 In progress** _(6.1, 6.2, 6.3 complete)_

---

### Phase 6.1 — Driving Analytics Foundation

**Status: ✅ Done**
**Completed: 2026-08-12**

#### What was done

- **`lib/features/analytics/models/driving_analytics.dart`** _(new)_ — `DrivingAnalytics` top-level result model. Holds `analyzedPoints`, `speedAnalysis`, `altitudeAnalysis`, and nullable stub fields for future phases (`turnAnalysis`, `brakingAnalysis`, `overallStatistics`). Immutable, extensible, no Flutter/Riverpod dependency. `DrivingAnalytics.empty(tripId)` factory for zero-point tracks.
- **`lib/features/analytics/models/analyzed_track_point.dart`** _(new)_ — `AnalyzedTrackPoint`. Enriches each `TrackPointRecord` with per-segment derived values: `segmentDistanceM`, `segmentDurationS`, `derivedSpeedMs`, `derivedSpeedKmh`, `speedChangeMps`, `accelerationMps2`, `headingChangeDeg`, `altitudeChangeMetre`. Raw GPS fields preserved unchanged. All derived fields nullable for the first point and invalid intervals.
- **`lib/features/analytics/models/speed_analysis.dart`** _(new)_ — `SpeedAnalysis` aggregates max/min/avg derived speed, max speed change, total distance, moving duration. Does NOT replace the persisted `averageSpeedKmh`/`minimumSpeedKmh`/`maximumSpeedKmh` on `Trip` — those remain authoritative.
- **`lib/features/analytics/models/altitude_analysis.dart`** _(new)_ — `AltitudeAnalysis` aggregates min/max altitude, total elevation gain/loss, altitude range. Null when no altitude data — never substitutes 0 for null.
- **`lib/features/analytics/services/gps_math_utils.dart`** _(new)_ — `GpsMathUtils` pure Dart static utility class. Methods: `distanceMetres` (latlong2 haversine), `timeDeltaSeconds` (returns null for zero/negative intervals), `derivedSpeedMs`, `speedMsToKmh`, `speedKmhToMs`, `accelerationMps2`, `bearingDegrees`, `headingChangeDegrees`, `altitudeChangeMetre`, `isValid`. All methods guard against NaN/Infinity/division-by-zero. No new packages — uses existing `latlong2` and `dart:math`.
- **`lib/features/analytics/services/driving_analytics_service.dart`** _(new)_ — `DrivingAnalyticsService` plain Dart class. `analyze({tripId, points})` method: sorts by timestamp, single-pass O(n) derivation, produces `DrivingAnalytics`. No Flutter, no Riverpod, no database. Returns `DrivingAnalytics.empty` for empty input. Never throws.
- **`lib/features/analytics/providers/trip_analytics_provider.dart`** _(new)_ — `drivingAnalyticsServiceProvider` (plain `Provider`), `TripAnalyticsState`, `TripAnalyticsNotifier` (family `Notifier` — same pattern as `TripStatsNotifier`), `tripAnalyticsProvider` (`NotifierProvider.family<TripAnalyticsNotifier, TripAnalyticsState, String>`). Loads track points from `TrackPointRepository` then runs `DrivingAnalyticsService`. Service itself has no Riverpod dependency.
- **`test/features/analytics/driving_analytics_test.dart`** _(new)_ — 52 tests. All 28 required spec cases covered (basic input, ordering, distance, time, speed, acceleration, altitude, heading, data quality, performance) plus 24 additional `GpsMathUtils` unit tests and service integration tests. No device/GPS/DB/internet required. Performance: 10 000-point track analyzed in 78–135 ms.

#### Architecture

```
Trip Stats / Future Phase 6 UI
        ↓
tripAnalyticsProvider (NotifierProvider.family — tripId)
        ↓
TripAnalyticsNotifier
        ├── trackPointRepositoryProvider  →  TrackPointRepository  →  SQLite
        └── drivingAnalyticsServiceProvider  →  DrivingAnalyticsService
                ↓
            GpsMathUtils  (pure Dart, no state)
                ↓
            DrivingAnalytics
             ├── List<AnalyzedTrackPoint>
             ├── SpeedAnalysis
             ├── AltitudeAnalysis
             ├── turnAnalysis        (null — Phase 6.2)
             ├── brakingAnalysis     (null — Phase 6.3)
             └── overallStatistics   (null — Phase 6.4)
```

#### Files created
- `lib/features/analytics/models/driving_analytics.dart`
- `lib/features/analytics/models/analyzed_track_point.dart`
- `lib/features/analytics/models/speed_analysis.dart`
- `lib/features/analytics/models/altitude_analysis.dart`
- `lib/features/analytics/services/gps_math_utils.dart`
- `lib/features/analytics/services/driving_analytics_service.dart`
- `lib/features/analytics/providers/trip_analytics_provider.dart`
- `test/features/analytics/driving_analytics_test.dart`

#### Files modified
None — no existing files were changed.

#### Dependencies added
None — uses existing `latlong2` and `dart:math`.

#### Not implemented (per spec — future phases)
- Left/right turn detection (Phase 6.2)
- Hard braking / sudden-stop detection (Phase 6.3)
- Overall driving statistics / score (Phase 6.4)
- Analytics UI integration (Phase 6.5)
- Analytics persistence / caching
- Database schema changes

#### Verification
- `flutter pub get` → **success**
- `flutter analyze` → **No issues found.**
- All **204 tests passed**:
  - 152 pre-existing tests (Phases 5.1–5.5 + smoke test) ✅
  - 52 new Phase 6.1 analytics tests ✅
    - Tests 1–4: Basic input (empty, 1 point, 2 points, multiple)
    - Tests 5–7: Ordering (out-of-order, duplicates, negative intervals)
    - Tests 8–10: Distance (known coords, identical, sub-metre)
    - Tests 11–13: Time delta (normal, zero, negative)
    - Tests 14–17: Speed (valid, missing, zero, speed changes)
    - Tests 18–20: Acceleration (positive, negative, zero-duration)
    - Tests 21–23: Altitude (valid, missing, null never → 0)
    - Tests 24–25: Heading (valid preserved, null handled)
    - Tests 26–27: Data quality (no crash, no NaN/Infinity)
    - Test 28: Performance (10 000 points in 78–135 ms)
    - 24 additional GpsMathUtils unit tests
- [x] DrivingAnalytics model extensible for Phases 6.2–6.4
- [x] AnalyzedTrackPoint preserves raw GPS data, adds derived values
- [x] GpsMathUtils: haversine distance, time delta, speed, acceleration, bearing, heading change, altitude change
- [x] DrivingAnalyticsService: single-pass O(n), sort-by-timestamp, defensive against all edge cases
- [x] tripAnalyticsProvider: family pattern, plain service, no Riverpod in service
- [x] No database schema modified
- [x] No existing Trip summary statistics replaced or contradicted
- [x] No UI changes
- [x] No new packages added
- [x] Turn/braking/stop algorithms NOT implemented

---

---

### Phase 6.2 — Turn Analysis

**Status: ✅ Done**
**Completed: 2026-08-22**

#### What was done

- **`lib/features/analytics/models/turn_event.dart`** _(new)_ — `TurnDirection` enum (`left`, `right`, `uTurn`) with documented sign convention. `TurnEvent` immutable model with: `direction`, `timestamp`, `latitude`, `longitude`, `angleDeg`, `entryBearingDeg`, `exitBearingDeg`, `speedKmh?`. Convenience getters `absAngleDeg`, `isLeft`, `isRight`, `isUTurn`.
- **`lib/features/analytics/models/turn_analysis.dart`** _(new)_ — `TurnAnalysis` aggregated result. Holds `List<TurnEvent>`. `leftTurns`, `rightTurns`, `uTurns` derived from the list at construction — single authoritative source, no duplication. `totalTurns`, `isEmpty` convenience getters. `TurnAnalysis.empty()` factory. U-turns explicitly excluded from left/right counts.
- **`lib/features/analytics/services/turn_detector.dart`** _(new)_ — `TurnDetectorConfig` centralising all thresholds as named constants. `TurnDetector` sliding-window algorithm with full documentation, circular-mean bearing, debounce, and classification.
- **`lib/features/analytics/services/driving_analytics_service.dart`** _(modified)_ — Wires `TurnDetector` into the analytics pipeline. `DrivingAnalyticsService` now accepts an optional `TurnDetector` for dependency injection in tests. `analyze()` calls `turnDetector.detectTurns(sorted)` after the single-pass derivation step and stores the result in `DrivingAnalytics.turnAnalysis`.
- **`lib/features/analytics/models/driving_analytics.dart`** _(modified)_ — `turnAnalysis` field changed from nullable stub to populated field. `DrivingAnalytics.empty()` now returns `TurnAnalysis.empty()` instead of `null`. `copyWith` and `toString` updated.
- **`test/features/analytics/turn_analysis_test.dart`** _(new)_ — 41 unit tests. All tests use deterministic synthetic GPS tracks generated via inverse-haversine `_advance` helper. No device, network, or database required.

#### Detection algorithm

```
Sorted GPS track
        ↓
Sliding window (windowSize = 5 points)
    ├── Movement gate: sum haversine distance across window
    │       < minMovementM (10 m) → skip (stationary / noise)
    ├── Debounce gate: distance traveled since last turn
    │       < debounceDistanceM (50 m) → skip (suppress multi-event from one turn)
    ├── Entry bearing: circular-mean bearing across first half of window
    │       (indices 0..halfSize-1, i.e. pairs 0→1 for ws=5)
    ├── Exit bearing: circular-mean bearing across second half of window
    │       (indices halfSize+1..ws-1, i.e. pairs 3→4 for ws=5)
    ├── Heading change: GpsMathUtils.headingChangeDegrees(entry, exit)
    │       normalised to (−180, +180]
    │       positive = clockwise = RIGHT
    │       negative = counter-clockwise = LEFT
    ├── |angle| < minTurnAngleDeg (35°) → skip (gentle curve / noise)
    ├── |angle| ≥ uTurnThresholdDeg (150°) → classify as uTurn
    └── otherwise → left or right, emit TurnEvent at window midpoint
```

#### Sign convention

`GpsMathUtils.headingChangeDegrees` normalises the bearing change to (−180, +180]:

| Sign | Direction | Classification |
|---|---|---|
| Negative | Counter-clockwise | `TurnDirection.left` |
| Positive | Clockwise | `TurnDirection.right` |
| \|angle\| ≥ 150° | Near-reversal | `TurnDirection.uTurn` |

This convention is documented in `turn_event.dart` and tested explicitly in the sign-convention tests.

#### Configuration (all centralised in `TurnDetectorConfig`)

| Constant | Value | Rationale |
|---|---|---|
| `windowSize` | 5 | Entry half = pair (0→1); exit half = pair (3→4); robust without merging nearby turns |
| `minTurnAngleDeg` | 35° | Real intersections ≥ 45°; 35° margin covers slightly-angled junctions; filters highway curves (< 20°) |
| `uTurnThresholdDeg` | 150° | True U-turns are 160–180°; 150° allows for GPS imprecision in the trace |
| `minMovementM` | 10 m | GPS at 30 km/h ≈ 8 m per fix; 10 m filters stationary clusters |
| `debounceDistanceM` | 50 m | Urban intersection span ≈ 10–20 m; 50 m separates events cleanly |

#### U-turn behaviour

- Classified as `TurnDirection.uTurn` — a separate category, not left or right.
- **Not counted** in `leftTurns` or `rightTurns`.
- Counted in `uTurns` and `totalTurns`.
- Not displayed in the left/right split bar UI (Phase 6.5).

#### GPS noise handling

- Minimum movement gate (10 m) rejects stationary GPS clusters and near-zero movement.
- Entry/exit circular-mean bearings average across half-windows, smoothing per-pair jitter.
- Sliding window requires coherent bearing change across multiple points — single-point noise cannot trigger a turn.
- ±4 m GPS jitter on a straight road: 0 false turns (tested).

#### Architecture

```
Persisted GPS Track Points
        ↓
DrivingAnalyticsService.analyze()
    ├── Sort by timestamp
    ├── Single-pass AnalyzedTrackPoint derivation (speed, altitude, heading)
    └── TurnDetector.detectTurns(sortedPoints)
            ↓  sliding window, O(n × windowSize) ≈ O(n)
        TurnAnalysis { turns, leftTurns, rightTurns, uTurns }
                ↓
        DrivingAnalytics.turnAnalysis
                ↓
        tripAnalyticsProvider (existing Riverpod family provider)
```

No new Riverpod providers, no new database tables, no new packages.

#### Files created
- `lib/features/analytics/models/turn_event.dart`
- `lib/features/analytics/models/turn_analysis.dart`
- `lib/features/analytics/services/turn_detector.dart`
- `test/features/analytics/turn_analysis_test.dart`

#### Files modified
- `lib/features/analytics/models/driving_analytics.dart` — `turnAnalysis` populated, `empty()` returns `TurnAnalysis.empty()`
- `lib/features/analytics/services/driving_analytics_service.dart` — wires `TurnDetector`, injects result into `DrivingAnalytics`

#### Dependencies added
None. Uses existing `latlong2`, `dart:math`, and `GpsMathUtils`.

#### Known limitations
- Turn detection operates only on the persisted GPS track — live tracking turns are not emitted in real time.
- Window-based algorithm may miss extremely sharp turns (<5 m total movement across the window) at very low GPS fix rates.
- The 50 m debounce distance may occasionally merge two legitimate closely-spaced turns (< 50 m apart) in dense urban environments such as roundabouts with multiple exits.
- U-turns are not yet displayed in any UI (deferred to Phase 6.5).

#### Not implemented (per spec — future phases)
- Hard braking / sudden-stop detection (Phase 6.3)
- Overall driving statistics / score (Phase 6.4)
- Turn split bar UI with real data (Phase 6.5)
- Turn event persistence to database (Phase 6.4/6.5)

#### Verification
- `flutter pub get` → **success**
- `flutter analyze` → **No issues found.**
- All **245 tests passed**:
  - 204 pre-existing tests (Phases 5.1–6.1 + smoke test) ✅
  - 41 new Phase 6.2 turn analysis tests ✅
    - Group 1 — Straight road (4 tests): north, east, GPS jitter, stationary points → 0 turns
    - Group 2 — Left turn (3 tests): 90° left, negative angleDeg, 45° left
    - Group 3 — Right turn (3 tests): 90° right, positive angleDeg, 45° right
    - Group 4 — Multiple turns (2 tests): left→right, two rights
    - Group 5 — Gentle curve (2 tests): 20° and 25° gradual changes → 0 turns
    - Group 6 — U-turn (2 tests): 180° and 160° → uTurn, not left/right
    - Group 7 — GPS noise (2 tests): stationary cluster, 1 m steps → 0 turns
    - Group 8 — Missing data (7 tests): null speed, null heading, duplicate timestamps/coords, short track, empty, single point
    - Group 9 — Heading wraparound (3 tests): 355→5 = +10°, 5→355 = −10°, 360° boundary track
    - Group 10 — Threshold boundary (4 tests): 34° (below), 36° (above), 149° (left not right), 150°+ (uTurn)
    - Group 11 — TurnAnalysis model (3 tests): empty factory, U-turn exclusion from counts, absAngleDeg
    - Group 12 — Service integration (1 test): turnAnalysis non-null for empty track
    - Group 13 — TurnDetectorConfig (3 tests): custom high threshold, custom low threshold, default values
    - Group 14 — Location and timestamp (2 tests): valid coordinates, timestamp within track range
- [x] Left/right turn detection implemented
- [x] U-turn classified separately, not counted in left/right
- [x] Multi-point sliding window (windowSize = 5)
- [x] Circular-mean bearing for entry and exit halves
- [x] Heading normalised to (−180, +180] via `GpsMathUtils.headingChangeDegrees`
- [x] Sign convention documented and tested: positive = right, negative = left
- [x] Minimum movement threshold (10 m) prevents stationary false turns
- [x] Minimum angle threshold (35°) filters gentle curves and noise
- [x] U-turn threshold (150°) separates large turns from true reversals
- [x] Distance-based debounce (50 m) suppresses duplicate events from one physical turn
- [x] GPS heading not required — bearing computed from coordinates
- [x] Speed field is optional
- [x] Turn location = window midpoint coordinates
- [x] Turn timestamp = window midpoint timestamp
- [x] `DrivingAnalytics.turnAnalysis` populated by `DrivingAnalyticsService`
- [x] `TurnAnalysis.empty()` returned for empty tracks
- [x] O(n × windowSize) ≈ O(n) performance
- [x] No database changes
- [x] No UI changes
- [x] No new packages
- [x] All existing Phase 5 and Phase 6.1 tests continue passing

---

### Phase 6.3 — Hard Braking & Sudden Stop Detection

**Status: ✅ Done**
**Completed: 2026-08-22**

#### What was done

- **`lib/features/analytics/models/braking_event.dart`** _(new)_ — `BrakingEventType` enum (`hardBraking`, `suddenStop`). `BrakingEventSeverity` enum (`mild`, `hard`, `severe`). `BrakingEvent` immutable model with all required fields: `type`, `timestamp`, `latitude`, `longitude`, `startSpeedKmh`, `endSpeedKmh`, `decelerationMps2`, `durationS?`, `severity`. Convenience getters `isSuddenStop`, `isHardBraking`, `speedReductionKmh`. Full documentation on GPS limitations, deduplication strategy, and severity rationale.
- **`lib/features/analytics/models/braking_analysis.dart`** _(new)_ — `BrakingAnalysis` aggregated result. Holds `List<BrakingEvent>`. `hardBrakingCount`, `suddenStopCount`, `severeCount` derived from the event list at construction — single authoritative source, no duplication. `totalEvents`, `isEmpty` convenience getters. `BrakingAnalysis.empty()` factory.
- **`lib/features/analytics/services/braking_detector.dart`** _(new)_ — `BrakingDetectorConfig` centralising all thresholds as named constants (8 configurable values). `BrakingDetector` single-pass O(n) algorithm with full documentation, sliding candidate window, cooldown debounce, and GPS noise filtering.
- **`lib/features/analytics/services/driving_analytics_service.dart`** _(modified)_ — Wires `BrakingDetector` into the analytics pipeline as step 5. `DrivingAnalyticsService` now accepts an optional `BrakingDetector` for dependency injection in tests.
- **`lib/features/analytics/models/driving_analytics.dart`** _(modified)_ — `brakingAnalysis` field changed from `dynamic` to typed `BrakingAnalysis?`. `DrivingAnalytics.empty()` now returns `BrakingAnalysis.empty()`. `copyWith` and `toString` updated.
- **`test/features/analytics/braking_analysis_test.dart`** _(new)_ — 59 unit tests. All tests use deterministic synthetic GPS tracks. No device, network, or database required.

#### Detection algorithm

```
Sorted GPS track
        ↓
Single forward pass O(n)
    ├── For each consecutive pair (prev, cur):
    │       ├── Resolve time delta (skip if ≤ 0 or > maxTimeGapS)
    │       ├── Resolve best speed (raw GPS speedKmh > derived haversine/time)
    │       ├── Skip if prevSpeed < minStartSpeedKmh (stationary / low speed)
    │       ├── Compute deceleration = (prevSpeed_ms - curSpeed_ms) / durS
    │       ├── Open candidate window when decel ≥ minDecelerationMps2
    │       │       (cooldown gate: no new window within cooldownDistanceM)
    │       ├── Extend window on each subsequent qualifying segment
    │       └── Seal and emit event when decel drops below threshold
    ├── At end of track, seal any open candidate
    └── Classification: endSpeedKmh ≤ suddenStopEndSpeedKmh → suddenStop
                        otherwise → hardBraking
```

#### Event deduplication

One physical braking maneuver → one event. When strong braking ends at near-zero speed, the event type is `suddenStop` — NOT both a `hardBraking` and a `suddenStop`. The `hardBrakingCount + suddenStopCount` always equals `totalEvents`.

#### Configuration (all centralised in `BrakingDetectorConfig`)

| Constant | Value | Rationale |
|---|---|---|
| `minDecelerationMps2` | 0.5 m/s² | Conservative GPS-derived threshold; GPS-based studies suggest 0.35–0.6 m/s². Chosen at middle of range — tune after physical-device testing |
| `suddenStopEndSpeedKmh` | 5 km/h | GPS speed noise at a true stop can report 0–3 km/h; 5 km/h captures legitimate near-stops |
| `minStartSpeedKmh` | 10 km/h | Above pedestrian/crawl speed; prevents stationary GPS jitter events |
| `maxTimeGapS` | 10 s | Skips segments where GPS gap is too large for reliable deceleration calculation |
| `cooldownDistanceM` | 100 m | Post-event cooldown to prevent one maneuver fragmenting into multiple events |
| `minBrakingSegments` | 1 | Minimum consecutive qualifying segments; increase to 2 for stricter noise rejection |
| `hardSeverityThresholdMps2` | 0.7 m/s² | mild → hard boundary |
| `severeSeverityThresholdMps2` | 1.0 m/s² | hard → severe boundary |

#### Threshold rationale — GPS vs accelerometer

Published accelerometer-based harsh-braking thresholds (0.3–0.5 g ≈ 3–5 m/s², SAE/ISO) **cannot** be used for GPS-derived data. GPS speed is rate-limited (1–5 s fix interval), has inherent noise (~0.1–0.3 m/s² apparent deceleration on smooth road), and computes averaged deceleration across each interval. The 0.5 m/s² threshold is based on GPS-specific literature (Bagdadi & Várhelyi 2011; Wahlberg 2006) which suggests 0.35–0.6 m/s² for GPS-only harsh-event detection.

#### Multi-point evidence

The sliding candidate window requires the deceleration to be sustained across at least `minBrakingSegments` consecutive GPS pairs. A single noisy speed spike cannot emit an event (especially when `minBrakingSegments` is increased to 2 in stricter configurations). This is the primary defence against GPS noise beyond the threshold filter.

#### Severity approach

Three levels derived from `decelerationMps2` against configurable thresholds:
- `mild` — above detection threshold but below `hardSeverityThresholdMps2`
- `hard` — above hard threshold but below severe
- `severe` — above `severeSeverityThresholdMps2`

Severity is a lightweight signal — the primary output is reliable event detection.

#### GPS noise handling

- `minStartSpeedKmh` (10 km/h) — blocks stationary jitter and low-speed parking
- `maxTimeGapS` (10 s) — skips unreliable large-gap segments
- `cooldownDistanceM` (100 m) — debounces multi-GPS-fix maneuvers
- `minBrakingSegments` — requires evidence across consecutive points
- Raw GPS speed preferred over derived speed (less noise)
- Speed conversion in m/s for all calculations (avoids km/h rounding artefacts)

#### Architecture

```
Persisted GPS Track Points
        ↓
DrivingAnalyticsService.analyze()
    ├── Sort by timestamp
    ├── Single-pass AnalyzedTrackPoint derivation (speed, altitude, heading)
    ├── TurnDetector.detectTurns(sortedPoints)          ← Phase 6.2
    └── BrakingDetector.detect(sortedPoints)            ← Phase 6.3
            ↓  single forward pass, O(n)
        BrakingAnalysis { events, hardBrakingCount, suddenStopCount, severeCount }
                ↓
        DrivingAnalytics.brakingAnalysis
                ↓
        tripAnalyticsProvider (existing Riverpod family provider)
```

No new Riverpod providers, no new database tables, no new packages.

#### Files created
- `lib/features/analytics/models/braking_event.dart`
- `lib/features/analytics/models/braking_analysis.dart`
- `lib/features/analytics/services/braking_detector.dart`
- `test/features/analytics/braking_analysis_test.dart`

#### Files modified
- `lib/features/analytics/models/driving_analytics.dart` — `brakingAnalysis` typed to `BrakingAnalysis?`, `empty()` returns `BrakingAnalysis.empty()`
- `lib/features/analytics/services/driving_analytics_service.dart` — wires `BrakingDetector`, injects result into `DrivingAnalytics`

#### Dependencies added
None. Uses existing `latlong2`, `dart:math`, and `GpsMathUtils`.

#### Known limitations
- Braking detection operates only on the persisted GPS track — not computed in real time during an active drive.
- GPS fix rate directly affects accuracy: at 1 s intervals a 3-second brake event gives only 3 data points. At 5 s intervals, the same event may appear as a single large deceleration step.
- `minDecelerationMps2 = 0.5` is a conservative starting value. Physical-device testing with known braking events is required to calibrate this threshold for the specific Android device and GPS sensor used.
- The 100 m cooldown may very occasionally merge two closely-spaced legitimate braking events (< 100 m apart at low urban speed).

#### Not implemented (per spec — future phases)
- Overall driving statistics / score (Phase 6.4)
- Braking section UI in Trip Stats (Phase 6.5)
- Braking event persistence to database (Phase 6.4/6.5)
- Real-time braking alerts during driving

#### Verification
- `flutter pub get` → **success**
- `flutter analyze` → **No issues found.**
- All **304 tests passed**:
  - 245 pre-existing tests (Phases 5.1–6.2 + smoke test) ✅
  - 59 new Phase 6.3 braking analysis tests ✅
    - Group 1 — Empty/minimal tracks (3 tests): empty, single point, two points no braking
    - Group 2 — Normal driving (4 tests): fluctuation, gradual decel, constant, moderate braking
    - Group 3 — Hard braking (9 tests): single-segment, start/end speed, decel magnitude, timestamp, multi-segment, below minStart, threshold boundary (inclusive/exclusive/just-above)
    - Group 4 — Sudden stop (5 tests): multi-segment stop, no double-count, non-stop hard brake, low-speed exclusion, entry speed
    - Group 5 — Multiple events (2 tests): two separate events, hard+sudden in sequence
    - Group 6 — GPS noise (4 tests): small fluctuations, stationary noise, near-zero speeds, single-spike with minBrakingSegments=2
    - Group 7 — Cooldown/debounce (2 tests): within cooldown suppressed, after cooldown allowed
    - Group 8 — Time gap handling (3 tests): large gap skipped, zero delta no crash, negative delta no crash
    - Group 9 — Missing/invalid data (6 tests): missing speed fallback, all null speeds, duplicate timestamps, duplicate coords no NaN, tiny movement, mixed null/non-null
    - Group 10 — Severity (4 tests): mild/hard/severe thresholds, severeCount increment
    - Group 11 — Event fields (4 tests): valid coordinates, positive duration, non-negative speedReduction, count consistency
    - Group 12 — BrakingAnalysis model (2 tests): empty factory, derived counts
    - Group 13 — BrakingDetectorConfig (4 tests): default values, high threshold, low threshold, custom suddenStopEndSpeedKmh
    - Group 14 — Service integration (4 tests): non-null on empty track, non-null on normal track, detects event, custom detector injection
    - Group 15 — NaN/Infinity safety (2 tests): hard braking event finite, long track all finite
    - Group 16 — Performance (1 test): 10 000 points in 27 ms
- [x] BrakingEvent model with all required fields
- [x] BrakingEventType (hardBraking, suddenStop)
- [x] BrakingEventSeverity (mild, hard, severe)
- [x] BrakingAnalysis with derived counts (single authoritative source)
- [x] BrakingDetectorConfig with 8 centralised, documented thresholds
- [x] BrakingDetector: single-pass O(n) algorithm
- [x] Multi-point evidence requirement (minBrakingSegments)
- [x] Cooldown/debounce (cooldownDistanceM)
- [x] GPS noise resistance (minStartSpeed, maxTimeGap, speed source preference)
- [x] Event deduplication (sudden stop is not also counted as hard braking)
- [x] Severity derived from peak deceleration
- [x] Event location = peak deceleration GPS coordinates
- [x] Event timestamp = peak deceleration GPS timestamp
- [x] No NaN or Infinity in any output
- [x] Raw GPS speedKmh preferred over derived speed
- [x] Derived speed fallback when raw speed unavailable
- [x] Large time gaps skipped
- [x] Zero/negative time deltas handled safely
- [x] `DrivingAnalytics.brakingAnalysis` populated by `DrivingAnalyticsService`
- [x] `BrakingAnalysis.empty()` returned for empty tracks
- [x] Dependency injection: `BrakingDetector` injectable into service
- [x] No database changes
- [x] No UI changes
- [x] No new packages
- [x] All existing Phase 5 and Phase 6.1–6.2 tests continue passing

---

## Phase 7 — Profile & Settings

**Status: ⬜ Not started**

---

## Phase 8 — Testing & Polish

**Status: ⬜ Not started**
