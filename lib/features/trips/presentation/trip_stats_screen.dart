import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../../core/services/unit_service.dart';
import '../../analytics/models/altitude_analysis.dart';
import '../../analytics/models/analyzed_track_point.dart';
import '../../analytics/models/braking_analysis.dart';
import '../../analytics/models/stop_analysis.dart';
import '../../analytics/models/turn_analysis.dart';
import '../../analytics/providers/trip_analytics_provider.dart';
import '../../cars/providers/vehicle_provider.dart';
import '../models/trip.dart';
import 'widgets/interactive_graph.dart';
import 'widgets/turn_split_bar.dart';

// ---------------------------------------------------------------------------
// TripStatsScreen
// ---------------------------------------------------------------------------

/// Vertically-scrollable Trip Stats page — Phase 6.5 integration.
///
/// Single data source: [tripAnalyticsProvider(tripId)] which exposes:
///   • [TripAnalyticsState.trip]      — persisted [Trip] summary
///   • [TripAnalyticsState.analytics] — full [DrivingAnalytics] result
///
/// Sections (top → bottom):
///   1. Trip header: date/time + FROM/TO (destination) or Free Drive (reckless).
///   2. Route map (flutter_map, fits polyline, pan/zoom, offline-safe).
///   3. Main stats card (distance, duration, stops, vehicle).
///   4. Speed stats card (avg/min/max).
///   5. Altitude stats card (min/max).
///   6. Speed graph (interactive, from analyzedPoints).
///   7. Altitude graph (interactive, from analyzedPoints).
///   8. Additional stats (elevation gain/loss, trip mode, U-turns).
///   9. Braking / stop statistics.
///  10. Turn split bar (left/right counts from TurnAnalysis).
///
/// ## Data rule
///
/// All values come from [tripAnalyticsProvider].  No SQLite access, no GPS
/// calculations inside widgets.  Persisted [Trip] values (distance, duration,
/// speed/altitude extremes) take precedence over derived values where both
/// exist.
///
/// ## Null safety
///
/// NaN and Infinity are never displayed.  Missing values show "—".
/// Analytics sections show loading indicators while [isLoading] is true.
class TripStatsScreen extends ConsumerWidget {
  const TripStatsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripAnalyticsProvider(tripId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(context),
      body: _buildBody(context, ref, state),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.backgroundDark,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.trips);
          }
        },
      ),
      title: const Text('Trip Details'),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(
      BuildContext context, WidgetRef ref, TripAnalyticsState state) {
    // Full-screen error when trip itself could not be loaded.
    if (!state.isLoading && state.error != null && state.trip == null) {
      return _ErrorView(message: state.error!);
    }

    // Full-screen spinner only while the initial trip row is being loaded.
    if (state.isLoading && state.trip == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // If trip is not yet available but we're loading, keep spinner.
    final trip = state.trip;
    if (trip == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final analytics = state.analytics;

    // Derive graph data from analyzedPoints — no GPS math in the widget.
    final analyzedPoints = analytics?.analyzedPoints ?? const [];

    // Route polyline from analyzedPoints.
    final polylineLatLngs = analyzedPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Unit service — provides unit-aware formatting for all displays.
    final unitService = ref.watch(unitServiceProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Header ────────────────────────────────────────────────────
          _TripHeader(trip: trip),
          const SizedBox(height: AppSpacing.md),

          // ── 2. Route map ─────────────────────────────────────────────────
          _RouteMapCard(
            polylinePoints: polylineLatLngs,
            startLatitude: trip.startLatitude,
            startLongitude: trip.startLongitude,
            isLoading: state.isLoading,
            errorMessage:
                (state.error != null && state.trip != null) ? state.error : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 3. Main stats ─────────────────────────────────────────────────
          _CoreStatsCard(trip: trip, ref: ref, unitService: unitService),
          const SizedBox(height: AppSpacing.md),

          // ── 4. Speed stats ────────────────────────────────────────────────
          if (trip.averageSpeedKmh != null) ...[
            _SpeedStatsCard(trip: trip, unitService: unitService),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── 5. Altitude stats ─────────────────────────────────────────────
          if (trip.minimumAltitudeM != null) ...[
            _AltitudeStatsCard(trip: trip, unitService: unitService),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── 6. Speed graph ────────────────────────────────────────────────
          _GraphCard(
            title: 'Speed over time',
            isLoading: state.isLoading,
            child: _toSpeedPoints(analyzedPoints, trip.startTime, unitService).isEmpty && !state.isLoading
                ? const _NoDataLabel(label: 'No speed data recorded.')
                : InteractiveGraph(
                    dataPoints: _toSpeedPoints(
                        analyzedPoints, trip.startTime, unitService),
                    title: 'Speed',
                    yUnit: unitService.speedUnit,
                    lineColor: AppColors.primaryLight,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 7. Altitude graph ─────────────────────────────────────────────
          _GraphCard(
            title: 'Altitude over time',
            isLoading: state.isLoading,
            child: _toAltitudePoints(analyzedPoints, trip.startTime, unitService).isEmpty && !state.isLoading
                ? const _NoDataLabel(label: 'No altitude data recorded.')
                : InteractiveGraph(
                    dataPoints: _toAltitudePoints(
                        analyzedPoints, trip.startTime, unitService),
                    title: 'Altitude',
                    yUnit: unitService.altitudeUnit,
                    lineColor: AppColors.success,
                    fillColor: AppColors.success.withValues(alpha: 0.15),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 8. Additional analytics ───────────────────────────────────────
          _AdditionalStatsCard(
            trip: trip,
            altitudeAnalysis: analytics?.altitudeAnalysis,
            turnAnalysis: analytics?.turnAnalysis,
            isLoading: state.isLoading,
            unitService: unitService,
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 9. Braking / stop statistics ──────────────────────────────────
          _BrakingStopCard(
            brakingAnalysis: analytics?.brakingAnalysis,
            stopAnalysis: analytics?.stopAnalysis,
            stopCountFromTrip: trip.stops,
            isLoading: state.isLoading,
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 10. Turn split bar ────────────────────────────────────────────
          _TurnCard(
            turnAnalysis: analytics?.turnAnalysis,
            isLoading: state.isLoading,
          ),

          // Extra space above the bottom nav bar.
          const SizedBox(
              height: AppSpacing.bottomNavHeight + AppSpacing.xl + 32),
        ],
      ),
    );
  }

  // ── Data helpers — convert analyzedPoints to DataPoints ───────────────────

  /// Convert analyzed points to speed DataPoints using [unitService].
  ///
  /// Uses [AnalyzedTrackPoint.bestSpeedKmh] (raw GPS preferred, derived
  /// fallback).  X-axis = elapsed seconds from [tripStart].
  /// Values are converted to the display unit before graphing.
  static List<DataPoint> _toSpeedPoints(
      List<AnalyzedTrackPoint> pts,
      DateTime tripStart,
      UnitService unitService) {
    if (pts.isEmpty) return const [];
    final result = <DataPoint>[];
    for (final p in pts) {
      final speed = p.bestSpeedKmh;
      if (speed == null || speed.isNaN || speed.isInfinite) continue;
      final elapsed =
          p.timestamp.difference(tripStart).inMilliseconds / 1000.0;
      if (elapsed < 0) continue;
      // Convert km/h to display unit.
      final displaySpeed = unitService.convertSpeed(speed);
      if (displaySpeed.isNaN || displaySpeed.isInfinite) continue;
      result.add(DataPoint(timeSeconds: elapsed, value: displaySpeed));
    }
    return result;
  }

  /// Convert analyzed points to altitude DataPoints using [unitService].
  ///
  /// Only points with non-null altitude are included.
  /// X-axis = elapsed seconds from [tripStart].
  /// Values are converted to the display unit before graphing.
  static List<DataPoint> _toAltitudePoints(
      List<AnalyzedTrackPoint> pts,
      DateTime tripStart,
      UnitService unitService) {
    if (pts.isEmpty) return const [];
    final result = <DataPoint>[];
    for (final p in pts) {
      final alt = p.altitude;
      if (alt == null || alt.isNaN || alt.isInfinite) continue;
      final elapsed =
          p.timestamp.difference(tripStart).inMilliseconds / 1000.0;
      if (elapsed < 0) continue;
      // Convert metres to display unit.
      final displayAlt = unitService.convertAltitude(alt);
      if (displayAlt.isNaN || displayAlt.isInfinite) continue;
      result.add(DataPoint(timeSeconds: elapsed, value: displayAlt));
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// _TripHeader — Section 1
// ---------------------------------------------------------------------------

/// Trip header showing date/time and destination or reckless mode info.
///
/// Destination mode: shows FROM (start) and TO (destination) labels.
/// Reckless mode: shows "Free Drive — no destination".
///
/// No network requests are made here.  Uses only persisted [Trip] fields.
class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = trip.startTime.toLocal();
    final dateStr = _formatDate(local);
    final timeStr = _formatTime(local);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date + time row.
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppColors.textSecondaryDark),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$timeStr · $dateStr',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Destination mode: FROM/TO.
        if (trip.mode == TripMode.destination) ...[
          _LocationRow(
            label: 'FROM',
            name: trip.startName ?? _coordLabel(trip.startLatitude, trip.startLongitude),
            icon: Icons.radio_button_checked_rounded,
            iconColor: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.xs),
          _LocationRow(
            label: 'TO',
            name: trip.destinationName ??
                (trip.destinationLatitude != null
                    ? _coordLabel(
                        trip.destinationLatitude!, trip.destinationLongitude!)
                    : 'Unknown destination'),
            icon: Icons.place_rounded,
            iconColor: AppColors.error,
          ),
        ] else ...[
          // Reckless mode.
          Row(
            children: [
              const Icon(Icons.explore_rounded,
                  size: 14, color: AppColors.textSecondaryDark),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Free Drive — no destination',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _coordLabel(double lat, double lng) {
    final latStr = lat.toStringAsFixed(4);
    final lngStr = lng.toStringAsFixed(4);
    return '$latStr, $lngStr';
  }
}

/// A labeled location row used in destination mode header.
class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.name,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String name;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label  ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimaryDark,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _RouteMapCard — Section 2
// ---------------------------------------------------------------------------

/// Map card showing the GPS route polyline.
///
/// Uses [polylinePoints] derived from [analytics.analyzedPoints].
/// The map fits the full route automatically when opened.
/// Pan and zoom are enabled.
///
/// ## Offline behavior
///
/// Tile errors are silently swallowed — [errorTileCallback] does nothing.
/// The polyline is drawn from stored lat/lng coordinates and remains visible
/// even when tiles fail to load.  Statistics are not dependent on tiles.
class _RouteMapCard extends StatefulWidget {
  const _RouteMapCard({
    required this.polylinePoints,
    required this.startLatitude,
    required this.startLongitude,
    required this.isLoading,
    this.errorMessage,
  });

  final List<LatLng> polylinePoints;
  final double startLatitude;
  final double startLongitude;
  final bool isLoading;
  final String? errorMessage;

  @override
  State<_RouteMapCard> createState() => _RouteMapCardState();
}

class _RouteMapCardState extends State<_RouteMapCard> {
  late final MapController _mapController;
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(_RouteMapCard old) {
    super.didUpdateWidget(old);
    // Fit route once when the polyline first becomes available.
    if (!_fitted &&
        widget.polylinePoints.isNotEmpty &&
        old.polylinePoints.isEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    }
  }

  void _fitRoute() {
    if (widget.polylinePoints.isEmpty) return;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: widget.polylinePoints,
          padding: const EdgeInsets.all(32),
          minZoom: 10,
          maxZoom: 17,
        ),
      );
    } catch (_) {
      // Map may not be rendered yet; the fit will happen on next update.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pts = widget.polylinePoints;
    final hasValidStart = widget.startLatitude != 0 || widget.startLongitude != 0;
    final center = hasValidStart
        ? LatLng(widget.startLatitude, widget.startLongitude)
        : const LatLng(33.888, 35.495);

    return _Card(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: SizedBox(
          height: 240,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13.0,
                  minZoom: 3.0,
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.triprank.app',
                    // Silently ignore tile errors — polyline still shows.
                    errorTileCallback: (tile, error, stackTrace) {},
                  ),
                  if (pts.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: pts,
                          strokeWidth: 4.0,
                          color: AppColors.primaryLight,
                        ),
                      ],
                    ),
                  if (pts.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: pts.first,
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                        Marker(
                          point: pts.last,
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Loading chip.
              if (widget.isLoading)
                Positioned(
                  bottom: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Loading route…',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Analytics error chip (non-blocking — route/stats may still load).
              if (widget.errorMessage != null)
                Positioned(
                  bottom: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      'Analytics unavailable',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
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
// _CoreStatsCard — Section 3
// ---------------------------------------------------------------------------

/// Main statistics card: distance, duration, stops, vehicle.
class _CoreStatsCard extends StatelessWidget {
  const _CoreStatsCard({required this.trip, required this.ref, required this.unitService});
  final Trip trip;
  final WidgetRef ref;
  final UnitService unitService;

  @override
  Widget build(BuildContext context) {
    // Vehicle lookup — gracefully handles deleted vehicle.
    final vehicleAsync = ref.watch(vehicleProvider);
    final vehicleState = vehicleAsync.value;
    final vehicle = vehicleState?.vehicles
        .where((v) => v.id == trip.vehicleId)
        .firstOrNull;

    final vehicleLabel = trip.vehicleId == null
        ? '—'
        : vehicle != null
            ? '${vehicle.brand} ${vehicle.model}'
            : 'Vehicle unavailable';

    final stopsLabel =
        trip.stops != null ? '${trip.stops}' : '—';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Summary', icon: Icons.info_outline_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                icon: Icons.straighten_rounded,
                label: 'Distance',
                value: unitService.formatDistance(trip.distanceKm),
              ),
              const _VDivider(),
              _StatCell(
                icon: Icons.timer_rounded,
                label: 'Duration',
                value: trip.durationLabel,
              ),
              const _VDivider(),
              _StatCell(
                icon: Icons.pause_circle_outline_rounded,
                label: 'Stops',
                value: stopsLabel,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.dividerDark),
          const SizedBox(height: AppSpacing.sm),
          // Vehicle row.
          Row(
            children: [
              const Icon(Icons.directions_car_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  vehicleLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: trip.vehicleId != null && vehicle == null
                            ? AppColors.textSecondaryDark
                            : AppColors.textPrimaryDark,
                        fontStyle: trip.vehicleId != null && vehicle == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SpeedStatsCard — Section 4
// ---------------------------------------------------------------------------

class _SpeedStatsCard extends StatelessWidget {
  const _SpeedStatsCard({required this.trip, required this.unitService});
  final Trip trip;
  final UnitService unitService;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Speed', icon: Icons.speed_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                icon: Icons.trending_flat_rounded,
                label: 'Average',
                value: unitService.formatSpeedOrDash(trip.averageSpeedKmh),
              ),
              const _VDivider(),
              _StatCell(
                icon: Icons.arrow_downward_rounded,
                label: 'Minimum',
                value: unitService.formatSpeedOrDash(trip.minimumSpeedKmh),
              ),
              const _VDivider(),
              _StatCell(
                icon: Icons.arrow_upward_rounded,
                label: 'Maximum',
                value: unitService.formatSpeedOrDash(trip.maximumSpeedKmh),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AltitudeStatsCard — Section 5
// ---------------------------------------------------------------------------

class _AltitudeStatsCard extends StatelessWidget {
  const _AltitudeStatsCard({required this.trip, required this.unitService});
  final Trip trip;
  final UnitService unitService;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Altitude', icon: Icons.terrain_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                icon: Icons.arrow_downward_rounded,
                label: 'Minimum',
                value: unitService.formatAltitudeOrDash(trip.minimumAltitudeM),
              ),
              const _VDivider(),
              _StatCell(
                icon: Icons.arrow_upward_rounded,
                label: 'Maximum',
                value: unitService.formatAltitudeOrDash(trip.maximumAltitudeM),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GraphCard — wrapper for Sections 6 & 7
// ---------------------------------------------------------------------------

class _GraphCard extends StatelessWidget {
  const _GraphCard({
    required this.title,
    required this.isLoading,
    required this.child,
  });

  final String title;
  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryDark,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Loading…',
                    style: TextStyle(color: AppColors.textSecondaryDark)),
              ],
            ),
          ],
        ),
      );
    }
    return _Card(child: child);
  }
}

// ---------------------------------------------------------------------------
// _AdditionalStatsCard — Section 8
// ---------------------------------------------------------------------------

/// Additional analytics section: elevation gain/loss, trip mode, U-turns.
///
/// Only displays rows that have valid (non-null) data.
class _AdditionalStatsCard extends StatelessWidget {
  const _AdditionalStatsCard({
    required this.trip,
    required this.altitudeAnalysis,
    required this.turnAnalysis,
    required this.isLoading,
    required this.unitService,
  });

  final Trip trip;
  final AltitudeAnalysis? altitudeAnalysis;
  final TurnAnalysis? turnAnalysis;
  final bool isLoading;
  final UnitService unitService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];

    // Trip mode.
    rows.add(_InfoRow(
      icon: Icons.route_rounded,
      label: 'Trip mode',
      value: trip.mode == TripMode.destination ? 'Destination' : 'Free Drive',
    ));

    // Elevation gain.
    final gain = altitudeAnalysis?.totalElevationGainM;
    if (gain != null && !gain.isNaN && !gain.isInfinite) {
      rows.add(_InfoRow(
        icon: Icons.trending_up_rounded,
        label: 'Elevation gain',
        value: unitService.formatElevation(gain),
        valueColor: AppColors.success,
      ));
    }

    // Elevation loss.
    final loss = altitudeAnalysis?.totalElevationLossM;
    if (loss != null && !loss.isNaN && !loss.isInfinite) {
      rows.add(_InfoRow(
        icon: Icons.trending_down_rounded,
        label: 'Elevation loss',
        value: unitService.formatElevation(loss),
        valueColor: AppColors.warning,
      ));
    }

    // U-turns (if any).
    final uTurns = turnAnalysis?.uTurns;
    if (uTurns != null && uTurns > 0) {
      rows.add(_InfoRow(
        icon: Icons.u_turn_right_rounded,
        label: 'U-turns',
        value: '$uTurns',
      ));
    }

    if (isLoading && altitudeAnalysis == null) {
      // Show a compact loading state — only for the analytics-derived rows.
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              title: 'Details',
              icon: Icons.analytics_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Mode row is always available.
            _InfoRow(
              icon: Icons.route_rounded,
              label: 'Trip mode',
              value: trip.mode == TripMode.destination
                  ? 'Destination'
                  : 'Free Drive',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.primary)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Computing elevation…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Details',
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...rows.expand((row) => [row, const SizedBox(height: AppSpacing.xs)]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BrakingStopCard — Section 9
// ---------------------------------------------------------------------------

/// Compact braking and stop statistics section.
///
/// Uses [brakingAnalysis] for hard braking and sudden stop counts,
/// and [stopCountFromTrip] (persisted) as the authoritative stop count.
class _BrakingStopCard extends StatelessWidget {
  const _BrakingStopCard({
    required this.brakingAnalysis,
    required this.stopAnalysis,
    required this.stopCountFromTrip,
    required this.isLoading,
  });

  final BrakingAnalysis? brakingAnalysis;
  final StopAnalysis? stopAnalysis;
  final int? stopCountFromTrip;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && brakingAnalysis == null) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              title: 'Safety events',
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Analyzing…',
                    style: TextStyle(
                        color: AppColors.textSecondaryDark, fontSize: 13)),
              ],
            ),
          ],
        ),
      );
    }

    final hardBraking = brakingAnalysis?.hardBrakingCount;
    final suddenStops = brakingAnalysis?.suddenStopCount;
    // Prefer persisted stop count from Trip; fall back to computed value.
    final stops = stopCountFromTrip ?? stopAnalysis?.stopCount;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Safety events',
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                icon: Icons.speed_rounded,
                label: 'Hard braking',
                value: hardBraking != null ? '$hardBraking' : '—',
                valueColor: hardBraking != null && hardBraking > 0
                    ? AppColors.warning
                    : null,
              ),
              const _VDivider(),
              _StatCell(
                icon: Icons.front_hand_rounded,
                label: 'Sudden stops',
                value: suddenStops != null ? '$suddenStops' : '—',
                valueColor: suddenStops != null && suddenStops > 0
                    ? AppColors.error
                    : null,
              ),
              const _VDivider(),
              _StatCell(
                icon: Icons.pause_circle_filled_rounded,
                label: 'Stops',
                value: stops != null ? '$stops' : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TurnCard — Section 10
// ---------------------------------------------------------------------------

/// Turn statistics section with left/right split bar and U-turn label.
class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.turnAnalysis,
    required this.isLoading,
  });

  final TurnAnalysis? turnAnalysis;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Left / Right Turns',
            icon: Icons.compare_arrows_rounded,
          ),
          const SizedBox(height: AppSpacing.md),

          if (isLoading && turnAnalysis == null)
            const Row(
              children: [
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.primary)),
                SizedBox(width: AppSpacing.sm),
                Text('Analyzing turns…',
                    style: TextStyle(
                        color: AppColors.textSecondaryDark, fontSize: 13)),
              ],
            )
          else
            TurnSplitBar(
              // Pass real counts — the widget handles null (not available)
              // and zero (no turns recorded) states internally.
              leftTurns: turnAnalysis?.leftTurns,
              rightTurns: turnAnalysis?.rightTurns,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NoDataLabel
// ---------------------------------------------------------------------------

class _NoDataLabel extends StatelessWidget {
  const _NoDataLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorView — full-screen error
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimaryDark,
                    )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _InfoRow — compact labeled value row
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondaryDark),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: valueColor ?? AppColors.textPrimaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimaryDark,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryDark,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 40,
      child: VerticalDivider(
        width: 1,
        color: AppColors.dividerDark,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
