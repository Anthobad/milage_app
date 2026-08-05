import 'package:flutter/material.dart';

/// Placeholder for the Map screen.
/// Real map implementation is deferred to Phase 4 — Map System.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64),
            SizedBox(height: 16),
            Text('Map'),
          ],
        ),
      ),
    );
  }
}
