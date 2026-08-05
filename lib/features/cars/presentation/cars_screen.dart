import 'package:flutter/material.dart';

/// Placeholder for the Cars screen.
/// Real vehicle management is deferred to Phase 3 — Vehicle System.
class CarsScreen extends StatelessWidget {
  const CarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cars')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, size: 64),
            SizedBox(height: 16),
            Text('Cars'),
          ],
        ),
      ),
    );
  }
}
