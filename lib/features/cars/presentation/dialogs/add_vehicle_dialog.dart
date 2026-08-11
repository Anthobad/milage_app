import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import 'vehicle_form_dialog.dart';

/// Opens the Add Vehicle dialog.
void showAddVehicleDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const AddVehicleDialog(),
  );
}

/// Centered modal dialog for creating a new vehicle.
///
/// On save: generates a UUID, creates a [Vehicle], persists it through
/// [vehicleProvider], and automatically selects it if it is the first vehicle.
class AddVehicleDialog extends ConsumerStatefulWidget {
  const AddVehicleDialog({super.key});

  @override
  ConsumerState<AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends ConsumerState<AddVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  VehicleType _selectedType = VehicleType.sedan;
  bool _saving = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);

    final vehicle = Vehicle(
      id: const Uuid().v4(),
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.parse(_yearCtrl.text.trim()),
      type: _selectedType,
      createdAt: DateTime.now(),
    );

    await ref.read(vehicleProvider.notifier).addVehicle(vehicle);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VehicleFormDialog(
      title: 'Add Vehicle',
      formKey: _formKey,
      brandCtrl: _brandCtrl,
      modelCtrl: _modelCtrl,
      yearCtrl: _yearCtrl,
      selectedType: _selectedType,
      onTypeChanged: (t) => setState(() => _selectedType = t),
      onSave: _saving ? () {} : _save,
    );
  }
}
