import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../cars/models/vehicle.dart';
import '../../cars/providers/vehicle_provider.dart';
import '../../trips/presentation/widgets/interactive_graph.dart';
import '../models/overall_driving_analytics.dart';
import '../models/trip_data_point.dart';
import '../providers/overall_analytics_provider.dart';

// ---------------------------------------------------------------------------
// AnalyticsScreen — Phase 6.6
// ---------------------------------------------------------------------------

/// Overall driving analytics dashboard for the currently selected vehicle.
///
/// Aggregates statistics across ALL trips belonging to the selected vehicle.
/// Trips from other vehicles are never shown here.
///
/// Data flow:
///   AnalyticsScreen
///       ↓
///   vehicleProvider (selectedVehicleId)
///       ↓
///   overallAnalyticsProvider(vehicleId)
///       ↓
///   OverallAnalyticsState / OverallDrivingAnalytics
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleProvider);

    // Loading vehicle state.
    if (vehicleAsync.isLoading) {
      return const _Shell(vehicle: null, child: _LoadingBody());
    }

    final vehicleState = vehicleAsync.value;
    final selectedId = vehicleState?.selectedVehicleId;

    // No vehicle selected.
    if (selectedId == null) {
      return const _Shell(
        vehicle: null,
        child: _EmptyStateView(
          icon: Icons.directions_car_outlined,
          title: 'No vehicle selected',
          subtitle:
              'Select a vehicle using the Cars tab\nto see your driving analytics.',
        ),
      );
    }

    final vehicle = vehicleState?.vehicles
        .where((v) => v.id == selectedId)
        .firstOrNull;

    return _AnalyticsDashboard(vehicleId: selectedId, vehicle: vehicle);
  }
}

// ---------------------------------------------------------------------------
// _Shell — common scaffold structure
// ---------------------------------------------------------------------------

class _Shell extends StatelessWidget {
  const _Shell({required this.vehicle, required this.child});
  final Vehicle? vehicle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AnalyticsDashboard — wires the provider
// ---------------------------------------------------------------------------

class _AnalyticsDashboard extends ConsumerWidget {
  const _AnalyticsDashboard({required this.vehicleId, required this.vehicle});
  final String vehicleId;
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overallAnalyticsProvider(vehicleId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () =>
              ref.read(overallAnalyticsProvider(vehicleId).notifier).reload(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AnalyticsHeader(vehicle: vehicle),
                      const SizedBox(height: AppSpacing.md),
                      _buildContent(context, ref, state),
                      const SizedBox(
                          height: AppSpacing.bottomNavHeight + AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, OverallAnalyticsState state) {
    if (state.isLoading) return const _LoadingBody();

    if (state.error != null) {
      return _ErrorBody(
        message: state.error!,
        onRetry: () =>
            ref.read(overallAnalyticsProvider(vehicleId).notifier).reload(),
      );
    }

    final analytics = state.analytics;
    if (analytics == null || analytics.isEmpty) {
      return const _EmptyStateView(
        icon: Icons.route_rounded,
        title: 'No trips yet',
        subtitle:
            'Complete your first drive to see\nyour overall driving analytics here.',
      );
    }

    return _DashboardBody(analytics: analytics);
  }
}

// ---------------------------------------------------------------------------
// _AnalyticsHeader
// ---------------------------------------------------------------------------

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({required this.vehicle});
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (vehicle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.directions_car_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    '${vehicle!.brand} ${vehicle!.model}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
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
// _DashboardBody — all stats sections
// ---------------------------------------------------------------------------

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.analytics});
  final OverallDrivingAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final pts = analytics.tripDataPoints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Overview
        _OverviewCard(analytics: analytics),
        const SizedBox(height: AppSpacing.md),

        // 2. Driving stats
        _DrivingStatsCard(analytics: analytics),
        const SizedBox(height: AppSpacing.md),

        // 3. Driving events (turns + braking) — only if data exists
        if (_hasEventData()) ...[
          _EventsCard(analytics: analytics),
          const SizedBox(height: AppSpacing.md),
        ],

        // 4. Altitude — only if data exists
        if (_hasAltitudeData()) ...[
          _AltitudeCard(analytics: analytics),
          const SizedBox(height: AppSpacing.md),
        ],

