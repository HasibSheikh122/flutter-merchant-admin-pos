import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSideDrawer extends StatefulWidget {
  final String storeName;
  final String? storeLogo;
  final Color brandGreen;
  final int totalOrders;
  final int totalCustomers;
  final int totalProducts;
  final int totalCategories;
  final int totalReviews;
  final int totalShops;
  final int maxProducts;
  final String planName;
  final String activeMenu;
  final bool isDarkMode;
  final ValueChanged? onToggleDarkMode;
  final ValueChanged? onMenuSelected;
  final VoidCallback onLogout;
  final VoidCallback? onOpenStore;

  const AdminSideDrawer({
    super.key,
    required this.storeName,
    this.storeLogo,
    this.brandGreen = const Color(0xFF16A34A),
    this.totalOrders = 0,
    this.totalCustomers = 0,
    this.totalProducts = 0,
    this.totalCategories = 0,
    this.totalReviews = 0,
    this.totalShops = 0,
    this.maxProducts = 100,
    this.planName = 'Growth Spark',
    this.activeMenu = 'overview',
    this.isDarkMode = false,
    this.onToggleDarkMode,
    this.onMenuSelected,
    required this.onLogout,
    this.onOpenStore,
  });

  @override
  State<AdminSideDrawer> createState() => _AdminSideDrawerState();
}

class _AdminSideDrawerState extends State<AdminSideDrawer> {
  final Set _openSections = {'shops'};

  late Color _primaryColor;
  late Color _secondaryColor;
  bool _useGradient = true;

