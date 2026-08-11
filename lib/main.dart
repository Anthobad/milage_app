import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── flutter_foreground_task ────────────────────────────────────────────────
  // Sets up the IPC port between the foreground-service isolate and the main
  // isolate.  Must be called before runApp().
  FlutterForegroundTask.initCommunicationPort();

  // ── Database initialization ────────────────────────────────────────────────
  // Initialize the SQLite database before the widget tree is built so that
  // repositories and providers can assume it is ready from the first frame.
  //
  // Failures are caught and reported to the console rather than crashing
  // silently.  The app continues to run so UI / non-database features remain
  // available.  Repositories must handle the case where the database failed
  // to open (the database getter will throw, which the repository layer will
  // surface as an error state rather than a crash).
  try {
    await AppDatabase.instance.initialize();
  } catch (error, stackTrace) {
    // ignore: avoid_print
    print('[TripRank] Database initialization failed: $error\n$stackTrace');
    // Do not rethrow — a database failure must not prevent the app from
    // starting.  Features that require the database will show appropriate
    // error states when they attempt to access it.
  }

  runApp(const TripRankApp());
}
