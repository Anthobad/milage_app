import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';

// ---------------------------------------------------------------------------
// AboutScreen — Phase 7.1 (placeholder)
// ---------------------------------------------------------------------------
//
// Minimal About TripRank page.
//
// Content will be expanded in later Phase 7 tasks.  For Phase 7.1 this
// page exists only to satisfy the "About TripRank" navigation requirement
// from the Profile page.

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        title: const Text('About TripRank'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Center(
              child: Text(
                'TripRank',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Center(
              child: Text(
                'Drive smarter. Understand your trips.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Placeholder for future content (version, licenses, etc.)
            const Center(
              child: Text(
                'More information coming soon.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
