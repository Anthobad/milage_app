import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';

// ---------------------------------------------------------------------------
// PolylineThumbnail
// ---------------------------------------------------------------------------

/// Square thumbnail that visualises a GPS route using [CustomPainter].
///
/// Features:
/// - Dark background
/// - Subtle grid lines
/// - Bright polyline scaled to fit (maintains shape/aspect ratio)
/// - Rounded corners via [ClipRRect]
/// - Padding around the route so it does not touch the edges
///
/// Accepts a list of [LatLng] points (from [TrackPointRecord.latLng]).
/// If the list is empty, shows a placeholder icon.
class PolylineThumbnail extends StatelessWidget {
  const PolylineThumbnail({
    super.key,
    required this.points,
    this.size = 72.0,
  });

  /// Ordered list of GPS points that make up the route.
  final List<LatLng> points;

  /// Side length of the square thumbnail in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PolylinePainter(points: points),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PolylinePainter
// ---------------------------------------------------------------------------

class _PolylinePainter extends CustomPainter {
  _PolylinePainter({required this.points});

  final List<LatLng> points;

  // ── Paint objects (created once) ──────────────────────────────────────────

  static final Paint _bgPaint = Paint()
    ..color = AppColors.backgroundDark
    ..style = PaintingStyle.fill;

  static final Paint _gridPaint = Paint()
    ..color = AppColors.surfaceVariantDark.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;

  static final Paint _routePaint = Paint()
    ..color = AppColors.primaryLight
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _startDotPaint = Paint()
    ..color = AppColors.success
    ..style = PaintingStyle.fill;

  static final Paint _endDotPaint = Paint()
    ..color = AppColors.error
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    // ── Background ─────────────────────────────────────────────────────────
    canvas.drawRect(Offset.zero & size, _bgPaint);

    // ── Grid ───────────────────────────────────────────────────────────────
    _drawGrid(canvas, size);

    // ── Route ──────────────────────────────────────────────────────────────
    if (points.length < 2) {
      _drawPlaceholder(canvas, size);
      return;
    }

    final path = _buildScaledPath(size);
    if (path == null) {
      _drawPlaceholder(canvas, size);
      return;
    }

    canvas.drawPath(path.routePath, _routePaint);

    // Start / end dots.
    const dotR = 3.0;
    canvas.drawCircle(path.startPoint, dotR, _startDotPaint);
    canvas.drawCircle(path.endPoint, dotR, _endDotPaint);
  }

  // ── Grid ───────────────────────────────────────────────────────────────

  void _drawGrid(Canvas canvas, Size size) {
    const cols = 4;
    const rows = 4;

    for (int i = 1; i < cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }
    for (int i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }
  }

  // ── Route path building ─────────────────────────────────────────────────

  _ScaledPath? _buildScaledPath(Size canvasSize) {
    // Compute geographic bounding box.
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;

    // If all points are at the same location, show placeholder.
    if (latRange < 1e-9 && lngRange < 1e-9) return null;

    // Padding: 15% on each side.
    const pad = 0.15;
    final drawW = canvasSize.width * (1 - 2 * pad);
    final drawH = canvasSize.height * (1 - 2 * pad);
    final offsetX = canvasSize.width * pad;
    final offsetY = canvasSize.height * pad;

    // Scale to fit while maintaining aspect ratio.
    // Note: latitude increases upward in geography but Y increases downward in canvas.
    Offset project(LatLng pt) {
      double nx = lngRange > 1e-9 ? (pt.longitude - minLng) / lngRange : 0.5;
      double ny = latRange > 1e-9 ? (maxLat - pt.latitude) / latRange : 0.5;

      // Maintain aspect ratio — fit the longer dimension.
      double x, y;
      if (lngRange > 1e-9 && latRange > 1e-9) {
        // Both axes have extent — scale to fill shorter dimension.
        final scaleX = drawW / lngRange;
        final scaleY = drawH / latRange;
        final scale = scaleX < scaleY ? scaleX : scaleY;

        final scaledW = lngRange * scale;
        final scaledH = latRange * scale;
        final centreX = offsetX + drawW / 2;
        final centreY = offsetY + drawH / 2;

        x = centreX - scaledW / 2 + nx * scaledW;
        y = centreY - scaledH / 2 + ny * scaledH;
      } else if (lngRange < 1e-9) {
        // Pure vertical route.
        x = offsetX + drawW / 2;
        y = offsetY + ny * drawH;
      } else {
        // Pure horizontal route.
        x = offsetX + nx * drawW;
        y = offsetY + drawH / 2;
      }

      return Offset(x, y);
    }

    final routePath = ui.Path();
    final first = project(points.first);
    routePath.moveTo(first.dx, first.dy);
    for (int i = 1; i < points.length; i++) {
      final p = project(points[i]);
      routePath.lineTo(p.dx, p.dy);
    }

    return _ScaledPath(
      routePath: routePath,
      startPoint: first,
      endPoint: project(points.last),
    );
  }

  // ── Placeholder (no / insufficient points) ──────────────────────────────

  void _drawPlaceholder(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surfaceVariantDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final centre = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(centre, size.width * 0.2, paint);

    // Small dot in the centre.
    canvas.drawCircle(
      centre,
      3,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_PolylinePainter oldDelegate) =>
      oldDelegate.points != points;
}

// ---------------------------------------------------------------------------
// _ScaledPath — result of projection
// ---------------------------------------------------------------------------

class _ScaledPath {
  const _ScaledPath({
    required this.routePath,
    required this.startPoint,
    required this.endPoint,
  });

  final ui.Path routePath;
  final Offset startPoint;
  final Offset endPoint;
}
