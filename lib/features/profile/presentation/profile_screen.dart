import 'package:flutter/material.dart';

/// Placeholder for the Profile screen.
/// Real profile & settings implementation is deferred to Phase 7 — Profile & Settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 64),
            SizedBox(height: 16),
            Text('Profile'),
          ],
        ),
      ),
    );
  }
}
