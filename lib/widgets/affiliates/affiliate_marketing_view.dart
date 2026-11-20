// lib/widgets/affiliates/affiliate_marketing_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';

class AffiliateMarketingView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final VoidCallback? onDataChanged;

  const AffiliateMarketingView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.initialTab = 'overview',
    this.onDataChanged,
  });

  @override
  State<AffiliateMarketingView> createState() => _AffiliateMarketingViewState();
}

class _AffiliateMarketingViewState extends State<AffiliateMarketingView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _loading = true;
  bool _saving = false;
  String _activeSubTab = 'overview';

  Map _overview = {};
  Map _settings = {};
  List _registrationFields = [];
  List _activeModeFields = [];
  List _affiliates = [];
  List _submissions = [];
  List _productAssignments = [];
  List _campaigns = [];
  List _campaignApplications = [];
  List _conversions = [];
  List _commissions = [];
  List _ledger = [];
  List _withdrawals = [];
  List _payments = [];
  List _fraudLogs = [];
  List _auditLogs = [];
  List _storeProducts = [];
  List _storeCategories = [];

  String _searchQuery = '';
  String _affiliateStatusFilter = 'all';
  String _withdrawalStatusFilter = 'all';
  String _commissionViewMode = 'commissions'; // commissions | conversions | ledger

  // Settings Controllers
  final TextEditingController _programTitleCtrl = TextEditingController();
  final TextEditingController _programTermsCtrl = TextEditingController();
  final TextEditingController _defaultRateCtrl = TextEditingController();
  final TextEditingController _firstOrderBonusCtrl = TextEditingController();
  final TextEditingController _repeatOrderRateCtrl = TextEditingController();
  final TextEditingController _cookieDaysCtrl = TextEditingController();
  final TextEditingController _minWithdrawCtrl = TextEditingController();
  final TextEditingController _maxWithdrawCtrl = TextEditingController();
  final TextEditingController _withdrawFeeCtrl = TextEditingController();
  final TextEditingController _maxClicksHourCtrl = TextEditingController();

  bool _isEnabled = true;
  bool _autoApproveAffiliates = false;
  bool _publicMarketplaceEnabled = true;
  bool _requireProductApplication = false;
  bool _deductCouponDiscounts = true;
  bool _autoApproveOnDelivery = true;
  bool _enableTierSystem = true;
  bool _fraudSelfReferralBlock = true;
  String _registrationMode = 'standard';
  String _calculationBase = 'selling_price';
  String _defaultCommissionType = 'percentage';
  String _attributionModel = 'last_click';
  String _withdrawalSchedule = 'on_demand';
  List _supportedPayoutMethods = ['bkash', 'nagad', 'rocket', 'bank_transfer'];

  @override
  void initState() {
    super.initState();
    _syncInitialTab(widget.initialTab);
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant AffiliateMarketingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _syncInitialTab(widget.initialTab);
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadThemeOnly();
    }
  }

  void _syncInitialTab(String rawTab) {
    final String clean = rawTab.trim().toLowerCase().replaceAll('affiliate_', '');
    if (clean == 'overview' || clean == 'affiliates') {
      _activeSubTab = 'overview';
    } else if (clean == 'list' ||
        clean == 'partners' ||
        clean == 'applications') {
      _activeSubTab = 'affiliates';
      if (clean == 'applications') {
        _affiliateStatusFilter = 'pending';
      }
    } else if (clean == 'form_builder' || clean == 'registration') {
      _activeSubTab = 'form_builder';
    } else if (clean == 'products' || clean == 'campaigns') {
      _activeSubTab = 'products_campaigns';
    } else if (clean == 'commissions' ||
        clean == 'orders' ||
        clean == 'ledger') {
      _activeSubTab = 'commissions';
      if (clean == 'orders') _commissionViewMode = 'conversions';
      if (clean == 'ledger') _commissionViewMode = 'ledger';
    } else if (clean == 'withdrawals' || clean == 'payouts') {
      _activeSubTab = 'withdrawals';
    } else if (clean == 'fraud' || clean == 'settings') {
      _activeSubTab = 'settings';
    } else {
      _activeSubTab = 'overview';
    }
  }

  Future<void> _reloadThemeOnly() async {
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() {
      _theme = t;
    });
  }

  Future<void> _initAndFetch() async {
    setState(() => _loading = true);
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() => _theme = t);
    await _fetchAffiliateDashboard();
  }

  Future<void> _fetchAffiliateDashboard() async {
    setState(() => _loading = true);
    try {
      final String sub = Uri.encodeComponent(_theme.subdomain);
      final Uri url = Uri.parse(
        '${_theme.apiBase}/api/v1/affiliates/merchant/?subdomain=$sub',
      );
      final response = await http
          .get(url, headers: _theme.headers)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          setState(() {
            _overview = decoded['overview'] is Map ? decoded['overview'] : {};
            _settings = decoded['settings'] is Map ? decoded['settings'] : {};
            _registrationFields = decoded['registration_fields'] is List
                ? decoded['registration_fields']
                : [];
            _activeModeFields = decoded['active_mode_fields'] is List
                ? decoded['active_mode_fields']
                : [];
            _affiliates =
                decoded['affiliates'] is List ? decoded['affiliates'] : [];
            _submissions =
                decoded['submissions'] is List ? decoded['submissions'] : [];
            _productAssignments = decoded['product_assignments'] is List
                ? decoded['product_assignments']
                : [];
            _campaigns =
                decoded['campaigns'] is List ? decoded['campaigns'] : [];
            _campaignApplications = decoded['campaign_applications'] is List
                ? decoded['campaign_applications']
                : [];
            _conversions =
                decoded['conversions'] is List ? decoded['conversions'] : [];
            _commissions =
                decoded['commissions'] is List ? decoded['commissions'] : [];
            _ledger = decoded['ledger'] is List ? decoded['ledger'] : [];
            _withdrawals =
                decoded['withdrawals'] is List ? decoded['withdrawals'] : [];
            _payments = decoded['payments'] is List ? decoded['payments'] : [];
            _fraudLogs =
                decoded['fraud_logs'] is List ? decoded['fraud_logs'] : [];
            _auditLogs =
                decoded['audit_logs'] is List ? decoded['audit_logs'] : [];
            _storeProducts = decoded['store_products'] is List
                ? decoded['store_products']
                : [];
            _storeCategories = decoded['store_categories'] is List
                ? decoded['store_categories']
                : [];
            _populateSettingsControllers();
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _populateSettingsControllers() {
    _isEnabled = _settings['is_enabled'] != false;
    _autoApproveAffiliates = _settings['auto_approve_affiliates'] == true;
    _publicMarketplaceEnabled =
        _settings['public_marketplace_enabled'] != false;
    _requireProductApplication =
        _settings['require_product_application'] == true;
    _deductCouponDiscounts = _settings['deduct_coupon_discounts'] != false;
    _autoApproveOnDelivery =
        _settings['auto_approve_commission_on_delivery'] != false;
    _enableTierSystem = _settings['enable_tier_system'] != false;
    _fraudSelfReferralBlock = _settings['fraud_self_referral_block'] != false;

    _registrationMode =
        (_settings['registration_mode'] ?? 'standard').toString();
    _calculationBase =
        (_settings['commission_calculation_base'] ?? 'selling_price')
            .toString();
    _defaultCommissionType =
        (_settings['default_commission_type'] ?? 'percentage').toString();
    _attributionModel =
        (_settings['attribution_model'] ?? 'last_click').toString();
    _withdrawalSchedule =
        (_settings['withdrawal_schedule'] ?? 'on_demand').toString();

    if (_settings['supported_payout_methods'] is List) {
      _supportedPayoutMethods =
          List.from(_settings['supported_payout_methods']);
    }

    _programTitleCtrl.text =
        (_settings['program_title'] ?? 'Partner & Affiliate Program')
            .toString();
    _programTermsCtrl.text = (_settings['program_terms'] ?? '').toString();
    _defaultRateCtrl.text =
        (_settings['default_commission_rate'] ?? '10.00').toString();
    _firstOrderBonusCtrl.text =
        (_settings['first_order_bonus_rate'] ?? '0.00').toString();
    _repeatOrderRateCtrl.text =
        (_settings['repeat_order_commission_rate'] ?? '').toString();
    _cookieDaysCtrl.text =
        (_settings['cookie_duration_days'] ?? '30').toString();
    _minWithdrawCtrl.text =
        (_settings['minimum_withdrawal'] ?? '500.00').toString();
    _maxWithdrawCtrl.text =
        (_settings['maximum_withdrawal'] ?? '50000.00').toString();
    _withdrawFeeCtrl.text =
        (_settings['withdrawal_processing_fee_percent'] ?? '0.00').toString();
    _maxClicksHourCtrl.text =
        (_settings['fraud_max_clicks_per_ip_hour'] ?? '40').toString();
  }

  Future _postMerchantAction(Map payload) async {
    setState(() => _saving = true);
    try {
      final String sub = Uri.encodeComponent(_theme.subdomain);
      final Uri url = Uri.parse(
        '${_theme.apiBase}/api/v1/affiliates/merchant/?subdomain=$sub',
      );
      final response = await http
          .post(
            url,
            headers: _theme.headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return null;
      setState(() => _saving = false);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String msg = (decoded is Map && decoded['message'] != null)
            ? decoded['message'].toString()
            : 'সফলভাবে সম্পন্ন হয়েছে!';
        _showToast(msg, isError: false);
        await _fetchAffiliateDashboard();
        if (widget.onDataChanged != null) widget.onDataChanged!();
        return decoded is Map ? decoded : {};
      } else {
        final String err = (decoded is Map && decoded['error'] != null)
            ? decoded['error'].toString()
            : 'অপারেশনটি সম্পন্ন করা যায়নি।';
        _showToast(err, isError: true);
      }
    } catch (e) {
      if (!mounted) return null;
      setState(() => _saving = false);
      _showToast('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    }
    return null;
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : _theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast('$label কপি করা হয়েছে!');
  }

  @override
  void dispose() {
    _programTitleCtrl.dispose();
    _programTermsCtrl.dispose();
    _defaultRateCtrl.dispose();
    _firstOrderBonusCtrl.dispose();
    _repeatOrderRateCtrl.dispose();
    _cookieDaysCtrl.dispose();
    _minWithdrawCtrl.dispose();
    _maxWithdrawCtrl.dispose();
    _withdrawFeeCtrl.dispose();
    _maxClicksHourCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopHeader(t),
        const SizedBox(height: 14),
        _buildNavigationTabs(t),
        const SizedBox(height: 16),
        if (_loading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: t.primaryColor),
          )
        else ...[
          if (_activeSubTab == 'overview') _buildOverviewSection(t),
          if (_activeSubTab == 'affiliates') _buildAffiliatesSection(t),
          if (_activeSubTab == 'form_builder') _buildFormBuilderSection(t),
          if (_activeSubTab == 'products_campaigns')
            _buildProductsAndCampaignsSection(t),
          if (_activeSubTab == 'commissions') _buildCommissionsSection(t),
          if (_activeSubTab == 'withdrawals') _buildWithdrawalsSection(t),
          if (_activeSubTab == 'settings') _buildSettingsAndFraudSection(t),
        ],
      ],
    );
  }

  Widget _buildTopHeader(CatalogThemeConfig t) {
    final String portalUrl =
        (_overview['affiliate_portal_url'] ?? '').toString();
    final String calcBase =
        (_overview['commission_calculation_base'] ?? _calculationBase)
            .toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: t.useGradient ? t.brandGradient : null,
                      color: t.useGradient ? null : t.primaryColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.handshake_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Affiliate Marketing Engine',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _isEnabled
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.15)
                                    : const Color(0xFFEF4444)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isEnabled ? 'ACTIVE' : 'PAUSED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _isEnabled
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          calcBase == 'profit'
                              ? 'কমিশন মোড: Net Profit Base (বিক্রয়মূল্য − কেনা দাম/TP)'
                              : 'কমিশন মোড: Selling Price Base (প্রোডাক্টের বিক্রয়মূল্যের ওপর %)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (portalUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _copyToClipboard(portalUrl, 'Affiliate Portal Link'),
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: t.primaryColor,
                      ),
                      label: Text(
                        'Copy Portal Link',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: t.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _fetchAffiliateDashboard,
                    tooltip: 'Refresh',
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: t.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (portalUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: t.inputBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: t.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: t.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Affiliate Portal: $portalUrl',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationTabs(CatalogThemeConfig t) {
    final int pendingApps =
        int.tryParse('${_overview['pending_applications'] ?? 0}') ?? 0;
    final int pendingWithdrawals =
        int.tryParse('${_overview['pending_withdrawals_count'] ?? 0}') ?? 0;
    final int fraudAlerts =
        int.tryParse('${_overview['unresolved_fraud_count'] ?? 0}') ?? 0;

    final List tabs = [
      {'id': 'overview', 'label': 'Overview', 'icon': Icons.analytics_outlined},
      {
        'id': 'affiliates',
        'label': 'Affiliates (${_affiliates.length})',
        'badge': pendingApps > 0 ? '$pendingApps Pending' : null,
        'icon': Icons.groups_rounded,
      },
      {
        'id': 'form_builder',
        'label': 'Reg. Form Builder',
        'icon': Icons.dynamic_form_rounded,
      },
      {
        'id': 'products_campaigns',
        'label': 'Products & Campaigns',
        'icon': Icons.campaign_rounded,
      },
      {
        'id': 'commissions',
        'label': 'Orders & Ledger',
        'icon': Icons.receipt_long_rounded,
      },
      {
        'id': 'withdrawals',
        'label': 'Withdrawals & Payouts',
        'badge': pendingWithdrawals > 0 ? '$pendingWithdrawals' : null,
        'icon': Icons.account_balance_wallet_rounded,
      },
      {
        'id': 'settings',
        'label': 'Settings & Fraud',
        'badge': fraudAlerts > 0 ? '$fraudAlerts Alert' : null,
        'icon': Icons.tune_rounded,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final String id = tab['id'].toString();
          final bool active = _activeSubTab == id;
          final String? badge = tab['badge']?.toString();

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeSubTab = id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: (active && t.useGradient) ? t.brandGradient : null,
                  color: active
                      ? (t.useGradient ? null : t.primaryColor)
                      : t.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? t.primaryColor : t.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: active ? Colors.white : t.secondaryText,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tab['label'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : t.primaryText,
                      ),
                    ),
                    if (badge != null && badge.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.25)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color:
                                active ? Colors.white : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===================================================================
  // 1. OVERVIEW SECTION
  // ===================================================================
  Widget _buildOverviewSection(CatalogThemeConfig t) {
    final List kpis = [
      {
        'title': 'Total Affiliates',
        'value': '${_overview['total_affiliates'] ?? 0}',
        'sub':
            'Approved: ${_overview['approved_affiliates'] ?? 0} | Pending: ${_overview['pending_applications'] ?? 0}',
        'icon': Icons.people_alt_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Referral Clicks',
        'value': '${_overview['total_clicks'] ?? 0}',
        'sub': 'Unique Visitors: ${_overview['unique_visitors'] ?? 0}',
        'icon': Icons.ads_click_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Referral Orders',
        'value': '${_overview['total_orders'] ?? 0}',
        'sub': 'Conversion Rate: ${_overview['conversion_rate'] ?? 0}%',
        'icon': Icons.shopping_bag_rounded,
        'color': const Color(0xFFA855F7),
      },
      {
        'title': 'Total Referral Sales',
        'value': '৳${_formatMoney(_overview['total_sales_amount'])}',
        'sub': 'Attributed Store Revenue',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF06B6D4),
      },
      {
        'title': 'Pending Commission',
        'value': '৳${_formatMoney(_overview['pending_commission'])}',
        'sub': 'Awaiting Order Delivery',
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Available Balance',
        'value': '৳${_formatMoney(_overview['available_balance'])}',
        'sub':
            'Paid Out: ৳${_formatMoney(_overview['paid_commission'])}',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF16A34A),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kpis.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisExtent: 112,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = kpis[index] as Map;
            final Color c = item['color'] as Color;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['title'].toString(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: t.secondaryText,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          size: 16,
                          color: c,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item['value'].toString(),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                  Text(
                    item['sub'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: t.secondaryText,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Quick Action Banner for Pending Applications or Withdrawals
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Performing Affiliates & Recent Activity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              if (_affiliates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'এখনো কোনো অ্যাফিলিয়েট রেজিস্ট্রেশন করেনি। উপরের Copy Portal Link বাটন থেকে আপনার স্টোরের অ্যাফিলিয়েট লিংক শেয়ার করুন।',
                    style: TextStyle(color: t.secondaryText, fontSize: 12.5),
                  ),
                )
              else
                ..._affiliates.take(5).map((aff) {
                  final Map a = aff is Map ? aff : {};
                  return _buildAffiliateRowCard(t, a);
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // 2. AFFILIATES & APPLICATIONS SECTION
  // ===================================================================
  Widget _buildAffiliatesSection(CatalogThemeConfig t) {
    final List filtered = _affiliates.where((raw) {
      final Map a = raw is Map ? raw : {};
      final String st = (a['status'] ?? 'pending').toString().toLowerCase();
      if (_affiliateStatusFilter != 'all' && st != _affiliateStatusFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final String q = _searchQuery.trim().toLowerCase();
        final String name = (a['full_name'] ?? '').toString().toLowerCase();
        final String email = (a['email'] ?? '').toString().toLowerCase();
        final String phone = (a['phone'] ?? '').toString().toLowerCase();
        final String code = (a['referral_code'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            email.contains(q) ||
            phone.contains(q) ||
            code.contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by Name, Email, Phone or Referral Code...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12.5),
                  prefixIcon: Icon(Icons.search_rounded, color: t.primaryColor),
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'all',
                    'pending',
                    'approved',
                    'suspended',
                    'rejected'
                  ].map((st) {
                    final bool selected = _affiliateStatusFilter == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          st.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : t.primaryText,
                          ),
                        ),
                        selected: selected,
                        selectedColor: t.primaryColor,
                        backgroundColor: t.inputBg,
                        onSelected: (_) =>
                            setState(() => _affiliateStatusFilter = st),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: t.cardBorder),
            ),
            child: Center(
              child: Text(
                'কোনো অ্যাফিলিয়েট প্রোফাইল পাওয়া যায়নি।',
                style: TextStyle(color: t.secondaryText, fontSize: 13),
              ),
            ),
          )
        else
          ...filtered.map((raw) {
            final Map a = raw is Map ? raw : {};
            return _buildAffiliateRowCard(t, a);
          }),
      ],
    );
  }

  Widget _buildAffiliateRowCard(CatalogThemeConfig t, Map a) {
    final String status = (a['status'] ?? 'pending').toString().toLowerCase();
    final String tier = (a['tier'] ?? 'bronze').toString().toUpperCase();
    final String refCode = (a['referral_code'] ?? '').toString();
    final Color statusColor = status == 'approved'
        ? const Color(0xFF10B981)
        : (status == 'pending'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: t.primaryColor.withValues(alpha: 0.15),
                    child: Text(
                      ((a['full_name'] ?? a['email'] ?? 'A').toString().isNotEmpty
                              ? (a['full_name'] ?? a['email'] ?? 'A')
                                  .toString()[0]
                              : 'A')
                          .toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: t.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                (a['full_name'] ?? 'Affiliate Partner')
                                    .toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA855F7)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tier,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFA855F7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${a['email'] ?? ''} • ${a['phone'] ?? 'No phone'} • Code: $refCode',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (status == 'pending' || status == 'rejected')
                    ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _postMerchantAction({
                                'action': 'approve_affiliate',
                                'affiliate_id': a['id'],
                              }),
                      icon: const Icon(Icons.check_circle_outline, size: 15),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (status == 'pending')
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _postMerchantAction({
                                'action': 'reject_affiliate',
                                'affiliate_id': a['id'],
                                'reason': 'Rejected by merchant admin',
                              }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (status == 'approved')
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _postMerchantAction({
                                'action': 'suspend_affiliate',
                                'affiliate_id': a['id'],
                                'reason': 'Suspended by merchant',
                              }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                      ),
                      child: const Text(
                        'Suspend',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (status == 'suspended')
                    ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () => _postMerchantAction({
                                'action': 'reactivate_affiliate',
                                'affiliate_id': a['id'],
                              }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Reactivate',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => _openEditAffiliateDialog(t, a),
                    tooltip: 'Custom Rate & Tier',
                    icon: Icon(
                      Icons.edit_note_rounded,
                      color: t.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: t.cardBorder, height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _buildMiniMetric(
                  t, 'Clicks', '${a['total_clicks'] ?? 0} (${a['unique_visitors'] ?? 0} uniq)'),
              _buildMiniMetric(t, 'Orders', '${a['total_orders'] ?? 0}'),
              _buildMiniMetric(
                  t, 'Sales', '৳${_formatMoney(a['total_sales_amount'])}'),
              _buildMiniMetric(
                  t, 'Pending', '৳${_formatMoney(a['pending_commission'])}'),
              _buildMiniMetric(
                  t, 'Available', '৳${_formatMoney(a['available_balance'])}'),
              _buildMiniMetric(
                  t, 'Paid', '৳${_formatMoney(a['paid_commission'])}'),
              _buildMiniMetric(
                t,
                'Payout Account',
                '${(a['primary_payout_method'] ?? 'bkash').toString().toUpperCase()}: ${a['primary_payout_account'] ?? 'N/A'}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(CatalogThemeConfig t, String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: t.primaryText,
          ),
        ),
      ],
    );
  }

  void _openEditAffiliateDialog(CatalogThemeConfig t, Map aff) {
    String selectedTier = (aff['tier'] ?? 'bronze').toString();
    String customType = (aff['custom_commission_type'] ?? 'default').toString();
    final TextEditingController rateCtrl = TextEditingController(
      text: (aff['custom_commission_rate'] ?? '').toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Update Affiliate: ${aff['full_name'] ?? aff['referral_code']}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Affiliate Rank / Tier',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField(
                      value: selectedTier,
                      dropdownColor: t.cardBg,
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: t.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: ['bronze', 'silver', 'gold', 'platinum']
                          .map(
                            (tr) => DropdownMenuItem(
                              value: tr,
                              child: Text(tr.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedTier = val.toString());
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Custom Commission Rule',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField(
                      value: customType,
                      dropdownColor: t.cardBg,
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: t.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'default',
                          child: Text('Use Store Default Rate'),
                        ),
                        DropdownMenuItem(
                          value: 'percentage',
                          child: Text('Custom Percentage (%)'),
                        ),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('Custom Fixed Amount (৳)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => customType = val.toString());
                        }
                      },
                    ),
                    if (customType != 'default') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: t.primaryText),
                        decoration: InputDecoration(
                          labelText: customType == 'percentage'
                              ? 'Custom Rate (%)'
                              : 'Fixed Commission (৳)',
                          filled: true,
                          fillColor: t.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: t.secondaryText),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _postMerchantAction({
                      'action': 'update_affiliate',
                      'affiliate_id': aff['id'],
                      'tier': selectedTier,
                      'manual_tier_override': true,
                      'custom_commission_type': customType,
                      'custom_commission_rate':
                          customType == 'default' ? null : rateCtrl.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===================================================================
  // 3. DYNAMIC REGISTRATION FORM BUILDER SECTION
  // ===================================================================
  Widget _buildFormBuilderSection(CatalogThemeConfig t) {
    final List modes = [
      {
        'key': 'simple',
        'title': 'Simple Mode',
        'desc': 'Email & Password only (Fastest 10-second signup)',
      },
      {
        'key': 'standard',
        'title': 'Standard Mode',
        'desc': 'Full Name, Email, Mobile Number & Password',
      },
      {
        'key': 'advanced',
        'title': 'Advanced KYC Mode',
        'desc': 'Includes Address, NID Number, Document Upload & Payout Info',
      },
      {
        'key': 'custom',
        'title': 'Custom Form Builder',
        'desc': 'Add, edit or reorder custom signup fields below',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Select Affiliate Registration Mode',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Auto-Approve',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.secondaryText,
                        ),
                      ),
                      Switch(
                        value: _autoApproveAffiliates,
                        activeColor: Colors.white,
                        activeTrackColor: t.primaryColor,
                        onChanged: (val) {
                          setState(() => _autoApproveAffiliates = val);
                          _postMerchantAction({
                            'action': 'update_registration_mode',
                            'registration_mode': _registrationMode,
                            'auto_approve_affiliates': val,
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: modes.map((m) {
                  final String k = m['key'].toString();
                  final bool selected = _registrationMode == k;
                  return InkWell(
                    onTap: () {
                      setState(() => _registrationMode = k);
                      _postMerchantAction({
                        'action': 'update_registration_mode',
                        'registration_mode': k,
                        'auto_approve_affiliates': _autoApproveAffiliates,
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 240,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? t.primaryColor.withValues(alpha: 0.10)
                            : t.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? t.primaryColor : t.cardBorder,
                          width: selected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                m['title'].toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      selected ? t.primaryColor : t.primaryText,
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: t.primaryColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m['desc'].toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Custom Registration Fields (${_registrationFields.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openAddOrEditFieldDialog(t),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Field'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._registrationFields.map((raw) {
                final Map f = raw is Map ? raw : {};
                final bool isSys = f['is_system_field'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${f['label']} (${f['field_key']})',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              'Type: ${f['field_type']} • Required: ${f['is_required'] == true ? 'Yes' : 'No'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSys)
                        IconButton(
                          onPressed: () => _postMerchantAction({
                            'action': 'delete_registration_field',
                            'id': f['id'],
                          }),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _openAddOrEditFieldDialog(CatalogThemeConfig t) {
    final TextEditingController labelCtrl = TextEditingController();
    final TextEditingController placeholderCtrl = TextEditingController();
    final TextEditingController optionsCtrl = TextEditingController();
    String fieldType = 'text';
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              title: Text(
                'Add Custom Registration Field',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Field Label (e.g. Bkash Number)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField(
                      value: fieldType,
                      dropdownColor: t.cardBg,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Field Type',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                      items: [
                        'text',
                        'email',
                        'phone',
                        'textarea',
                        'dropdown',
                        'url',
                        'file'
                      ]
                          .map(
                            (tp) => DropdownMenuItem(
                              value: tp,
                              child: Text(tp.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => fieldType = v.toString());
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: placeholderCtrl,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Placeholder',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                    if (fieldType == 'dropdown') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: optionsCtrl,
                        style: TextStyle(color: t.primaryText),
                        decoration: InputDecoration(
                          labelText: 'Dropdown Options (comma separated)',
                          filled: true,
                          fillColor: t.inputBg,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isRequired,
                      title: Text(
                        'Required Field',
                        style: TextStyle(color: t.primaryText, fontSize: 13),
                      ),
                      onChanged: (v) => setModalState(() => isRequired = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _postMerchantAction({
                      'action': 'save_registration_field',
                      'label': labelCtrl.text.trim(),
                      'field_type': fieldType,
                      'placeholder': placeholderCtrl.text.trim(),
                      'options': optionsCtrl.text.trim(),
                      'is_required': isRequired,
                      'is_enabled': true,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Field'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===================================================================
  // 4. PRODUCTS & CAMPAIGNS SECTION
  // ===================================================================
  Widget _buildProductsAndCampaignsSection(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Commission Assignments
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product & Category Commission Rules (${_productAssignments.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          'নির্দিষ্ট প্রোডাক্ট বা ক্যাটাগরিতে আলাদা কমিশন রেট নির্ধারণ করুন',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openAssignProductDialog(t),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Assign Rule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_productAssignments.isEmpty)
                Text(
                  'কোনো আলাদা প্রোডাক্ট রুল সেট করা নেই। সব প্রোডাক্টে ডিফল্ট কমিশন (${_settings['default_commission_rate'] ?? 10}%) প্রযোজ্য হচ্ছে।',
                  style: TextStyle(color: t.secondaryText, fontSize: 12),
                )
              else
                ..._productAssignments.map((raw) {
                  final Map pa = raw is Map ? raw : {};
                  final String targetName =
                      (pa['product_name'] ?? pa['category_name'] ?? 'Store Rule')
                          .toString();
                  final String affName = (pa['affiliate_name'] ?? 'All Affiliates (Public)').toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                targetName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                              ),
                              Text(
                                'Target: $affName • Rate: ${pa['commission_rate']}${pa['commission_type'] == 'percentage' ? '%' : '৳'} (${pa['visibility']})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: t.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _postMerchantAction({
                            'action': 'delete_assignment',
                            'id': pa['id'],
                          }),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Promotional Campaigns
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Promotional Campaigns (${_campaigns.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openCreateCampaignDialog(t),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New Campaign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_campaigns.isEmpty)
                Text(
                  'কোনো অ্যাক্টিভ প্রমোশনাল ক্যাম্পেইন নেই।',
                  style: TextStyle(color: t.secondaryText, fontSize: 12),
                )
              else
                ..._campaigns.map((raw) {
                  final Map c = raw is Map ? raw : {};
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (c['name'] ?? 'Campaign').toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                              ),
                              Text(
                                'Bonus Rate: ${c['commission_rate']}${c['commission_type'] == 'percentage' ? '%' : '৳'} • Status: ${(c['status'] ?? 'active').toString().toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: t.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _postMerchantAction({
                            'action': 'delete_campaign',
                            'id': c['id'],
                          }),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  void _openAssignProductDialog(CatalogThemeConfig t) {
    int? selectedProductId =
        _storeProducts.isNotEmpty ? (_storeProducts.first['id'] as int?) : null;
    int? selectedAffiliateId;
    String commType = 'percentage';
    final TextEditingController rateCtrl = TextEditingController(text: '12');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              title: Text(
                'Assign Product Commission Rule',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_storeProducts.isNotEmpty)
                      DropdownButtonFormField(
                        value: selectedProductId,
                        isExpanded: true,
                        dropdownColor: t.cardBg,
                        style: TextStyle(color: t.primaryText, fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'Select Product',
                          filled: true,
                          fillColor: t.inputBg,
                        ),
                        items: _storeProducts.map((p) {
                          return DropdownMenuItem(
                            value: p['id'] as int?,
                            child: Text(
                              '${p['name']} (Sell: ৳${p['price']} | TP: ৳${p['trade_price']})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setModalState(() => selectedProductId = v),
                      ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField(
                      value: selectedAffiliateId,
                      isExpanded: true,
                      dropdownColor: t.cardBg,
                      style: TextStyle(color: t.primaryText, fontSize: 12.5),
                      decoration: InputDecoration(
                        labelText: 'Target Affiliate (Optional)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Affiliates (Public Marketplace)'),
                        ),
                        ..._affiliates.map((a) {
                          return DropdownMenuItem(
                            value: a['id'] as int?,
                            child: Text(
                              '${a['full_name']} (${a['referral_code']})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) =>
                          setModalState(() => selectedAffiliateId = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField(
                      value: commType,
                      dropdownColor: t.cardBg,
                      style: TextStyle(color: t.primaryText, fontSize: 12.5),
                      decoration: InputDecoration(
                        labelText: 'Commission Type',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'percentage',
                          child: Text('Percentage (%)'),
                        ),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('Fixed Amount (৳)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => commType = v.toString());
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: rateCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText:
                            commType == 'percentage' ? 'Rate (%)' : 'Amount (৳)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedProductId == null) return;
                    Navigator.of(ctx).pop();
                    await _postMerchantAction({
                      'action': 'assign_products',
                      'product_ids': [selectedProductId],
                      'affiliate_ids': selectedAffiliateId != null
                          ? [selectedAffiliateId]
                          : [],
                      'visibility':
                          selectedAffiliateId != null ? 'private' : 'public',
                      'commission_type': commType,
                      'commission_rate': rateCtrl.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Assign Rule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openCreateCampaignDialog(CatalogThemeConfig t) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController rateCtrl = TextEditingController(text: '15');
    final TextEditingController descCtrl = TextEditingController();
    String commType = 'percentage';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              title: Text(
                'Create Affiliate Campaign',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Campaign Title (e.g. Eid Mega Sale)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField(
                      value: commType,
                      dropdownColor: t.cardBg,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Commission Type',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'percentage',
                          child: Text('Percentage (%)'),
                        ),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('Fixed (৳)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => commType = v.toString());
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: rateCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Campaign Commission Rate',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _postMerchantAction({
                      'action': 'save_campaign',
                      'name': nameCtrl.text.trim(),
                      'commission_type': commType,
                      'commission_rate': rateCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'status': 'active',
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Campaign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===================================================================
  // 5. ORDERS, COMMISSIONS & LEDGER SECTION
  // ===================================================================
  Widget _buildCommissionsSection(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('Product Commissions (${_commissions.length})'),
              selected: _commissionViewMode == 'commissions',
              selectedColor: t.primaryColor,
              labelStyle: TextStyle(
                color: _commissionViewMode == 'commissions'
                    ? Colors.white
                    : t.primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              onSelected: (_) =>
                  setState(() => _commissionViewMode = 'commissions'),
            ),
            ChoiceChip(
              label: Text('Referral Orders (${_conversions.length})'),
              selected: _commissionViewMode == 'conversions',
              selectedColor: t.primaryColor,
              labelStyle: TextStyle(
                color: _commissionViewMode == 'conversions'
                    ? Colors.white
                    : t.primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              onSelected: (_) =>
                  setState(() => _commissionViewMode = 'conversions'),
            ),
            ChoiceChip(
              label: Text('Immutable Balance Ledger (${_ledger.length})'),
              selected: _commissionViewMode == 'ledger',
              selectedColor: t.primaryColor,
              labelStyle: TextStyle(
                color: _commissionViewMode == 'ledger'
                    ? Colors.white
                    : t.primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => _commissionViewMode = 'ledger'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_commissionViewMode == 'commissions')
          ..._commissions.map((raw) {
            final Map c = raw is Map ? raw : {};
            final String st = (c['status'] ?? 'pending').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '#${c['order_number']} • ${c['product_name']}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '৳${_formatMoney(c['net_commission_amount'])} (${st.toUpperCase()})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: st == 'approved'
                              ? const Color(0xFF10B981)
                              : (st == 'pending'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Affiliate: ${c['affiliate_name']} (${c['referral_code']}) • Eligible Base: ৳${_formatMoney(c['eligible_amount'])} • Rule: ${c['commission_rule_source']}',
                    style: TextStyle(fontSize: 11.5, color: t.secondaryText),
                  ),
                  if ((c['notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      c['notes'].toString(),
                      style: TextStyle(fontSize: 11, color: t.secondaryText),
                    ),
                  ],
                  if (st == 'pending') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _postMerchantAction({
                                    'action': 'approve_commission',
                                    'commission_id': c['id'],
                                  }),
                          icon: const Icon(Icons.check_rounded, size: 15),
                          label: const Text('Approve & Credit Balance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _postMerchantAction({
                                    'action': 'reverse_commission',
                                    'commission_id': c['id'],
                                  }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                          child: const Text(
                            'Reverse',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        if (_commissionViewMode == 'conversions')
          ..._conversions.map((raw) {
            final Map conv = raw is Map ? raw : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${conv['order_number']} (${(conv['order_status'] ?? conv['status'] ?? '').toString().toUpperCase()})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          'Affiliate: ${conv['affiliate_name']} (${conv['referral_code']}) • Subtotal: ৳${_formatMoney(conv['order_subtotal'])}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Comm: ৳${_formatMoney(conv['total_commission'])}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: t.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        if (_commissionViewMode == 'ledger')
          ..._ledger.map((raw) {
            final Map l = raw is Map ? raw : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l['affiliate_name']} (${l['adjustment_type']})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      Text(
                        '৳${_formatMoney(l['amount'])} (Bal: ৳${_formatMoney(l['available_balance_after'])})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: t.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${l['reason']} • ${l['created_at_formatted'] ?? ''}',
                    style: TextStyle(fontSize: 11, color: t.secondaryText),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ===================================================================
  // 6. WITHDRAWALS & PAYOUTS SECTION
  // ===================================================================
  Widget _buildWithdrawalsSection(CatalogThemeConfig t) {
    final List filtered = _withdrawals.where((raw) {
      final Map w = raw is Map ? raw : {};
      if (_withdrawalStatusFilter == 'all') return true;
      return (w['status'] ?? '').toString().toLowerCase() ==
          _withdrawalStatusFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['all', 'pending', 'approved', 'processing', 'paid', 'rejected']
                .map((st) {
              final bool sel = _withdrawalStatusFilter == st;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    st.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : t.primaryText,
                    ),
                  ),
                  selected: sel,
                  selectedColor: t.primaryColor,
                  backgroundColor: t.cardBg,
                  onSelected: (_) =>
                      setState(() => _withdrawalStatusFilter = st),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: t.cardBorder),
            ),
            child: Center(
              child: Text(
                'কোনো উইথড্রয়াল রিকোয়েস্ট পাওয়া যায়নি।',
                style: TextStyle(color: t.secondaryText),
              ),
            ),
          )
        else
          ...filtered.map((raw) {
            final Map w = raw is Map ? raw : {};
            final String st = (w['status'] ?? 'pending').toString().toLowerCase();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${w['reference_no']} • ${w['affiliate_name']} (${w['referral_code']})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        'Net Payable: ৳${_formatMoney(w['net_payable_amount'])} (${st.toUpperCase()})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: st == 'paid'
                              ? const Color(0xFF10B981)
                              : (st == 'rejected'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF59E0B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Method: ${(w['payment_method'] ?? '').toString().toUpperCase()} • Account: ${w['account_number']} • Requested: ৳${_formatMoney(w['requested_amount'])} • Fee: ৳${_formatMoney(w['processing_fee'])}',
                    style: TextStyle(fontSize: 11.5, color: t.secondaryText),
                  ),
                  if ((w['transaction_id'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'TrxID: ${w['transaction_id']} • Paid At: ${w['processed_at_formatted'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                  if (st != 'paid' && st != 'rejected') ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _openMarkPaidWithdrawalDialog(t, w),
                          icon: const Icon(Icons.payments_rounded, size: 15),
                          label: const Text('Mark Paid (with TrxID)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _postMerchantAction({
                            'action': 'process_withdrawal',
                            'withdrawal_id': w['id'],
                            'status': 'rejected',
                            'admin_note': 'Rejected & balance refunded',
                          }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                          child: const Text(
                            'Reject & Refund Balance',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  void _openMarkPaidWithdrawalDialog(CatalogThemeConfig t, Map w) {
    final TextEditingController trxCtrl = TextEditingController();
    final TextEditingController noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: t.cardBg,
          title: Text(
            'Complete Payout: ${w['reference_no']}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send ৳${_formatMoney(w['net_payable_amount'])} to ${(w['payment_method'] ?? '').toString().toUpperCase()} (${w['account_number']})',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: t.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: trxCtrl,
                style: TextStyle(color: t.primaryText),
                decoration: InputDecoration(
                  labelText: 'bKash / Nagad / Bank Transaction ID',
                  filled: true,
                  fillColor: t.inputBg,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                style: TextStyle(color: t.primaryText),
                decoration: InputDecoration(
                  labelText: 'Admin Note (Optional)',
                  filled: true,
                  fillColor: t.inputBg,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _postMerchantAction({
                  'action': 'process_withdrawal',
                  'withdrawal_id': w['id'],
                  'status': 'paid',
                  'transaction_id': trxCtrl.text.trim(),
                  'admin_note': noteCtrl.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Paid'),
            ),
          ],
        );
      },
    );
  }

  // ===================================================================
  // 7. PROGRAM SETTINGS & FRAUD SHIELD SECTION
  // ===================================================================
  Widget _buildSettingsAndFraudSection(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commission & Attribution Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),

              // Selling Price vs Net Profit Base Selector
              Text(
                'Commission Calculation Base (বিক্রয়মূল্য বনাম লাভের ওপর কমিশন)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: t.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Selling Price Base (বিক্রয়মূল্যের ওপর %)'),
                    selected: _calculationBase == 'selling_price',
                    selectedColor: t.primaryColor,
                    labelStyle: TextStyle(
                      color: _calculationBase == 'selling_price'
                          ? Colors.white
                          : t.primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) =>
                        setState(() => _calculationBase = 'selling_price'),
                  ),
                  ChoiceChip(
                    label: const Text(
                        'Net Profit Base (Selling Price − Trade Price / TP)'),
                    selected: _calculationBase == 'profit',
                    selectedColor: t.primaryColor,
                    labelStyle: TextStyle(
                      color: _calculationBase == 'profit'
                          ? Colors.white
                          : t.primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) =>
                        setState(() => _calculationBase = 'profit'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _defaultRateCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Default Commission Rate (%)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _firstOrderBonusCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'First Order Bonus (%)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _cookieDaysCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Cookie Duration (Days)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _minWithdrawCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Minimum Withdrawal (৳)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isEnabled,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Enable Affiliate Program for Store',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
                onChanged: (v) => setState(() => _isEnabled = v),
              ),
              SwitchListTile(
                value: _autoApproveOnDelivery,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Auto-Approve & Credit Commission When Order is Delivered',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
                onChanged: (v) => setState(() => _autoApproveOnDelivery = v),
              ),
              SwitchListTile(
                value: _fraudSelfReferralBlock,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Block Self-Referral Fraud (Same Email / Phone as Affiliate)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
                onChanged: (v) => setState(() => _fraudSelfReferralBlock = v),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _postMerchantAction({
                          'action': 'update_settings',
                          'is_enabled': _isEnabled,
                          'auto_approve_affiliates': _autoApproveAffiliates,
                          'public_marketplace_enabled':
                              _publicMarketplaceEnabled,
                          'require_product_application':
                              _requireProductApplication,
                          'commission_calculation_base': _calculationBase,
                          'default_commission_type': _defaultCommissionType,
                          'default_commission_rate':
                              _defaultRateCtrl.text.trim(),
                          'first_order_bonus_rate':
                              _firstOrderBonusCtrl.text.trim(),
                          'cookie_duration_days': _cookieDaysCtrl.text.trim(),
                          'minimum_withdrawal': _minWithdrawCtrl.text.trim(),
                          'maximum_withdrawal': _maxWithdrawCtrl.text.trim(),
                          'withdrawal_processing_fee_percent':
                              _withdrawFeeCtrl.text.trim(),
                          'auto_approve_commission_on_delivery':
                              _autoApproveOnDelivery,
                          'deduct_coupon_discounts': _deductCouponDiscounts,
                          'enable_tier_system': _enableTierSystem,
                          'fraud_self_referral_block': _fraudSelfReferralBlock,
                          'program_title': _programTitleCtrl.text.trim(),
                          'program_terms': _programTermsCtrl.text.trim(),
                        }),
                icon: const Icon(Icons.save_rounded, size: 17),
                label: const Text('Save Affiliate Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Fraud Alerts Log
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fraud Detection Logs (${_fraudLogs.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              if (_fraudLogs.isEmpty)
                Text(
                  'কোনো সন্দেহজনক ফ্রড অ্যাক্টিভিটি পাওয়া যায়নি।',
                  style: TextStyle(color: t.secondaryText, fontSize: 12),
                )
              else
                ..._fraudLogs.map((raw) {
                  final Map f = raw is Map ? raw : {};
                  final bool resolved = f['is_resolved'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(f['fraud_type'] ?? '').toString().toUpperCase()} • ${f['affiliate_name'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                              ),
                              Text(
                                '${f['description'] ?? ''} (${f['created_at_formatted'] ?? ''})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: t.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!resolved)
                          TextButton(
                            onPressed: () => _postMerchantAction({
                              'action': 'resolve_fraud_log',
                              'id': f['id'],
                            }),
                            child: const Text('Resolve'),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  String _formatMoney(dynamic val) {
    final double d = double.tryParse('${val ?? 0}') ?? 0.0;
    return d.toStringAsFixed(2);
  }
}