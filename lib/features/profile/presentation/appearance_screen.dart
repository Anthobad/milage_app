import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../../app/theme/theme_provider.dart';

// ---------------------------------------------------------------------------
// AppearanceScreen — Phase 7.2
// ---------------------------------------------------------------------------
//
// Dedicated Appearance settings page, opened from Profile → Appearance.
//
// Shows three theme options: Dark, Light, System.
// The active option is marked with a checkmark.
// Tapping any option applies the theme immediately (no restart required)
// and persists the choice via SharedPreferences.
//
// MAP THEME IS NOT CONTROLLED HERE — Phase 7.3.

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current theme mode — default to dark during async load.
    final ThemeMode current =
        ref.watch(themeProvider).value ?? ThemeMode.dark;

    return Scaffold(
      // Use the theme-aware scaffold background so the page looks correct
      // in both dark and light mode when the user switches.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Appearance'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── THEME section label ───────────────────────────────────────
              Text(
                'THEME',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Theme options card ─────────────────────────────────────────
              _ThemeOptionsCard(current: current),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ThemeOptionsCard
// ---------------------------------------------------------------------------

class _ThemeOptionsCard extends ConsumerWidget {
  const _ThemeOptionsCard({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('appearance_theme_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          _ThemeOptionRow(
            key: const Key('theme_option_dark'),
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            themeMode: ThemeMode.dark,
            isSelected: current == ThemeMode.dark,
          ),
          const _OptionDivider(),
          _ThemeOptionRow(
            key: const Key('theme_option_light'),
            icon: Icons.light_mode_outlined,
            label: 'Light',
            themeMode: ThemeMode.light,
            isSelected: current == ThemeMode.light,
          ),
          const _OptionDivider(),
          _ThemeOptionRow(
            key: const Key('theme_option_system'),
            icon: Icons.settings_outlined,
            label: 'System',
            themeMode: ThemeMode.system,
            isSelected: current == ThemeMode.system,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ThemeOptionRow
// ---------------------------------------------------------------------------

class _ThemeOptionRow extends ConsumerWidget {
  const _ThemeOptionRow({
    required this.icon,
    required this.label,
    required this.themeMode,
    required this.isSelected,
    this.isLast = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final ThemeMode themeMode;
  final bool isSelected;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(AppSpacing.radiusLg),
          bottom: isLast
              ? const Radius.circular(AppSpacing.radiusLg)
              : Radius.zero,
        ),
        onTap: () {
          ref.read(themeProvider.notifier).setTheme(themeMode);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              // Mode icon
              Icon(
                icon,
                color: colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.md),

              // Label
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ),

              // Checkmark — visible only for the selected option
              if (isSelected)
                Icon(
                  Icons.check,
                  key: Key('checkmark_$label'),
                  color: AppColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _OptionDivider
// ---------------------------------------------------------------------------

class _OptionDivider extends StatelessWidget {
  const _OptionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md + 22 + AppSpacing.md,
      ),
      child: Divider(
        color: Theme.of(context).colorScheme.outline,
        height: 1,
        thickness: 1,
      ),
    );
  }
}
