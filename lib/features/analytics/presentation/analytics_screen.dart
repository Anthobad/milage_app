import 'package:flutter/material.dart';

/// Placeholder for the Analytics screen.
/// Real analytics implementation is deferred to Phase 6 — Driving Analytics.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64),
            SizedBox(height: 16),
            Text('Analytics'),
          ],
        ),
      ),
    );
  }
}
