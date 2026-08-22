import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';

// ---------------------------------------------------------------------------
// SettingPlaceholderScreen — Phase 7.1
// ---------------------------------------------------------------------------
//
// Generic placeholder used by each individual settings sub-page:
//   Appearance, Map Appearance, Units, Permissions
//
// Each sub-page will be replaced with a real implementation in later Phase 7
// tasks.  For now every sub-page shows its title and "Coming soon."
//
// Why a single reusable widget rather than 4 separate files?
// The content is identical for all four at this phase.  A future phase will
// replace the relevant screen(s) with real implementations.

class SettingPlaceholderScreen extends StatelessWidget {
  const SettingPlaceholderScreen({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        title: Text(title),
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Coming soon.',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
