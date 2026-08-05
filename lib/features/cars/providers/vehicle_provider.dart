import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vehicle.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the vehicle list feature.
///
/// Holds both the full list of vehicles and the ID of the currently
/// selected vehicle. Keeping them together avoids sync issues between
/// separate providers.
///
/// [selectedVehicleId] is `null` when no vehicle is selected.
class VehicleState {
  const VehicleState({
    this.vehicles = const [],
    this.selectedVehicleId,
  });

  final List<Vehicle> vehicles;
  final String? selectedVehicleId;

  VehicleState copyWith({
    List<Vehicle>? vehicles,
    // Use a sentinel to allow explicitly setting selectedVehicleId to null.
    Object? selectedVehicleId = _keep,
  }) {
    return VehicleState(
      vehicles: vehicles ?? this.vehicles,
      selectedVehicleId: identical(selectedVehicleId, _keep)
          ? this.selectedVehicleId
          : selectedVehicleId as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleState &&
          runtimeType == other.runtimeType &&
          vehicles == other.vehicles &&
          selectedVehicleId == other.selectedVehicleId;

  @override
  int get hashCode => Object.hash(vehicles, selectedVehicleId);
}

// Sentinel value used by copyWith to distinguish "not provided" from null.
const Object _keep = Object();

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the list of vehicles and the selected vehicle.
///
/// Currently uses in-memory state.
/// Ready for database integration in a future phase — replace the
/// in-memory mutations with repository calls inside each method.
class VehicleListNotifier extends Notifier<VehicleState> {
  @override
  VehicleState build() => const VehicleState();

  // --- CRUD ------------------------------------------------------------------

  /// Add a new [vehicle] to the list.
  ///
  /// If the list was empty before adding, the new vehicle is automatically
  /// selected.
  void addVehicle(Vehicle vehicle) {
    final updated = [...state.vehicles, vehicle];
    state = state.copyWith(
      vehicles: updated,
      // Auto-select first vehicle added.
      selectedVehicleId:
          state.vehicles.isEmpty ? vehicle.id : state.selectedVehicleId,
    );
  }

  /// Replace the vehicle that has the same [Vehicle.id] as [updated].
  ///
  /// Does nothing if no matching vehicle is found.
  void updateVehicle(Vehicle updated) {
    final index = state.vehicles.indexWhere((v) => v.id == updated.id);
    if (index == -1) return;

    final list = [...state.vehicles];
    list[index] = updated;
    state = state.copyWith(vehicles: list);
  }

  /// Remove the vehicle with [id] from the list.
  ///
  /// If the deleted vehicle was selected, the selection is cleared.
  void deleteVehicle(String id) {
    final list = state.vehicles.where((v) => v.id != id).toList();
    final stillSelected =
        state.selectedVehicleId != id ? state.selectedVehicleId : null;
    state = state.copyWith(
      vehicles: list,
      selectedVehicleId: stillSelected,
    );
  }

  // --- Selection -------------------------------------------------------------

  /// Set the vehicle with [id] as the selected vehicle.
  ///
  /// Passing `null` clears the selection.
  void selectVehicle(String? id) {
    state = state.copyWith(selectedVehicleId: id);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Primary vehicle provider.
///
/// Exposes the full [VehicleState] (list + selected ID).
/// Use [selectedVehicleProvider] for convenient access to the selected vehicle.
final NotifierProvider<VehicleListNotifier, VehicleState> vehicleProvider =
    NotifierProvider<VehicleListNotifier, VehicleState>(
  VehicleListNotifier.new,
);

/// Derived provider that returns the currently selected [Vehicle], or `null`
/// if no vehicle is selected or the ID no longer exists in the list.
final Provider<Vehicle?> selectedVehicleProvider = Provider<Vehicle?>(
  (ref) {
    final state = ref.watch(vehicleProvider);
    if (state.selectedVehicleId == null) return null;
    return state.vehicles.firstWhere(
      (v) => v.id == state.selectedVehicleId,
      orElse: () => state.vehicles.first,
    );
  },
);