        // 5. Distance trend graph
        if (pts.length >= 2) ...[
          _TrendGraphCard(
            title: 'Distance per trip',
            icon: Icons.straighten_rounded,
            dataPoints: _distancePoints(pts),
            yUnit: 'km',
            lineColor: AppColors.primaryLight,
            tripDataPoints: pts,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 6. Avg speed trend graph
        if (_hasAvgSpeedTrend(pts)) ...[
          _TrendGraphCard(
            title: 'Average speed per trip',
            icon: Icons.speed_rounded,
            dataPoints: _avgSpeedPoints(pts),
            yUnit: 'km/h',
            lineColor: AppColors.success,
            fillColor: AppColors.success.withValues(alpha: 0.15),
            tripDataPoints: pts,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 7. Max speed trend graph
        if (_hasMaxSpeedTrend(pts))
          _TrendGraphCard(
            title: 'Top speed per trip',
            icon: Icons.arrow_upward_rounded,
            dataPoints: _maxSpeedPoints(pts),
            yUnit: 'km/h',
            lineColor: AppColors.warning,
            fillColor: AppColors.warning.withValues(alpha: 0.12),
            tripDataPoints: pts,
          ),
      ],
    );
  }

  bool _hasEventData() =>
      analytics.totalLeftTurns != null ||
      analytics.totalRightTurns != null ||
      analytics.totalHardBraking != null ||
      analytics.totalSuddenStops != null ||
      analytics.totalUTurns != null;

  bool _hasAltitudeData() =>
      analytics.minimumAltitudeM != null ||
      analytics.maximumAltitudeM != null ||
      analytics.totalElevationGainM != null ||
      analytics.totalElevationLossM != null;

  bool _hasAvgSpeedTrend(List<TripDataPoint> pts) =>
      pts.length >= 2 &&
      pts.any((p) => p.averageSpeedKmh != null && p.averageSpeedKmh!.isFinite);

  bool _hasMaxSpeedTrend(List<TripDataPoint> pts) =>
      pts.length >= 2 &&
      pts.any((p) => p.maximumSpeedKmh != null && p.maximumSpeedKmh!.isFinite);

  List<DataPoint> _distancePoints(List<TripDataPoint> pts) {
    final result = <DataPoint>[];
    for (int i = 0; i < pts.length; i++) {
      final v = pts[i].distanceKm;
      if (v.isFinite) result.add(DataPoint(timeSeconds: i.toDouble(), value: v));
    }
    return result;
  }

  List<DataPoint> _avgSpeedPoints(List<TripDataPoint> pts) {
    final result = <DataPoint>[];
    for (int i = 0; i < pts.length; i++) {
      final v = pts[i].averageSpeedKmh;
      if (v != null && v.isFinite) {
        result.add(DataPoint(timeSeconds: i.toDouble(), value: v));
      }
    }
    return result;
  }

  List<DataPoint> _maxSpeedPoints(List<TripDataPoint> pts) {
    final result = <DataPoint>[];
    for (int i = 0; i < pts.length; i++) {
      final v = pts[i].maximumSpeedKmh;
      if (v != null && v.isFinite) {
        result.add(DataPoint(timeSeconds: i.toDouble(), value: v));
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// _OverviewCard
// ---------------------------------------------------------------------------

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.analytics});
  final OverallDrivingAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Overview', icon: Icons.bar_chart_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                  icon: Icons.route_rounded,
                  label: 'Trips',
                  value: '${analytics.tripCount}'),
              const _VDivider(),
              _StatCell(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: analytics.totalDistanceLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.dividerDark),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                  icon: Icons.timer_rounded,
                  label: 'Drive time',
                  value: analytics.totalDurationLabel),
              const _VDivider(),
              _StatCell(
                  icon: Icons.trending_flat_rounded,
                  label: 'Avg speed',
                  value: _fmtSpeed(analytics.averageSpeedKmh),
                  valueColor: analytics.averageSpeedKmh != null
                      ? AppColors.success
                      : null),
              const _VDivider(),
              _StatCell(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Top speed',
                  value: _fmtSpeed(analytics.maximumSpeedKmh),
                  valueColor: analytics.maximumSpeedKmh != null
                      ? AppColors.warning
                      : null),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtSpeed(double? v) =>
      (v != null && v.isFinite) ? '${v.toStringAsFixed(0)} km/h' : '—';
}

// ---------------------------------------------------------------------------
// _DrivingStatsCard
// ---------------------------------------------------------------------------

class _DrivingStatsCard extends StatelessWidget {
  const _DrivingStatsCard({required this.analytics});
  final OverallDrivingAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
              title: 'Driving statistics', icon: Icons.speed_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                  icon: Icons.trending_flat_rounded,
                  label: 'Avg speed',
                  value: _fmtSpeed(analytics.averageSpeedKmh)),
              const _VDivider(),
              _StatCell(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Min speed',
                  value: _fmtSpeed(analytics.minimumSpeedKmh)),
              const _VDivider(),
              _StatCell(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Max speed',
                  value: _fmtSpeed(analytics.maximumSpeedKmh)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.dividerDark),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatCell(
                  icon: Icons.pause_circle_outline_rounded,
                  label: 'Stops',
                  value: analytics.totalStops != null
                      ? '${analytics.totalStops}'
                      : '—'),
              const _VDivider(),
              _StatCell(
                  icon: Icons.timer_outlined,
                  label: 'Moving time',
                  value: _fmtMoving(analytics.movingDurationSeconds)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtSpeed(double? v) =>
      (v != null && v.isFinite) ? '${v.toStringAsFixed(0)} km/h' : '—';

  String _fmtMoving(double? v) {
    if (v == null || !v.isFinite) return '—';
    final s = v.round();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }
}

// ---------------------------------------------------------------------------
// _EventsCard
// ---------------------------------------------------------------------------

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.analytics});
  final OverallDrivingAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final hasTurns = analytics.totalLeftTurns != null ||
        analytics.totalRightTurns != null ||
        analytics.totalUTurns != null;
    final hasBraking = analytics.totalHardBraking != null ||
        analytics.totalSuddenStops != null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
              title: 'Driving events', icon: Icons.warning_amber_rounded),
          const SizedBox(height: AppSpacing.sm),
          if (hasTurns) ...[
            Row(
              children: [
                _StatCell(
                  icon: Icons.turn_left_rounded,
                  label: 'Left turns',
                  value: analytics.totalLeftTurns != null
                      ? '${analytics.totalLeftTurns}'
                      : '—',
                  valueColor: AppColors.primary,
                ),
                const _VDivider(),
                _StatCell(
                  icon: Icons.turn_right_rounded,
                  label: 'Right turns',
                  value: analytics.totalRightTurns != null
                      ? '${analytics.totalRightTurns}'
                      : '—',
                  valueColor: AppColors.warning,
                ),
                const _VDivider(),
                _StatCell(
                  icon: Icons.u_turn_right_rounded,
                  label: 'U-turns',
                  value: analytics.totalUTurns != null
                      ? '${analytics.totalUTurns}'
                      : '—',
                ),
              ],
            ),
          ],
          if (hasTurns && hasBraking) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.dividerDark),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (hasBraking)
            Row(
              children: [
                _StatCell(
                  icon: Icons.speed_rounded,
                  label: 'Hard braking',
                  value: analytics.totalHardBraking != null
                      ? '${analytics.totalHardBraking}'
                      : '—',
                  valueColor: (analytics.totalHardBraking ?? 0) > 0
                      ? AppColors.warning
                      : null,
                ),
                const _VDivider(),
                _StatCell(
                  icon: Icons.front_hand_rounded,
                  label: 'Sudden stops',
                  value: analytics.totalSuddenStops != null
                      ? '${analytics.totalSuddenStops}'
                      : '—',
                  valueColor: (analytics.totalSuddenStops ?? 0) > 0
                      ? AppColors.error
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AltitudeCard
// ---------------------------------------------------------------------------

class _AltitudeCard extends StatelessWidget {
  const _AltitudeCard({required this.analytics});
  final OverallDrivingAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final hasGainLoss = analytics.totalElevationGainM != null ||
        analytics.totalElevationLossM != null;

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
                  label: 'Min altitude',
                  value: _fmtAlt(analytics.minimumAltitudeM)),
              const _VDivider(),
              _StatCell(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Max altitude',
                  value: _fmtAlt(analytics.maximumAltitudeM)),
            ],
          ),
          if (hasGainLoss) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.dividerDark),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _StatCell(
                  icon: Icons.trending_up_rounded,
                  label: 'Elevation gain',
                  value: _fmtAlt(analytics.totalElevationGainM),
                  valueColor: AppColors.success,
                ),
                const _VDivider(),
                _StatCell(
                  icon: Icons.trending_down_rounded,
                  label: 'Elevation loss',
                  value: _fmtAlt(analytics.totalElevationLossM),
                  valueColor: AppColors.warning,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtAlt(double? v) =>
      (v != null && v.isFinite) ? '${v.toStringAsFixed(0)} m' : '—';
}

