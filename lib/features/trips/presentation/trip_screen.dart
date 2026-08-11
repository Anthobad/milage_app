import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../cars/providers/vehicle_provider.dart';
import '../models/trip.dart';
import '../providers/trips_filter_provider.dart';
import '../providers/trip_stats_provider.dart';
import 'widgets/trip_card.dart';

// ---------------------------------------------------------------------------
// TripsScreen
// ---------------------------------------------------------------------------

/// Trips page — shows only trips for the currently selected vehicle.
///
/// Features:
/// - Vehicle filter via [vehicleTripsProvider] (auto-refreshes on vehicle change)
/// - Animated search bar (destination search, local, case-insensitive)
/// - Calendar date filter popup
/// - Combined filter + empty state handling
/// - Newest → oldest ordering (from repository)
/// - Delete trip via card's delete icon
class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen>
    with SingleTickerProviderStateMixin {
  // ── Search ────────────────────────────────────────────────────────────────

  bool _searchExpanded = false;
  late final AnimationController _animController;
  late final Animation<double> _fadeSearch;
  late final Animation<double> _fadeTitle;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
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
    setState(() => _searchExpanded = true);
    _animController.forward();
    _searchFocus.requestFocus();
  }

  void _collapseSearch() {
    _debounce?.cancel();
    _animController.reverse().then((_) {
      if (mounted) setState(() => _searchExpanded = false);
    });
    _searchCtrl.clear();
    _searchFocus.unfocus();
    ref.read(tripsFilterProvider.notifier).clearSearch();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) ref.read(tripsFilterProvider.notifier).setSearch(query);
    });
  }

  // ── Date filter ───────────────────────────────────────────────────────────

  Future<void> _openDateFilter(BuildContext context) async {
    final filter = ref.read(tripsFilterProvider);
    final now = DateTime.now();

    // Show date range picker.
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: (filter.startDate != null && filter.endDate != null)
          ? DateTimeRange(start: filter.startDate!, end: filter.endDate!)
          : null,
      helpText: 'Filter trips by date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.surfaceDark,
                  onSurface: AppColors.textPrimaryDark,
                ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.surfaceDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return;

    if (range != null) {
      ref
          .read(tripsFilterProvider.notifier)
          .setDateRange(range.start, range.end);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(selectedVehicleProvider);
    final filter = ref.watch(tripsFilterProvider);
    final asyncFiltered = ref.watch(filteredTripsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, //Theme.of(context).colorScheme.surface
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────────
            _TopBar(
              searchExpanded: _searchExpanded,
              fadeTitle: _fadeTitle,
              fadeSearch: _fadeSearch,
              searchCtrl: _searchCtrl,
              searchFocus: _searchFocus,
              filter: filter,
              onSearchExpand: _expandSearch,
              onSearchCollapse: _collapseSearch,
              onSearchChanged: _onSearchChanged,
              onCalendarTap: () => _openDateFilter(context),
              onClearDate: () =>
                  ref.read(tripsFilterProvider.notifier).clearDateFilter(),
            ),

            // ── Filter chips ────────────────────────────────────────────
            if (filter.hasAnyFilter)
              _FilterChips(
                filter: filter,
                onClearSearch: () {
                  _searchCtrl.clear();
                  ref.read(tripsFilterProvider.notifier).clearSearch();
                },
                onClearDate: () =>
                    ref.read(tripsFilterProvider.notifier).clearDateFilter(),
                onClearAll: () {
                  _collapseSearch();
                  ref.read(tripsFilterProvider.notifier).clearAll();
                },
              ),

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: asyncFiltered.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (trips) {
                  if (vehicle == null) return const _NoVehicleState();
                  if (trips.isEmpty && !filter.hasAnyFilter) {
                    return _EmptyVehicleState(
                        vehicleName:
                            '${vehicle.brand} ${vehicle.model}');
                  }
                  if (trips.isEmpty && filter.hasAnyFilter) {
                    return const _NoResultsState();
                  }
                  return _TripList(trips: trips);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TopBar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchExpanded,
    required this.fadeTitle,
    required this.fadeSearch,
    required this.searchCtrl,
    required this.searchFocus,
    required this.filter,
    required this.onSearchExpand,
    required this.onSearchCollapse,
    required this.onSearchChanged,
    required this.onCalendarTap,
    required this.onClearDate,
  });

  final bool searchExpanded;
  final Animation<double> fadeTitle;
  final Animation<double> fadeSearch;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final TripsFilterState filter;
  final VoidCallback onSearchExpand;
  final VoidCallback onSearchCollapse;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCalendarTap;
  final VoidCallback onClearDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = AppColors.textPrimaryDark;
    final iconColor = AppColors.textSecondaryDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.md,
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Title — fades out when search is expanded.
          FadeTransition(
            opacity: fadeTitle,
            child: searchExpanded
                ? const SizedBox.shrink()
                : Text(
                    'Trips',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),

          // Search field — expands when active.
          Expanded(
            child: AnimatedBuilder(
              animation: fadeSearch,
              builder: (context, child) {
                if (!searchExpanded && _animValue(fadeSearch) == 0) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: _animValue(fadeSearch),
                  child: child,
                );
              },
              child: TextField(
                controller: searchCtrl,
                focusNode: searchFocus,
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search by destination…',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: iconColor,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Icon(Icons.search, color: iconColor, size: 18),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 30, minHeight: 0),
                ),
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
              ),
            ),
          ),

          // Icons: search / close + calendar.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search toggle.
              IconButton(
                icon: Icon(
                  searchExpanded ? Icons.close : Icons.search,
                  color: searchExpanded ? AppColors.primary : iconColor,
                ),
                tooltip: searchExpanded ? 'Close search' : 'Search trips',
                onPressed:
                    searchExpanded ? onSearchCollapse : onSearchExpand,
                visualDensity: VisualDensity.compact,
              ),

              // Calendar — only show when search is not expanded.
              if (!searchExpanded)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.calendar_month_outlined,
                        color: filter.hasDateFilter
                            ? AppColors.primary
                            : iconColor,
                      ),
                      tooltip: 'Filter by date',
                      onPressed: onCalendarTap,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (filter.hasDateFilter)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  double _animValue(Animation<double> anim) => anim.value;
}

