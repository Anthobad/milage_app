import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/trip_repository.dart';

// ---------------------------------------------------------------------------
// tripRepositoryProvider
// ---------------------------------------------------------------------------

/// Exposes a [TripRepository] instance to the Riverpod dependency graph.
///
/// Passes the raw [Database] connection from [AppDatabase.instance.database]
/// so the repository is decoupled from the singleton and testable by
/// injecting an in-memory [Database] directly.
///
/// [databaseProvider] is guaranteed to be ready before [ProviderScope] is
/// created (initialized in [main()]).
final Provider<TripRepository> tripRepositoryProvider =
    Provider<TripRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return TripRepository(appDb.database);
});
