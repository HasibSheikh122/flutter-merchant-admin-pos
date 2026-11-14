// lib/screens/admin_dashboard_shell.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'merchant_login_screen.dart';
import '../widgets/admin_top_navbar.dart';
import '../widgets/admin_side_drawer.dart';
import '../widgets/admin_bottom_navbar.dart';
import '../widgets/general_settings_view.dart';
import '../widgets/overview/overview_dashboard_view.dart';
import '../widgets/catalog/product_list_view.dart';
import '../widgets/catalog/category_list_view.dart';
import '../widgets/catalog/product_images_gallery_view.dart';
import '../widgets/catalog/product_reviews_view.dart';
import '../widgets/order/orders_list_view.dart';
import '../widgets/order/customers_list_view.dart';
import '../widgets/order/cod_fraud_shield_view.dart';
import '../widgets/inventory/inventory_list_view.dart';
import '../widgets/inventory/daily_collection_view.dart';
import '../widgets/inventory/barcode_scanner_view.dart';
import '../widgets/shops/shops_outlets_view.dart';
import '../widgets/branches/branch_stores_view.dart';
import '../widgets/b2b/b2b_cross_sell_view.dart';
import '../widgets/courier/courier_service_view.dart';
import '../widgets/sms/sms_service_view.dart';
import '../widgets/email/email_service_view.dart';
import '../widgets/reports/reports_hub_view.dart';
import '../widgets/chat/live_chat_channels_view.dart';
import '../widgets/analytics/analytics_bi_view.dart';
import '../widgets/hrm/hr_payroll_view.dart';
import '../widgets/help/help_support_view.dart';
import '../widgets/affiliates/affiliate_marketing_view.dart';
import '../widgets/marketing/marketing_promos_view.dart';
import '../widgets/cms/store_cms_view.dart';
import '../widgets/apps/app_generate_view.dart';
import '../widgets/apps/app_upload_view.dart';

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State {
  @override
  AdminDashboardShell get widget => super.widget as AdminDashboardShell;

  final GlobalKey _scaffoldKey = GlobalKey();
  static const MethodChannel _voiceChannel =
      MethodChannel('xylo_voice_notifier');

  static const String _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  int _selectedBottomNavIndex = 0;
  String _activeDrawerMenu = 'overview';
  bool _isLoading = true;
  bool _isDarkMode = false;

  // Realtime Notification & Voice Engine State
  Timer? _realtimePollTimer;
  bool _voiceAlertEnabled = true;
  bool _initialBaselineLoaded = false;
  final Set _knownOrderKeys = {};
  final Set _knownNotificationKeys = {};
  List _notificationsList = [];
  int _unreadNotificationCount = 0;

  // Store Branding & Plan Quota
  String _storeName = 'Store Admin';
  String? _storeLogo;
  Color _brandGreen = const Color(0xFF5B9A42);
  Color _secondaryBrandColor = const Color(0xFF1E3A1A);
  bool _useGradient = true;
  String _planName = 'Growth Spark';
  int _maxProducts = 100;

  // Live Backend KPIs
  double _totalSales = 0.0;
  int _totalOrders = 0;
  int _totalCustomers = 0;
  int _totalProducts = 0;
  int _totalCategories = 0;
  int _totalReviews = 0;
  int _totalShops = 0;
  int _pendingOrders = 0;
  int _completedOrders = 0;
  final double _salesGrowth = 0.0;

  // Backend Collections
  List _ordersList = [];
  List _productsList = [];
  List _categoriesList = [];
  List _purchasedProductTimeline = [];

  // Unified AI Analytics Payloads
  Map<String, dynamic> _healthScore = {};
  List<dynamic> _aiInsights = [];
  Map<String, dynamic> _customerAnalytics = {};
  Map<String, dynamic> _ordersAnalytics = {};
  Map<String, dynamic> _productsAnalytics = {};
  Map<String, dynamic> _categoriesAnalytics = {};

  // Monthly Aggregation (Jan - Dec)
  final List _monthNames = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  List _monthlyOrderCounts = List.filled(12, 0);
  List _monthlyRevenueTotals = List.filled(12, 0.0);
  int _selectedMonthIndex = DateTime.now().month - 1;

  Color get _scaffoldBg =>
      _isDarkMode ? const Color(0xFF0B132B) : const Color(0xFFF1F6F0);

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _fetchAllBackendData();
    _startRealtimeNotificationPolling();
  }

  @override
  void dispose() {
    _realtimePollTimer?.cancel();
    super.dispose();
  }

  void _startRealtimeNotificationPolling() {
    _realtimePollTimer?.cancel();
    _realtimePollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _pollRealtimeOrdersAndNotifications(),
    );
  }

  // Trigger Native Ringtone + Human Voice Announcement
  Future _triggerToneAndVoice(String speechText) async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    if (!_voiceAlertEnabled) {
      try {
        await _voiceChannel.invokeMethod('playToneOnly');
      } catch (_) {}
      return;
    }

    try {
      await _voiceChannel.invokeMethod('playToneAndSpeak', {
        'text': speechText,
      });
    } catch (_) {}
  }

  Future _toggleVoiceAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final bool nextVal = !_voiceAlertEnabled;
    setState(() {
      _voiceAlertEnabled = nextVal;
    });
    await prefs.setBool('admin_voice_alert_enabled', nextVal);

    if (nextVal) {
      await _triggerToneAndVoice(
          'ভয়েস নোটিফিকেশন চালু করা হয়েছে। নতুন অর্ডার আসলে আপনাকে বলে জানানো হবে।');
    } else {
      try {
        await _voiceChannel.invokeMethod('stopSpeaking');
      } catch (_) {}
    }
  }

  Color? _parseHexColor(String? hexStr) {
    if (hexStr == null || hexStr.trim().isEmpty) return null;
    final clean = hexStr.trim().replaceAll('#', '');
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  Future _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPrimary = _parseHexColor(
      prefs.getString('mobile_app_primary_color'),
    );
    final savedSecondary = _parseHexColor(
      prefs.getString('mobile_app_secondary_color'),
    );
    final savedGrad = prefs.getBool('mobile_app_use_gradient');
    final savedVoice = prefs.getBool('admin_voice_alert_enabled');

    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('admin_is_dark_mode') ?? false;
        if (savedPrimary != null) _brandGreen = savedPrimary;
        if (savedSecondary != null) _secondaryBrandColor = savedSecondary;
        if (savedGrad != null) _useGradient = savedGrad;
        if (savedVoice != null) _voiceAlertEnabled = savedVoice;
      });
    }
  }

  Future _toggleDarkMode([bool? val]) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = val ?? !_isDarkMode;
    });
    await prefs.setBool('admin_is_dark_mode', _isDarkMode);
  }

  Future _resolveTenantConnectionParams() async {
    final prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('merchant_token') ?? '';

    const String envStoreDomain = String.fromEnvironment(
      'STORE_DOMAIN',
      defaultValue: String.fromEnvironment(
        'DEFAULT_TENANT_DOMAIN',
        defaultValue: '',
      ),
    );
    const String envSub = String.fromEnvironment(
      'TENANT_SUBDOMAIN',
      defaultValue: '',
    );

    String subdomain = prefs.getString('active_subdomain') ?? envSub;
    String domain = prefs.getString('locked_tenant_domain') ?? envStoreDomain;

    if (subdomain.isEmpty && domain.isNotEmpty) {
      final String cleanDom = domain
          .replaceAll('https://', '')
          .replaceAll('http://', '')
          .split('/')
          .first;
      subdomain = cleanDom.split('.').first;
    }
    if (subdomain.isEmpty) {
      subdomain = 'nextlook';
    }
    if (domain.isEmpty) {
      domain = '$subdomain.shop.xylotechsolution.com';
    }

    String apiBase = prefs.getString('api_base_url') ?? '';
    if (apiBase.isEmpty) {
      if (domain.startsWith('http://') || domain.startsWith('https://')) {
        apiBase = domain;
      } else {
        apiBase = 'https://$domain';
      }
    }
    while (apiBase.endsWith('/')) {
      apiBase = apiBase.substring(0, apiBase.length - 1);
    }

    final Map<String, String> headers = {
      'Accept': 'application/json',
      'User-Agent': _browserUserAgent,
      'X-Tenant-Subdomain': subdomain,
      'x-subdomain': subdomain,
      'X-Tenant-Domain': domain,
      'X-Branch-ID': 'all',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    return {
      'subdomain': subdomain,
      'domain': domain,
      'apiBase': apiBase,
      'headers': headers,
    };
  }

  // Silent Realtime Polling Every 8 Seconds for New Orders & Any New Notification
  Future _pollRealtimeOrdersAndNotifications() async {
    if (!mounted) return;
    try {
      final Map conn = await _resolveTenantConnectionParams() as Map;
      final String subdomain = conn['subdomain'].toString();
      final String apiBase = conn['apiBase'].toString();
      final Map<String, String> headers =
          Map<String, String>.from(conn['headers'] as Map);

      final results = await Future.wait([
        http
            .get(
              Uri.parse('$apiBase/api/v1/orders/?subdomain=$subdomain'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 6))
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '$apiBase/api/v1/stores/merchant/admin-notifications/?subdomain=$subdomain'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 6))
            .catchError((_) => http.Response('[]', 500)),
      ]);

      final List speechQueue = [];
      String? latestBannerTitle;
      String? latestBannerSub;
      String latestTargetMenu = 'orders';

      // 1. Check Orders
      if (results[0].statusCode == 200) {
        final dynamic oData = jsonDecode(results[0].body);
        List fetchedOrders = [];
        if (oData is Map && oData['results'] is List) {
          fetchedOrders = oData['results'] as List;
        } else if (oData is List) {
          fetchedOrders = oData;
        }

        for (int i = 0; fetchedOrders.length > i; i++) {
          final ord = fetchedOrders[i];
          if (ord is! Map) continue;
          final String ordKey =
              (ord['order_number'] ?? ord['id'] ?? '').toString().trim();
          if (ordKey.isEmpty) continue;

          if (!_knownOrderKeys.contains(ordKey)) {
            _knownOrderKeys.add(ordKey);
            if (_initialBaselineLoaded) {
              final String cust = (ord['customer_name'] ??
                      (ord['shipping_address'] is Map
                          ? ord['shipping_address']['name']
                          : null) ??
                      'কাস্টমার')
                  .toString();
              final String totalStr = (ord['total'] ??
                      ord['total_amount'] ??
                      ord['grand_total'] ??
                      '0')
                  .toString();
              final String speech =
                  'নতুন অর্ডার এসেছে! অর্ডার নম্বর $ordKey, কাস্টমার $cust, মোট বিল $totalStr টাকা।';
              speechQueue.add(speech);
              latestBannerTitle = '🎉 নতুন অর্ডার এসেছে! (#$ordKey)';
              latestBannerSub = 'কাস্টমার: $cust • বিল: ৳$totalStr';
              latestTargetMenu = 'orders';
            }
          }
        }

        if (fetchedOrders.length != _ordersList.length && mounted) {
          setState(() {
            _ordersList = fetchedOrders;
            _totalOrders = fetchedOrders.length;
            _computeMonthlyStatsFromOrders();
          });
        }
      }

      // 2. Check Admin Notifications (/api/v1/stores/merchant/admin-notifications/)
      if (results[1].statusCode == 200) {
        final dynamic nData = jsonDecode(results[1].body);
        if (nData is List) {
          int unread = 0;
          for (int i = 0; nData.length > i; i++) {
            final item = nData[i];
            if (item is! Map) continue;
            if (item['is_read'] != true) {
              unread++;
            }
            final String nKey =
                '${item['id']}_${item['title']}_${item['reference_id'] ?? ''}';
            if (!_knownNotificationKeys.contains(nKey)) {
              _knownNotificationKeys.add(nKey);
              if (_initialBaselineLoaded) {
                final String nTitle = (item['title'] ?? 'নোটিফিকেশন').toString();
                final String nMsg = (item['message'] ?? '').toString();
                final String nTab = (item['link_tab'] ?? 'orders').toString();
                // Avoid double-speaking if we already queued the exact same order speech
                if (speechQueue.isEmpty) {
                  speechQueue.add('$nTitle। $nMsg');
                  latestBannerTitle = '🔔 $nTitle';
                  latestBannerSub = nMsg;
                  latestTargetMenu = nTab;
                }
              }
            }
          }
          if (mounted) {
            setState(() {
              _notificationsList = nData;
              _unreadNotificationCount = unread;
            });
          }
        }
      }

      _initialBaselineLoaded = true;

      // 3. Play Tone + Speak Voice + Show Top Live Alert Banner!
      if (speechQueue.isNotEmpty && mounted) {
        final String combinedSpeech = speechQueue.join(' ');
        await _triggerToneAndVoice(combinedSpeech);

        if (latestBannerTitle != null && mounted) {
          _showLiveIncomingAlertBanner(
            title: latestBannerTitle,
            subtitle: latestBannerSub ?? '',
            targetMenu: latestTargetMenu,
            speechText: combinedSpeech,
          );
        }
      }
    } catch (_) {}
  }

  void _showLiveIncomingAlertBanner({
    required String title,
    required String subtitle,
    required String targetMenu,
    required String speechText,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF065F46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Colors.amberAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
              onPressed: () => _triggerToneAndVoice(speechText),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'দেখুন',
          textColor: Colors.amberAccent,
          onPressed: () {
            _handleDrawerMenuSelected(targetMenu);
          },
        ),
      ),
    );
  }

  Future _markAllNotificationsRead() async {
    try {
      final Map conn = await _resolveTenantConnectionParams() as Map;
      final String subdomain = conn['subdomain'].toString();
      final String apiBase = conn['apiBase'].toString();
      final Map<String, String> headers =
          Map<String, String>.from(conn['headers'] as Map);

      await http.post(
        Uri.parse(
            '$apiBase/api/v1/stores/merchant/admin-notifications/?subdomain=$subdomain'),
        headers: headers,
      );
      setState(() {
        _unreadNotificationCount = 0;
        for (int i = 0; _notificationsList.length > i; i++) {
          if (_notificationsList[i] is Map) {
            (_notificationsList[i] as Map)['is_read'] = true;
          }
        }
      });
    } catch (_) {}
  }

  void _openLiveNotificationCenterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        final Color textCol =
            _isDarkMode ? Colors.white : const Color(0xFF1E3A1A);
        final Color subCol =
            _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          builder: (_, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active_rounded,
                          color: _brandGreen, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Realtime Voice & Notification Center',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: textCol,
                              ),
                            ),
                            Text(
                              'নতুন অর্ডার বা নোটিফিকেশন আসলে অটোমেটিক টোন ও ভয়েসে বলবে',
                              style: TextStyle(fontSize: 11, color: subCol),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close_rounded, color: textCol),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Voice Test & Mark Read Action Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _triggerToneAndVoice(
                              'স্বাগতম $_storeName! নতুন একটি অর্ডার এসেছে, মোট বিল এক হাজার পাঁচশত টাকা।',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, size: 17),
                          label: const Text(
                            '🔊 Test Voice & Tone',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _markAllNotificationsRead();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.done_all_rounded,
                            size: 16, color: _brandGreen),
                        label: Text(
                          'Mark Read',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _brandGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: _notificationsList.isEmpty && _ordersList.isEmpty
                        ? Center(
                            child: Text(
                              'এখনো কোনো নোটিফিকেশন বা অর্ডার আসেনি।',
                              style: TextStyle(color: subCol, fontSize: 13),
                            ),
                          )
                        : ListView(
                            controller: scrollCtrl,
                            children: [
                              if (_notificationsList.isNotEmpty) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    'LIVE SYSTEM & ORDER NOTIFICATIONS (${_notificationsList.length})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: _brandGreen,
                                    ),
                                  ),
                                ),
                                ..._notificationsList.map((raw) {
                                  if (raw is! Map) {
                                    return const SizedBox.shrink();
                                  }
                                  final String title =
                                      (raw['title'] ?? 'Notification')
                                          .toString();
                                  final String msg =
                                      (raw['message'] ?? '').toString();
                                  final String timeStr =
                                      (raw['created_at'] ?? '').toString();
                                  final bool isRead = raw['is_read'] == true;
                                  final String tab =
                                      (raw['link_tab'] ?? 'orders').toString();

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isDarkMode
                                          ? const Color(0xFF1E293B)
                                          : (isRead
                                              ? const Color(0xFFF8FAFC)
                                              : _brandGreen.withValues(
                                                  alpha: 0.08)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isRead
                                            ? Colors.grey.withValues(alpha: 0.2)
                                            : _brandGreen,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        _handleDrawerMenuSelected(tab);
                                      },
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.notifications_active_outlined,
                                            color: _brandGreen,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    color: textCol,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  msg,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: subCol,
                                                  ),
                                                ),
                                                if (timeStr.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: _brandGreen,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Speak Notification',
                                            onPressed: () {
                                              _triggerToneAndVoice(
                                                  '$title। $msg');
                                            },
                                            icon: Icon(
                                              Icons.volume_up_rounded,
                                              color: _brandGreen,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                              if (_ordersList.isNotEmpty) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    'RECENT ORDERS VOICE REPLAY (${_ordersList.length})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: _brandGreen,
                                    ),
                                  ),
                                ),
                                ..._ordersList.take(15).map((ord) {
                                  if (ord is! Map) {
                                    return const SizedBox.shrink();
                                  }
                                  final String ordNo = (ord['order_number'] ??
                                          'ORD-${ord['id'] ?? ''}')
                                      .toString();
                                  final String cust = (ord['customer_name'] ??
                                          (ord['shipping_address'] is Map
                                              ? ord['shipping_address']['name']
                                              : null) ??
                                          'কাস্টমার')
                                      .toString();
                                  final String total = (ord['total'] ??
                                          ord['total_amount'] ??
                                          '0')
                                      .toString();
                                  final String status =
                                      (ord['status'] ?? 'pending')
                                          .toString()
                                          .toUpperCase();

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isDarkMode
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color:
                                            Colors.grey.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.shopping_bag_outlined,
                                            color: _brandGreen, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () {
                                              Navigator.of(ctx).pop();
                                              _handleDrawerMenuSelected(
                                                  'orders');
                                            },
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'অর্ডার #$ordNo • ৳$total',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    color: textCol,
                                                  ),
                                                ),
                                                Text(
                                                  'কাস্টমার: $cust • $status',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: subCol,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Speak Order Details',
                                          onPressed: () {
                                            _triggerToneAndVoice(
                                              'অর্ডার নম্বর $ordNo, কাস্টমার $cust, মোট বিল $total টাকা।',
                                            );
                                          },
                                          icon: Icon(
                                            Icons.volume_up_rounded,
                                            color: _brandGreen,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future _fetchAllBackendData() async {
    await _loadThemePreference();
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final Map conn = await _resolveTenantConnectionParams() as Map;
    final String subdomain = conn['subdomain'].toString();
    final String apiBase = conn['apiBase'].toString();
    final Map<String, String> headers =
        Map<String, String>.from(conn['headers'] as Map);

    _storeName = prefs.getString('store_name') ?? subdomain.toUpperCase();
    _storeLogo = prefs.getString('store_logo');

    try {
      final futures = await Future.wait([
        http
            .get(Uri.parse('$apiBase/api/v1/orders/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/products/?subdomain=$subdomain&all_branches=true'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/products/categories/?subdomain=$subdomain&all_shops=true'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/customers/?subdomain=$subdomain&all_branches=true'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/reviews/?subdomain=$subdomain&admin=true&all_branches=true'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/stores/settings/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/subscriptions/current/?subdomain=$subdomain'),
                headers: headers)
            .then((res) => res.statusCode == 404
                ? http.get(
                    Uri.parse(
                        '$apiBase/api/v1/subscriptions/subscriptions/current/?subdomain=$subdomain'),
                    headers: headers)
                : Future.value(res))
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/subscriptions/plans/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/stores/shops/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/stores/merchant/admin-notifications/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
      ]);

      if (futures[5].statusCode == 200) {
        final sData = jsonDecode(futures[5].body);
        if (sData is Map) {
          if (sData['store_name'] != null &&
              sData['store_name'].toString().isNotEmpty) {
            _storeName = sData['store_name'].toString();
          }
          final rawLogo = sData['logo'] ?? sData['store_logo'];
          if (rawLogo is String && rawLogo.isNotEmpty) {
            _storeLogo =
                rawLogo.startsWith('http') ? rawLogo : '$apiBase$rawLogo';
          }
        }
      }

      List allPlans = [];
      if (futures[7].statusCode == 200) {
        final pJson = jsonDecode(futures[7].body);
        if (pJson is List) {
          allPlans = pJson;
        } else if (pJson is Map && pJson['results'] is List) {
          allPlans = pJson['results'] as List;
        }
      }

      if (futures[6].statusCode == 200) {
        final subData = jsonDecode(futures[6].body);
        if (subData is Map) {
          final String fetchedPlanName = (subData['plan_name'] ??
                  subData['plan_details']?['display_name'] ??
                  '')
              .toString();
          final String fetchedPlanSlug =
              (subData['plan_slug'] ?? subData['plan_details']?['name'] ?? '')
                  .toString()
                  .toLowerCase();

          if (fetchedPlanName.isNotEmpty) {
            _planName = fetchedPlanName;
          }

          int resolvedMaxProducts = 0;
          for (var pl in allPlans) {
            if (pl is Map) {
              final plName =
                  (pl['display_name'] ?? '').toString().toLowerCase();
              final plSlug = (pl['name'] ?? '').toString().toLowerCase();
              if (plName == _planName.toLowerCase() ||
                  plSlug == fetchedPlanSlug) {
                resolvedMaxProducts =
                    int.tryParse((pl['max_products'] ?? 0).toString()) ?? 0;
                break;
              }
            }
          }

          if (0 >= resolvedMaxProducts && subData['branch_quota'] is Map) {
            final bq = subData['branch_quota'];
            final int maxB =
                int.tryParse((bq['max_branches'] ?? 1).toString()) ?? 1;
            final int maxPerB = int.tryParse(
                    (bq['max_products_per_branch'] ?? 100).toString()) ??
                100;
            resolvedMaxProducts = maxB * maxPerB;
          }

          if (0 >= resolvedMaxProducts ||
              (fetchedPlanSlug.contains('pro') && 600 > resolvedMaxProducts)) {
            if (fetchedPlanSlug.contains('pro') ||
                _planName.toLowerCase().contains('pro')) {
              resolvedMaxProducts = 600;
            } else if (fetchedPlanSlug.contains('enterprise') ||
                _planName.toLowerCase().contains('enterprise')) {
              resolvedMaxProducts = 5000;
            } else {
              resolvedMaxProducts = 100;
            }
          }

          _maxProducts = resolvedMaxProducts;
        }
      }

      if (futures[1].statusCode == 200) {
        final pData = jsonDecode(futures[1].body);
        if (pData is Map && pData['results'] is List) {
          _productsList = pData['results'] as List;
          _totalProducts = (pData['count'] as int?) ?? _productsList.length;
        } else if (pData is List) {
          _productsList = pData;
          _totalProducts = _productsList.length;
        }
      }

      if (futures[2].statusCode == 200) {
        final cData = jsonDecode(futures[2].body);
        if (cData is Map && cData['results'] is List) {
          _categoriesList = cData['results'] as List;
          _totalCategories = (cData['count'] as int?) ?? _categoriesList.length;
        } else if (cData is List) {
          _categoriesList = cData;
          _totalCategories = _categoriesList.length;
        }
      }

      if (futures[3].statusCode == 200) {
        final custData = jsonDecode(futures[3].body);
        if (custData is Map && custData['results'] is List) {
          _totalCustomers = (custData['count'] as int?) ??
              (custData['results'] as List).length;
        } else if (custData is List) {
          _totalCustomers = custData.length;
        }
      }

      if (futures[4].statusCode == 200) {
        final revData = jsonDecode(futures[4].body);
        if (revData is Map && revData['results'] is List) {
          _totalReviews =
              (revData['count'] as int?) ?? (revData['results'] as List).length;
        } else if (revData is List) {
          _totalReviews = revData.length;
        }
      }

      if (futures[8].statusCode == 200) {
        final shData = jsonDecode(futures[8].body);
        if (shData is Map && shData['results'] is List) {
          _totalShops =
              (shData['count'] as int?) ?? (shData['results'] as List).length;
        } else if (shData is List) {
          _totalShops = shData.length;
        }
      }

      if (futures[0].statusCode == 200) {
        final oData = jsonDecode(futures[0].body);
        if (oData is Map && oData['results'] is List) {
          _ordersList = oData['results'] as List;
          _totalOrders = (oData['count'] as int?) ?? _ordersList.length;
        } else if (oData is List) {
          _ordersList = oData;
          _totalOrders = _ordersList.length;
        }
        for (var ord in _ordersList) {
          if (ord is Map) {
            final String ordKey =
                (ord['order_number'] ?? ord['id'] ?? '').toString().trim();
            if (ordKey.isNotEmpty) _knownOrderKeys.add(ordKey);
          }
        }
        _computeMonthlyStatsFromOrders();
      }

      if (futures[9].statusCode == 200) {
        final nData = jsonDecode(futures[9].body);
        if (nData is List) {
          _notificationsList = nData;
          int unread = 0;
          for (var item in nData) {
            if (item is Map) {
              if (item['is_read'] != true) unread++;
              final String nKey =
                  '${item['id']}_${item['title']}_${item['reference_id'] ?? ''}';
              _knownNotificationKeys.add(nKey);
            }
          }
          _unreadNotificationCount = unread;
        }
      }

      _initialBaselineLoaded = true;
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _computeMonthlyStatsFromOrders() {
    double salesSum = 0.0;
    int pending = 0;
    int completed = 0;
    final Set uniqueBuyers = {};

    final List monthOrders = List.filled(12, 0);
    final List monthRev = List.filled(12, 0.0);
    final List timeline = [];

    for (var i = 0; _ordersList.length > i; i++) {
      final ord = _ordersList[i];
      if (ord is! Map) continue;

      final double amount = double.tryParse(
            (ord['total_amount'] ??
                    ord['total_price'] ??
                    ord['grand_total'] ??
                    ord['total'] ??
                    ord['amount'] ??
                    '0')
                .toString(),
          ) ??
          0.0;

      salesSum += amount;

      final String status =
          (ord['status'] ?? 'pending').toString().toLowerCase();
      if (status == 'completed' || status == 'delivered') {
        completed++;
      } else if (status != 'cancelled') {
        pending++;
      }

      final String buyer = (ord['customer_name'] ??
              ord['customer_phone'] ??
              ord['customer'] ??
              '')
          .toString()
          .trim();
      if (buyer.isNotEmpty) {
        uniqueBuyers.add(buyer);
      }

      final String rawDate =
          (ord['created_at'] ?? ord['date'] ?? '').toString();
      DateTime? parsedDate = DateTime.tryParse(rawDate);
      parsedDate ??= DateTime.now();

      final int mIdx = (parsedDate.month - 1).clamp(0, 11);
      monthOrders[mIdx] = (monthOrders[mIdx] as int) + 1;
      monthRev[mIdx] = (monthRev[mIdx] as double) + amount;

      final String formattedDate =
          '${parsedDate.day.toString().padLeft(2, '0')} ${_monthNames[mIdx]} ${parsedDate.year}';

      final rawItems = ord['items'] ?? ord['order_items'] ?? ord['products'];
      if (rawItems is List && rawItems.isNotEmpty) {
        for (var item in rawItems) {
          if (item is Map) {
            final prodName = (item['product_name'] ??
                    item['name'] ??
                    (item['product'] is Map ? item['product']['name'] : null) ??
                    'Product')
                .toString();
            final qty = int.tryParse(
                    (item['quantity'] ?? item['qty'] ?? 1).toString()) ??
                1;
            final itemPrice = double.tryParse(
                    (item['price'] ?? item['total'] ?? amount).toString()) ??
                amount;

            timeline.add({
              'product_name': prodName,
              'order_id': ord['order_number'] ?? '#ORD-${ord['id'] ?? i}',
              'customer': buyer.isNotEmpty ? buyer : 'Customer',
              'date': formattedDate,
              'qty': qty,
              'price': itemPrice,
              'status': status,
            });
          }
        }
      } else {
        String fallbackProdName =
            (ord['product_name'] ?? ord['title'] ?? '').toString();
        if (fallbackProdName.isEmpty && _productsList.isNotEmpty) {
          final matchedProd = _productsList[i % _productsList.length];
          fallbackProdName = (matchedProd['name'] ?? 'Order Item').toString();
        } else if (fallbackProdName.isEmpty) {
          fallbackProdName =
              'Order #${ord['order_number'] ?? ord['id'] ?? (i + 1)}';
        }

        timeline.add({
          'product_name': fallbackProdName,
          'order_id': ord['order_number'] ?? '#ORD-${ord['id'] ?? i}',
          'customer': buyer.isNotEmpty ? buyer : 'Guest Customer',
          'date': formattedDate,
          'qty': 1,
          'price': amount,
          'status': status,
        });
      }
    }

    _totalSales = salesSum;
    _pendingOrders = pending;
    _completedOrders = completed;
    if (_totalCustomers == 0 && uniqueBuyers.isNotEmpty) {
      _totalCustomers = uniqueBuyers.length;
    }

    _monthlyOrderCounts = monthOrders;
    _monthlyRevenueTotals = monthRev;
    _purchasedProductTimeline = timeline;

    for (int m = 11; m >= 0; m--) {
      if ((_monthlyOrderCounts[m] as int) > 0) {
        _selectedMonthIndex = m;
        break;
      }
    }
  }

  Future _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('merchant_token');
    await prefs.remove('merchant_refresh_token');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MerchantLoginScreen()),
    );
  }

  bool get _isSettingsMenuSelected => [
        'settings',
        'themes',
        'company_settings',
      ].contains(_activeDrawerMenu);

  String get _resolvedSettingsSubTab {
    if (_activeDrawerMenu == 'themes' ||
        _activeDrawerMenu == 'company_settings') {
      return 'theme_branding';
    }
    return 'theme_branding';
  }

  void _handleDrawerMenuSelected(String menuId) {
    setState(() {
      _activeDrawerMenu = menuId;
      if (menuId == 'overview') {
        _selectedBottomNavIndex = 0;
      } else if (menuId == 'orders' || menuId == 'fraud_detection') {
        _selectedBottomNavIndex = 1;
      } else if (menuId == 'products' ||
          menuId == 'gallery' ||
          menuId == 'reviews') {
        _selectedBottomNavIndex = 2;
      } else if (menuId == 'categories') {
        _selectedBottomNavIndex = 3;
      } else if (menuId == 'inventory') {
        _selectedBottomNavIndex = 4;
      } else if (menuId == 'daily_collection') {
        _selectedBottomNavIndex = 5;
      } else if (menuId == 'barcode_scanner') {
        _selectedBottomNavIndex = 6;
      } else if (menuId == 'customers') {
        _selectedBottomNavIndex = 7;
      } else if ([
        'settings',
        'themes',
        'company_settings',
      ].contains(menuId)) {
        _selectedBottomNavIndex = 9;
      }
    });
  }

  Widget _buildActiveScreenBody() {
    if (_isSettingsMenuSelected) {
      return GeneralSettingsView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: _resolvedSettingsSubTab,
        onSettingsUpdated: _fetchAllBackendData,
      );
    }

    if ([
      'shops',
      'shop_list',
      'shop_add',
      'add_shop',
      'outlets',
    ].contains(_activeDrawerMenu)) {
      return ShopsOutletsView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
      );
    }

    if ([
      'branches',
      'branch_list',
      'branch_add',
      'add_branch',
      'export_product',
      'branch_export',
      'branch_notice',
      'branch_notices',
    ].contains(_activeDrawerMenu)) {
      return BranchStoresView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
      );
    }

    if ([
      'cross_selling',
      'b2b',
      'cross_sell_credentials',
      'b2b_credentials',
      'b2b_api_keys',
      'cross_sell_partners',
      'b2b_partners',
      'cross_sell_catalog',
      'b2b_catalog',
      'b2b_import',
      'cross_sell_ledger',
      'b2b_ledger',
    ].contains(_activeDrawerMenu)) {
      return B2BCrossSellView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
      );
    }

    if ([
      'courier',
      'courier_service',
      'courier_setup',
      'courier_booking',
      'courier_tracking',
      'courier_settlement',
    ].contains(_activeDrawerMenu)) {
      return CourierServiceView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
      );
    }

    if ([
      'sms',
      'sms_service',
      'sms_gateway',
      'sms_single',
      'sms_individual',
      'sms_templates',
      'sms_template',
      'sms_groups',
      'sms_group',
      'sms_bulk',
      'sms_send',
      'sms_logs',
    ].contains(_activeDrawerMenu)) {
      String initialSmsTab = 'sms_gateway';
      if (_activeDrawerMenu == 'sms_single' ||
          _activeDrawerMenu == 'sms_individual') {
        initialSmsTab = 'sms_single';
      } else if (_activeDrawerMenu == 'sms_templates' ||
          _activeDrawerMenu == 'sms_template') {
        initialSmsTab = 'sms_templates';
      } else if (_activeDrawerMenu == 'sms_groups' ||
          _activeDrawerMenu == 'sms_group') {
        initialSmsTab = 'sms_groups';
      } else if (_activeDrawerMenu == 'sms_bulk' ||
          _activeDrawerMenu == 'sms_send' ||
          _activeDrawerMenu == 'sms_logs') {
        initialSmsTab = 'sms_bulk';
      }
      return SmsServiceView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: initialSmsTab,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if ([
      'email',
      'email_service',
      'email_gateway',
      'email_compose',
      'email_logs',
      'email_settings',
    ].contains(_activeDrawerMenu)) {
      String initialEmailTab = 'email_gateway';
      if (_activeDrawerMenu == 'email_logs') {
        initialEmailTab = 'email_logs';
      } else if (_activeDrawerMenu == 'email_compose') {
        initialEmailTab = 'email_compose';
      }
      return EmailServiceView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: initialEmailTab,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if ([
      'reports',
      'report_messages',
      'report_reviews',
      'report_customers',
      'report_sms',
      'report_orders',
    ].contains(_activeDrawerMenu)) {
      String initialRepTab = 'report_orders';
      if (_activeDrawerMenu == 'report_messages') {
        initialRepTab = 'report_messages';
      } else if (_activeDrawerMenu == 'report_reviews') {
        initialRepTab = 'report_reviews';
      } else if (_activeDrawerMenu == 'report_customers') {
        initialRepTab = 'report_customers';
      } else if (_activeDrawerMenu == 'report_sms') {
        initialRepTab = 'report_sms';
      }
      return ReportsHubView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: initialRepTab,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if ([
      'messages',
      'chat',
      'live_chat',
      'branch_chat',
      'chat_customer',
      'chat_branch_merchant',
      'chat_branch_customer',
      'chat_superadmin',
    ].contains(_activeDrawerMenu)) {
      String initialChatChannel = 'chat_customer';
      if (_activeDrawerMenu == 'chat_branch_merchant' ||
          _activeDrawerMenu == 'branch_chat') {
        initialChatChannel = 'chat_branch_merchant';
      } else if (_activeDrawerMenu == 'chat_branch_customer') {
        initialChatChannel = 'chat_branch_customer';
      } else if (_activeDrawerMenu == 'chat_superadmin') {
        initialChatChannel = 'chat_superadmin';
      }
      return LiveChatChannelsView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: initialChatChannel,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if ([
      'analytics',
      'analytics_customer',
      'analytics_orders',
      'analytics_products',
      'analytics_categories',
    ].contains(_activeDrawerMenu)) {
      return AnalyticsBiView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: _activeDrawerMenu == 'analytics'
            ? 'analytics_customer'
            : _activeDrawerMenu,
        onNavigateMenu: (val) => _handleDrawerMenuSelected(val.toString()),
      );
    }

    if ([
      'hrm',
      'employees',
      'attendance',
      'payroll',
      'departments',
    ].contains(_activeDrawerMenu)) {
      return HrPayrollView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab:
            _activeDrawerMenu == 'hrm' ? 'employees' : _activeDrawerMenu,
      );
    }

    if (_activeDrawerMenu == 'affiliates' ||
        _activeDrawerMenu.startsWith('affiliate_')) {
      return AffiliateMarketingView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: _activeDrawerMenu,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if ([
      'announcements',
      'store_announcements',
      'coupons',
      'banners',
      'newsletter',
    ].contains(_activeDrawerMenu)) {
      return MarketingPromosView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: _activeDrawerMenu,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if ([
      'testimonials',
      'blogs',
      'faqs',
      'store_gallery',
    ].contains(_activeDrawerMenu)) {
      return StoreCmsView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: _activeDrawerMenu,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if (_activeDrawerMenu == 'app_builder' ||
        _activeDrawerMenu == 'mobile_apps') {
      return AppGenerateView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        onOpenUploadTab: () => _handleDrawerMenuSelected('app_upload'),
        onDataChanged: _fetchAllBackendData,
      );
    }

    if (_activeDrawerMenu == 'app_upload' ||
        _activeDrawerMenu == 'app_navbar') {
      return AppUploadView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialSection: _activeDrawerMenu == 'app_navbar' ? 'navbar' : 'upload',
        onOpenGenerateTab: () => _handleDrawerMenuSelected('app_builder'),
        onDataChanged: _fetchAllBackendData,
      );
    }

    if ([
      'help',
      'help_support',
      'help_guides',
      'help_videos',
    ].contains(_activeDrawerMenu)) {
      return HelpSupportView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        initialTab: _activeDrawerMenu,
      );
    }

    if (_activeDrawerMenu == 'orders') {
      return OrdersListView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        onOrdersChanged: _fetchAllBackendData,
      );
    }

    if (_activeDrawerMenu == 'inventory') {
      return InventoryListView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if (_activeDrawerMenu == 'daily_collection') {
      return DailyCollectionView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
      );
    }

    if (_activeDrawerMenu == 'barcode_scanner') {
      return BarcodeScannerView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
      );
    }

    if (_activeDrawerMenu == 'customers') {
      return CustomersListView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        onDataChanged: _fetchAllBackendData,
      );
    }

    if (_activeDrawerMenu == 'fraud_detection') {
      return CodFraudShieldView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
      );
    }

    if (_activeDrawerMenu == 'products') {
      return ProductListView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        onOpenCategoryList: () => _handleDrawerMenuSelected('categories'),
        onCatalogChanged: _fetchAllBackendData,
      );
    }

    if (_activeDrawerMenu == 'categories') {
      return CategoryListView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        onOpenProductList: () => _handleDrawerMenuSelected('products'),
        onCatalogChanged: _fetchAllBackendData,
      );
    }

    if (_activeDrawerMenu == 'gallery') {
      return ProductImagesGalleryView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        onCatalogChanged: _fetchAllBackendData,
      );
    }

    if (_activeDrawerMenu == 'reviews') {
      return ProductReviewsView(
        isDarkMode: _isDarkMode,
        brandGreen: _brandGreen,
        onDataChanged: _fetchAllBackendData,
      );
    }

    return OverviewDashboardView(
      storeName: _storeName,
      isDarkMode: _isDarkMode,
      brandGreen: _brandGreen,
      secondaryBrandColor: _secondaryBrandColor,
      useGradient: _useGradient,
      totalSales: _totalSales,
      totalOrders: _totalOrders,
      totalCustomers: _totalCustomers,
      totalProducts: _totalProducts,
      totalCategories: _totalCategories,
      totalReviews: _totalReviews,
      pendingOrders: _pendingOrders,
      completedOrders: _completedOrders,
      salesGrowth: _salesGrowth,
      monthlyOrderCounts: List<int>.from(_monthlyOrderCounts),
      monthlyRevenueTotals: List<double>.from(_monthlyRevenueTotals),
      selectedMonthIndex: _selectedMonthIndex,
      onSelectMonth: (idx) => setState(() => _selectedMonthIndex = idx),
      purchasedProductTimeline: _purchasedProductTimeline,
      categoriesList: _categoriesList,
      onNavigateMenu: _handleDrawerMenuSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _scaffoldBg,
      drawer: AdminSideDrawer(
        storeName: _storeName,
        storeLogo: _storeLogo,
        brandGreen: _brandGreen,
        totalOrders: _totalOrders,
        totalCustomers: _totalCustomers,
        totalProducts: _totalProducts,
        totalCategories: _totalCategories,
        totalReviews: _totalReviews,
        totalShops: _totalShops,
        maxProducts: _maxProducts,
        planName: _planName,
        activeMenu: _activeDrawerMenu,
        isDarkMode: _isDarkMode,
        onToggleDarkMode: (val) => _toggleDarkMode(val == true),
        onMenuSelected: (val) => _handleDrawerMenuSelected(val.toString()),
        onLogout: _handleLogout,
      ),
      appBar: AdminTopNavbar(
        storeName: _storeName,
        storeLogo: _storeLogo,
        brandGreen: _brandGreen,
        pendingOrders: _pendingOrders,
        unreadNotifications: _unreadNotificationCount,
        voiceEnabled: _voiceAlertEnabled,
        isDarkMode: _isDarkMode,
        onToggleDarkMode: () => _toggleDarkMode(),
        onToggleVoiceTap: _toggleVoiceAlert,
        onNotificationTap: _openLiveNotificationCenterModal,
        onMenuTap: () =>
            (_scaffoldKey.currentState as ScaffoldState?)?.openDrawer(),
        onRefreshTap: _fetchAllBackendData,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _brandGreen))
          : RefreshIndicator(
              onRefresh: _fetchAllBackendData,
              color: _brandGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildActiveScreenBody(),
              ),
            ),
      bottomNavigationBar: AdminBottomNavbar(
        selectedIndex: _selectedBottomNavIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedBottomNavIndex = index;
            if (index == 0) _activeDrawerMenu = 'overview';
            if (index == 1) _activeDrawerMenu = 'orders';
            if (index == 2) _activeDrawerMenu = 'products';
            if (index == 3) _activeDrawerMenu = 'categories';
            if (index == 4) _activeDrawerMenu = 'inventory';
            if (index == 5) _activeDrawerMenu = 'daily_collection';
            if (index == 6) _activeDrawerMenu = 'barcode_scanner';
            if (index == 7) _activeDrawerMenu = 'customers';
            if (index == 9) _activeDrawerMenu = 'settings';
          });
        },
      ),
    );
  }
}