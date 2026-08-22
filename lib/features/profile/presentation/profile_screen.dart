import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../../core/services/unit_service.dart';
import '../providers/profile_driving_summary_provider.dart';
import '../providers/profile_image_provider.dart';

// ---------------------------------------------------------------------------
// ProfileScreen — Phase 7.1
// ---------------------------------------------------------------------------
//
// Structure:
//
//   PROFILE header
//     ├── title "PROFILE"
//     ├── generic icon / selected local photo
//     └── static label "Driver"
//
//   DRIVING section
//     └── Overall Driving card (trips, distance, time — all vehicles)
//         tap → Analytics page
//
//   SETTINGS section
//     ├── Appearance       (→ /profile/settings/appearance)
//     ├── Map Appearance   (→ /profile/settings/map-appearance)
//     └── Units            (→ /profile/settings/units)
//
//   ABOUT section
//     └── About TripRank   (→ /profile/about)
//
// The page is vertically scrollable so all sections are reachable on
// small phones without clipping.

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App-bar (title only — no gear icon) ────────────────────────
            const SliverAppBar(
              pinned: false,
              floating: true,
              backgroundColor: AppColors.backgroundDark,
              foregroundColor: AppColors.textPrimaryDark,
              elevation: 0,
              title: Text(
                'PROFILE',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile avatar ─────────────────────────────────────
                    const SizedBox(height: AppSpacing.md),
                    const _ProfileAvatar(),
                    const SizedBox(height: AppSpacing.lg),

                    // ── DRIVING section ────────────────────────────────────
                    const _SectionLabel(label: 'DRIVING'),
                    const SizedBox(height: AppSpacing.sm),
                    const _DrivingSummaryCard(),
                    const SizedBox(height: AppSpacing.lg),

                    // ── SETTINGS section ───────────────────────────────────
                    const _SectionLabel(label: 'SETTINGS'),
                    const SizedBox(height: AppSpacing.sm),
                    const _SettingsSectionCard(),
                    const SizedBox(height: AppSpacing.lg),

                    // ── ABOUT section ──────────────────────────────────────
                    const _SectionLabel(label: 'ABOUT'),
                    const SizedBox(height: AppSpacing.sm),
                    const _AboutSectionCard(),

                    // Bottom padding so last card is not hidden by nav bar.
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionLabel
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ProfileAvatar — generic icon or local photo + "Driver" label
// ---------------------------------------------------------------------------

class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagePath = ref.watch(profileImageProvider);

    return Center(
      child: Column(
        children: [
          _AvatarCircle(imagePath: imagePath),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Driver',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.imagePath});
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    const double size = 96;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceDark,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath != null && File(imagePath!).existsSync()
          ? Image.file(
              File(imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (ctx, e, st) => const _DefaultProfileIcon(),
            )
          : const _DefaultProfileIcon(),
    );
  }
}

class _DefaultProfileIcon extends StatelessWidget {
  const _DefaultProfileIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.person_outline,
      key: Key('profile_default_icon'),
      color: AppColors.textSecondaryDark,
      size: 52,
    );
  }
}

// ---------------------------------------------------------------------------
// _DrivingSummaryCard — all-vehicle overall driving stats
// ---------------------------------------------------------------------------

class _DrivingSummaryCard extends ConsumerWidget {
  const _DrivingSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileDrivingSummaryProvider);
    final unitService = ref.watch(unitServiceProvider);

    return Container(
      key: const Key('driving_summary_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Driving',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          state.isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              : _DrivingStatRow(
                  summary: state.summary ?? ProfileDrivingSummary.zero,
                  unitService: unitService,
                ),
        ],
      ),
    );
  }
}

class _DrivingStatRow extends StatelessWidget {
  const _DrivingStatRow({required this.summary, required this.unitService});
  final ProfileDrivingSummary summary;
  final UnitService unitService;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            label: 'Trips',
            value: '${summary.tripCount}',
          ),
        ),
        Expanded(
          child: _StatCell(
            label: 'Distance',
            value: unitService.formatDistance(summary.totalDistanceKm),
          ),
        ),
        Expanded(
          child: _StatCell(
            label: 'Time',
            value: summary.tripCount == 0 ? '—' : summary.durationLabel,
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SettingsSectionCard — four settings rows, each to its own sub-page
// ---------------------------------------------------------------------------

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          _NavRow(
            key: const Key('settings_row_appearance'),
            icon: Icons.palette_outlined,
            label: 'Appearance',
            onTap: () => context.push(AppRoutes.profileAppearance),
          ),
          const _Divider(),
          _NavRow(
            key: const Key('settings_row_map_appearance'),
            icon: Icons.map_outlined,
            label: 'Map Appearance',
            onTap: () => context.push(AppRoutes.profileMapAppearance),
          ),
          const _Divider(),
          _NavRow(
            key: const Key('settings_row_units'),
            icon: Icons.straighten_outlined,
            label: 'Units',
            isLast: true,
            onTap: () => context.push(AppRoutes.profileUnits),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AboutSectionCard
// ---------------------------------------------------------------------------

class _AboutSectionCard extends StatelessWidget {
  const _AboutSectionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: _NavRow(
        key: const Key('about_milage_row'),
        icon: Icons.info_outline,
        label: 'About Milage',
        isLast: true,
        onTap: () => context.push(AppRoutes.profileAbout),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NavRow — generic navigation list row
// ---------------------------------------------------------------------------

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(AppSpacing.radiusLg),
          bottom: isLast
              ? const Radius.circular(AppSpacing.radiusLg)
              : Radius.zero,
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondaryDark, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Divider
// ---------------------------------------------------------------------------

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: AppSpacing.md + 22 + AppSpacing.md),
      child: Divider(
        color: AppColors.dividerDark,
        height: 1,
      ),
    );
  }
}
