import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../cars/providers/vehicle_provider.dart';
import '../models/track_point_record.dart';
import '../models/trip.dart';
import '../providers/trip_stats_provider.dart';
import 'widgets/interactive_graph.dart';
import 'widgets/turn_split_bar.dart';

// ---------------------------------------------------------------------------
// TripStatsScreen
// ---------------------------------------------------------------------------

/// Vertically-scrollable Trip Stats page.
///
/// Sections (top → bottom):
///   1. Header: date/time + destination or Free Drive indicator.
///   2. Route map (flutter_map, fits polyline, pan/zoom).
///   3. Core stats card (distance, duration, stops).
///   4. Speed stats card.
///   5. Altitude stats card.
///   6. Speed graph (interactive, full width).
///   7. Altitude graph (interactive, full width).
///   8. Turn split bar (placeholder until turn detection is implemented).
///
/// Data strategy:
///   - Summary stats (section 3-5) available immediately from [Trip] row.
///   - GPS track (map, graphs) loads independently.  Loading placeholders
///     are shown until ready.
class TripStatsScreen extends ConsumerWidget {
  const TripStatsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(tripStatsProvider(tripId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(context),
      body: _buildBody(context, ref, stats),
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

  Widget _buildBody(BuildContext context, WidgetRef ref, TripStatsState stats) {
    if (stats.isLoadingTrip) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stats.tripError != null) {
      return _ErrorView(message: stats.tripError!);
    }

    final trip = stats.trip!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Header ────────────────────────────────────────────────
          _TripHeader(trip: trip),
          const SizedBox(height: AppSpacing.md),

          // ── 2. Route map ─────────────────────────────────────────────
          _RouteMapCard(
            stats: stats,
            trip: trip,
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 3. Core stats ─────────────────────────────────────────────
          _CoreStatsCard(trip: trip, ref: ref),
          const SizedBox(height: AppSpacing.md),

          // ── 4. Speed stats ────────────────────────────────────────────
          if (trip.averageSpeedKmh != null) ...[
            _SpeedStatsCard(trip: trip),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── 5. Altitude stats ─────────────────────────────────────────
          if (trip.minimumAltitudeM != null) ...[
            _AltitudeStatsCard(trip: trip),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── 6. Speed graph ────────────────────────────────────────────
          _GraphCard(
            title: 'Speed over time',
            isLoading: stats.isLoadingTrack,
            errorMessage: stats.trackError,
            child: stats.trackPoints.isEmpty && !stats.isLoadingTrack
                ? const _NoTrackLabel()
                : InteractiveGraph(
                    dataPoints: _toSpeedPoints(stats.trackPoints),
                    title: 'Speed',
                    yUnit: 'km/h',
                    lineColor: AppColors.primaryLight,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 7. Altitude graph ─────────────────────────────────────────
          _GraphCard(
            title: 'Altitude over time',
            isLoading: stats.isLoadingTrack,
            errorMessage: stats.trackError,
            child: stats.trackPoints.isEmpty && !stats.isLoadingTrack
                ? const _NoTrackLabel()
                : InteractiveGraph(
                    dataPoints: _toAltitudePoints(stats.trackPoints),
                    title: 'Altitude',
                    yUnit: 'm',
                    lineColor: AppColors.success,
                    fillColor: AppColors.success.withValues(alpha: 0.15),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 8. Turn split ─────────────────────────────────────────────
          _TurnCard(trip: trip),

          // Extra space so the turn split bar clears the bottom nav bar
          // when the user scrolls to the end.
          const SizedBox(height: AppSpacing.bottomNavHeight + AppSpacing.xl + 32),
        ],
      ),
    );
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  static List<DataPoint> _toSpeedPoints(List<TrackPointRecord> pts) {
    if (pts.isEmpty) return [];
    final origin = pts.first.timestamp;
    return pts
        .where((p) => p.speedKmh != null)
        .map((p) => DataPoint(
              timeSeconds:
                  p.timestamp.difference(origin).inMilliseconds / 1000.0,
              value: p.speedKmh!,
            ))
        .toList();
  }

  static List<DataPoint> _toAltitudePoints(List<TrackPointRecord> pts) {
    if (pts.isEmpty) return [];
    final origin = pts.first.timestamp;
    return pts
        .where((p) => p.altitude != null)
        .map((p) => DataPoint(
              timeSeconds:
                  p.timestamp.difference(origin).inMilliseconds / 1000.0,
              value: p.altitude!,
            ))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// _TripHeader
// ---------------------------------------------------------------------------

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
        // Date + time.
        Text(
          '$timeStr · $dateStr',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Destination / mode.
        if (trip.mode == TripMode.destination &&
            trip.destinationName != null) ...[
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  trip.destinationName!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              const Icon(Icons.explore_rounded,
                  size: 14, color: AppColors.textSecondaryDark),
              const SizedBox(width: 4),
              Text(
                'Free Drive — no destination',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontStyle: FontStyle.italic,
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
}

// ---------------------------------------------------------------------------
// _RouteMapCard
// ---------------------------------------------------------------------------

/// Map card showing the GPS route with flutter_map.
///
/// The map is initially fitted around the entire polyline.
/// Pan and zoom are enabled.
class _RouteMapCard extends StatefulWidget {
  const _RouteMapCard({required this.stats, required this.trip});
  final TripStatsState stats;
  final Trip trip;

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
    // Fit route once when the GPS track becomes available.
    if (!_fitted &&
        widget.stats.trackPoints.isNotEmpty &&
        old.stats.trackPoints.isEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    }
  }

  void _fitRoute() {
    final pts = widget.stats.trackPoints.map((p) => p.latLng).toList();
    if (pts.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(32),
        minZoom: 10,
        maxZoom: 17,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pts = widget.stats.trackPoints.map((p) => p.latLng).toList();

    // Initial centre — use start lat/lng from Trip.
    final startLatLng = LatLng(
      widget.trip.startLatitude,
      widget.trip.startLongitude,
    );
    final hasValidStart =
        widget.trip.startLatitude != 0 || widget.trip.startLongitude != 0;

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
                  initialCenter: hasValidStart
                      ? startLatLng
                      : const LatLng(33.888, 35.495),
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
                    errorTileCallback: (tile, error, stackTrace) {
                      // Silently ignore tile errors — polyline still shows.
                    },
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
                        // Start marker.
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
                        // End marker.
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

              // Loading overlay.
              if (widget.stats.isLoadingTrack)
                Positioned(
                  bottom: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color:
                          AppColors.backgroundDark.withValues(alpha: 0.85),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Loading route…',
                          style:
                              theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error chip.
              if (widget.stats.trackError != null)
                Positioned(
                  bottom: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.9),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      'Track unavailable',
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
// _CoreStatsCard
// ---------------------------------------------------------------------------

class _CoreStatsCard extends StatelessWidget {
  const _CoreStatsCard({required this.trip, required this.ref});
  final Trip trip;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    // Vehicle name.
    final vehicleState = ref.watch(vehicleProvider).value;
    final vehicle = vehicleState?.vehicles
        .where((v) => v.id == trip.vehicleId)
        .firstOrNull;
    final vehicleLabel =
        vehicle != null ? '${vehicle.brand} ${vehicle.model}' : '—';

    final stopsLabel =
        trip.stops != null ? '${trip.stops}' : '—';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Summary', icon: Icons.info_outline_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                icon: Icons.straighten_rounded,
                label: 'Distance',
                value: trip.distanceLabel,
              ),
              _VDivider(),
              _StatCell(
                icon: Icons.timer_rounded,
                label: 'Duration',
                value: trip.durationLabel,
              ),
              _VDivider(),
              _StatCell(
                icon: Icons.pause_circle_outline_rounded,
                label: 'Stops',
                value: stopsLabel,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
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
                        color: AppColors.textPrimaryDark,
                      ),
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
// _SpeedStatsCard
// ---------------------------------------------------------------------------

class _SpeedStatsCard extends StatelessWidget {
  const _SpeedStatsCard({required this.trip});
  final Trip trip;

  String _fmt(double? v) =>
      v != null ? '${v.toStringAsFixed(0)} km/h' : '—';

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Speed', icon: Icons.speed_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                icon: Icons.trending_flat_rounded,
                label: 'Average',
                value: _fmt(trip.averageSpeedKmh),
              ),
              _VDivider(),
              _StatCell(
                icon: Icons.arrow_downward_rounded,
                label: 'Minimum',
                value: _fmt(trip.minimumSpeedKmh),
              ),
              _VDivider(),
              _StatCell(
                icon: Icons.arrow_upward_rounded,
                label: 'Maximum',
                value: _fmt(trip.maximumSpeedKmh),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AltitudeStatsCard
// ---------------------------------------------------------------------------

class _AltitudeStatsCard extends StatelessWidget {
  const _AltitudeStatsCard({required this.trip});
  final Trip trip;

  String _fmt(double? v) =>
      v != null ? '${v.toStringAsFixed(0)} m' : '—';

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Altitude', icon: Icons.terrain_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                icon: Icons.arrow_downward_rounded,
                label: 'Minimum',
                value: _fmt(trip.minimumAltitudeM),
              ),
              _VDivider(),
              _StatCell(
                icon: Icons.arrow_upward_rounded,
                label: 'Maximum',
                value: _fmt(trip.maximumAltitudeM),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GraphCard
// ---------------------------------------------------------------------------

class _GraphCard extends StatelessWidget {
  const _GraphCard({
    required this.title,
    required this.isLoading,
    this.errorMessage,
    required this.child,
  });

  final String title;
  final bool isLoading;
  final String? errorMessage;
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
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Loading…'),
              ],
            ),
          ],
        ),
      );
    }
    if (errorMessage != null) {
      return _Card(
        child: Text(
          errorMessage!,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.error),
        ),
      );
    }
    return _Card(child: child);
  }
}

// ---------------------------------------------------------------------------
// _TurnCard
// ---------------------------------------------------------------------------

class _TurnCard extends StatelessWidget {
  const _TurnCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Left / Right Turns',
            icon: Icons.compare_arrows_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          // Turn detection not yet implemented — pass null.
          const TurnSplitBar(leftTurns: null, rightTurns: null),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NoTrackLabel
// ---------------------------------------------------------------------------

class _NoTrackLabel extends StatelessWidget {
  const _NoTrackLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        'No GPS data recorded for this trip.',
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
// _ErrorView
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
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
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
  });
  final IconData icon;
  final String label;
  final String value;

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
              color: AppColors.textPrimaryDark,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryDark,
              ),
        ),
      ],
    );
  }
}
