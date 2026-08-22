import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../core/services/unit_service.dart';
import '../../providers/drive_provider.dart';

/// Minimal floating info bar shown at the bottom of the map.
///
/// When a drive is active, shows live speed, altitude, and distance from
/// [driveProvider], formatted using [unitServiceProvider] so the values
/// respect the user's selected unit system (Metric / Imperial).
///
/// Otherwise shows placeholder dashes.
///
/// UNIT-AWARE: values are formatted via [UnitService] — not hardcoded.
class MapInfoBar extends ConsumerWidget {
  const MapInfoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveProvider);
    final unitService = ref.watch(unitServiceProvider);

    final brightness = Theme.of(context).brightness;
    final Color barColor = brightness == Brightness.dark
        ? AppColors.surfaceDark.withValues(alpha: 0.92)
        : AppColors.surfaceLight.withValues(alpha: 0.92);

    // Build unit-aware labels from live drive state.
    final speedValue = drive.isDriving
        ? unitService.formatSpeed(drive.currentSpeedKmh)
        : '—';
    final altitudeValue = drive.isDriving
        ? unitService.formatAltitude(drive.currentAltitudeM)
        : '—';
    final distanceValue = drive.isDriving
        ? _formatLiveDistance(drive.distanceKm, unitService)
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoItem(label: 'Speed', value: speedValue),
          const _Divider(),
          _InfoItem(label: 'Altitude', value: altitudeValue),
          const _Divider(),
          _InfoItem(label: 'Distance', value: distanceValue),
        ],
      ),
    );
  }

  /// Formats a live distance value (in km) for the info bar.
  ///
  /// Metric:   sub-1 km shown as metres (e.g. "850 m"); otherwise km.
  /// Imperial: always shown as miles.
  ///
  /// This mirrors the short-distance logic in [UnitService.formatDistance]
  /// but uses [UnitService] so no raw conversions exist here.
  static String _formatLiveDistance(double distanceKm, UnitService unitService) {
    return unitService.formatDistance(distanceKm);
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color labelColor = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final Color valueColor = brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
              ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: 1,
      height: 28,
      color: brightness == Brightness.dark
          ? AppColors.dividerDark
          : AppColors.dividerLight,
    );
  }
}
