import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';

// ---------------------------------------------------------------------------
// TurnSplitBar
// ---------------------------------------------------------------------------

/// Visual representation of left/right turn distribution.
///
/// Displays a horizontal split bar where:
/// - Left (blue) represents left turns.
/// - Right (orange) represents right turns.
///
/// If turn detection is not yet implemented ([leftTurns] and [rightTurns]
/// are both null), shows a "not available" placeholder.
///
/// If [leftTurns] and [rightTurns] are both 0, shows a zero-turn state.
class TurnSplitBar extends StatelessWidget {
  const TurnSplitBar({
    super.key,
    this.leftTurns,
    this.rightTurns,
  });

  /// Number of left turns, or null if turn detection is not available.
  final int? leftTurns;

  /// Number of right turns, or null if turn detection is not available.
  final int? rightTurns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ── Not available ───────────────────────────────────────────────────────
    if (leftTurns == null || rightTurns == null) {
      return _NotAvailable(theme: theme);
    }

    final total = leftTurns! + rightTurns!;

    // ── Zero turns ──────────────────────────────────────────────────────────
    if (total == 0) {
      return _ZeroTurns(theme: theme);
    }

    final leftFrac = leftTurns! / total;
    final rightFrac = rightTurns! / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Bar ──────────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                // Left side.
                Expanded(
                  flex: (leftFrac * 100).round().clamp(1, 99),
                  child: Container(
                    color: AppColors.primary,
                    alignment: Alignment.centerLeft,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: leftFrac > 0.15
                        ? Text(
                            '${leftTurns!}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
                // Right side.
                Expanded(
                  flex: (rightFrac * 100).round().clamp(1, 99),
                  child: Container(
                    color: AppColors.warning,
                    alignment: Alignment.centerRight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: rightFrac > 0.15
                        ? Text(
                            '${rightTurns!}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Labels ──────────────────────────────────────────────────────
        Row(
          children: [
            // Left.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.turn_left_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${leftTurns!} left  '
                  '(${(leftFrac * 100).toStringAsFixed(0)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Right.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '(${(rightFrac * 100).toStringAsFixed(0)}%)  '
                  '${rightTurns!} right',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.turn_right_rounded,
                    size: 16, color: AppColors.warning),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _NotAvailable
// ---------------------------------------------------------------------------

class _NotAvailable extends StatelessWidget {
  const _NotAvailable({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.dividerDark,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            size: 16,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turn detection not yet available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                Text(
                  'Turn counting will be added in a future update.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondaryDark.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ZeroTurns
// ---------------------------------------------------------------------------

class _ZeroTurns extends StatelessWidget {
  const _ZeroTurns({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.straighten_rounded,
            size: 16,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'No turns recorded for this trip.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
