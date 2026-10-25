// lib/widgets/admin_side_drawer.dart
import 'package:flutter/material.dart';

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
  final ValueChanged<String>? onMenuSelected;
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
    this.onMenuSelected,
    required this.onLogout,
    this.onOpenStore,
  });

  @override
  State<AdminSideDrawer> createState() => _AdminSideDrawerState();
}

class _AdminSideDrawerState extends State<AdminSideDrawer> {
  final Set<String> _openSections = {'shops'};

  // Standard Color Palette
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
    _autoOpenSectionForMenu(widget.activeMenu);
  }

  @override
  void didUpdateWidget(covariant AdminSideDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeMenu != widget.activeMenu) {
      _autoOpenSectionForMenu(widget.activeMenu);
    }
  }

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
    } else if ([
      'email_gateway',
      'email_logs',
      'email'
    ].contains(menu)) {
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
      'messages',
      'chat'
    ].contains(menu)) {
      _openSections.add('chat');
    } else if (menu.startsWith('analytics')) {
      _openSections.add('analytics');
    } else if ([
      'barcode_scanner',
      'daily_collection',
      'inventory'
    ].contains(menu)) {
      _openSections.add('pos');
    } else if ([
      'products',
      'categories',
      'reviews',
      'gallery'
    ].contains(menu)) {
      _openSections.add('catalog');
    } else if ([
      'orders',
      'customers',
      'fraud_detection'
    ].contains(menu)) {
      _openSections.add('sales');
    } else if ([
      'employees',
      'attendance',
      'payroll',
      'departments'
    ].contains(menu)) {
      _openSections.add('hrm');
    } else if ([
      'announcements',
      'store_announcements',
      'coupons',
      'banners',
      'newsletter'
    ].contains(menu)) {
      _openSections.add('marketing');
    } else if ([
      'testimonials',
      'blogs',
      'faqs',
      'store_gallery'
    ].contains(menu)) {
      _openSections.add('cms');
    } else if ([
      'app_builder',
      'app_upload',
      'app_navbar',
      'mobile_apps'
    ].contains(menu)) {
      _openSections.add('apps');
    } else if ([
      'themes',
      'settings',
      'company_settings'
    ].contains(menu)) {
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
        (widget.activeMenu == 'messages' || widget.activeMenu == 'chat')) {
      return true;
    }
    if (key == 'courier_setup' && widget.activeMenu == 'courier') return true;
    if (key == 'sms_gateway' && widget.activeMenu == 'sms') return true;
    if (key == 'email_gateway' && widget.activeMenu == 'email') return true;
    if (key == 'report_orders' && widget.activeMenu == 'reports') return true;
    if (key == 'announcements' && widget.activeMenu == 'store_announcements') {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final double quotaPercent = widget.maxProducts > 0
        ? (widget.totalProducts / widget.maxProducts).clamp(0.0, 1.0)
        : 0.0;

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // Header: Store identity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.brandGreen,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: widget.brandGreen.withValues(alpha: 0.35),
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
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: emeraldColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MERCHANT LIVE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: widget.brandGreen,
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Menu List with Dropdown Groups
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                physics: const BouncingScrollPhysics(),
                children: [
                  // 1. Overview
                  _buildSingleItem(
                    keyName: 'overview',
                    label: 'Overview',
                    icon: Icons.dashboard_outlined,
                  ),
                  const SizedBox(height: 4),

                  // 2. Shops & Outlets
                  _buildDropdownGroup(
                    sectionKey: 'shops',
                    title: 'Shops & Outlets',
                    icon: Icons.storefront_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'shop_list',
                        label: 'Shop List',
                        icon: Icons.store_outlined,
                        badgeText: widget.totalShops > 0
                            ? '${widget.totalShops}'
                            : 'Manage',
                      ),
                      _buildSubItem(
                        keyName: 'shop_add',
                        label: 'Add Shop',
                        icon: Icons.add_business_outlined,
                        badgeText: '+ New',
                        badgeColor: emeraldColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 3. Branch Stores
                  _buildDropdownGroup(
                    sectionKey: 'branches',
                    title: 'Branch Stores',
                    icon: Icons.hub_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'branch_list',
                        label: 'Branch List',
                        icon: Icons.apartment_rounded,
                        badgeText: 'Manage',
                      ),
                      _buildSubItem(
                        keyName: 'branch_add',
                        label: 'Add Branch',
                        icon: Icons.add_circle_outline_rounded,
                        badgeText: '+ New',
                        badgeColor: emeraldColor,
                      ),
                      _buildSubItem(
                        keyName: 'branch_export',
                        label: 'Export Product',
                        icon: Icons.file_download_outlined,
                        badgeText: 'Transfer',
                      ),
                      _buildSubItem(
                        keyName: 'branch_notices',
                        label: 'Branch Notice',
                        icon: Icons.notifications_none_rounded,
                        badgeText: 'Alerts',
                      ),
                      _buildSubItem(
                        keyName: 'branch_chat',
                        label: 'Branch Chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        badgeDot: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 4. B2B Cross-Sell API
                  _buildDropdownGroup(
                    sectionKey: 'cross_sell',
                    title: 'B2B Cross-Sell API',
                    icon: Icons.sync_alt_rounded,
                    children: [
                      _buildSubItem(
                        keyName: 'cross_sell_credentials',
                        label: 'API Keys & Platform %',
                        icon: Icons.key_outlined,
                        badgeText: 'Keys',
                        badgeColor: purpleColor,
                      ),
                      _buildSubItem(
                        keyName: 'cross_sell_partners',
                        label: 'Partner & Markup %',
                        icon: Icons.percent_rounded,
                        badgeText: '+Profit',
                        badgeColor: emeraldColor,
                      ),
                      _buildSubItem(
                        keyName: 'cross_sell_catalog',
                        label: 'Catalog Import',
                        icon: Icons.cloud_download_outlined,
                        badgeText: 'Sync',
                      ),
                      _buildSubItem(
                        keyName: 'cross_sell_ledger',
                        label: 'Commission Ledger',
                        icon: Icons.account_balance_wallet_outlined,
                        badgeText: 'Split',
                        badgeColor: amberColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 5. Courier Service
                  _buildDropdownGroup(
                    sectionKey: 'courier',
                    title: 'Courier Service',
                    icon: Icons.local_shipping_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'courier_setup',
                        label: 'Courier API Setup',
                        icon: Icons.vpn_key_outlined,
                        badgeText: 'API',
                        badgeColor: orangeColor,
                      ),
                      _buildSubItem(
                        keyName: 'courier_booking',
                        label: 'Booking & Dispatch',
                        icon: Icons.send_rounded,
                        badgeText: '1-Click',
                        badgeColor: emeraldColor,
                      ),
                      _buildSubItem(
                        keyName: 'courier_tracking',
                        label: 'Live Tracking',
                        icon: Icons.radar_rounded,
                        badgeText: 'Sync',
                        badgeColor: cyanColor,
                      ),
                      _buildSubItem(
                        keyName: 'courier_settlement',
                        label: 'COD Settlement',
                        icon: Icons.payments_outlined,
                        badgeText: 'Report',
                        badgeColor: purpleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 6. SMS Service
                  _buildDropdownGroup(
                    sectionKey: 'sms',
                    title: 'SMS Service',
                    icon: Icons.sms_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'sms_individual',
                        label: 'Individual SMS',
                        icon: Icons.chat_outlined,
                        badgeText: 'Single',
                      ),
                      _buildSubItem(
                        keyName: 'sms_template',
                        label: 'SMS Template',
                        icon: Icons.description_outlined,
                        badgeText: 'Presets',
                      ),
                      _buildSubItem(
                        keyName: 'sms_group',
                        label: 'SMS Group',
                        icon: Icons.groups_outlined,
                        badgeText: 'Lists',
                      ),
                      _buildSubItem(
                        keyName: 'sms_send',
                        label: 'Send SMS',
                        icon: Icons.forward_to_inbox_rounded,
                        badgeText: 'Bulk',
                        badgeColor: emeraldColor,
                      ),
                      _buildSubItem(
                        keyName: 'sms_gateway',
                        label: 'SMS Gateway',
                        icon: Icons.settings_ethernet_rounded,
                        badgeText: 'API',
                        badgeColor: purpleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 7. Email Service
                  _buildDropdownGroup(
                    sectionKey: 'email',
                    title: 'Email Service',
                    icon: Icons.mail_outline_rounded,
                    children: [
                      _buildSubItem(
                        keyName: 'email_gateway',
                        label: 'Email Gateway',
                        icon: Icons.dns_outlined,
                        badgeText: 'SMTP',
                        badgeColor: emeraldColor,
                      ),
                      _buildSubItem(
                        keyName: 'email_logs',
                        label: 'Email Logs',
                        icon: Icons.mark_email_read_outlined,
                        badgeText: 'History',
                        badgeColor: purpleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 8. Reports
                  _buildDropdownGroup(
                    sectionKey: 'reports',
                    title: 'Reports',
                    icon: Icons.assignment_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'report_messages',
                        label: 'Message Reports',
                        icon: Icons.mark_chat_read_outlined,
                        badgeText: 'Chat',
                      ),
                      _buildSubItem(
                        keyName: 'report_reviews',
                        label: 'Review Reports',
                        icon: Icons.star_border_rounded,
                        badgeText: '${widget.totalReviews}',
                        badgeColor: amberColor,
                      ),
                      _buildSubItem(
                        keyName: 'report_customers',
                        label: 'Customers Report',
                        icon: Icons.people_outline_rounded,
                        badgeText: '${widget.totalCustomers}',
                      ),
                      _buildSubItem(
                        keyName: 'report_sms',
                        label: 'SMS Reports',
                        icon: Icons.textsms_outlined,
                        badgeText: 'Logs',
                        badgeColor: emeraldColor,
                      ),
                      _buildSubItem(
                        keyName: 'report_orders',
                        label: 'Order Reports',
                        icon: Icons.receipt_long_outlined,
                        badgeText: 'Sales',
                        badgeColor: purpleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 9. Live Chat Channels
                  _buildDropdownGroup(
                    sectionKey: 'chat',
                    title: 'Live Chat Channels',
                    icon: Icons.forum_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'chat_customer',
                        label: 'Customer Chat',
                        icon: Icons.support_agent_rounded,
                        badgeDot: true,
                      ),
                      _buildSubItem(
                        keyName: 'chat_branch_merchant',
                        label: 'Merchant & Branch',
                        icon: Icons.business_center_outlined,
                        badgeText: 'B2B',
                        badgeColor: blueColor,
                      ),
                      _buildSubItem(
                        keyName: 'chat_branch_customer',
                        label: 'Branch & Customer',
                        icon: Icons.store_mall_directory_outlined,
                        badgeText: 'Outlet',
                        badgeColor: purpleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 10. Analytics & BI
                  _buildDropdownGroup(
                    sectionKey: 'analytics',
                    title: 'Analytics & BI',
                    icon: Icons.bar_chart_rounded,
                    children: [
                      _buildSubItem(
                        keyName: 'analytics_customer',
                        label: 'Customer Intelligence',
                        icon: Icons.insights_rounded,
                        badgeText: widget.totalCustomers > 0
                            ? '${widget.totalCustomers} Users'
                            : 'Funnel',
                      ),
                      _buildSubItem(
                        keyName: 'analytics_orders',
                        label: 'Orders & Cashflow',
                        icon: Icons.show_chart_rounded,
                        badgeText: '24h Heat',
                      ),
                      _buildSubItem(
                        keyName: 'analytics_products',
                        label: 'Product & AI Curves',
                        icon: Icons.trending_up_rounded,
                        badgeText: widget.totalProducts > 0
                            ? '${widget.totalProducts} SKUs'
                            : 'Predict',
                      ),
                      _buildSubItem(
                        keyName: 'analytics_categories',
                        label: 'Category & FB Market',
                        icon: Icons.pie_chart_outline_rounded,
                        badgeText: widget.totalCategories > 0
                            ? '${widget.totalCategories} Dept'
                            : 'Treemap',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 11. POS & Counter
                  _buildDropdownGroup(
                    sectionKey: 'pos',
                    title: 'POS & Counter',
                    icon: Icons.qr_code_scanner_rounded,
                    children: [
                      _buildSubItem(
                        keyName: 'barcode_scanner',
                        label: 'Barcode Stock Out',
                        icon: Icons.document_scanner_outlined,
                        badgeText: 'Scan',
                      ),
                      _buildSubItem(
                        keyName: 'daily_collection',
                        label: 'Daily Collection',
                        icon: Icons.point_of_sale_rounded,
                        badgeText: 'Audit',
                      ),
                      _buildSubItem(
                        keyName: 'inventory',
                        label: 'Inventory & Stock',
                        icon: Icons.shelves,
                        badgeText: 'Live',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 12. Products & Catalog
                  _buildDropdownGroup(
                    sectionKey: 'catalog',
                    title: 'Products & Catalog',
                    icon: Icons.inventory_2_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'products',
                        label: 'Products',
                        icon: Icons.inventory_outlined,
                        badgeText: '${widget.totalProducts}',
                      ),
                      _buildSubItem(
                        keyName: 'categories',
                        label: 'Categories',
                        icon: Icons.category_outlined,
                        badgeText: '${widget.totalCategories}',
                      ),
                      _buildSubItem(
                        keyName: 'reviews',
                        label: 'Reviews',
                        icon: Icons.star_rate_rounded,
                        badgeText: widget.totalReviews > 0
                            ? '${widget.totalReviews}'
                            : null,
                        badgeColor: amberColor,
                      ),
                      _buildSubItem(
                        keyName: 'gallery',
                        label: 'Product Images',
                        icon: Icons.photo_library_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 13. Sales & Orders
                  _buildDropdownGroup(
                    sectionKey: 'sales',
                    title: 'Sales & Orders',
                    icon: Icons.shopping_bag_outlined,
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
                      ),
                      _buildSubItem(
                        keyName: 'customers',
                        label: 'Customers',
                        icon: Icons.people_alt_outlined,
                        badgeText: '${widget.totalCustomers}',
                      ),
                      _buildSubItem(
                        keyName: 'fraud_detection',
                        label: 'COD Fraud Shield',
                        icon: Icons.security_rounded,
                        badgeText: 'AI',
                        badgeColor: redColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 14. HR & Payroll
                  _buildDropdownGroup(
                    sectionKey: 'hrm',
                    title: 'HR & Payroll',
                    icon: Icons.badge_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'employees',
                        label: 'Employee List',
                        icon: Icons.badge_rounded,
                      ),
                      _buildSubItem(
                        keyName: 'attendance',
                        label: 'Attendance Daily',
                        icon: Icons.how_to_reg_outlined,
                        badgeText: 'Live',
                      ),
                      _buildSubItem(
                        keyName: 'payroll',
                        label: 'Salary Sheet & Payslip',
                        icon: Icons.receipt_outlined,
                      ),
                      _buildSubItem(
                        keyName: 'departments',
                        label: 'Departments & Roles',
                        icon: Icons.workspaces_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 15. Marketing & Promos
                  _buildDropdownGroup(
                    sectionKey: 'marketing',
                    title: 'Marketing & Promos',
                    icon: Icons.campaign_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'announcements',
                        label: 'Store Announcements',
                        icon: Icons.volume_up_outlined,
                        badgeText: 'Marquee',
                        badgeColor: emeraldColor,
                      ),
                      _buildSubItem(
                        keyName: 'coupons',
                        label: 'Coupons',
                        icon: Icons.confirmation_number_outlined,
                      ),
                      _buildSubItem(
                        keyName: 'banners',
                        label: 'Banners & Promos',
                        icon: Icons.photo_size_select_actual_outlined,
                      ),
                      _buildSubItem(
                        keyName: 'newsletter',
                        label: 'Newsletter Leads',
                        icon: Icons.mark_email_unread_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 16. Store CMS
                  _buildDropdownGroup(
                    sectionKey: 'cms',
                    title: 'Store CMS',
                    icon: Icons.article_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'testimonials',
                        label: 'Testimonials',
                        icon: Icons.format_quote_rounded,
                      ),
                      _buildSubItem(
                        keyName: 'blogs',
                        label: 'News & Blogs',
                        icon: Icons.newspaper_rounded,
                      ),
                      _buildSubItem(
                        keyName: 'faqs',
                        label: 'Store FAQs',
                        icon: Icons.help_outline_rounded,
                      ),
                      _buildSubItem(
                        keyName: 'store_gallery',
                        label: 'Store Gallery',
                        icon: Icons.add_photo_alternate_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 17. Mobile & Desktop Apps
                  _buildDropdownGroup(
                    sectionKey: 'apps',
                    title: 'Mobile & Desktop Apps',
                    icon: Icons.smartphone_rounded,
                    children: [
                      _buildSubItem(
                        keyName: 'app_builder',
                        label: 'Generate Apps',
                        icon: Icons.auto_awesome_rounded,
                        badgeText: '2 GitHub',
                        badgeColor: emeraldColor,
                      ),
                      _buildSubItem(
                        keyName: 'app_upload',
                        label: 'Upload APK / iOS',
                        icon: Icons.upload_file_rounded,
                        badgeText: 'Binaries',
                        badgeColor: cyanColor,
                      ),
                      _buildSubItem(
                        keyName: 'app_navbar',
                        label: 'Navbar App Links',
                        icon: Icons.download_rounded,
                        badgeText: 'Live',
                        badgeColor: purpleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 18. Settings & Theme
                  _buildDropdownGroup(
                    sectionKey: 'settings',
                    title: 'Settings & Theme',
                    icon: Icons.settings_outlined,
                    children: [
                      _buildSubItem(
                        keyName: 'themes',
                        label: 'Theme Store',
                        icon: Icons.auto_fix_high_rounded,
                        badgeText: 'NEW',
                        badgeColor: amberColor,
                      ),
                      _buildSubItem(
                        keyName: 'settings',
                        label: 'General Settings',
                        icon: Icons.tune_rounded,
                      ),
                      _buildSubItem(
                        keyName: 'company_settings',
                        label: 'Company Settings',
                        icon: Icons.business_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Bottom Area: Quota Tracker + Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  // Quota Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Quota',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              widget.planName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: widget.brandGreen,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: quotaPercent,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.brandGreen,
                            ),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${widget.totalProducts} Items',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'Max: ${widget.maxProducts}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Store & Logout Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onOpenStore,
                          icon: Icon(
                            Icons.open_in_new_rounded,
                            size: 15,
                            color: widget.brandGreen,
                          ),
                          label: const Text(
                            'Store',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
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
                            backgroundColor: const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0xFFFECACA),
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
  }) {
    final bool isSelected = _isMenuSelected(keyName);

    return InkWell(
      onTap: () => _selectMenu(keyName),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? widget.brandGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: widget.brandGreen.withValues(alpha: 0.3),
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
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
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
    required List<Widget> children,
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
                  ? widget.brandGreen.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOpen
                    ? widget.brandGreen.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: widget.brandGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isOpen ? widget.brandGreen : const Color(0xFF94A3B8),
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
                  color: widget.brandGreen.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
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
  }) {
    final bool isSelected = _isMenuSelected(keyName);
    final Color effectiveBadgeColor = badgeColor ?? const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => _selectMenu(keyName),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected ? widget.brandGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: widget.brandGreen.withValues(alpha: 0.25),
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
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
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
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
              if (badgeDot)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: emeraldColor,
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