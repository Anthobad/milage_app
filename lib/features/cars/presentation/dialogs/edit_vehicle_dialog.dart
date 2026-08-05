import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import 'vehicle_form_dialog.dart';

/// Opens the Edit Vehicle dialog pre-populated with [vehicle]'s values.
void showEditVehicleDialog(BuildContext context, Vehicle vehicle) {
  showDialog<void>(
    context: context,
    builder: (_) => EditVehicleDialog(vehicle: vehicle),
  );
}

/// Centered modal dialog for editing an existing vehicle.
///
/// Pre-fills all fields from [vehicle]. On save: updates the vehicle through
/// [vehicleProvider] keeping the same ID.
class EditVehicleDialog extends ConsumerStatefulWidget {
  const EditVehicleDialog({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<EditVehicleDialog> createState() => _EditVehicleDialogState();
}

class _EditVehicleDialogState extends ConsumerState<EditVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _yearCtrl;
  late VehicleType _selectedType;

  @override
  void initState() {
    super.initState();
    _brandCtrl = TextEditingController(text: widget.vehicle.brand);
    _modelCtrl = TextEditingController(text: widget.vehicle.model);
    _yearCtrl = TextEditingController(text: widget.vehicle.year.toString());
    _selectedType = widget.vehicle.type;
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.vehicle.copyWith(
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.parse(_yearCtrl.text.trim()),
      type: _selectedType,
    );

    ref.read(vehicleProvider.notifier).updateVehicle(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VehicleFormDialog(
      title: 'Edit Vehicle',
      formKey: _formKey,
      brandCtrl: _brandCtrl,
      modelCtrl: _modelCtrl,
      yearCtrl: _yearCtrl,
      selectedType: _selectedType,
      onTypeChanged: (t) => setState(() => _selectedType = t),
      onSave: _save,
    );
  }
}
