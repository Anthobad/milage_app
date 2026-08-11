import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';

// ---------------------------------------------------------------------------
// DataPoint
// ---------------------------------------------------------------------------

/// A single data point on the graph — time on X axis, value on Y axis.
class DataPoint {
  const DataPoint({required this.timeSeconds, required this.value});

  /// Seconds from the start of the trip.
  final double timeSeconds;

  /// Y-axis value (speed in km/h or altitude in m).
  final double value;
}

// ---------------------------------------------------------------------------
// InteractiveGraph
// ---------------------------------------------------------------------------

/// Full-width interactive line graph for trip data (speed or altitude).
///
/// Features:
/// - Fills available screen width — no horizontal scrolling required.
/// - No horizontal pan / zoom — the whole dataset always fits on screen.
/// - Touch/drag to select a data point → shows crosshair + tooltip.
/// - Axis labels, grid lines, fill area under the curve.
/// - Dark theme compatible.
class InteractiveGraph extends StatefulWidget {
  const InteractiveGraph({
    super.key,
    required this.dataPoints,
    required this.title,
    required this.yUnit,
    this.lineColor = AppColors.primaryLight,
    this.fillColor,
  });

  /// Ordered list of data points (time → value).
  final List<DataPoint> dataPoints;

  /// Graph section title (e.g. "Speed", "Altitude").
  final String title;

  /// Unit label for the Y axis (e.g. "km/h", "m").
  final String yUnit;

  /// Colour of the plotted line.
  final Color lineColor;

  /// Fill colour under the line (defaults to [lineColor] at low opacity).
  final Color? fillColor;

  @override
  State<InteractiveGraph> createState() => _InteractiveGraphState();
}

