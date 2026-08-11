import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Required by flutter_foreground_task to set up the communication port
  // between the foreground-service isolate and the main isolate.
  // Must be called before runApp().
  FlutterForegroundTask.initCommunicationPort();

  runApp(const TripRankApp());
}
