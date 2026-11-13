// lib/widgets/admin_bottom_navbar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminBottomNavbar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color backgroundColor;
  final Color activeColor;

  const AdminBottomNavbar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.backgroundColor = const Color(0xFF1E3A1A),
    this.activeColor = const Color(0xFF10B981),
  });

  @override
  State<AdminBottomNavbar> createState() => _AdminBottomNavbarState();
}

class _AdminBottomNavbarState extends State<AdminBottomNavbar> {
  late final ScrollController _scrollController;

  Color _primaryColor = const Color(0xFF10B981);
  Color _secondaryColor = const Color(0xFF1E3A1A);
  bool _useGradient = true;

  static const _navItems = [
    _NavItemData(
      title: 'Overview',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    _NavItemData(
      title: 'Orders',
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag_rounded,
    ),
    _NavItemData(
      title: 'Products',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
    ),
    _NavItemData(
      title: 'Category',
      icon: Icons.category_outlined,
      activeIcon: Icons.category_rounded,
    ),
    _NavItemData(
      title: 'Inventory',
      icon: Icons.shelves,
      activeIcon: Icons.shelves,
    ),
    _NavItemData(
      title: 'Daily Collection',
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale_rounded,
    ),
    _NavItemData(
      title: 'Barcode Scan',
      icon: Icons.qr_code_scanner_rounded,
      activeIcon: Icons.qr_code_scanner_rounded,
    ),
    _NavItemData(
      title: 'Customers',
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
    ),
    _NavItemData(
      title: 'Notifications',
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
    ),
    _NavItemData(
      title: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _primaryColor = widget.activeColor;
    _secondaryColor = widget.backgroundColor;
    _scrollController = ScrollController();
    _loadSavedMobileColors();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(widget.selectedIndex);
    });
  }

  @override
  void didUpdateWidget(covariant AdminBottomNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSavedMobileColors();
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToIndex(widget.selectedIndex);
    }
  }

  Future<void> _loadSavedMobileColors() async {
    final prefs = await SharedPreferences.getInstance();
    final String? pHex = prefs.getString('mobile_app_primary_color');
    final String? sHex = prefs.getString('mobile_app_secondary_color');
    final bool useGrad = prefs.getBool('mobile_app_use_gradient') ?? true;

    if (!mounted) return;
    setState(() {
      _primaryColor = _parseHex(pHex, widget.activeColor);
      _secondaryColor = _parseHex(sHex, widget.backgroundColor);
      _useGradient = useGrad;
    });
  }

  Color _parseHex(String? hexStr, Color fallback) {
    if (hexStr == null || hexStr.trim().isEmpty) return fallback;
    String clean = hexStr.trim().replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const double approxItemWidth = 100.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double targetOffset =
        (index * approxItemWidth) - (screenWidth / 2) + (approxItemWidth / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color blendedEnd =
        Color.lerp(_secondaryColor, _primaryColor, 0.38) ?? _primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: _useGradient ? null : _secondaryColor,
        gradient: _useGradient
            ? LinearGradient(
                colors: [_secondaryColor, blendedEnd],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: _primaryColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 68,
          child: ScrollConfiguration(
            behavior: const _CustomMouseAndTouchScrollBehavior(),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final isSelected = widget.selectedIndex == index;

                  return _AnimatedNavButton(
                    item: item,
                    isSelected: isSelected,
                    primaryColor: _primaryColor,
                    secondaryColor: _secondaryColor,
                    useGradient: _useGradient,
                    onTap: () {
                      widget.onTabSelected(index);
                      _scrollToIndex(index);
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomMouseAndTouchScrollBehavior extends MaterialScrollBehavior {
  const _CustomMouseAndTouchScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class _AnimatedNavButton extends StatefulWidget {
  final _NavItemData item;
  final bool isSelected;
  final Color primaryColor;
  final Color secondaryColor;
  final bool useGradient;
  final VoidCallback onTap;

  const _AnimatedNavButton({
    required this.item,
    required this.isSelected,
    required this.primaryColor,
    required this.secondaryColor,
    required this.useGradient,
    required this.onTap,
  });

  @override
  State<_AnimatedNavButton> createState() => _AnimatedNavButtonState();
}

class _AnimatedNavButtonState extends State<_AnimatedNavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool highlighted = widget.isSelected || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : (widget.isSelected ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isSelected ? 16 : 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? (widget.useGradient
                      ? null
                      : widget.primaryColor.withValues(alpha: 0.85))
                  : (_isHovered
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent),
              gradient: (widget.isSelected && widget.useGradient)
                  ? LinearGradient(
                      colors: [
                        widget.primaryColor,
                        Color.lerp(widget.primaryColor, widget.secondaryColor,
                                0.55) ??
                            widget.secondaryColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? Colors.white.withValues(alpha: 0.45)
                    : (_isHovered
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.transparent),
                width: 1.2,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.primaryColor.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: Icon(
                    widget.isSelected
                        ? widget.item.activeIcon
                        : widget.item.icon,
                    key: ValueKey(widget.isSelected),
                    color: widget.isSelected
                        ? Colors.white
                        : (_isHovered
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7)),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.white
                        : (_isHovered
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7)),
                    fontSize: 10,
                    fontWeight: widget.isSelected
                        ? FontWeight.w900
                        : (highlighted ? FontWeight.w700 : FontWeight.w500),
                    letterSpacing: 0.2,
                  ),
                  child: Text(widget.item.title),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String title;
  final IconData icon;
  final IconData activeIcon;

  const _NavItemData({
    required this.title,
    required this.icon,
    required this.activeIcon,
  });
}