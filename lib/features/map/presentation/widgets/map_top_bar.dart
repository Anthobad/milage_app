import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../models/destination.dart';
import '../../models/drive_state.dart';
import '../../providers/destination_provider.dart';
import '../../providers/drive_provider.dart';
import '../../providers/map_provider.dart';
import '../../services/geocoding_service.dart';
import '../dialogs/end_reckless_drive_dialog.dart';

// ---------------------------------------------------------------------------
// MapTopBar
// ---------------------------------------------------------------------------

/// Floating top bar displayed over the map.
///
/// Collapsed state:  "MILEAGE" title  |  search icon
/// Expanded state:   search text field  |  close icon  →  results overlay
///
/// Search flow:
///   1. User taps search icon → field expands, keyboard opens.
///   2. User types → 400 ms debounce → Nominatim query.
///   3. Results drop down below the bar.
///   4. User selects a result → destination set, map moves, search collapses.
///   5. User taps close → search collapses, results cleared.
class MapTopBar extends ConsumerStatefulWidget {
  const MapTopBar({super.key});

  @override
  ConsumerState<MapTopBar> createState() => _MapTopBarState();
}

class _MapTopBarState extends ConsumerState<MapTopBar>
    with SingleTickerProviderStateMixin {
  // ── Animation ────────────────────────────────────────────────────────────

  bool _searchExpanded = false;
  late final AnimationController _animController;
  late final Animation<double> _fadeSearch;
  late final Animation<double> _fadeTitle;

  // ── Search ────────────────────────────────────────────────────────────────

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  List<Destination> _results = [];
  bool _isSearching = false;
  String? _searchError;

  final GeocodingService _geocodingService = const GeocodingService();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeSearch = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _fadeTitle = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search control ────────────────────────────────────────────────────────

  void _expandSearch() {
    setState(() {
      _searchExpanded = true;
      _results = [];
      _searchError = null;
    });
    _animController.forward();
    _searchFocus.requestFocus();
  }

  void _collapseSearch() {
    _debounce?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _searchExpanded = false;
          _results = [];
          _isSearching = false;
          _searchError = null;
        });
      }
    });
    _searchCtrl.clear();
    _searchFocus.unfocus();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    // 400 ms debounce — Nominatim fair-use requires ≤1 req/s.
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final result = await _geocodingService.search(query);
      if (!mounted) return;

      switch (result) {
        case GeocodingSuccess(:final places):
          setState(() {
            _results = places;
            _isSearching = false;
            _searchError =
                places.isEmpty ? 'No results found.' : null;
          });
        case GeocodingError(:final message):
          setState(() {
            _results = [];
            _isSearching = false;
            _searchError = message;
          });
      }
    });
  }

  Future<void> _onResultSelected(Destination destination) async {
    final drive = ref.read(driveProvider);

    // ── Reckless drive active: ask before switching to destination mode ──────
    // Selecting a destination while Reckless Mode is running must never silently
    // switch modes.  Show a confirmation dialog first.
    if (drive.isActive && drive.mode == DriveMode.reckless) {
      // Collapse search first so the dialog renders on top cleanly.
      _collapseSearch();

      if (!mounted) return;
      final confirmed = await showEndRecklessDriveDialog(context);

      if (!mounted) return;
      if (confirmed != true) {
        // User cancelled — keep Reckless drive running, discard the destination.
        return;
      }

      // User confirmed → end the Reckless drive, then set the destination.
      await ref.read(driveProvider.notifier).finishDrive();
    } else {
      // Normal path — collapse search UI immediately.
      _collapseSearch();
    }

    if (!mounted) return;

    // 1. Save destination to provider (drive is now idle / not reckless).
    ref.read(destinationProvider.notifier).setDestination(destination);

    // 2. Move map camera to the selected destination.
    ref.read(mapProvider.notifier).moveCamera(destination.latLng);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color barColor = brightness == Brightness.dark
        ? AppColors.surfaceDark.withValues(alpha: 0.92)
        : AppColors.surfaceLight.withValues(alpha: 0.92);
    final Color textColor = brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final Color iconColor = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main bar ───────────────────────────────────────────────────────
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              // Title — fades out as search expands.
              FadeTransition(
                opacity: _fadeTitle,
                child: _searchExpanded
                    ? const SizedBox.shrink()
                    : Text(
                        'MILEAGE',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                      ),
              ),

              // Search field — expands from right to full width.
              Expanded(
                child: AnimatedBuilder(
                  animation: _fadeSearch,
                  builder: (context, child) {
                    if (!_searchExpanded && _animController.value == 0) {
                      return const SizedBox.shrink();
                    }
                    return Opacity(
                      opacity: _fadeSearch.value,
                      child: child,
                    );
                  },
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search destination…',
                      hintStyle: TextStyle(color: iconColor),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),

              // Loading indicator while searching.
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),

              // Search / close icon.
              GestureDetector(
                onTap: _searchExpanded ? _collapseSearch : _expandSearch,
                child: Icon(
                  _searchExpanded ? Icons.close : Icons.search,
                  color: _searchExpanded ? AppColors.primary : iconColor,
                  size: 22,
                ),
              ),
            ],
          ),
        ),

        // ── Results dropdown ───────────────────────────────────────────────
        if (_searchExpanded && (_results.isNotEmpty || _searchError != null))
          _SearchResultsDropdown(
            results: _results,
            error: _searchError,
            barColor: barColor,
            onSelected: _onResultSelected,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search results dropdown
// ---------------------------------------------------------------------------

class _SearchResultsDropdown extends StatelessWidget {
  const _SearchResultsDropdown({
    required this.results,
    required this.error,
    required this.barColor,
    required this.onSelected,
  });

  final List<Destination> results;
  final String? error;
  final Color barColor;
  final ValueChanged<Destination> onSelected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color textColor = brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final Color secondaryColor = brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final Color dividerColor = secondaryColor.withValues(alpha: 0.15);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: error != null
            ? _ErrorRow(message: error!, color: secondaryColor)
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 1,
                  color: dividerColor,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                ),
                itemBuilder: (context, index) {
                  final place = results[index];
                  return _ResultTile(
                    destination: place,
                    textColor: textColor,
                    secondaryColor: secondaryColor,
                    onTap: () => onSelected(place),
                  );
                },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single result tile
// ---------------------------------------------------------------------------

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.destination,
    required this.textColor,
    required this.secondaryColor,
    required this.onTap,
  });

  final Destination destination;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                destination.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error row
// ---------------------------------------------------------------------------

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}
