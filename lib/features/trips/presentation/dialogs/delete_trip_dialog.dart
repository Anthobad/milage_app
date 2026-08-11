import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../trips/data/trip_repository.dart';
import '../../../trips/providers/trip_repository_provider.dart';
import '../../../trips/providers/trips_filter_provider.dart';

// ---------------------------------------------------------------------------
// DeleteTripDialog
// ---------------------------------------------------------------------------

/// Confirmation dialog shown before deleting a trip.
///
/// On confirm:
/// 1. Deletes the [Trip] via [TripRepository.deleteTrip].
///    The associated GPS track is removed automatically by the
///    `ON DELETE CASCADE` constraint on `trip_track_points`.
/// 2. Invalidates [vehicleTripsProvider] so the Trips page refreshes.
///
/// On cancel: does nothing.
class DeleteTripDialog extends ConsumerStatefulWidget {
  const DeleteTripDialog({
    super.key,
    required this.tripId,
    required this.tripLabel,
  });

  /// UUID of the trip to delete.
  final String tripId;

  /// Human-readable label shown in the confirmation message (e.g. date/destination).
  final String tripLabel;

  @override
  ConsumerState<DeleteTripDialog> createState() => _DeleteTripDialogState();
}

class _DeleteTripDialogState extends ConsumerState<DeleteTripDialog> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);

    try {
      final repo = ref.read(tripRepositoryProvider);
      await repo.deleteTrip(widget.tripId);
      // Refresh the trips list.
      ref.invalidate(vehicleTripsProvider);
    } catch (e) {
      // ignore: avoid_print
      print('[DeleteTripDialog] Error deleting trip: $e');
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      title: const Text('Delete Trip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete the trip and all its recorded GPS data.',
            style: theme.textTheme.bodyMedium,
          ),
          if (widget.tripLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.tripLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          onPressed: _deleting ? null : _delete,
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

/// Shows the [DeleteTripDialog] and returns `true` if the trip was deleted.
Future<bool> showDeleteTripDialog({
  required BuildContext context,
  required String tripId,
  required String tripLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DeleteTripDialog(tripId: tripId, tripLabel: tripLabel),
  );
  return result == true;
}
