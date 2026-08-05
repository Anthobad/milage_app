import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../../../../app/theme/colors.dart';
import '../../../../../app/theme/spacing.dart';

/// Opens the delete confirmation dialog for [vehicle].
void showDeleteVehicleDialog(BuildContext context, Vehicle vehicle) {
  showDialog<void>(
    context: context,
    builder: (_) => DeleteVehicleDialog(vehicle: vehicle),
  );
}

/// Centered confirmation dialog before deleting a vehicle.
///
/// On confirm: removes the vehicle through [vehicleProvider].
/// Selection rules are handled entirely by the provider.
class DeleteVehicleDialog extends ConsumerWidget {
  const DeleteVehicleDialog({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      title: const Text('Delete Vehicle?'),
      content: Text(
        'Are you sure you want to delete '
        '${vehicle.brand} ${vehicle.model}?',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(vehicleProvider.notifier).deleteVehicle(vehicle.id);
            Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
