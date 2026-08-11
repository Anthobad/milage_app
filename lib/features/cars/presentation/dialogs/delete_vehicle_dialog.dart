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
/// If the deleted vehicle was selected, the provider clears/updates the
/// selection automatically.
class DeleteVehicleDialog extends ConsumerStatefulWidget {
  const DeleteVehicleDialog({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<DeleteVehicleDialog> createState() =>
      _DeleteVehicleDialogState();
}

class _DeleteVehicleDialogState extends ConsumerState<DeleteVehicleDialog> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);

    await ref
        .read(vehicleProvider.notifier)
        .deleteVehicle(widget.vehicle.id);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      title: const Text('Delete Vehicle?'),
      content: Text(
        'Are you sure you want to delete '
        '${widget.vehicle.brand} ${widget.vehicle.model}?',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _deleting ? null : _delete,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
          ),
          child: _deleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}
