import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vehicle.dart';
import 'vehicle_repository_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the vehicle list feature.
///
/// Holds both the full list of vehicles and the ID of the currently
/// selected vehicle.  Keeping them together avoids sync issues between
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

// Sentinel used by copyWith to distinguish "not provided" from explicit null.
const Object _keep = Object();

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the vehicle list and selected vehicle, backed by [VehicleRepository].
///
/// On first build, loads all vehicles and the persisted selected vehicle ID
/// from SQLite.  All mutations write through the repository so changes survive
/// app restarts.
///
/// ## Data flow
///
/// Load:    build() → repository.getAll() + repository.getSelectedVehicleId()
/// Create:  addVehicle()  → repository.create()  → refresh state
/// Edit:    updateVehicle() → repository.update() → refresh state
/// Delete:  deleteVehicle() → repository.delete() → refresh state
/// Select:  selectVehicle() → repository.setSelectedVehicleId() → update state
class VehicleListNotifier extends AsyncNotifier<VehicleState> {
  @override
  Future<VehicleState> build() async {
    final repo = ref.read(vehicleRepositoryProvider);
    final vehicles = await repo.getAll();
    final selectedId = await repo.getSelectedVehicleId();

    // If the persisted selected ID no longer points to a real vehicle
    // (e.g. database was cleared externally) clear it silently.
    final validSelectedId =
        vehicles.any((v) => v.id == selectedId) ? selectedId : null;
    if (validSelectedId == null && selectedId != null) {
      await repo.clearSelectedVehicle();
    }

    return VehicleState(
      vehicles: vehicles,
      selectedVehicleId: validSelectedId,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns the current [VehicleState] or an empty state while loading.
  VehicleState get _current => state.value ?? const VehicleState();

  // ── CRUD ─────────────────────────────────────────────────────────────────

  /// Persists [vehicle] and refreshes state.
  ///
  /// Per the existing product spec, the first vehicle added is automatically
  /// selected.
  Future<void> addVehicle(Vehicle vehicle) async {
    final repo = ref.read(vehicleRepositoryProvider);
    await repo.create(vehicle);

    final current = _current;
    final wasEmpty = current.vehicles.isEmpty;
    final updated = [...current.vehicles, vehicle];

    // Auto-select the very first vehicle.
    String? newSelectedId = current.selectedVehicleId;
    if (wasEmpty) {
      newSelectedId = vehicle.id;
      await repo.setSelectedVehicleId(vehicle.id);
    }

    state = AsyncData(
      current.copyWith(vehicles: updated, selectedVehicleId: newSelectedId),
    );
  }

  /// Updates the existing vehicle record matching [updated.id].
  ///
  /// Does nothing if no matching vehicle is found.
  Future<void> updateVehicle(Vehicle updated) async {
    final current = _current;
    final index = current.vehicles.indexWhere((v) => v.id == updated.id);
    if (index == -1) return;

    final repo = ref.read(vehicleRepositoryProvider);
    await repo.update(updated);

    final list = [...current.vehicles];
    list[index] = updated;
    state = AsyncData(current.copyWith(vehicles: list));
  }

  /// Deletes the vehicle with [id] and clears selection if needed.
  ///
  /// Selection rules:
  /// - If the deleted vehicle was not selected, selection is unchanged.
  /// - If it was selected and other vehicles remain, the adjacent vehicle
  ///   (next, or last if at end) becomes selected and is persisted.
  /// - If no vehicles remain after deletion, selection is cleared.
  Future<void> deleteVehicle(String id) async {
    final repo = ref.read(vehicleRepositoryProvider);
    // Repository handles clearing the selected ID when the deleted vehicle
    // was selected — but we also apply the "select next" logic here.
    final current = _current;
    final oldList = current.vehicles;
    final newList = oldList.where((v) => v.id != id).toList();

    String? nextSelectedId;
    if (current.selectedVehicleId == id) {
      if (newList.isNotEmpty) {
        final deletedIndex = oldList.indexWhere((v) => v.id == id);
        final nextIndex = deletedIndex.clamp(0, newList.length - 1);
        nextSelectedId = newList[nextIndex].id;
        await repo.setSelectedVehicleId(nextSelectedId);
      } else {
        nextSelectedId = null;
        // repo.delete() will clear the selected ID automatically.
      }
    } else {
      nextSelectedId = current.selectedVehicleId;
    }

    await repo.delete(id);

    state = AsyncData(
      current.copyWith(
        vehicles: newList,
        selectedVehicleId: nextSelectedId,
      ),
    );
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  /// Selects the vehicle with [id] and persists the choice.
  ///
  /// Pass `null` to clear the selection.
  Future<void> selectVehicle(String? id) async {
    final repo = ref.read(vehicleRepositoryProvider);
    if (id == null) {
      await repo.clearSelectedVehicle();
    } else {
      await repo.setSelectedVehicleId(id);
    }
    state = AsyncData(_current.copyWith(selectedVehicleId: id));
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Primary vehicle provider.
///
/// Exposes [AsyncValue<VehicleState>].  On first access it loads vehicles and
/// the selected vehicle ID from SQLite.  All subsequent mutations are
/// reflected immediately without a full reload.
///
/// Typical UI usage:
/// ```dart
/// final asyncState = ref.watch(vehicleProvider);
/// final vehicles = asyncState.valueOrNull?.vehicles ?? [];
/// ```
final AsyncNotifierProvider<VehicleListNotifier, VehicleState> vehicleProvider =
    AsyncNotifierProvider<VehicleListNotifier, VehicleState>(
  VehicleListNotifier.new,
);

/// Derived convenience provider — returns the currently selected [Vehicle],
/// or `null` when none is selected or the state is still loading.
final Provider<Vehicle?> selectedVehicleProvider = Provider<Vehicle?>(
  (ref) {
    final asyncState = ref.watch(vehicleProvider);
    final vehicleState = asyncState.value;
    if (vehicleState == null) return null;
    if (vehicleState.selectedVehicleId == null) return null;
    return vehicleState.vehicles.firstWhere(
      (v) => v.id == vehicleState.selectedVehicleId,
      orElse: () => vehicleState.vehicles.first,
    );
  },
);
