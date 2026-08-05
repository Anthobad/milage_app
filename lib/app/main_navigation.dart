import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/colors.dart';
import 'theme/spacing.dart';
import 'router.dart';

/// Shell widget that wraps all main tabs with a floating [_FloatingNavBar].
///
/// Rendered by the [StatefulShellRoute] in [appRouter].
/// Each tab maintains its own navigation stack.
class MainNavigation extends StatelessWidget {
  const MainNavigation({
    super.key,
    required this.navigationShell,
  });

  /// Provided by [StatefulShellRoute]; holds per-branch navigation state.
  final StatefulNavigationShell navigationShell;

  // Tab order: Map → Trips → Cars → Analytics → Profile
  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Map',
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
    ),
    _NavItem(
      label: 'Trips',
      icon: Icons.route_outlined,
      activeIcon: Icons.route,
    ),
    _NavItem(
      label: 'Cars',
      icon: Icons.directions_car_outlined,
      activeIcon: Icons.directions_car,
    ),
    _NavItem(
      label: 'Analytics',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      // Return to the initial route of the branch when re-tapping active tab.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No bottomNavigationBar — the nav bar floats over the body via Stack.
      body: Stack(
        children: [
          // Content — full screen; inner screens add their own padding if needed.
          navigationShell,

          // Floating nav bar pinned to bottom, respecting safe area.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingNavBar(
              selectedIndex: navigationShell.currentIndex,
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

/// A floating pill-shaped navigation bar that sits above the screen edge.
///
/// - Rounded corners (pill shape)
/// - Respects system safe area (bottom inset)
/// - Large touch targets (min 48 × 48 dp per item)
/// - Blue highlight + scale animation on the active tab
/// - Smooth animated transitions between tabs
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  /// Horizontal margin from screen edges.
  static const double _hMargin = 16.0;

  /// Bottom margin above the system safe area.
  static const double _vMargin = 12.0;

  /// Internal vertical padding inside the bar.
  static const double _vPadding = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final Color barColor = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _hMargin,
        0,
        _hMargin,
        _vMargin + bottomInset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _vPadding,
            horizontal: _vPadding,
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

    final Color iconColor = isSelected ? activeColor : inactiveColor;
    final Color labelColor = isSelected ? activeColor : inactiveColor;

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
              // Icon — scale animation on active.
              AnimatedScale(
                scale: isSelected ? 1.10 : 1.0,
                duration: _duration,
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: _duration,
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    key: ValueKey(isSelected),
                    color: iconColor,
                    size: 24,
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // Label with animated color.
              AnimatedDefaultTextStyle(
                duration: _duration,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: labelColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
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
