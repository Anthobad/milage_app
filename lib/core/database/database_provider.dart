import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

// ---------------------------------------------------------------------------
// databaseProvider
// ---------------------------------------------------------------------------

/// Exposes the [AppDatabase] singleton to the Riverpod dependency graph.
///
/// ## Contract
///
/// [AppDatabase.instance.initialize()] MUST be called and awaited in
/// [main()] before [runApp()] so the singleton is fully open by the time
/// any provider or widget reads this.
///
/// ## Usage in repositories (future phases)
///
/// ```dart
/// class VehicleRepository {
///   VehicleRepository(this._db);
///   final AppDatabase _db;
///
///   Future<List<Vehicle>> getAll() async {
///     final rows = await _db.database.query('vehicles');
///     return rows.map(Vehicle.fromMap).toList();
///   }
/// }
///
/// final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
///   return VehicleRepository(ref.watch(databaseProvider));
/// });
/// ```
///
/// ## Why a simple [Provider] and not [FutureProvider]?
///
/// The database is initialized synchronously from Riverpod's perspective —
/// all async work is completed in [main()] before [ProviderScope] is created.
/// A [FutureProvider] would force every consumer to handle loading/error
/// states even though the database is guaranteed ready at that point.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});
