import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../providers/destination_provider.dart';
import '../../providers/route_provider.dart';

// ---------------------------------------------------------------------------
// StartDriveButton
// ---------------------------------------------------------------------------

/// Floating "START" button positioned alongside the recenter control.
///
/// Appearance and label:
/// - Always shows "START" for this phase.
/// - Highlighted in [AppColors.success] (green) when a route is ready —
///   visually signals the user that the route is calculated and ready to use.
/// - Subtle loading ring replaces the icon while the route is calculating.
///
/// Behaviour (this phase only — no navigation launched):
/// - No destination: tapping START will later enter Reckless Mode.
/// - Destination selected: tapping START will later enter Destination Mode.
///
/// The button is always visible once the map is ready.
/// It never triggers navigation or trip recording in Phase 4.3.
class StartDriveButton extends ConsumerWidget {
  const StartDriveButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(destinationProvider);
    final route = ref.watch(routeProvider);

    final bool isCalculating = route.isCalculating;
    final bool isReady = route.isReady;
    final bool hasDestination = destination != null;

    // Colour: green when route is ready, primary blue otherwise.
    final Color buttonColor =
        isReady ? AppColors.success : AppColors.primary;

    final brightness = Theme.of(context).brightness;
    final Color bgColor = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => _onTap(context, hasDestination, route.isReady),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon: spinner while calculating, play icon otherwise.
              if (isCalculating)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: buttonColor,
                ),

              const SizedBox(width: AppSpacing.xs),

              // Label.
              Text(
                'START',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: buttonColor,
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
  // Tap handler — Phase 4.3: UI shell only
  // ---------------------------------------------------------------------------

  void _onTap(BuildContext context, bool hasDestination, bool routeReady) {
    // Phase 4.3: button is wired but does not launch navigation.
    // Future phases will branch here:
    //   hasDestination && routeReady → Destination Mode (Phase 5)
    //   !hasDestination             → Reckless Mode (Phase 5)
    //
    // For now show a brief snackbar to confirm the button is wired.
    final message = hasDestination
        ? 'Route ready. Drive recording will start in Phase 5.'
        : 'No destination. Reckless mode will start in Phase 5.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
