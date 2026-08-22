import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../map/providers/map_theme_provider.dart';

// ---------------------------------------------------------------------------
// MapAppearanceScreen — Phase 7.3
// ---------------------------------------------------------------------------
//
// Dedicated Map Appearance settings page, opened from Profile → Map Appearance.
//
// Controls ONLY the map tile theme (Dark / Light / System).
// Has NO effect on the TripRank application UI theme.
//
// Design mirrors AppearanceScreen (Phase 7.2) for visual consistency:
//   - Same rounded-card style
//   - Same section label
//   - Same checkmark for the active option (blue)
//   - Same InkWell tap interaction
//
// The TripRank app ThemeMode (themeProvider) is NEVER read or written here.

class MapAppearanceScreen extends ConsumerWidget {
  const MapAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current map theme mode — default to dark during async load.
    final MapThemeMode current =
        ref.watch(mapThemeProvider).value ?? MapThemeMode.dark;

    return Scaffold(
      // Use the theme-aware scaffold background so the page responds
      // correctly regardless of the currently selected app theme.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Map Appearance'),
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

              // ── Map theme options card ─────────────────────────────────────
              _MapThemeOptionsCard(current: current),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MapThemeOptionsCard
// ---------------------------------------------------------------------------

class _MapThemeOptionsCard extends ConsumerWidget {
  const _MapThemeOptionsCard({required this.current});

  final MapThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('map_appearance_theme_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          _MapThemeOptionRow(
            key: const Key('map_theme_option_dark'),
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            themeMode: MapThemeMode.dark,
            isSelected: current == MapThemeMode.dark,
          ),
          const _OptionDivider(),
          _MapThemeOptionRow(
            key: const Key('map_theme_option_light'),
            icon: Icons.light_mode_outlined,
            label: 'Light',
            themeMode: MapThemeMode.light,
            isSelected: current == MapThemeMode.light,
          ),
          const _OptionDivider(),
          _MapThemeOptionRow(
            key: const Key('map_theme_option_system'),
            icon: Icons.settings_outlined,
            label: 'System',
            themeMode: MapThemeMode.system,
            isSelected: current == MapThemeMode.system,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MapThemeOptionRow
// ---------------------------------------------------------------------------

class _MapThemeOptionRow extends ConsumerWidget {
  const _MapThemeOptionRow({
    required this.icon,
    required this.label,
    required this.themeMode,
    required this.isSelected,
    this.isLast = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final MapThemeMode themeMode;
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
          // Updates mapThemeProvider ONLY — never touches themeProvider.
          ref.read(mapThemeProvider.notifier).setMapTheme(themeMode);
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
                  key: Key('map_checkmark_$label'),
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
