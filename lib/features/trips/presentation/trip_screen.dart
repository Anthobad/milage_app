import 'package:flutter/material.dart';

/// Placeholder for the Trips screen.
/// Real trips implementation is deferred to Phase 5 — Trip System.
class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 64),
            SizedBox(height: 16),
            Text('Trips'),
          ],
        ),
      ),
    );
  }
}
