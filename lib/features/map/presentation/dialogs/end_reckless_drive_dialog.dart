import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';

// ---------------------------------------------------------------------------
// EndRecklessDriveDialog
// ---------------------------------------------------------------------------

/// Confirmation dialog shown when the user selects a destination while a
/// Reckless Mode drive is active.
///
/// The dialog does NOT perform any drive or destination state changes itself —
/// all business logic is handled by the caller via [onEndDrive].
///
/// Usage:
/// ```dart
/// final confirmed = await showEndRecklessDriveDialog(context);
/// if (confirmed == true) {
///   await ref.read(driveProvider.notifier).finishDrive();
///   ref.read(destinationProvider.notifier).setDestination(pendingDestination);
/// }
/// ```
///
/// Returns:
/// - `true`  — user confirmed "End Drive".
/// - `false` / `null` — user cancelled or dismissed.
Future<bool?> showEndRecklessDriveDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true, // tapping outside counts as Cancel.
    builder: (_) => const _EndRecklessDriveDialog(),
  );
}

class _EndRecklessDriveDialog extends StatelessWidget {
  const _EndRecklessDriveDialog();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    final Color bgColor = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final Color secondaryColor = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      // Icon at the top for quick visual context.
      icon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.warning.withValues(alpha: 0.15),
        ),
        child: Icon(
          Icons.route_rounded,
          color: AppColors.warning,
          size: 26,
        ),
      ),
      title: Text(
        'End reckless drive\nto start destination mode?',
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      content: Text(
        'Your current Reckless Mode drive will be stopped and its statistics '
        'cleared. The selected destination will be set — tap START ROUTE to '
        'begin navigation.',
        style: textTheme.bodySmall?.copyWith(color: secondaryColor),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      actions: [
        // Cancel — keep the Reckless drive going.
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            foregroundColor: secondaryColor,
            side: BorderSide(color: secondaryColor.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          child: const Text('Cancel'),
        ),

        // End Drive — confirm ending the Reckless drive.
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          child: const Text('End Drive'),
        ),
      ],
    );
  }
}
