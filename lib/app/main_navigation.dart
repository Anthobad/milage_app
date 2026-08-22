import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cars/presentation/widgets/car_selector_sheet.dart';
import '../features/map/providers/open_car_sheet_provider.dart';
import 'theme/colors.dart';
import 'theme/spacing.dart';

// ---------------------------------------------------------------------------
// Nav bar layout constants (shared between the bar and the sheet positioning)
// ---------------------------------------------------------------------------

/// Horizontal margin from screen edge — matches nav bar.
const double _kNavHMargin = 16.0;

/// Bottom margin above safe area — matches nav bar.
const double _kNavVMargin = 12.0;

/// Internal vertical padding of the nav bar.
const double _kNavVPadding = 10.0;

/// Approximate rendered height of a single nav item (icon + gap + label).
const double _kNavItemHeight = 52.0;

/// Gap between the sheet and the top of the nav bar.
const double _kSheetNavGap = 12.0;

/// Total height the nav bar occupies from the bottom of the screen
/// (excluding the system safe area, which is added at runtime).
const double _kNavBarStaticHeight =
    _kNavVMargin + _kNavVPadding * 2 + _kNavItemHeight;

// ---------------------------------------------------------------------------
// MainNavigation
// ---------------------------------------------------------------------------

/// Shell widget that wraps all main tabs with a floating [_FloatingNavBar].
///
/// The Cars tab is special — it shows [CarSelectorSheet] as an inline
/// overlay inside the same Stack so the nav bar remains fully interactive.
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with SingleTickerProviderStateMixin {
  static const List<_NavItem> _items = [
    _NavItem(label: 'Map',       icon: Icons.map_outlined,            activeIcon: Icons.map),
    _NavItem(label: 'Trips',     icon: Icons.route_outlined,          activeIcon: Icons.route),
    _NavItem(label: 'Cars',      icon: Icons.directions_car_outlined, activeIcon: Icons.directions_car),
    _NavItem(label: 'Analytics', icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart),
    _NavItem(label: 'Profile',   icon: Icons.person_outline,          activeIcon: Icons.person),
  ];

  static const int _carsTabIndex = 2;

  bool _sheetOpen = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openSheet() {
    setState(() => _sheetOpen = true);
    _animController.forward();
  }

  void _closeSheet() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  void _onTabSelected(int index) {
    if (index == _carsTabIndex) {
      _sheetOpen ? _closeSheet() : _openSheet();
      return;
    }
    // Tapping any other tab also closes the sheet if open.
    if (_sheetOpen) _closeSheet();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for programmatic requests to open the car sheet (e.g. from the
    // no-vehicle dialog on the Start Drive button).  Resets to false after
    // acting so repeated requests work correctly.
    ref.listen<bool>(openCarSheetProvider, (_, shouldOpen) {
      if (shouldOpen) {
        _openSheet();
        // Reset the flag so a future request triggers the listener again.
        ref.read(openCarSheetProvider.notifier).reset();
      }
    });

    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Total height from screen bottom to the top of the nav bar.
    final double navBarBottom =
        _kNavBarStaticHeight + bottomInset + _kNavVMargin;

    // Sheet sits this far above the screen bottom.
    final double sheetBottom = navBarBottom + _kSheetNavGap;

    final int displayIndex =
        _sheetOpen ? _carsTabIndex : widget.navigationShell.currentIndex;

    return Scaffold(
      body: Stack(
        children: [
          // ── Page content ──────────────────────────────────────────────────
          widget.navigationShell,

          // ── Scrim — closes sheet on tap, sits below nav bar ───────────────
          if (_sheetOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSheet,
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

          // ── Car selector sheet ────────────────────────────────────────────
          if (_sheetOpen)
            Positioned(
              left: _kNavHMargin,
              right: _kNavHMargin,
              bottom: sheetBottom,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: CarSelectorSheet(onClose: _closeSheet),
                ),
              ),
            ),

          // ── Floating nav bar ──────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingNavBar(
              selectedIndex: displayIndex,
              items: _items,
              onTap: _onTabSelected,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating navigation bar
// ---------------------------------------------------------------------------

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final Color barColor = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kNavHMargin,
        0,
        _kNavHMargin,
        _kNavVMargin + bottomInset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _kNavVPadding,
            horizontal: _kNavVPadding,
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              return Expanded(
                child: _NavBarItem(
                  item: items[index],
                  isSelected: index == selectedIndex,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual nav item
// ---------------------------------------------------------------------------

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final Color activeColor = AppColors.primary;
    final Color inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Semantics(
      label: item.label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.10 : 1.0,
                duration: _duration,
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: _duration,
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    key: ValueKey(isSelected),
                    color: isSelected ? activeColor : inactiveColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: _duration,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: isSelected ? activeColor : inactiveColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
