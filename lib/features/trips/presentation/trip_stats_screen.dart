import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../models/trip.dart';
import '../models/track_point_record.dart';
import '../providers/trip_stats_provider.dart';

// ---------------------------------------------------------------------------
// TripStatsScreen
// ---------------------------------------------------------------------------

/// Displays the summary and GPS track for a completed trip.
///
/// ## Data loading strategy
///
/// The pre-computed [Trip] summary (distance, duration, speed stats) is
/// shown immediately from SQLite — no recalculation required.
///
/// The raw GPS track ([TrackPointRecord] list) loads independently and will
/// display when available.  A subtle loading indicator is shown while the
/// track is fetching.
///
/// ## Post-drive flow
///
/// After FINISH is pressed in [StartDriveButton], [DriveNotifier.finishDrive]
/// returns the trip ID and the button calls [GoRouter.go] to this screen with
/// that ID.  The newly persisted [Trip] is immediately visible.
class TripStatsScreen extends ConsumerWidget {
  const TripStatsScreen({super.key, required this.tripId});

  /// UUID of the trip to display.
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(tripStatsProvider(tripId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Trip Stats'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Navigate back — either to the map (post-drive) or the trips list.
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: _buildBody(context, stats),
    );
  }

  Widget _buildBody(BuildContext context, TripStatsState stats) {
    // Trip not yet loaded.
    if (stats.isLoadingTrip) {
      return const Center(child: CircularProgressIndicator());
    }

    // Trip load failed.
    if (stats.tripError != null) {
      return _ErrorView(message: stats.tripError!);
    }

    // Trip loaded — show everything.
    final trip = stats.trip!;
    return RefreshIndicator(
      onRefresh: () async {
        // No direct ref access here; the user can use the back button and
        // re-open the screen.  RefreshIndicator is left for future extension.
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.screenPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: date & mode ────────────────────────────────────────
            _TripHeaderCard(trip: trip),
            const SizedBox(height: AppSpacing.md),

            // ── Core statistics ────────────────────────────────────────────
            _CoreStatsCard(trip: trip),
            const SizedBox(height: AppSpacing.md),

            // ── Speed statistics ───────────────────────────────────────────
            if (trip.averageSpeedKmh != null) ...[
              _SpeedStatsCard(trip: trip),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Altitude statistics ────────────────────────────────────────
            if (trip.minimumAltitudeM != null) ...[
              _AltitudeStatsCard(trip: trip),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── GPS track section ──────────────────────────────────────────
            _TrackSection(
              isLoading: stats.isLoadingTrack,
              error: stats.trackError,
              points: stats.trackPoints,
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TripHeaderCard
// ---------------------------------------------------------------------------

class _TripHeaderCard extends StatelessWidget {
  const _TripHeaderCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = trip.startTime.toLocal();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final modeLabel =
        trip.mode == TripMode.reckless ? 'Free Drive' : 'Navigation';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                trip.mode == TripMode.reckless
                    ? Icons.explore_rounded
                    : Icons.navigation_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                modeLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$dateStr at $timeStr',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (trip.destinationName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trip.destinationName!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CoreStatsCard
// ---------------------------------------------------------------------------

class _CoreStatsCard extends StatelessWidget {
  const _CoreStatsCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          _StatCell(
            icon: Icons.straighten_rounded,
            label: 'Distance',
            value: trip.distanceLabel,
          ),
          _Divider(),
          _StatCell(
            icon: Icons.timer_rounded,
            label: 'Duration',
            value: trip.durationLabel,
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

  String _fmt(double? v) => v != null ? '${v.toStringAsFixed(0)} km/h' : '—';

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
              _Divider(),
              _StatCell(
                icon: Icons.arrow_downward_rounded,
                label: 'Minimum',
                value: _fmt(trip.minimumSpeedKmh),
              ),
              _Divider(),
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

  String _fmt(double? v) => v != null ? '${v.toStringAsFixed(0)} m' : '—';

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
              _Divider(),
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
// _TrackSection
// ---------------------------------------------------------------------------

class _TrackSection extends StatelessWidget {
  const _TrackSection({
    required this.isLoading,
    required this.error,
    required this.points,
  });

  final bool isLoading;
  final String? error;
  final List<TrackPointRecord> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'GPS Track',
            icon: Icons.route_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Loading track…'),
                ],
              ),
            )
          else if (error != null)
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
            )
          else if (points.isEmpty)
            Text(
              'No GPS points recorded.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          else
            Text(
              '${points.length} GPS points recorded.',
              style: theme.textTheme.bodyMedium,
            ),
        ],
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
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
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
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
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
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: VerticalDivider(
        width: 1,
        color: Theme.of(context).dividerColor,
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
              ),
        ),
      ],
    );
  }
}
