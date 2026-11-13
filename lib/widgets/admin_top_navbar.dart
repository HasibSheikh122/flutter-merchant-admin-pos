// lib/widgets/admin_top_navbar.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminTopNavbar extends StatefulWidget implements PreferredSizeWidget {
  final String storeName;
  final String? storeLogo;
  final Color brandGreen;
  final int pendingOrders;
  final int unreadNotifications;
  final bool voiceEnabled;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;
  final VoidCallback? onToggleVoiceTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback onMenuTap;
  final VoidCallback onRefreshTap;

  const AdminTopNavbar({
    super.key,
    required this.storeName,
    required this.storeLogo,
    required this.brandGreen,
    required this.pendingOrders,
    this.unreadNotifications = 0,
    this.voiceEnabled = true,
    this.isDarkMode = false,
    this.onToggleDarkMode,
    this.onToggleVoiceTap,
    this.onNotificationTap,
    required this.onMenuTap,
    required this.onRefreshTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 3);

  @override
  State createState() => _AdminTopNavbarState();
}

class _AdminTopNavbarState extends State {
  @override
  AdminTopNavbar get widget => super.widget as AdminTopNavbar;

  late Color _primaryColor;
  late Color _secondaryColor;
  bool _useGradient = true;

  @override
  void initState() {
    super.initState();
    _primaryColor = widget.brandGreen;
    _secondaryColor = const Color(0xFF1E3A1A);
    _loadSavedMobileColors();
  }

  @override
  void didUpdateWidget(covariant AdminTopNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSavedMobileColors();
  }

  Future _loadSavedMobileColors() async {
    final prefs = await SharedPreferences.getInstance();
    final String? pHex = prefs.getString('mobile_app_primary_color');
    final String? sHex = prefs.getString('mobile_app_secondary_color');
    final bool useGrad = prefs.getBool('mobile_app_use_gradient') ?? true;

    if (!mounted) return;
    setState(() {
      _primaryColor = _parseHex(pHex, widget.brandGreen);
      _secondaryColor = _parseHex(sHex, const Color(0xFF1E3A1A));
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
  Widget build(BuildContext context) {
    final Color appBarBg = widget.isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F6F0);
    final Color textColor =
        widget.isDarkMode ? Colors.white : const Color(0xFF1E3A1A);
    final Color subTextColor =
        widget.isDarkMode ? const Color(0xFF94A3B8) : _primaryColor;

    final int badgeCount = widget.unreadNotifications > 0
        ? widget.unreadNotifications
        : widget.pendingOrders;

    return AppBar(
      backgroundColor: appBarBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: _useGradient
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor.withValues(
                        alpha: widget.isDarkMode ? 0.22 : 0.14),
                    _secondaryColor.withValues(
                        alpha: widget.isDarkMode ? 0.18 : 0.08),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            )
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: _useGradient ? null : _primaryColor,
            gradient: _useGradient
                ? LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.menu_rounded, color: textColor, size: 28),
        onPressed: widget.onMenuTap,
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _useGradient
                  ? LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _useGradient
                  ? null
                  : (widget.isDarkMode
                      ? const Color(0xFF1E293B)
                      : Colors.white),
              border: Border.all(
                  color: _primaryColor.withValues(alpha: 0.7), width: 1.5),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              ),
              child: ClipOval(
                child: widget.storeLogo != null && widget.storeLogo!.isNotEmpty
                    ? Image.network(
                        widget.storeLogo!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.storefront_rounded,
                            color: _primaryColor,
                            size: 20),
                      )
                    : Icon(Icons.storefront_rounded,
                        color: _primaryColor, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Live Voice Alert Active',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.onToggleVoiceTap != null)
          IconButton(
            icon: Icon(
              widget.voiceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: widget.voiceEnabled ? _primaryColor : Colors.redAccent,
              size: 21,
            ),
            onPressed: widget.onToggleVoiceTap,
            tooltip: widget.voiceEnabled
                ? 'Voice Alert ON (Tap to Mute)'
                : 'Voice Alert Muted (Tap to Enable)',
          ),
        if (widget.onToggleDarkMode != null)
          IconButton(
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: widget.isDarkMode ? Colors.amber : _primaryColor,
              size: 21,
            ),
            onPressed: widget.onToggleDarkMode,
            tooltip: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
          ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: textColor, size: 22),
          onPressed: widget.onRefreshTap,
          tooltip: 'Sync Backend Data',
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                badgeCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: badgeCount > 0 ? _primaryColor : textColor,
                size: 24,
              ),
              onPressed: widget.onNotificationTap,
              tooltip: 'Live Notifications & Voice Center',
            ),
            if (badgeCount > 0)
              Positioned(
                right: 6,
                top: 8,
                child: GestureDetector(
                  onTap: widget.onNotificationTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}