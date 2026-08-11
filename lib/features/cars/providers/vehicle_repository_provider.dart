import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/vehicle_repository.dart';

// ---------------------------------------------------------------------------
// vehicleRepositoryProvider
// ---------------------------------------------------------------------------

/// Exposes a [VehicleRepository] instance to the Riverpod dependency graph.
///
/// Passes the raw [Database] connection from [AppDatabase.instance.database]
/// to [VehicleRepository] so the repository is decoupled from the
/// [AppDatabase] singleton and can be tested by injecting an in-memory
/// [Database] directly.
///
/// [databaseProvider] is guaranteed to be ready before [ProviderScope] is
/// created (initialized in [main()]).
final Provider<VehicleRepository> vehicleRepositoryProvider =
    Provider<VehicleRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return VehicleRepository(appDb.database);
});