class _InteractiveGraphState extends State<InteractiveGraph> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.dataPoints.isEmpty) {
      return _empty(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(
              bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                _titleIcon(),
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                widget.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // ── Tooltip ────────────────────────────────────────────────────
        _Tooltip(
          dataPoints: widget.dataPoints,
          selectedIndex: _selectedIndex,
          yUnit: widget.yUnit,
        ),

        const SizedBox(height: AppSpacing.xs),

        // ── Canvas ─────────────────────────────────────────────────────
        AspectRatio(
          aspectRatio: 2.6,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) =>
                _updateSelection(details.localPosition),
            onTapDown: (details) =>
                _updateSelection(details.localPosition),
            onPanEnd: (_) {/* keep last selected */},
            child: CustomPaint(
              painter: _GraphPainter(
                dataPoints: widget.dataPoints,
                selectedIndex: _selectedIndex,
                lineColor: widget.lineColor,
                fillColor: widget.fillColor ??
                    widget.lineColor.withValues(alpha: 0.18),
                yUnit: widget.yUnit,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateSelection(Offset localPos) {
    if (widget.dataPoints.isEmpty) return;
    // Find nearest data point by X position.
    setState(() {
      _selectedIndex = _nearestIndex(localPos.dx);
    });
  }

  int _nearestIndex(double x) {
    if (widget.dataPoints.isEmpty) return 0;
    // We need the render box width to compute the mapping.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final w = box.size.width;
    if (w <= 0) return 0;

    // Map pixel X to time domain.
    final minT = widget.dataPoints.first.timeSeconds;
    final maxT = widget.dataPoints.last.timeSeconds;
    final tRange = maxT - minT;
    if (tRange <= 0) return 0;

    final t = minT + (x / w) * tRange;

    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < widget.dataPoints.length; i++) {
      final d = (widget.dataPoints[i].timeSeconds - t).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  IconData _titleIcon() {
    if (widget.yUnit == 'km/h') return Icons.speed_rounded;
    if (widget.yUnit == 'm') return Icons.terrain_rounded;
    return Icons.show_chart_rounded;
  }

  Widget _empty(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(_titleIcon(), size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${widget.title} — no data',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Tooltip
// ---------------------------------------------------------------------------

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.dataPoints,
    required this.selectedIndex,
    required this.yUnit,
  });

  final List<DataPoint> dataPoints;
  final int? selectedIndex;
  final String yUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurface.withValues(alpha: 0.35);

    if (selectedIndex == null || dataPoints.isEmpty) {
      return Text(
        'Touch graph to inspect',
        style: theme.textTheme.bodySmall?.copyWith(color: dim),
      );
    }

    final pt = dataPoints[selectedIndex!];
    final timeLabel = _fmtTime(pt.timeSeconds);
    final valueLabel = '${pt.value.toStringAsFixed(1)} $yUnit';

    return Row(
      children: [
        const Icon(Icons.access_time_rounded,
            size: 13, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          timeLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(
          yUnit == 'km/h' ? Icons.speed_rounded : Icons.terrain_rounded,
          size: 13,
          color: AppColors.primaryLight,
        ),
        const SizedBox(width: 4),
        Text(
          valueLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static String _fmtTime(double seconds) {
    final s = seconds.round();
    final m = s ~/ 60;
    final rem = s % 60;
    if (m > 0) return '${m}m ${rem}s';
    return '${rem}s';
  }
}

// ---------------------------------------------------------------------------
// _GraphPainter
// ---------------------------------------------------------------------------

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.dataPoints,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.yUnit,
  });

  final List<DataPoint> dataPoints;
  final int? selectedIndex;
  final Color lineColor;
  final Color fillColor;
  final String yUnit;

  static const double _paddingTop = 12;
  static const double _paddingBottom = 28; // room for X axis labels
  static const double _paddingLeft = 42;   // room for Y axis labels
  static const double _paddingRight = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final graphRect = Rect.fromLTRB(
      _paddingLeft,
      _paddingTop,
      size.width - _paddingRight,
      size.height - _paddingBottom,
    );

    final minY = dataPoints.map((p) => p.value).reduce(math.min);
    final maxY = dataPoints.map((p) => p.value).reduce(math.max);
    final minT = dataPoints.first.timeSeconds;
    final maxT = dataPoints.last.timeSeconds;

    // Expand Y range slightly so the line doesn't hug the edges.
    final yRange = (maxY - minY).clamp(1.0, double.infinity);
    final yPad = yRange * 0.1;
    final yMin = (minY - yPad).floorToDouble();
    final yMax = (maxY + yPad).ceilToDouble();
    final tRange = (maxT - minT).clamp(1.0, double.infinity);

    Offset toCanvas(DataPoint p) {
      final x = graphRect.left +
          ((p.timeSeconds - minT) / tRange) * graphRect.width;
      final y = graphRect.bottom -
          ((p.value - yMin) / (yMax - yMin)) * graphRect.height;
      return Offset(x, y);
    }

    // ── Grid ─────────────────────────────────────────────────────────────
    _drawGrid(canvas, graphRect, yMin, yMax);

    // ── Fill ─────────────────────────────────────────────────────────────
    _drawFill(canvas, graphRect, toCanvas);

    // ── Line ─────────────────────────────────────────────────────────────
    _drawLine(canvas, toCanvas);

    // ── Axis labels ───────────────────────────────────────────────────────
    _drawYLabels(canvas, size, graphRect, yMin, yMax);
    _drawXLabels(canvas, size, graphRect, minT, maxT);

    // ── Crosshair ────────────────────────────────────────────────────────
    if (selectedIndex != null) {
      _drawCrosshair(canvas, graphRect, toCanvas(dataPoints[selectedIndex!]));
    }
  }

  void _drawGrid(Canvas canvas, Rect r, double yMin, double yMax) {
    final paint = Paint()
      ..color = AppColors.surfaceVariantDark.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    const steps = 4;
    for (int i = 0; i <= steps; i++) {
      final y = r.bottom - (i / steps) * r.height;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
    }
    // Vertical grid — 4 divisions.
    for (int i = 0; i <= 4; i++) {
      final x = r.left + (i / 4) * r.width;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), paint);
    }
  }

  void _drawFill(Canvas canvas, Rect r, Offset Function(DataPoint) project) {
    final fillPath = Path();
    final first = project(dataPoints.first);
    fillPath.moveTo(first.dx, r.bottom);
    fillPath.lineTo(first.dx, first.dy);
    for (int i = 1; i < dataPoints.length; i++) {
      final p = project(dataPoints[i]);
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(project(dataPoints.last).dx, r.bottom);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
  }

  void _drawLine(Canvas canvas, Offset Function(DataPoint) project) {
    final linePath = Path();
    final first = project(dataPoints.first);
    linePath.moveTo(first.dx, first.dy);
    for (int i = 1; i < dataPoints.length; i++) {
      final p = project(dataPoints[i]);
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawYLabels(
      Canvas canvas, Size size, Rect r, double yMin, double yMax) {
    const steps = 4;
    final textPaint = _textPainter();
    for (int i = 0; i <= steps; i++) {
      final v = yMin + (yMax - yMin) * i / steps;
      final y = r.bottom - (i / steps) * r.height;
      final label = v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}k'
          : v.toStringAsFixed(0);
      textPaint.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 9,
          fontFamily: 'Inter',
        ),
      );
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(_paddingLeft - textPaint.width - 4, y - textPaint.height / 2),
      );
    }
  }

  void _drawXLabels(
      Canvas canvas, Size size, Rect r, double minT, double maxT) {
    final tRange = maxT - minT;
    final textPaint = _textPainter();
    const divisions = 4;
    for (int i = 0; i <= divisions; i++) {
      final t = minT + tRange * i / divisions;
      final x = r.left + (i / divisions) * r.width;
      final label = _fmtTime(t - minT);
      textPaint.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 9,
          fontFamily: 'Inter',
        ),
      );
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(
          x - textPaint.width / 2,
          r.bottom + 4,
        ),
      );
    }
  }

  void _drawCrosshair(Canvas canvas, Rect r, Offset pt) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // Vertical line.
    canvas.drawLine(Offset(pt.dx, r.top), Offset(pt.dx, r.bottom), linePaint);
    // Dot on line.
    canvas.drawCircle(
        pt,
        4,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        pt,
        4,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  TextPainter _textPainter() => TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

  static String _fmtTime(double seconds) {
    final s = seconds.round();
    final m = s ~/ 60;
    final h = m ~/ 60;
    if (h > 0) return '${h}h${m % 60}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.dataPoints != dataPoints ||
      old.selectedIndex != selectedIndex ||
      old.lineColor != lineColor;
}
