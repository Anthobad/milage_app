import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../providers/unit_preference_provider.dart';

// ---------------------------------------------------------------------------
// UnitsScreen — Phase 7.4
// ---------------------------------------------------------------------------
//
// Dedicated Units settings page, opened from Profile → Units.
//
// Shows two unit system options: Metric and Imperial.
// The active option is marked with a checkmark.
// Tapping any option applies immediately (no restart required)
// and persists the choice via SharedPreferences.
//
// DISPLAY-ONLY: Changing units does NOT affect stored trip data,
// GPS records, analytics calculations, or database values.

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current unit system — default to metric during async load.
    final UnitSystem current =
        ref.watch(unitPreferenceProvider).value ?? UnitSystem.metric;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Units'),
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
              // ── UNIT SYSTEM section label ─────────────────────────────────
              Text(
                'UNIT SYSTEM',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Unit system options card ───────────────────────────────────
              _UnitOptionsCard(current: current),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _UnitOptionsCard
// ---------------------------------------------------------------------------

class _UnitOptionsCard extends ConsumerWidget {
  const _UnitOptionsCard({required this.current});

  final UnitSystem current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('units_system_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          _UnitOptionRow(
            key: const Key('unit_option_metric'),
            emoji: '🌍',
            label: 'Metric',
            subtitle: 'km, km/h, m',
            system: UnitSystem.metric,
            isSelected: current == UnitSystem.metric,
          ),
          const _OptionDivider(),
          _UnitOptionRow(
            key: const Key('unit_option_imperial'),
            emoji: '🇺🇸',
            label: 'Imperial',
            subtitle: 'mi, mph, ft',
            system: UnitSystem.imperial,
            isSelected: current == UnitSystem.imperial,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _UnitOptionRow
// ---------------------------------------------------------------------------

class _UnitOptionRow extends ConsumerWidget {
  const _UnitOptionRow({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.system,
    required this.isSelected,
    this.isLast = false,
    super.key,
  });

  final String emoji;
  final String label;
  final String subtitle;
  final UnitSystem system;
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
          ref.read(unitPreferenceProvider.notifier).setUnitSystem(system);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              // Emoji icon
              Text(
                emoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: AppSpacing.md),

              // Label + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Checkmark — visible only for the selected option
              if (isSelected)
                Icon(
                  Icons.check,
                  key: Key('checkmark_${system.value}'),
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
