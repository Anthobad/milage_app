import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../models/route_result.dart';
import '../../providers/route_provider.dart';

// ---------------------------------------------------------------------------
// RouteInfoBubble
// ---------------------------------------------------------------------------

/// Minimal floating bubble that displays route distance and estimated duration
/// when a route is in the [RouteStatus.ready] state.
///
/// Positioned near the centre of the map — above the info bar — so it points
/// visually toward the drawn polyline without covering important map content.
///
/// Fades in/out smoothly as route state changes.
class RouteInfoBubble extends ConsumerWidget {
  const RouteInfoBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider);

    // Only show when a route is ready.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: route.isReady ? _Bubble(route: route) : const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Bubble body
// ---------------------------------------------------------------------------

class _Bubble extends StatelessWidget {
  const _Bubble({required this.route});

  final RouteResult route;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color bgColor = brightness == Brightness.dark
        ? AppColors.surfaceDark.withValues(alpha: 0.95)
        : AppColors.surfaceLight.withValues(alpha: 0.95);
    final Color textPrimary = brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final Color textSecondary = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Distance.
            _InfoChip(
              icon: Icons.route_outlined,
              value: route.distanceLabel,
              label: 'Distance',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // Vertical divider.
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              color: (brightness == Brightness.dark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight),
            ),

            // Duration.
            _InfoChip(
              icon: Icons.schedule_outlined,
              value: route.durationLabel,
              label: 'Duration',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info chip — icon + value + label
// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.textPrimary,
    required this.textSecondary,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textSecondary,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
