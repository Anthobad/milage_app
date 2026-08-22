import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../models/destination.dart';
import '../models/drive_state.dart';
import '../models/route_result.dart';
import '../providers/destination_provider.dart';
import '../providers/drive_provider.dart';
import '../providers/map_provider.dart';
import '../providers/map_theme_provider.dart';
import '../providers/route_provider.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../utils/map_style_constants.dart';
import 'dialogs/end_reckless_drive_dialog.dart';
import 'widgets/map_info_bar.dart';
import 'widgets/map_top_bar.dart';
import 'widgets/route_info_bubble.dart';
import 'widgets/start_drive_button.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

/// Horizontal margin matching the floating nav bar.
const double _kHMargin = 16.0;

/// Nav bar static height (mirrors constants in main_navigation.dart).
/// vMargin(12) + vPadding*2(20) + itemHeight(52) = 84dp
const double _kNavBarStaticHeight = 84.0;

/// Extra gap between the map bottom edge and the top of the nav bar.
const double _kMapNavGap = 12.0;

/// Gap below the top safe area before the map container starts.
const double _kTopMargin = 16.0;

// ---------------------------------------------------------------------------
// MapScreen
// ---------------------------------------------------------------------------

/// Main map screen.
///
/// Phase 4.3 additions:
/// - Polyline layer drawn from [routeProvider] when route is ready.
/// - Camera auto-fits to show the full route when it becomes ready.
/// - [RouteInfoBubble] overlaid above the info bar (distance + duration).
/// - [StartDriveButton] placed above the recenter button.
/// - Subtle loading overlay while route is calculating.
/// - Error banner with retry button when route calculation fails.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Total bottom padding = nav bar height + system safe area + gap.
    final double bottomPadding =
        _kNavBarStaticHeight + bottomInset + _kMapNavGap;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.only(
          left: _kHMargin,
          right: _kHMargin,
          top: topPadding + _kTopMargin,
          bottom: bottomPadding,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Stack(
            children: [
              // ── Map or permission/loading state ──────────────────────────
              _MapBody(mapState: mapState),

              // ── Top bar overlay ──────────────────────────────────────────
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: const MapTopBar(),
              ),

              // ── Route error banner ───────────────────────────────────────
              if (mapState.isReady)
                Positioned(
                  top: AppSpacing.md + 52 + AppSpacing.sm, // below top bar
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: const _RouteErrorBanner(),
                ),

              // ── Route info bubble ────────────────────────────────────────
              if (mapState.isReady)
                Positioned(
                  bottom: 88 + AppSpacing.md + 40, // above controls stack
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: const Align(
                    alignment: Alignment.center,
                    child: RouteInfoBubble(),
                  ),
                ),

              // ── Bottom info bar overlay ──────────────────────────────────
              Positioned(
                bottom: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: const MapInfoBar(),
              ),

              // ── Map controls (recenter + start drive) ────────────────────
              if (mapState.isReady)
                Positioned(
                  bottom: 88,
                  right: AppSpacing.md,
                  child: const _MapControls(),
                ),

              // ── Route calculating overlay ────────────────────────────────
              if (mapState.isReady) const _RouteLoadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map body — handles all location states
// ---------------------------------------------------------------------------

class _MapBody extends StatelessWidget {
  const _MapBody({required this.mapState});

  final MapState mapState;

  @override
  Widget build(BuildContext context) {
    if (mapState.isLoadingLocation) {
      return const _LoadingView();
    }

    return switch (mapState.locationStatus) {
      LocationStatus.serviceDisabled => const _PermissionView(
          icon: Icons.location_disabled_outlined,
          title: 'Location Services Off',
          message: 'Enable location services on your device to use the map.',
          actionLabel: 'Open Settings',
          isSettings: true,
        ),
      LocationStatus.permissionDeniedForever => const _PermissionView(
          icon: Icons.location_off_outlined,
          title: 'Location Permission Denied',
          message:
              'Location access is permanently denied. Enable it in app settings.',
          actionLabel: 'Open App Settings',
          isSettings: true,
        ),
      LocationStatus.permissionDenied => const _PermissionView(
          icon: Icons.my_location,
          title: 'Location Permission Needed',
          message: 'TripRank needs location access to show your position.',
          actionLabel: 'Allow Access',
          isSettings: false,
        ),
      LocationStatus.ready => const _LiveMap(),
    };
  }
}

// ---------------------------------------------------------------------------
// Live flutter_map — polyline + destination + user location
// ---------------------------------------------------------------------------

class _LiveMap extends ConsumerStatefulWidget {
  const _LiveMap();

  @override
  ConsumerState<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends ConsumerState<_LiveMap> {
  // Track the last route we fitted the camera for so we don't re-fit on
  // every rebuild (e.g. on orientation changes or parent rebuilds).
  RouteResult? _lastFittedRoute;

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    final destination = ref.watch(destinationProvider);
    final route = ref.watch(routeProvider);
    final drive = ref.watch(driveProvider);
    final mapNotifier = ref.read(mapProvider.notifier);

    // ── Resolve the tile URL from mapThemeProvider ──────────────────────────
    //
    // mapThemeProvider is the single authoritative source for map appearance.
    // We default to dark during async load (matches MapThemeMode.dark default).
    final mapThemeMode =
        ref.watch(mapThemeProvider).value ?? MapThemeMode.dark;
    final systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDark = resolveMapIsDark(mapThemeMode, systemBrightness);
    final tileUrl = isDark ? kMapTileUrlDark : kMapTileUrlLight;

    final center = mapState.currentLocation ?? LocationService.defaultLocation;

    // Auto-fit camera when a new route becomes ready (only when no drive active).
    if (route.isReady && route != _lastFittedRoute && !drive.isDriving) {
      _lastFittedRoute = route;
      // Defer to after the current frame so the map controller is attached.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final points = [
          // Include current location in the bounds if available.
          if (mapState.currentLocation != null) mapState.currentLocation!,
          ...route.coordinates,
        ];
        mapNotifier.fitRoute(points);
      });
    }

    // Clear the cache if route is reset so we fit again on next route.
    if (!route.isReady) {
      _lastFittedRoute = null;
    }

    return FlutterMap(
      mapController: mapNotifier.mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        minZoom: 3,
        maxZoom: 19,
        onTap: (tapPosition, point) => _onMapTap(context, ref, point),
      ),
      children: [
        // ── Tile layer ──────────────────────────────────────────────────
        TileLayer(
          urlTemplate: tileUrl,
          userAgentPackageName: kMapTileUserAgent,
        ),

        // ── Route preview polyline (shown before drive starts) ──────────
        if (!drive.isDriving && route.isReady && route.coordinates.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.coordinates,
                color: AppColors.primary,
                strokeWidth: 5.0,
                borderColor: AppColors.primaryDark.withValues(alpha: 0.4),
                borderStrokeWidth: 2.0,
              ),
            ],
          ),

        // ── Recorded drive path polyline (shown during active drive) ────
        if (drive.isDriving && drive.path.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: drive.path,
                color: AppColors.success,
                strokeWidth: 5.0,
                borderColor: AppColors.success.withValues(alpha: 0.3),
                borderStrokeWidth: 2.0,
              ),
            ],
          ),

        // ── Markers layer ───────────────────────────────────────────────
        MarkerLayer(
          markers: [
            // User location marker.
            if (mapState.currentLocation != null)
              Marker(
                point: mapState.currentLocation!,
                width: 40,
                height: 40,
                child: const _LocationMarker(),
              ),

            // Destination marker — hidden while drive is active.
            if (destination != null && !drive.isDriving)
              Marker(
                point: destination.latLng,
                width: 40,
                height: 56,
                alignment: Alignment.topCenter,
                child: const _DestinationMarker(),
              ),
          ],
        ),
      ],
    );
  }

  /// Handle map tap: reverse-geocode the point and set destination.
  ///
  /// If a Reckless Mode drive is active, shows a confirmation dialog before
  /// ending the drive and setting the new destination.  This prevents the
  /// invalid state of Reckless + Destination modes being active simultaneously.
  void _onMapTap(BuildContext context, WidgetRef ref, LatLng point) async {
    const geocodingService = GeocodingService();
    final name = await geocodingService.reverseLookup(
      point.latitude,
      point.longitude,
    );

    if (!context.mounted) return;

    final destination = Destination(
      name: name,
      latitude: point.latitude,
      longitude: point.longitude,
    );

    final drive = ref.read(driveProvider);

    // ── Reckless drive active: confirm before switching to destination mode ──
    if (drive.isActive && drive.mode == DriveMode.reckless) {
      final confirmed = await showEndRecklessDriveDialog(context);

      if (!context.mounted) return;
      if (confirmed != true) {
        // User cancelled — keep Reckless drive unchanged, discard destination.
        return;
      }

      // End the Reckless drive before setting the destination.
      await ref.read(driveProvider.notifier).finishDrive();

      if (!context.mounted) return;
    }

    // Set destination — the START ROUTE button will now be available.
    ref.read(destinationProvider.notifier).setDestination(destination);
  }
}