  static const Color emeraldColor = Color(0xFF10B981);
  static const Color purpleColor = Color(0xFFA855F7);
  static const Color amberColor = Color(0xFFF59E0B);
  static const Color orangeColor = Color(0xFFF97316);
  static const Color cyanColor = Color(0xFF06B6D4);
  static const Color blueColor = Color(0xFF3B82F6);
  static const Color redColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _primaryColor = widget.brandGreen;
    _secondaryColor = const Color(0xFF1E3A1A);
    _autoOpenSectionForMenu(widget.activeMenu);
    _loadSavedMobileColors();
  }

  @override
  void didUpdateWidget(covariant AdminSideDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSavedMobileColors();
    if (oldWidget.activeMenu != widget.activeMenu) {
      _autoOpenSectionForMenu(widget.activeMenu);
    }
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

  LinearGradient get _brandGradient => LinearGradient(
        colors: [_primaryColor, _secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  void _autoOpenSectionForMenu(String menu) {
    if (['shop_list', 'shop_add', 'shops'].contains(menu)) {
      _openSections.add('shops');
    } else if ([
      'branch_list',
      'branch_add',
      'branch_export',
      'branch_notices',
      'branch_chat'
    ].contains(menu)) {
      _openSections.add('branches');
    } else if ([
      'cross_sell_credentials',
      'cross_sell_partners',
      'cross_sell_catalog',
      'cross_sell_ledger',
      'cross_selling'
    ].contains(menu)) {
      _openSections.add('cross_sell');
    } else if ([
      'courier_setup',
      'courier_booking',
      'courier_tracking',
      'courier_settlement',
      'courier'
    ].contains(menu)) {
      _openSections.add('courier');
    } else if ([
      'sms_individual',
      'sms_template',
      'sms_group',
      'sms_send',
      'sms_gateway',
      'sms'
    ].contains(menu)) {
      _openSections.add('sms');
    } else if (['email_gateway', 'email_logs', 'email'].contains(menu)) {
      _openSections.add('email');
    } else if ([
      'report_messages',
      'report_reviews',
      'report_customers',
      'report_sms',
      'report_orders',
      'reports'
    ].contains(menu)) {
      _openSections.add('reports');
    } else if ([
      'chat_customer',
      'chat_branch_merchant',
      'chat_branch_customer',
      'chat_superadmin',
      'messages',
      'chat',
      'live_chat'
    ].contains(menu)) {
      _openSections.add('chat');
    } else if (menu.startsWith('analytics')) {
      _openSections.add('analytics');
    } else if (['barcode_scanner', 'daily_collection', 'inventory']
        .contains(menu)) {
      _openSections.add('pos');
    } else if (['products', 'categories', 'reviews', 'gallery']
        .contains(menu)) {
      _openSections.add('catalog');
    } else if (['orders', 'customers', 'fraud_detection'].contains(menu)) {
      _openSections.add('sales');
    } else if (['employees', 'attendance', 'payroll', 'departments']
        .contains(menu)) {
      _openSections.add('hrm');
    } else if (menu == 'affiliates' || menu.startsWith('affiliate_')) {
      _openSections.add('affiliates');
    } else if ([
      'announcements',
      'store_announcements',
      'coupons',
      'banners',
      'newsletter'
    ].contains(menu)) {
      _openSections.add('marketing');
    } else if (['testimonials', 'blogs', 'faqs', 'store_gallery']
        .contains(menu)) {
      _openSections.add('cms');
    } else if (['app_builder', 'app_upload', 'app_navbar', 'mobile_apps']
        .contains(menu)) {
      _openSections.add('apps');
    } else if (['help', 'help_support', 'help_guides', 'help_videos']
        .contains(menu)) {
      _openSections.add('help');
    } else if (['themes', 'settings', 'company_settings'].contains(menu)) {
      _openSections.add('settings');
    }
  }

  void _toggleSection(String sectionKey) {
    setState(() {
      if (_openSections.contains(sectionKey)) {
        _openSections.remove(sectionKey);
      } else {
        _openSections.add(sectionKey);
      }
    });
  }

  void _selectMenu(String menuKey) {
    Navigator.of(context).maybePop();
    if (widget.onMenuSelected != null) {
      widget.onMenuSelected!(menuKey);
    }
  }

  bool _isMenuSelected(String key) {
    if (widget.activeMenu == key) return true;
    if (key == 'shop_list' && widget.activeMenu == 'shops') return true;
    if (key == 'chat_customer' &&
        (widget.activeMenu == 'messages' ||
            widget.activeMenu == 'chat' ||
            widget.activeMenu == 'live_chat')) {
      return true;
    }
    if (key == 'courier_setup' && widget.activeMenu == 'courier') return true;
    if (key == 'sms_gateway' && widget.activeMenu == 'sms') return true;
    if (key == 'email_gateway' && widget.activeMenu == 'email') return true;
    if (key == 'report_orders' && widget.activeMenu == 'reports') return true;
    if (key == 'affiliates' && widget.activeMenu == 'affiliate_overview') {
      return true;
    }
    if (key == 'help_support' && widget.activeMenu == 'help') return true;
    if (key == 'announcements' && widget.activeMenu == 'store_announcements') {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final double quotaPercent = widget.maxProducts > 0
        ? (widget.totalProducts / widget.maxProducts).clamp(0.0, 1.0)
        : 0.0;

    final Color bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color borderColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color itemTextColor =
        isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final Color subItemTextColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final Color mutedTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color boxBgColor =
        isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);

    return Drawer(
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: _useGradient
                    ? LinearGradient(
                        colors: [
                          _primaryColor.withValues(alpha: isDark ? 0.18 : 0.10),
                          _secondaryColor.withValues(
                              alpha: isDark ? 0.12 : 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _useGradient ? null : _primaryColor,
                      gradient: _useGradient ? _brandGradient : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.storeLogo != null &&
                              widget.storeLogo!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                widget.storeLogo!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MERCHANT LIVE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: _primaryColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Menu List
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildSingleItem(
                    keyName: 'overview',
                    label: 'Overview',
                    icon: Icons.dashboard_outlined,
                    itemTextColor: itemTextColor,
                    mutedTextColor: mutedTextColor,
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'shops',
                    title: 'Shops & Outlets',
                    icon: Icons.storefront_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'shop_list',
                        label: 'Shop List',
                        icon: Icons.store_outlined,
                        badgeText: widget.totalShops > 0
                            ? '${widget.totalShops}'
                            : 'Manage',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'shop_add',
                        label: 'Add Shop',
                        icon: Icons.add_business_outlined,
                        badgeText: '+ New',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'branches',
                    title: 'Branch Stores',
                    icon: Icons.hub_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'branch_list',
                        label: 'Branch List',
                        icon: Icons.apartment_rounded,
                        badgeText: 'Manage',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'branch_add',
                        label: 'Add Branch',
                        icon: Icons.add_circle_outline_rounded,
                        badgeText: '+ New',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'branch_export',
                        label: 'Export Product',
                        icon: Icons.file_download_outlined,
                        badgeText: 'Transfer',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'branch_notices',
                        label: 'Branch Notice',
                        icon: Icons.notifications_none_rounded,
                        badgeText: 'Alerts',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'branch_chat',
                        label: 'Branch Chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        badgeDot: true,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'cross_sell',
                    title: 'B2B Cross-Sell API',
                    icon: Icons.sync_alt_rounded,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'cross_sell_credentials',
                        label: 'API Keys & Platform %',
                        icon: Icons.key_outlined,
                        badgeText: 'Keys',
                        badgeColor: purpleColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'cross_sell_partners',
                        label: 'Partner & Markup %',
                        icon: Icons.percent_rounded,
                        badgeText: '+Profit',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'cross_sell_catalog',
                        label: 'Catalog Import',
                        icon: Icons.cloud_download_outlined,
                        badgeText: 'Sync',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'cross_sell_ledger',
                        label: 'Commission Ledger',
                        icon: Icons.account_balance_wallet_outlined,
                        badgeText: 'Split',
                        badgeColor: amberColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'courier',
                    title: 'Courier Service',
                    icon: Icons.local_shipping_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'courier_setup',
                        label: 'Courier API Setup',
                        icon: Icons.vpn_key_outlined,
                        badgeText: 'API',
                        badgeColor: orangeColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'courier_booking',
                        label: 'Booking & Dispatch',
                        icon: Icons.send_rounded,
                        badgeText: '1-Click',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'courier_tracking',
                        label: 'Live Tracking',
                        icon: Icons.radar_rounded,
                        badgeText: 'Sync',
                        badgeColor: cyanColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'courier_settlement',
                        label: 'COD Settlement',
                        icon: Icons.payments_outlined,
                        badgeText: 'Report',
                        badgeColor: purpleColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'sms',
                    title: 'SMS Service',
                    icon: Icons.sms_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'sms_individual',
                        label: 'Individual SMS',
                        icon: Icons.chat_outlined,
                        badgeText: 'Single',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'sms_template',
                        label: 'SMS Template',
                        icon: Icons.description_outlined,
                        badgeText: 'Presets',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'sms_group',
                        label: 'SMS Group',
                        icon: Icons.groups_outlined,
                        badgeText: 'Lists',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'sms_send',
                        label: 'Send SMS',
                        icon: Icons.forward_to_inbox_rounded,
                        badgeText: 'Bulk',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'sms_gateway',
                        label: 'SMS Gateway',
                        icon: Icons.settings_ethernet_rounded,
                        badgeText: 'API',
                        badgeColor: purpleColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'email',
                    title: 'Email Service',
                    icon: Icons.mail_outline_rounded,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'email_gateway',
                        label: 'Email Gateway',
                        icon: Icons.dns_outlined,
                        badgeText: 'SMTP',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'email_logs',
                        label: 'Email Logs',
                        icon: Icons.mark_email_read_outlined,
                        badgeText: 'History',
                        badgeColor: purpleColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'reports',
                    title: 'Reports',
                    icon: Icons.assignment_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'report_messages',
                        label: 'Message Reports',
                        icon: Icons.mark_chat_read_outlined,
                        badgeText: 'Chat',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'report_reviews',
                        label: 'Review Reports',
                        icon: Icons.star_border_rounded,
                        badgeText: '${widget.totalReviews}',
                        badgeColor: amberColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'report_customers',
                        label: 'Customers Report',
                        icon: Icons.people_outline_rounded,
                        badgeText: '${widget.totalCustomers}',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'report_sms',
                        label: 'SMS Reports',
                        icon: Icons.textsms_outlined,
                        badgeText: 'Logs',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'report_orders',
                        label: 'Order Reports',
                        icon: Icons.receipt_long_outlined,
                        badgeText: 'Sales',
                        badgeColor: purpleColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'chat',
                    title: 'Live Chat Channels',
                    icon: Icons.forum_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'chat_customer',
                        label: 'Customer Chat',
                        icon: Icons.support_agent_rounded,
                        badgeDot: true,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'chat_branch_merchant',
                        label: 'Merchant & Branch',
                        icon: Icons.business_center_outlined,
                        badgeText: 'B2B',
                        badgeColor: blueColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'chat_branch_customer',
                        label: 'Branch & Customer',
                        icon: Icons.store_mall_directory_outlined,
                        badgeText: 'OUTLET',
                        badgeColor: purpleColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'chat_superadmin',
                        label: 'SuperAdmin HQ',
                        icon: Icons.verified_user_outlined,
                        badgeText: 'HQ MEET',
                        badgeColor: amberColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'analytics',
                    title: 'Analytics & BI',
                    icon: Icons.bar_chart_rounded,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'analytics_customer',
                        label: 'Customer Intelligence',
                        icon: Icons.insights_rounded,
                        badgeText: widget.totalCustomers > 0
                            ? '${widget.totalCustomers} Users'
                            : 'Funnel',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'analytics_orders',
                        label: 'Orders & Cashflow',
                        icon: Icons.show_chart_rounded,
                        badgeText: '24h Heat',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'analytics_products',
                        label: 'Product & AI Curves',
                        icon: Icons.trending_up_rounded,
                        badgeText: widget.totalProducts > 0
                            ? '${widget.totalProducts} SKUs'
                            : 'Predict',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'analytics_categories',
                        label: 'Category & FB Market',
                        icon: Icons.pie_chart_outline_rounded,
                        badgeText: widget.totalCategories > 0
                            ? '${widget.totalCategories} Dept'
                            : 'Treemap',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'pos',
                    title: 'POS & Counter',
                    icon: Icons.qr_code_scanner_rounded,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'barcode_scanner',
                        label: 'Barcode Stock Out',
                        icon: Icons.document_scanner_outlined,
                        badgeText: 'Scan',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'daily_collection',
                        label: 'Daily Collection',
                        icon: Icons.point_of_sale_rounded,
                        badgeText: 'Audit',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'inventory',
                        label: 'Inventory & Stock',
                        icon: Icons.shelves,
                        badgeText: 'Live',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'catalog',
                    title: 'Products & Catalog',
                    icon: Icons.inventory_2_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'products',
                        label: 'Products',
                        icon: Icons.inventory_outlined,
                        badgeText: '${widget.totalProducts}',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'categories',
                        label: 'Categories',
                        icon: Icons.category_outlined,
                        badgeText: '${widget.totalCategories}',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'reviews',
                        label: 'Reviews',
                        icon: Icons.star_rate_rounded,
                        badgeText: widget.totalReviews > 0
                            ? '${widget.totalReviews}'
                            : null,
                        badgeColor: amberColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'gallery',
                        label: 'Product Images',
                        icon: Icons.photo_library_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'sales',
                    title: 'Sales & Orders',
                    icon: Icons.shopping_bag_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'orders',
                        label: 'Orders',
                        icon: Icons.shopping_cart_outlined,
                        badgeText: widget.totalOrders > 0
                            ? '${widget.totalOrders}'
                            : '0',
                        badgeColor: widget.totalOrders > 0
                            ? amberColor
                            : const Color(0xFF64748B),
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'customers',
                        label: 'Customers',
                        icon: Icons.people_alt_outlined,
                        badgeText: '${widget.totalCustomers}',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'fraud_detection',
                        label: 'COD Fraud Shield',
                        icon: Icons.security_rounded,
                        badgeText: 'AI',
                        badgeColor: redColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'hrm',
                    title: 'HR & Payroll',
                    icon: Icons.badge_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'employees',
                        label: 'Employee List',
                        icon: Icons.badge_rounded,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'attendance',
                        label: 'Attendance Daily',
                        icon: Icons.how_to_reg_outlined,
                        badgeText: 'Live',
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'payroll',
                        label: 'Salary Sheet & Payslip',
                        icon: Icons.receipt_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'departments',
                        label: 'Departments & Roles',
                        icon: Icons.workspaces_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'affiliates',
                    title: 'Affiliate Marketing',
                    icon: Icons.diversity_3_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'affiliates',
                        label: 'Affiliate Overview',
                        icon: Icons.auto_graph_rounded,
                        badgeText: 'Earn',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'affiliate_partners',
                        label: 'Marketers & Links',
                        icon: Icons.link_rounded,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'affiliate_form_builder',
                        label: 'Reg. Form Builder',
                        icon: Icons.dynamic_form_outlined,
                        badgeText: '4 Modes',
                        badgeColor: purpleColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'affiliate_products',
                        label: 'Products & Campaigns',
                        icon: Icons.campaign_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'affiliate_commissions',
                        label: 'Orders & Ledger',
                        icon: Icons.receipt_long_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'affiliate_payouts',
                        label: 'Commission Payouts',
                        icon: Icons.payments_outlined,
                        badgeText: 'Payout',
                        badgeColor: amberColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'affiliate_settings',
                        label: 'Settings & Fraud',
                        icon: Icons.tune_rounded,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'marketing',
                    title: 'Marketing & Promos',
                    icon: Icons.campaign_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'announcements',
                        label: 'Store Announcements',
                        icon: Icons.volume_up_outlined,
                        badgeText: 'Marquee',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'coupons',
                        label: 'Coupons',
                        icon: Icons.confirmation_number_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'banners',
                        label: 'Banners & Promos',
                        icon: Icons.photo_size_select_actual_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'newsletter',
                        label: 'Newsletter Leads',
                        icon: Icons.mark_email_unread_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'cms',
                    title: 'Store CMS',
                    icon: Icons.article_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'testimonials',
                        label: 'Testimonials',
                        icon: Icons.format_quote_rounded,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'blogs',
                        label: 'News & Blogs',
                        icon: Icons.newspaper_rounded,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'faqs',
                        label: 'Store FAQs',
                        icon: Icons.help_outline_rounded,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'store_gallery',
                        label: 'Store Gallery',
                        icon: Icons.add_photo_alternate_outlined,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'apps',
                    title: 'Mobile & Desktop Apps',
                    icon: Icons.smartphone_rounded,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'app_builder',
                        label: 'Generate Apps',
                        icon: Icons.auto_awesome_rounded,
                        badgeText: '2 GitHub',
                        badgeColor: _primaryColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'app_upload',
                        label: 'Upload APK / iOS',
                        icon: Icons.upload_file_rounded,
                        badgeText: 'Binaries',
                        badgeColor: cyanColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'app_navbar',
                        label: 'Navbar App Links',
                        icon: Icons.download_rounded,
                        badgeText: 'Live',
                        badgeColor: purpleColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Help & Support Visual Guide Section
                  _buildDropdownGroup(
                    sectionKey: 'help',
                    title: 'Help & Support',
                    icon: Icons.menu_book_rounded,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'help_support',
                        label: 'Setup & Video Guides',
                        icon: Icons.play_lesson_outlined,
                        badgeText: 'GUIDE',
                        badgeColor: amberColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'help_videos',
                        label: 'YouTube & FB Tutorials',
                        icon: Icons.ondemand_video_rounded,
                        badgeText: 'HD',
                        badgeColor: cyanColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildDropdownGroup(
                    sectionKey: 'settings',
                    title: 'Settings & Theme',
                    icon: Icons.settings_outlined,
                    titleColor: titleColor,
                    mutedTextColor: mutedTextColor,
                    subItemTextColor: subItemTextColor,
                    children: [
                      _buildSubItem(
                        keyName: 'themes',
                        label: 'Theme Store',
                        icon: Icons.auto_fix_high_rounded,
                        badgeText: 'NEW',
                        badgeColor: amberColor,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'settings',
                        label: 'General Settings',
                        icon: Icons.tune_rounded,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                      _buildSubItem(
                        keyName: 'company_settings',
                        label: 'Company Settings',
                        icon: Icons.business_rounded,
                        subItemTextColor: subItemTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Bottom Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: borderColor, width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: boxBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                              size: 16,
                              color: isDark ? amberColor : _primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 24,
                          child: Switch(
                            value: isDark,
                            activeColor: Colors.white,
                            activeTrackColor: _primaryColor,
                            onChanged: (val) {
                              if (widget.onToggleDarkMode != null) {
                                widget.onToggleDarkMode!(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: boxBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quota',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: mutedTextColor,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                widget.planName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: _primaryColor,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: quotaPercent,
                            backgroundColor: borderColor,
                            color: _primaryColor,
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${widget.totalProducts} Items',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: mutedTextColor,
                              ),
                            ),
                            Text(
                              'Max: ${widget.maxProducts}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onOpenStore,
                          icon: Icon(
                            Icons.open_in_new_rounded,
                            size: 15,
                            color: _primaryColor,
                          ),
                          label: Text(
                            'Store',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: itemTextColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: bgColor,
                            side: BorderSide(
                              color: borderColor,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: widget.onLogout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 15,
                            color: Color(0xFFEF4444),
                          ),
                          label: const Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF450A0A).withValues(alpha: 0.4)
                                : const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF7F1D1D)
                                    : const Color(0xFFFECACA),
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
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
      ),
    );
  }

  Widget _buildSingleItem({
    required String keyName,
    required String label,
    required IconData icon,
    required Color itemTextColor,
    required Color mutedTextColor,
  }) {
    final bool isSelected = _isMenuSelected(keyName);

    return InkWell(
      onTap: () => _selectMenu(keyName),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (_useGradient ? null : _primaryColor)
              : Colors.transparent,
          gradient: (isSelected && _useGradient) ? _brandGradient : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : mutedTextColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? Colors.white : itemTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownGroup({
    required String sectionKey,
    required String title,
    required IconData icon,
    required Color titleColor,
    required Color mutedTextColor,
    required Color subItemTextColor,
    required List children,
  }) {
    final bool isOpen = _openSections.contains(sectionKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleSection(sectionKey),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isOpen
                  ? _primaryColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOpen
                    ? _primaryColor.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: _primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isOpen ? _primaryColor : mutedTextColor,
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          Container(
            margin: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: _primaryColor.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children.cast(),
            ),
          ),
      ],
    );
  }

  Widget _buildSubItem({
    required String keyName,
    required String label,
    IconData? icon,
    String? badgeText,
    Color? badgeColor,
    bool badgeDot = false,
    required Color subItemTextColor,
    required Color mutedTextColor,
  }) {
    final bool isSelected = _isMenuSelected(keyName);
    final Color effectiveBadgeColor = badgeColor ?? mutedTextColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => _selectMenu(keyName),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected
                ? (_useGradient ? null : _primaryColor)
                : Colors.transparent,
            gradient: (isSelected && _useGradient) ? _brandGradient : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : mutedTextColor,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : subItemTextColor,
                  ),
                ),
              ),
              if (badgeDot)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryColor,
                  ),
                )
              else if (badgeText != null && badgeText.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : effectiveBadgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: isSelected ? Colors.white : effectiveBadgeColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}