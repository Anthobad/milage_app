import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';

// ---------------------------------------------------------------------------
// About Mileage — Phase 7.5
// ---------------------------------------------------------------------------
//
// Displays:
//   • App icon (assets/images/mileage_icon.png)
//   • App name: "Mileage"
//   • Subtitle: "Personal Driving Tracker"
//   • Version card (loaded dynamically via package_info_plus)
//   • About description card
//   • Footer: "Built for personal use."
//
// The page is fully scrollable so it fits on narrow screens.
// The back button returns to the Profile page.
//
// DO NOT configure launcher/app icons here — that is Phase 8.

// ---------------------------------------------------------------------------
// Version provider — keeps UI loading separate from the package_info_plus call
// ---------------------------------------------------------------------------

/// Provides the version string loaded from [PackageInfo].
///
/// Returns `null` while loading, the version string on success, and an empty
/// string as a graceful fallback on failure (never throws).
final _appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    return version.isNotEmpty ? version : null;
  } catch (_) {
    // Package info unavailable (e.g. unit-test environment without a real
    // platform channel).  Return null so the UI shows a graceful fallback.
    return null;
  }
});

// ---------------------------------------------------------------------------
// AboutScreen
// ---------------------------------------------------------------------------

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text(
          'About Mileage',
          key: Key('about_page_title'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          children: const [
            _AppIconSection(),
            SizedBox(height: AppSpacing.lg),
            _VersionCard(),
            SizedBox(height: AppSpacing.md),
            _AboutCard(),
            SizedBox(height: AppSpacing.xl),
            _Footer(),
            SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AppIconSection — icon + app name + subtitle
// ---------------------------------------------------------------------------

class _AppIconSection extends StatelessWidget {
  const _AppIconSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),

        // Mileage icon — uses the existing stored asset.
        // DO NOT configure launcher icons here (Phase 8).
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            child: Image.asset(
              'assets/images/mileage_icon.png',
              key: const Key('about_app_icon'),
              width: 96,
              height: 96,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Graceful fallback if asset is missing.
                return Container(
                  key: const Key('about_app_icon_fallback'),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppColors.primary,
                    size: 52,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // App name
        const Center(
          child: Text(
            'Mileage',
            key: Key('about_app_name'),
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        // Subtitle
        const Center(
          child: Text(
            'Personal Driving Tracker',
            key: Key('about_app_subtitle'),
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _VersionCard — dynamically loaded version number
// ---------------------------------------------------------------------------

class _VersionCard extends ConsumerWidget {
  const _VersionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(_appVersionProvider);

    return _SectionCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
        versionAsync.when(
          loading: () => const Text(
            '—',
            key: Key('about_version_loading'),
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          error: (e, _) => const Text(
            '—',
            key: Key('about_version_fallback'),
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 16,
            ),
          ),
          data: (version) => Text(
            version ?? '—',
            key: const Key('about_version_value'),
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _AboutCard — app description
// ---------------------------------------------------------------------------

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      sectionLabel: 'ABOUT',
      children: [
        Text(
          'Mileage is a personal driving tracker that records trips and provides '
          'driving statistics and analytics.',
          key: Key('about_description'),
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _Footer
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Built for personal use.',
        key: Key('about_footer'),
        style: TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionCard — shared rounded card container
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.children,
    this.sectionLabel,
  });

  final List<Widget> children;
  final String? sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionLabel != null) ...[
          Text(
            sectionLabel!,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}
