import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../models/drive_state.dart';
import '../../providers/destination_provider.dart';
import '../../providers/drive_provider.dart';
import '../../providers/route_provider.dart';

// ---------------------------------------------------------------------------
// StartDriveButton
// ---------------------------------------------------------------------------

/// The primary action button on the map screen.
///
/// States:
/// - Idle, no destination → "START" (blue) — starts Reckless Mode.
/// - Idle, destination selected, route calculating → spinner.
/// - Idle, destination selected, route ready → "START ROUTE" (green) — starts Destination Mode.
/// - Starting → "STARTING…" with spinner (disabled).
/// - Active → "FINISH" (red) — finishes the active drive.
/// - Finishing → "FINISHING…" with spinner (disabled).
class StartDriveButton extends ConsumerWidget {
  const StartDriveButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveProvider);
    final destination = ref.watch(destinationProvider);
    final route = ref.watch(routeProvider);

    final brightness = Theme.of(context).brightness;
    final Color bgColor = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    // Determine button content from combined state.
    final config = _ButtonConfig.from(
      driveStatus: drive.status,
      hasDestination: destination != null,
      routeCalculating: route.isCalculating,
      routeReady: route.isReady,
    );

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: config.enabled
            ? () => _onTap(context, ref, drive.status)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon / spinner.
              if (config.showSpinner)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: config.color,
                  ),
                )
              else
                Icon(config.icon, size: 18, color: config.color),

              const SizedBox(width: AppSpacing.xs),

              // Label.
              Text(
                config.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: config.color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tap handler
  // ---------------------------------------------------------------------------

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    DriveStatus status,
  ) async {
    final notifier = ref.read(driveProvider.notifier);

    if (status == DriveStatus.active) {
      // ── FINISH ────────────────────────────────────────────────────────────
      //
      // finishDrive() returns the completed Trip ID on success, or null if
      // persistence failed.  Navigate to Trip Stats only when we have a valid
      // ID — never navigate to a non-existent trip.
      final tripId = await notifier.finishDrive();

      if (!context.mounted) return;

      if (tripId != null) {
        // Navigate to Trip Stats for the completed trip.
        // vehicleTripsProvider is already invalidated inside finishDrive().
        context.go(AppRoutes.tripStatsPath(tripId));
      } else {
        // Persistence failed — inform the user but do not navigate.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Trip could not be saved. Your drive data may be incomplete.',
            ),
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // ── START ──────────────────────────────────────────────────────────────
    final destination = ref.read(destinationProvider);
    final error = await notifier.startDrive(destination: destination);

    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error.contains('could not be launched')
              ? AppColors.warning // warning — drive is still active
              : AppColors.error,  // fatal — drive did not start
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// _ButtonConfig — derives label, icon, color, enabled from state
// ---------------------------------------------------------------------------

class _ButtonConfig {
  const _ButtonConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.showSpinner,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool showSpinner;
  final bool enabled;

  factory _ButtonConfig.from({
    required DriveStatus driveStatus,
    required bool hasDestination,
    required bool routeCalculating,
    required bool routeReady,
  }) {
    switch (driveStatus) {
      case DriveStatus.starting:
        return _ButtonConfig(
          label: 'STARTING…',
          icon: Icons.play_arrow_rounded,
          color: AppColors.primary,
          showSpinner: true,
          enabled: false,
        );

      case DriveStatus.active:
        return _ButtonConfig(
          label: 'FINISH',
          icon: Icons.stop_rounded,
          color: AppColors.error,
          showSpinner: false,
          enabled: true,
        );

      case DriveStatus.finishing:
        return _ButtonConfig(
          label: 'FINISHING…',
          icon: Icons.stop_rounded,
          color: AppColors.error,
          showSpinner: true,
          enabled: false,
        );

      case DriveStatus.completed:
      case DriveStatus.error:
      case DriveStatus.idle:
        if (hasDestination && routeCalculating) {
          return _ButtonConfig(
            label: 'START ROUTE',
            icon: Icons.play_arrow_rounded,
            color: AppColors.primary,
            showSpinner: true,
            enabled: false,
          );
        }
        if (hasDestination && routeReady) {
          return _ButtonConfig(
            label: 'START ROUTE',
            icon: Icons.navigation_rounded,
            color: AppColors.success,
            showSpinner: false,
            enabled: true,
          );
        }
        if (hasDestination) {
          // Route in error state — still allow starting Destination Mode.
          return _ButtonConfig(
            label: 'START ROUTE',
            icon: Icons.navigation_rounded,
            color: AppColors.primary,
            showSpinner: false,
            enabled: true,
          );
        }
        // No destination → Reckless Mode.
        return _ButtonConfig(
          label: 'START',
          icon: Icons.play_arrow_rounded,
          color: AppColors.primary,
          showSpinner: false,
          enabled: true,
        );
    }
  }
}
