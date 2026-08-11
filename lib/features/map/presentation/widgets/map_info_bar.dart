import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../providers/drive_provider.dart';

/// Minimal floating info bar shown at the bottom of the map.
///
/// When a drive is active, shows live speed, altitude, and distance from
/// [driveProvider]. Otherwise shows placeholder dashes.
class MapInfoBar extends ConsumerWidget {
  const MapInfoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveProvider);

    final brightness = Theme.of(context).brightness;
    final Color barColor = brightness == Brightness.dark
        ? AppColors.surfaceDark.withValues(alpha: 0.92)
        : AppColors.surfaceLight.withValues(alpha: 0.92);

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
          _InfoItem(label: 'Speed', value: drive.speedLabel),
          const _Divider(),
          _InfoItem(label: 'Altitude', value: drive.altitudeLabel),
          const _Divider(),
          _InfoItem(label: 'Distance', value: drive.distanceLabel),
        ],
      ),
    );
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
