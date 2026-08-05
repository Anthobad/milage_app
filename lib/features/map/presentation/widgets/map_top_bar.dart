import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';

/// Floating top bar displayed over the map.
///
/// Left side: "MILEAGE" title.
/// Right side: search icon that animates into a full-width search field.
///
/// Search functionality is a placeholder — wired up in a future phase.
class MapTopBar extends StatefulWidget {
  const MapTopBar({super.key});

  @override
  State<MapTopBar> createState() => _MapTopBarState();
}

class _MapTopBarState extends State<MapTopBar>
    with SingleTickerProviderStateMixin {
  bool _searchExpanded = false;
  late final AnimationController _animController;
  late final Animation<double> _widthFactor;
  late final Animation<double> _fadeTitle;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _widthFactor = CurvedAnimation(
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
    super.dispose();
  }

  void _expandSearch() {
    setState(() => _searchExpanded = true);
    _animController.forward();
    _searchFocus.requestFocus();
  }

  void _collapseSearch() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _searchExpanded = false);
    });
    _searchCtrl.clear();
    _searchFocus.unfocus();
  }

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

    return Container(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                  ),
          ),

          // Search field — expands from right to full width.
          Expanded(
            child: AnimatedBuilder(
              animation: _widthFactor,
              builder: (context, child) {
                if (!_searchExpanded && _animController.value == 0) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: _widthFactor.value,
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
                onSubmitted: (_) {
                  // Destination search wired in Phase 4.2.
                },
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
    );
  }
}
