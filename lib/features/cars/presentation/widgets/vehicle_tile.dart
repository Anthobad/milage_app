import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../dialogs/edit_vehicle_dialog.dart';

/// A single row in the vehicle selector list.
///
/// Displays brand + model. Shows a check mark when [isSelected].
/// Shows an edit icon button that opens [EditVehicleDialog].
class VehicleTile extends StatelessWidget {
  const VehicleTile({
    super.key,
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: Row(
          children: [
            // Brand + Model label.
            Expanded(
              child: Text(
                '${vehicle.brand} ${vehicle.model}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Check mark — visible only when selected.
            if (isSelected) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.check, color: AppColors.primary, size: 20),
            ],

            // Edit icon — opens EditVehicleDialog.
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: () => showEditVehicleDialog(context, vehicle),
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Edit vehicle',
            ),
          ],
        ),
      ),
    );
  }
}