// ---------------------------------------------------------------------------
// _FilterChips
// ---------------------------------------------------------------------------

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.onClearSearch,
    required this.onClearDate,
    required this.onClearAll,
  });

  final TripsFilterState filter;
  final VoidCallback onClearSearch;
  final VoidCallback onClearDate;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        0,
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          if (filter.hasSearch)
            _Chip(
              label: '"${filter.searchQuery}"',
              onRemove: onClearSearch,
            ),
          if (filter.hasDateFilter)
            _Chip(
              label: _dateRangeLabel(filter),
              onRemove: onClearDate,
            ),
          if (filter.hasSearch && filter.hasDateFilter)
            TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Clear all',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  static String _dateRangeLabel(TripsFilterState f) {
    if (f.startDate != null && f.endDate != null) {
      final s = _fmt(f.startDate!);
      final e = _fmt(f.endDate!);
      return s == e ? s : '$s – $e';
    }
    if (f.startDate != null) return 'From ${_fmt(f.startDate!)}';
    if (f.endDate != null) return 'Until ${_fmt(f.endDate!)}';
    return 'Date filtered';
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 13, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TripList
// ---------------------------------------------------------------------------

class _TripList extends ConsumerWidget {
  const _TripList({required this.trips});
  final List<Trip> trips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.screenPaddingV,
      ),
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final trip = trips[index];
        // Load the GPS track points for this trip's thumbnail.
        final statsState = ref.watch(tripStatsProvider(trip.id));
        final trackPoints = statsState.trackPoints
            .map((tp) => tp.latLng)
            .toList();

        return TripCard(trip: trip, trackPoints: trackPoints);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------

class _NoVehicleState extends StatelessWidget {
  const _NoVehicleState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No vehicle selected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Select or add a vehicle to see trips.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyVehicleState extends StatelessWidget {
  const _EmptyVehicleState({required this.vehicleName});
  final String vehicleName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 64,
              color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No trips yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No trips have been recorded for $vehicleName.\nStart a drive to record your first trip.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 64,
              color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No matching trips',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No trips match the current filters.\nTry adjusting your search or date range.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