// ---------------------------------------------------------------------------
// Map controls — Cancel button + Start Drive button + Re-center button
// ---------------------------------------------------------------------------

class _MapControls extends ConsumerWidget {
  const _MapControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(destinationProvider);
    final drive = ref.watch(driveProvider);
    final hasDestination = destination != null;
    final isDriving = drive.isDriving;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Cancel button — visible when a destination is chosen AND no drive is active.
        if (hasDestination && !isDriving) ...[
          const _CancelDestinationButton(),
          const SizedBox(width: AppSpacing.sm),
        ],

        // Start Drive button.
        const StartDriveButton(),
        const SizedBox(width: AppSpacing.sm),

        // Re-center button.
        _RecenterButton(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cancel destination button
// ---------------------------------------------------------------------------

/// Shown next to the START button when a destination is selected.
///
/// Tapping it:
/// 1. Clears the destination via [destinationProvider] — which automatically
///    resets the route via [routeProvider]'s `ref.listen`.
/// 2. Re-centers the camera on the user's current location.
class _CancelDestinationButton extends ConsumerWidget {
  const _CancelDestinationButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final Color bgColor = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () {
          // Clear destination — routeProvider resets automatically.
          ref.read(destinationProvider.notifier).clearDestination();
          // Return camera to user location.
          ref.read(mapProvider.notifier).recenterOnUser();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'CANCEL',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route calculating loading overlay
// ---------------------------------------------------------------------------

/// Subtle top-right spinner shown while the route is being fetched.
/// Does not cover the map — purely informational.
class _RouteLoadingOverlay extends ConsumerWidget {
  const _RouteLoadingOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: route.isCalculating
          ? Center(
              key: const ValueKey('loading'),
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Route error banner with retry
// ---------------------------------------------------------------------------

class _RouteErrorBanner extends ConsumerWidget {
  const _RouteErrorBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: route.isError
          ? _ErrorBanner(
              key: const ValueKey('error'),
              message: route.errorMessage ?? 'Route calculation failed.',
              onRetry: () => ref.read(routeProvider.notifier).retry(),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                'Retry',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User location marker
// ---------------------------------------------------------------------------

class _LocationMarker extends StatelessWidget {
  const _LocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.2),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: const Center(
        child: CircleAvatar(
          radius: 8,
          backgroundColor: AppColors.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Destination marker — pin style
// ---------------------------------------------------------------------------

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin head.
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.shade600,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.flag_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        // Pin stem.
        Container(
          width: 2.5,
          height: 10,
          color: Colors.red.shade600,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Re-center button
// ---------------------------------------------------------------------------

class _RecenterButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final Color bgColor = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => ref.read(mapProvider.notifier).recenterOnUser(),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
          child: Icon(Icons.my_location, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading view
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ColoredBox(
      color: brightness == Brightness.dark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Permission / service error view
// ---------------------------------------------------------------------------

class _PermissionView extends ConsumerWidget {
  const _PermissionView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.isSettings,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final bool isSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final Color bgColor = brightness == Brightness.dark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final Color secondaryColor = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return ColoredBox(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: secondaryColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: secondaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () =>
                  ref.read(mapProvider.notifier).requestPermission(),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
