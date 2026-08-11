import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../cars/providers/vehicle_provider.dart';
import '../../models/trip.dart';
import '../dialogs/delete_trip_dialog.dart';
import 'polyline_thumbnail.dart';

// ---------------------------------------------------------------------------
// TripCard
// ---------------------------------------------------------------------------

/// Rich list-item card for a single completed trip.
///
/// Layout:
/// ```
/// ┌──────────────────────────────────────────┐
/// │ [thumb]  Date + Time               [🗑️]  │
/// │          Destination / Free Drive         │
/// │          Vehicle                          │
/// │          Avg speed  Time  Distance        │
/// └──────────────────────────────────────────┘
/// ```
///
/// Tapping the card (except the delete icon) navigates to Trip Stats.
class TripCard extends ConsumerWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.trackPoints,
  });

  final Trip trip;

  /// GPS points for the polyline thumbnail.  May be empty while loading.
  final List<LatLng> trackPoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = trip.startTime.toLocal();
    final dateStr = _formatDate(date);
    final timeStr = _formatTime(date);

    // Vehicle label — look up from provider.
    final vehicleState = ref.watch(vehicleProvider).value;
    final vehicle = vehicleState?.vehicles
        .where((v) => v.id == trip.vehicleId)
        .firstOrNull;
    final vehicleLabel =
        vehicle != null ? '${vehicle.brand} ${vehicle.model}' : 'Unknown vehicle';

    // Destination line.
    final isDestMode = trip.mode == TripMode.destination;
    final destLabel =
        isDestMode ? (trip.destinationName ?? 'Unknown destination') : null;

    // Stats.
    final avgSpeedLabel = trip.averageSpeedKmh != null
        ? '${trip.averageSpeedKmh!.toStringAsFixed(0)} km/h'
        : '— km/h';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          onTap: () => context.go(AppRoutes.tripStatsPath(trip.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Polyline thumbnail ────────────────────────────────────
                PolylineThumbnail(
                  points: trackPoints,
                  size: 76,
                ),
                const SizedBox(width: AppSpacing.md),

                // ── Text content ──────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date + time row.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '$dateStr · $timeStr',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          // Delete button — separate tap target.
                          _DeleteButton(trip: trip, dateStr: dateStr),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Destination or free-drive label.
                      if (destLabel != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              size: 13,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                destLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.explore_rounded,
                              size: 13,
                              color: AppColors.textSecondaryDark,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Free Drive',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],

                      // Vehicle.
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_car_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              vehicleLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Stats row: avg speed · duration · distance.
                      _StatsRow(
                        avgSpeed: avgSpeedLabel,
                        duration: trip.durationLabel,
                        distance: trip.distanceLabel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Formatters ────────────────────────────────────────────────────────────

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
// _DeleteButton
// ---------------------------------------------------------------------------

class _DeleteButton extends ConsumerWidget {
  const _DeleteButton({required this.trip, required this.dateStr});

  final Trip trip;
  final String dateStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final label = trip.destinationName ?? dateStr;
        await showDeleteTripDialog(
          context: context,
          tripId: trip.id,
          tripLabel: label,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Icon(
          Icons.delete_outline_rounded,
          size: 18,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatsRow
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.avgSpeed,
    required this.duration,
    required this.distance,
  });

  final String avgSpeed;
  final String duration;
  final String distance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.labelMedium?.copyWith(
      color: AppColors.textPrimaryDark,
      fontWeight: FontWeight.w600,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
    );

    return Row(
      children: [
        _StatChip(
          icon: Icons.speed_rounded,
          value: avgSpeed,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
        ),
        const SizedBox(width: AppSpacing.md),
        _StatChip(
          icon: Icons.timer_outlined,
          value: duration,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
        ),
        const SizedBox(width: AppSpacing.md),
        _StatChip(
          icon: Icons.straighten_rounded,
          value: distance,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    this.valueStyle,
    this.labelStyle,
  });

  final IconData icon;
  final String value;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 3),
        Text(value, style: valueStyle),
      ],
    );
  }
}
