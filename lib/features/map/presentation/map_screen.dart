import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../models/destination.dart';
import '../providers/destination_provider.dart';
import '../providers/map_provider.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import 'widgets/map_info_bar.dart';
import 'widgets/map_top_bar.dart';

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
/// Displays an OpenStreetMap tile map inside a rounded container.
/// Handles location permission states with appropriate UI feedback.
///
/// Phase 4.2 additions:
/// - [MapController] attached from [mapProvider] for programmatic camera moves.
/// - Tap on the map creates a destination via [destinationProvider].
/// - Destination marker rendered alongside the user location marker.
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
              // ── Map or permission state ──────────────────────────────────
              _MapBody(mapState: mapState),

              // ── Top bar overlay ──────────────────────────────────────────
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: const MapTopBar(),
              ),

              // ── Bottom info bar overlay ──────────────────────────────────
              Positioned(
                bottom: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: const MapInfoBar(),
              ),

              // ── Re-center button ─────────────────────────────────────────
              if (mapState.isReady && mapState.currentLocation != null)
                Positioned(
                  bottom: 88,
                  right: AppSpacing.md,
                  child: _RecenterButton(),
                ),
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
// Live flutter_map — with destination marker + tap-to-select
// ---------------------------------------------------------------------------

class _LiveMap extends ConsumerWidget {
  const _LiveMap();

  // OSM tile URL template — standard tiles, no API key needed.
  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    final destination = ref.watch(destinationProvider);
    final mapNotifier = ref.read(mapProvider.notifier);

    final center = mapState.currentLocation ?? LocationService.defaultLocation;

    return FlutterMap(
      mapController: mapNotifier.mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        minZoom: 3,
        maxZoom: 19,
        // Tap on the map sets the destination.
        onTap: (tapPosition, point) =>
            _onMapTap(context, ref, point),
      ),
      children: [
        // Tile layer — OSM standard.
        TileLayer(
          urlTemplate: _osmTileUrl,
          userAgentPackageName: 'com.triprank.app',
        ),

        // Markers layer — user location + optional destination.
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

            // Destination marker.
            if (destination != null)
              Marker(
                point: destination.latLng,
                width: 40,
                height: 56,
                // Anchor at the pin tip so the point of the pin sits exactly
                // on the tapped coordinate.
                alignment: Alignment.topCenter,
                child: const _DestinationMarker(),
              ),
          ],
        ),
      ],
    );
  }

  /// Handle tap: reverse-geocode the point and set destination.
  void _onMapTap(
      BuildContext context, WidgetRef ref, LatLng point) async {
    final geocodingService = const GeocodingService();
    final name = await geocodingService.reverseLookup(
      point.latitude,
      point.longitude,
    );

    final destination = Destination(
      name: name,
      latitude: point.latitude,
      longitude: point.longitude,
    );

    ref.read(destinationProvider.notifier).setDestination(destination);
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
  const _RecenterButton();

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
