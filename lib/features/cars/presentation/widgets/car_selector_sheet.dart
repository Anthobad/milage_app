import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/vehicle_provider.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../dialogs/add_vehicle_dialog.dart';
import '../dialogs/delete_vehicle_dialog.dart';
import 'vehicle_tile.dart';

/// Vehicle selector sheet content.
///
/// Rendered directly inside the [MainNavigation] Stack — not as a modal.
/// This keeps the floating nav bar fully interactive while the sheet is open.
///
/// Positioning (margins, gap above nav bar, corner radius) is handled by
/// the parent Stack, not by this widget.
class CarSelectorSheet extends ConsumerWidget {
  const CarSelectorSheet({
    super.key,
    required this.onClose,
  });

  /// Called when the sheet should close (vehicle selected, or tapped outside).
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleState = ref.watch(vehicleProvider);
    final vehicles = vehicleState.vehicles;
    final selectedId = vehicleState.selectedVehicleId;

    final brightness = Theme.of(context).brightness;
    final Color sheetColor = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final Color dividerColor = brightness == Brightness.dark
        ? AppColors.dividerDark
        : AppColors.dividerLight;
    final Color secondaryTextColor = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: brightness == Brightness.dark ? 0.4 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(color: dividerColor),
          _SheetHeader(secondaryTextColor: secondaryTextColor),
          Divider(color: dividerColor, height: 1, thickness: 1),
          vehicles.isEmpty
              ? _EmptyState(secondaryTextColor: secondaryTextColor)
              : _VehicleList(
                  vehicles: vehicles,
                  selectedId: selectedId,
                  onSelect: (id) {
                    ref.read(vehicleProvider.notifier).selectVehicle(id);
                    onClose();
                  },
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends ConsumerWidget {
  const _SheetHeader({required this.secondaryTextColor});
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedVehicle = ref.watch(selectedVehicleProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Select Vehicle',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          // Delete selected vehicle.
          IconButton(
            onPressed: selectedVehicle == null
                ? null
                : () => showDeleteVehicleDialog(context, selectedVehicle),
            icon: Icon(Icons.delete_outline, color: secondaryTextColor),
            tooltip: 'Delete vehicle',
          ),
          // Add new vehicle.
          IconButton(
            onPressed: () => showAddVehicleDialog(context),
            icon: const Icon(Icons.add, color: AppColors.primary),
            tooltip: 'Add vehicle',
          ),
        ],
      ),
    );
  }
}

class _VehicleList extends StatelessWidget {
  const _VehicleList({
    required this.vehicles,
    required this.selectedId,
    required this.onSelect,
  });

  final List vehicles;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.xs,
        ),
        itemCount: vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          return VehicleTile(
            vehicle: vehicle,
            isSelected: vehicle.id == selectedId,
            onTap: () => onSelect(vehicle.id),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.secondaryTextColor});
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, size: 48, color: secondaryTextColor),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No vehicles yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: secondaryTextColor,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => showAddVehicleDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create your first vehicle'),
          ),
        ],
      ),
    );
  }
}
