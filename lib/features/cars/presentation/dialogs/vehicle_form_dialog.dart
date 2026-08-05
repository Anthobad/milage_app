import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/vehicle.dart';
import '../../../../../app/theme/spacing.dart';

/// Shared form layout used by [AddVehicleDialog] and [EditVehicleDialog].
///
/// Contains all the UI — title, fields, validation, buttons.
/// No business logic: save/cancel callbacks are injected by the caller.
class VehicleFormDialog extends StatelessWidget {
  const VehicleFormDialog({
    super.key,
    required this.title,
    required this.formKey,
    required this.brandCtrl,
    required this.modelCtrl,
    required this.yearCtrl,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onSave,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final TextEditingController brandCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController yearCtrl;
  final VehicleType selectedType;
  final ValueChanged<VehicleType> onTypeChanged;
  final VoidCallback onSave;

  // Types shown in the dropdown (easy to extend).
  static const List<VehicleType> _types = [
    VehicleType.sedan,
    VehicleType.hatchback,
    VehicleType.suv,
    VehicleType.coupe,
    VehicleType.pickup,
    VehicleType.van,
    VehicleType.other,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Brand
              _FormField(
                controller: brandCtrl,
                label: 'Brand',
                hint: 'e.g. Toyota',
                validator: _requiredValidator('Brand'),
              ),
              const SizedBox(height: AppSpacing.md),

              // Model
              _FormField(
                controller: modelCtrl,
                label: 'Model',
                hint: 'e.g. Corolla',
                validator: _requiredValidator('Model'),
              ),
              const SizedBox(height: AppSpacing.md),

              // Year
              _FormField(
                controller: yearCtrl,
                label: 'Year',
                hint: 'e.g. 2020',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _yearValidator,
              ),
              const SizedBox(height: AppSpacing.md),

              // Type dropdown
              DropdownButtonFormField<VehicleType>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _types
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onTypeChanged(v);
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm + AppSpacing.xs,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? Function(String?) _requiredValidator(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName cannot be empty';
      }
      return null;
    };
  }

  static String? _yearValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Year cannot be empty';
    final year = int.tryParse(value.trim());
    if (year == null) return 'Year must be a number';
    final currentYear = DateTime.now().year;
    if (year < 1886 || year > currentYear + 1) {
      return 'Enter a valid year';
    }
    return null;
  }
}

/// Reusable text form field for the vehicle form.
class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: TextCapitalization.words,
    );
  }
}