// ---------------------------------------------------------------------------
// _TrendGraphCard
// ---------------------------------------------------------------------------

/// Cross-trip trend graph. X-axis = trip index (0,1,2…), Y-axis = metric.
/// Tapping shows the trip date + value. Navigates to Trip Stats on tap.
class _TrendGraphCard extends StatefulWidget {
  const _TrendGraphCard({
    required this.title,
    required this.icon,
    required this.dataPoints,
    required this.yUnit,
    required this.lineColor,
    required this.tripDataPoints,
    this.fillColor,
  });

  final String title;
  final IconData icon;
  final List<DataPoint> dataPoints;
  final String yUnit;
  final Color lineColor;
  final Color? fillColor;
  final List<TripDataPoint> tripDataPoints;

  @override
  State<_TrendGraphCard> createState() => _TrendGraphCardState();
}

class _TrendGraphCardState extends State<_TrendGraphCard> {
  int? _selectedIdx;

  @override
  Widget build(BuildContext context) {
    if (widget.dataPoints.isEmpty) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryDark,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildTooltip(context),
          const SizedBox(height: AppSpacing.xs),
          AspectRatio(
            aspectRatio: 2.6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => _onTouch(d.localPosition.dx),
              onTapDown: (d) => _onTouch(d.localPosition.dx),
              child: CustomPaint(
                painter: _TrendPainter(
                  dataPoints: widget.dataPoints,
                  selectedIndex: _selectedIdx,
                  lineColor: widget.lineColor,
                  fillColor: widget.fillColor ??
                      widget.lineColor.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurface.withValues(alpha: 0.35);

    if (_selectedIdx == null || widget.dataPoints.isEmpty) {
      return Text('Touch graph to inspect',
          style: theme.textTheme.bodySmall?.copyWith(color: dim));
    }

    final idx = _selectedIdx!;
    if (idx >= widget.dataPoints.length) {
      return Text('Touch graph to inspect',
          style: theme.textTheme.bodySmall?.copyWith(color: dim));
    }

    final dp = widget.dataPoints[idx];
    // timeSeconds is the trip index (0, 1, 2…).
    final tripIdx =
        dp.timeSeconds.round().clamp(0, widget.tripDataPoints.length - 1);
    final tdp = widget.tripDataPoints[tripIdx];

    final dateStr = _fmtDate(tdp.startTime.toLocal());
    final valueStr = '${dp.value.toStringAsFixed(1)} ${widget.yUnit}';

    return GestureDetector(
      onTap: () => context.go(AppRoutes.tripStatsPath(tdp.tripId)),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(dateStr,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: AppColors.textPrimaryDark)),
          const SizedBox(width: AppSpacing.md),
          Icon(widget.icon, size: 13, color: widget.lineColor),
          const SizedBox(width: 4),
          Text(
            valueStr,
            style: theme.textTheme.labelMedium?.copyWith(
              color: widget.lineColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const Icon(Icons.open_in_new_rounded,
              size: 12, color: AppColors.textSecondaryDark),
        ],
      ),
    );
  }

  void _onTouch(double localX) {
    if (widget.dataPoints.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final w = box.size.width;
    if (w <= 0) return;

    final minT = widget.dataPoints.first.timeSeconds;
    final maxT = widget.dataPoints.last.timeSeconds;
    final tRange = (maxT - minT).clamp(1.0, double.infinity);
    final t = minT + (localX / w) * tRange;

    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < widget.dataPoints.length; i++) {
      final d = (widget.dataPoints[i].timeSeconds - t).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    setState(() => _selectedIdx = best);
  }

  static String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// _TrendPainter
// ---------------------------------------------------------------------------

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.dataPoints,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
  });

  final List<DataPoint> dataPoints;
  final int? selectedIndex;
  final Color lineColor;
  final Color fillColor;

  static const double _pTop = 12;
  static const double _pBottom = 28;
  static const double _pLeft = 42;
  static const double _pRight = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final r = Rect.fromLTRB(
        _pLeft, _pTop, size.width - _pRight, size.height - _pBottom);

    final minY =
        dataPoints.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY =
        dataPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minT = dataPoints.first.timeSeconds;
    final maxT = dataPoints.last.timeSeconds;

    final yRange = (maxY - minY).clamp(1.0, double.infinity);
    final yPad = yRange * 0.1;
    final yMin = (minY - yPad).floorToDouble();
    final yMax = (maxY + yPad).ceilToDouble();
    final tRange = (maxT - minT).clamp(1.0, double.infinity);

    Offset toCanvas(DataPoint p) {
      final x = r.left + ((p.timeSeconds - minT) / tRange) * r.width;
      final y = r.bottom - ((p.value - yMin) / (yMax - yMin)) * r.height;
      return Offset(x, y);
    }

    // Grid.
    final gridPaint = Paint()
      ..color = AppColors.surfaceVariantDark.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = r.bottom - (i / 4) * r.height;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), gridPaint);
    }
    final cols = dataPoints.length.clamp(2, 5);
    for (int i = 0; i < cols; i++) {
      final x = r.left + (i / (cols - 1)) * r.width;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), gridPaint);
    }

    // Fill.
    final fillPath = Path();
    final first = toCanvas(dataPoints.first);
    fillPath.moveTo(first.dx, r.bottom);
    fillPath.lineTo(first.dx, first.dy);
    for (int i = 1; i < dataPoints.length; i++) {
      final o = toCanvas(dataPoints[i]);
      fillPath.lineTo(o.dx, o.dy);
    }
    fillPath.lineTo(toCanvas(dataPoints.last).dx, r.bottom);
    fillPath.close();
    canvas.drawPath(
        fillPath, Paint()..color = fillColor..style = PaintingStyle.fill);

    // Line.
    final linePath = Path();
    linePath.moveTo(first.dx, first.dy);
    for (int i = 1; i < dataPoints.length; i++) {
      final o = toCanvas(dataPoints[i]);
      linePath.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // Y labels.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 4; i++) {
      final v = yMin + (yMax - yMin) * i / 4;
      final y = r.bottom - (i / 4) * r.height;
      final label =
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);
      tp.text = TextSpan(
        text: label,
        style: const TextStyle(
            color: AppColors.textSecondaryDark, fontSize: 9, fontFamily: 'Inter'),
      );
      tp.layout();
      tp.paint(canvas, Offset(_pLeft - tp.width - 4, y - tp.height / 2));
    }

    // X labels (trip numbers).
    for (int i = 0; i < cols; i++) {
      final t = minT + (maxT - minT) * i / (cols - 1);
      final x = r.left + (i / (cols - 1)) * r.width;
      tp.text = TextSpan(
        text: '${t.round() + 1}',
        style: const TextStyle(
            color: AppColors.textSecondaryDark, fontSize: 9, fontFamily: 'Inter'),
      );
      tp.layout(maxWidth: 30);
      tp.paint(canvas, Offset(x - tp.width / 2, r.bottom + 4));
    }

    // Crosshair.
    if (selectedIndex != null && selectedIndex! < dataPoints.length) {
      final pt = toCanvas(dataPoints[selectedIndex!]);
      canvas.drawLine(Offset(pt.dx, r.top), Offset(pt.dx, r.bottom),
          Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 1);
      canvas.drawCircle(pt, 4, Paint()..color = lineColor..style = PaintingStyle.fill);
      canvas.drawCircle(
          pt,
          4,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.dataPoints != dataPoints || old.selectedIndex != selectedIndex;
}

// ---------------------------------------------------------------------------
// Loading / empty / error states
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: _Card(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Computing analytics…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondaryDark),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondaryDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textPrimaryDark)),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
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
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondaryDark),
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
      child: VerticalDivider(width: 1, color: AppColors.dividerDark),
    );
  }
}
