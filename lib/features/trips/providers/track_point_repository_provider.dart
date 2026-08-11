import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/track_point_repository.dart';

/// Riverpod provider that exposes the [TrackPointRepository] singleton.
///
/// Downstream consumers (providers, notifiers) read this provider to access
/// GPS track-point data without importing the database layer directly.
///
/// ## Usage
///
/// ```dart
/// final repo = ref.read(trackPointRepositoryProvider);
/// await repo.addTrackPoint(record);
/// final points = await repo.getTrackPointsForTrip(tripId);
/// ```
final Provider<TrackPointRepository> trackPointRepositoryProvider =
    Provider<TrackPointRepository>((ref) {
  final appDb = ref.read(databaseProvider);
  return TrackPointRepository(appDb.database);
});
