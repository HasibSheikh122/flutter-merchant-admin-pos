// lib/widgets/marketing/coupons_promos_view.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';
import 'marketing_promos_view.dart';
import '../../core/config/tenant_config.dart';

class CouponsPromosView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onDataChanged;

  const CouponsPromosView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.onDataChanged,
  });

  @override
  State createState() => _CouponsPromosViewState();
}

class _CouponsPromosViewState extends State {
  static const String _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static String _cachedSubdomain = '';
  static List _cachedList = [];

  static const List _monthShort = [
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
    'Dec',
  ];

  static const List _audienceChoices = [
    {'id': 'all', 'name': '🌐 All Customers'},
    {'id': 'new_only', 'name': '🆕 New / First-Order Customers Only'},
    {'id': 'Champions', 'name': '🏆 Champions (Top VIP Spenders)'},
    {'id': 'Loyal Customers', 'name': '💎 Loyal Customers'},
    {'id': 'Potential Loyalists', 'name': '🌱 Potential Loyalists'},
    {'id': 'At Risk', 'name': '⚠️ At-Risk Buyers (Win-Back)'},
  ];

  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _loading = true;
  List _coupons = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _statusTab = 'all';
  String _typeFilter = 'all';
  int _currentPage = 1;
  static const int _itemsPerPage = 8;

  @override
  void initState() {
    super.initState();
    _initAndFetch(forceRefresh: false);
  }

  @override
  void didUpdateWidget(covariant StatefulWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dynamic oldW = oldWidget;
    final dynamic curW = widget;
    if (oldW.isDarkMode != curW.isDarkMode ||
        oldW.brandGreen != curW.brandGreen) {
      _reloadThemeOnly();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future _reloadThemeOnly() async {
    final dynamic curW = widget;
    final t = await CatalogThemeConfig.load(
      isDarkMode: curW.isDarkMode == true,
      fallbackBrandGreen: curW.brandGreen as Color,
    );
    if (!mounted) return;
    setState(() => _theme = t);
  }

  Future _initAndFetch({bool forceRefresh = false}) async {
    final dynamic curW = widget;
    final t = await CatalogThemeConfig.load(
      isDarkMode: curW.isDarkMode == true,
      fallbackBrandGreen: curW.brandGreen as Color,
    );
    if (!mounted) return;

    if (!forceRefresh &&
        _cachedSubdomain == t.subdomain &&
        _cachedList.isNotEmpty) {
      setState(() {
        _theme = t;
        _coupons = List.from(_cachedList);
        _loading = false;
      });
      return;
    }

    setState(() {
      _theme = t;
      _loading = true;
    });
    await _fetchCoupons();
  }

  Future _resolveConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('merchant_token') ??
        prefs.getString('token') ??
        prefs.getString('access_token') ??
        _theme.token;

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
      subdomain = _theme.subdomain.isNotEmpty ? _theme.subdomain : TenantConfig.defaultSubdomain;
    }
    if (domain.isEmpty) {
      domain = '$subdomain.shop.xylotechsolution.com';
    }

    String apiBase = prefs.getString('api_base_url') ?? _theme.apiBase;
    if (apiBase.isEmpty) {
      apiBase = domain.startsWith('http') ? domain : 'https://$domain';
    }
    while (apiBase.endsWith('/')) {
      apiBase = apiBase.substring(0, apiBase.length - 1);
    }

    final Map hdrs = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': _browserUserAgent,
      'X-Tenant-Subdomain': subdomain,
      'x-subdomain': subdomain,
      'X-Tenant-Domain': domain,
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    return {
      'subdomain': subdomain,
      'domain': domain,
      'apiBase': apiBase,
      'headers': hdrs.cast(),
    };
  }

  Future _tryRefreshToken(String apiBase, String subdomain) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String refresh =
          prefs.getString('merchant_refresh_token') ?? '';
      if (refresh.isEmpty) return null;

      final List endpoints = [
        '$apiBase/api/v1/auth/token/refresh/?subdomain=$subdomain',
        '$apiBase/api/v1/users/token/refresh/?subdomain=$subdomain',
      ];

      for (int i = 0; endpoints.length > i; i++) {
        final res = await http.post(
          Uri.parse(endpoints[i].toString()),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': _browserUserAgent,
            'X-Tenant-Subdomain': subdomain,
            'x-subdomain': subdomain,
          },
          body: jsonEncode({'refresh': refresh}),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map && data['access'] != null) {
            final String newTok = data['access'].toString();
            await prefs.setString('merchant_token', newTok);
            return newTok;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future _requestApi({
    required String method,
    required String path,
    Map? body,
  }) async {
    final Map conn = await _resolveConnection() as Map;
    final String apiBase = conn['apiBase'].toString();
    final String subdomain = conn['subdomain'].toString();
    final Map headers = Map.from(conn['headers'] as Map);

    final String sep = path.contains('?') ? '&' : '?';
    final Uri uri = Uri.parse(
      '$apiBase$path${path.contains('subdomain=') ? '' : '${sep}subdomain=${Uri.encodeComponent(subdomain)}'}',
    );

    Future sendOnce(Map h) {
      if (method == 'GET') {
        return http.get(uri, headers: h.cast());
      } else if (method == 'POST') {
        return http.post(uri, headers: h.cast(), body: jsonEncode(body ?? {}));
      } else if (method == 'PATCH') {
        return http.patch(uri, headers: h.cast(), body: jsonEncode(body ?? {}));
      } else {
        return http.delete(uri, headers: h.cast());
      }
    }

    http.Response res = await sendOnce(headers);
    if (res.statusCode == 401) {
      final String? refreshed = await _tryRefreshToken(apiBase, subdomain);
      if (refreshed != null && refreshed.isNotEmpty) {
        headers['Authorization'] = 'Bearer $refreshed';
        res = await sendOnce(headers);
      }
    }
    return res;
  }

  Future _fetchCoupons() async {
    setState(() => _loading = true);
    try {
      final http.Response res = await _requestApi(
        method: 'GET',
        path: '/api/v1/coupons/',
      );
      if (!mounted) return;
      final List list = MarketingUi.extractList(res.bodyBytes);
      _cachedSubdomain = _theme.subdomain;
      _cachedList = List.from(list);
      setState(() {
        _coupons = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _generateRandomCode([String prefix = 'XYLO']) {
    const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final math.Random rnd = math.Random();
    String suffix = '';
    for (int i = 0; 4 > i; i++) {
      suffix += chars[rnd.nextInt(chars.length)];
    }
    return '$prefix$suffix';
  }

  bool _isCouponExpired(Map c) {
    final String st = (c['status'] ?? '').toString().toLowerCase();
    if (st == 'expired' || st == 'used_up') return true;
    final String validToStr = (c['valid_to'] ?? '').toString();
    final DateTime? exp = DateTime.tryParse(validToStr);
    if (exp != null && DateTime.now().isAfter(exp.toLocal())) {
      return true;
    }
    return false;
  }

  String _effectiveStatus(Map c) {
    if (_isCouponExpired(c)) return 'expired';
    final String raw = (c['status'] ?? 'active').toString().toLowerCase();
    if (['active', 'paused', 'draft', 'expired'].contains(raw)) {
      return raw;
    }
    return 'active';
  }

  String _resolveAudienceLabel(Map c) {
    if (c['first_order_only'] == true || c['new_customers_only'] == true) {
      return 'New Buyers';
    }
    final dynamic segs = c['applicable_customer_segments'];
    if (segs is List && segs.isNotEmpty) {
      return segs.join(', ');
    }
    return 'All Users';
  }

  String _resolveAudienceChoiceValue(Map? c) {
    if (c == null) return 'all';
    if (c['first_order_only'] == true || c['new_customers_only'] == true) {
      return 'new_only';
    }
    final dynamic segs = c['applicable_customer_segments'];
    if (segs is List && segs.isNotEmpty) {
      final String first = segs.first.toString();
      if (_audienceChoices.any((a) => a['id'] == first)) {
        return first;
      }
    }
    return 'all';
  }

  String _formatDisplayDateShort(dynamic raw, {bool includeYear = true}) {
    if (raw == null) return 'N/A';
    final DateTime? dt = DateTime.tryParse(raw.toString());
    if (dt == null) return 'N/A';
    final DateTime local = dt.toLocal();
    final String d = local.day.toString().padLeft(2, '0');
    final String m = _monthShort[(local.month - 1).clamp(0, 11)];
    if (!includeYear) return '$d $m';
    return '$d $m ${local.year}';
  }

  String _formatDateTimeField(DateTime dt) {
    final DateTime local = dt.toLocal();
    final String mm = local.month.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    final String yyyy = local.year.toString();
    int hour = local.hour;
    final String ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final String hh = hour.toString().padLeft(2, '0');
    final String min = local.minute.toString().padLeft(2, '0');
    return '$mm/$dd/$yyyy, $hh:$min $ampm';
  }

  String _cleanNum(dynamic raw, [String fallback = '0']) {
    if (raw == null) return fallback;
    final double? val = double.tryParse(raw.toString());
    if (val == null) return fallback;
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  Future _toggleCouponPower(Map c) async {
    final String cur = _effectiveStatus(c);
    final String nextStatus = cur == 'active' ? 'paused' : 'active';
    try {
      final http.Response res = await _requestApi(
        method: 'PATCH',
        path: '/api/v1/coupons/${c['id']}/',
        body: {'status': nextStatus},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        MarketingUi.showToast(
          context,
          _theme,
          nextStatus == 'active'
              ? 'কুপন Active করা হয়েছে!'
              : 'কুপন Paused করা হয়েছে।',
        );
        await _fetchCoupons();
        final dynamic curW = widget;
        if (curW.onDataChanged != null) curW.onDataChanged();
      } else {
        MarketingUi.showToast(
          context,
          _theme,
          'স্ট্যাটাস পরিবর্তন ব্যর্থ (${res.statusCode}): ${res.body}',
          isError: true,
        );
      }
    } catch (_) {}
  }

  Future _deleteCoupon(Map c) async {
    final String code = (c['code'] ?? '').toString();
    try {
      final http.Response res = await _requestApi(
        method: 'DELETE',
        path: '/api/v1/coupons/${c['id']}/',
      );
      if (!mounted) return;
      if (res.statusCode == 204 || res.statusCode == 200) {
        MarketingUi.showToast(
          context,
          _theme,
          'কুপন "$code" মুছে ফেলা হয়েছে।',
        );
        await _fetchCoupons();
        final dynamic curW = widget;
        if (curW.onDataChanged != null) curW.onDataChanged();
      } else {
        MarketingUi.showToast(
          context,
          _theme,
          'ডিলিট ব্যর্থ (${res.statusCode})',
          isError: true,
        );
      }
    } catch (_) {}
  }

  void _exportCsv(List list) {
    if (list.isEmpty) {
      MarketingUi.showToast(
        context,
        _theme,
        'এক্সপোর্ট করার মতো কোনো কুপন নেই।',
        isError: true,
      );
      return;
    }
    final List rows = [
      'Code,Campaign Name,Discount Type,Discount Value,Min Order,Target Audience,Used,Usage Limit,Valid From,Valid To,Status'
    ];
    for (int i = 0; list.length > i; i++) {
      final Map c = list[i] is Map ? list[i] : {};
      rows.add(
        '"${c['code'] ?? ''}","${c['name'] ?? ''}","${c['discount_type'] ?? ''}","${_cleanNum(c['discount_value'])}","${_cleanNum(c['minimum_order_amount'])}","${_resolveAudienceLabel(c)}","${c['used_count'] ?? 0}","${c['usage_limit'] ?? 'Unlimited'}","${_formatDisplayDateShort(c['valid_from'])}","${_formatDisplayDateShort(c['valid_to'])}","${_effectiveStatus(c).toUpperCase()}"',
      );
    }
    Clipboard.setData(ClipboardData(text: rows.join('\n')));
    MarketingUi.showToast(
      context,
      _theme,
      'সব কুপন ডাটা Excel (CSV) ফরম্যাটে ক্লিপবোর্ডে কপি হয়েছে!',
    );
  }

  void _showPdfReportDialog(CatalogThemeConfig t, List list) {
    if (list.isEmpty) {
      MarketingUi.showToast(
        context,
        t,
        'PDF রিপোর্ট তৈরির জন্য কোনো কুপন নেই।',
        isError: true,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: MarketingUi.modalBg(t),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: MarketingUi.fieldBorder(t)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_theme.subdomain.toUpperCase()} - Coupons Report',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: MarketingUi.textColor(t),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: Icon(Icons.close_rounded, color: MarketingUi.textColor(t)),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: list.map((raw) {
                  final Map c = raw is Map ? raw : {};
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MarketingUi.sectionBg(t),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MarketingUi.fieldBorder(t)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${c['code'] ?? ''} — ${c['name'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: MarketingUi.textColor(t),
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Text(
                          '${_cleanNum(c['discount_value'])} (${c['discount_type'] ?? ''}) • ${_effectiveStatus(c).toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t.primaryColor,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _exportCsv(list);
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Copy Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // CREATE / EDIT COUPON MODAL (100% Matching Next.js Video & Payload)
  // ===========================================================================
  void _openCouponModal(
    CatalogThemeConfig t, {
    Map? existing,
    String? presetCode,
    String? presetName,
    String? presetAudience,
    String? presetDiscountType,
    String? presetValue,
    String? presetDesc,
  }) {
    final DateTime now = DateTime.now();
    DateTime validFromDt = now;
    DateTime validToDt = now.add(const Duration(days: 7));

    if (existing != null) {
      final DateTime? pf =
          DateTime.tryParse((existing['valid_from'] ?? '').toString());
      final DateTime? pt =
          DateTime.tryParse((existing['valid_to'] ?? '').toString());
      if (pf != null) validFromDt = pf.toLocal();
      if (pt != null) validToDt = pt.toLocal();
    }

    final TextEditingController codeCtrl = TextEditingController(
      text: existing != null
          ? (existing['code'] ?? '').toString()
          : (presetCode ?? _generateRandomCode('XYLO')),
    );
    final TextEditingController nameCtrl = TextEditingController(
      text: existing != null
          ? (existing['name'] ?? 'Special Discount Offer').toString()
          : (presetName ?? 'Special Discount Offer'),
    );
    final TextEditingController valCtrl = TextEditingController(
      text: existing != null
          ? _cleanNum(existing['discount_value'], '15')
          : (presetValue ?? '15'),
    );
    final TextEditingController minOrderCtrl = TextEditingController(
      text: existing != null
          ? _cleanNum(existing['minimum_order_amount'], '500')
          : '500',
    );
    final TextEditingController maxDiscCtrl = TextEditingController(
      text: existing != null
          ? _cleanNum(existing['max_discount_amount'], '300')
          : '300',
    );
    final TextEditingController limitCtrl = TextEditingController(
      text: existing != null
          ? (existing['usage_limit'] ?? '50').toString()
          : '50',
    );
    final TextEditingController perUserCtrl = TextEditingController(
      text: existing != null
          ? (existing['per_user_limit'] ?? '1').toString()
          : '1',
    );
    final TextEditingController validFromCtrl = TextEditingController(
      text: _formatDateTimeField(validFromDt),
    );
    final TextEditingController validToCtrl = TextEditingController(
      text: _formatDateTimeField(validToDt),
    );
    final TextEditingController descCtrl = TextEditingController(
      text: existing != null
          ? (existing['description'] ??
                  'Special promotion for our valuable store customers')
              .toString()
          : (presetDesc ??
              'Special promotion for our valuable store customers'),
    );

    String targetAudience =
        presetAudience ?? _resolveAudienceChoiceValue(existing);
    if (!_audienceChoices.any((a) => a['id'] == targetAudience)) {
      targetAudience = 'all';
    }

    String discountType = existing != null
        ? (existing['discount_type'] ?? 'percentage').toString()
        : (presetDiscountType ?? 'percentage');
    if (!['percentage', 'fixed', 'free_shipping'].contains(discountType)) {
      discountType = 'percentage';
    }

    String couponStatus = existing != null
        ? (existing['status'] ?? 'active').toString().toLowerCase()
        : 'active';
    if (!['active', 'paused', 'draft'].contains(couponStatus)) {
      couponStatus = 'active';
    }

    bool saving = false;
    String? modalError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double screenW = MediaQuery.of(ctx).size.width;
            final double modalW = screenW > 700
                ? 560
                : (screenW > 500 ? screenW * 0.94 : screenW - 20);
            final bool twoCol = modalW >= 460;

            Future pickDateTime({required bool isFrom}) async {
              final DateTime initDt = isFrom ? validFromDt : validToDt;
              final DateTime? pickedDate = await showDatePicker(
                context: ctx,
                initialDate: initDt,
                firstDate: DateTime(2024),
                lastDate: DateTime(2035),
              );
              if (pickedDate == null || !ctx.mounted) return;
              final TimeOfDay? pickedTime = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay.fromDateTime(initDt),
              );
              final DateTime combined = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime?.hour ?? initDt.hour,
                pickedTime?.minute ?? initDt.minute,
              );
              setModalState(() {
                if (isFrom) {
                  validFromDt = combined;
                  validFromCtrl.text = _formatDateTimeField(validFromDt);
                  if (!validToDt.isAfter(validFromDt)) {
                    validToDt = validFromDt.add(const Duration(days: 7));
                    validToCtrl.text = _formatDateTimeField(validToDt);
                  }
                } else {
                  validToDt = combined;
                  validToCtrl.text = _formatDateTimeField(validToDt);
                }
              });
            }

            final String valueLabel = discountType == 'percentage'
                ? 'Value (%) *'
                : (discountType == 'fixed' ? 'Value (৳) *' : 'Value');

            return Dialog(
              backgroundColor: MarketingUi.modalBg(t),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: MarketingUi.fieldBorder(t), width: 1.5),
              ),
              child: Container(
                width: modalW,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modal Title Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.confirmation_number_outlined,
                                color: Color(0xFF10B981),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                existing != null
                                    ? 'Edit Coupon'
                                    : 'Create New Coupon',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: MarketingUi.textColor(t),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: MarketingUi.textColor(t),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      Divider(color: MarketingUi.fieldBorder(t), height: 18),

                      if (modalError != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            modalError!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],

                      // Row 1: Coupon Code * & Campaign Name *
                      if (twoCol)
                        Row(
                          children: [
                            Expanded(
                              child: MarketingUi.textField(
                                t: t,
                                label: 'Coupon Code *',
                                controller: codeCtrl,
                                hint: 'e.g. EID28',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MarketingUi.textField(
                                t: t,
                                label: 'Campaign Name *',
                                controller: nameCtrl,
                                hint: 'Special Discount Offer',
                              ),
                            ),
                          ],
                        )
                      else ...[
                        MarketingUi.textField(
                          t: t,
                          label: 'Coupon Code *',
                          controller: codeCtrl,
                          hint: 'e.g. EID28',
                        ),
                        const SizedBox(height: 12),
                        MarketingUi.textField(
                          t: t,
                          label: 'Campaign Name *',
                          controller: nameCtrl,
                          hint: 'Special Discount Offer',
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Row 2: Highlighted Target Audience Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MarketingUi.sectionBg(t),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 15,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Target Audience (Who is this coupon for?)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: MarketingUi.labelColor(t),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MarketingUi.dropdownField(
                              t: t,
                              label: '',
                              value: targetAudience,
                              items: _audienceChoices,
                              onChanged: (v) {
                                if (v != null) {
                                  setModalState(
                                    () => targetAudience = v.toString(),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Row 3: Discount Type & Value (%) / Value (৳)
                      if (twoCol)
                        Row(
                          children: [
                            Expanded(
                              child: MarketingUi.dropdownField(
                                t: t,
                                label: 'Discount Type',
                                value: discountType,
                                items: const [
                                  {
                                    'id': 'percentage',
                                    'name': 'Percentage (%)'
                                  },
                                  {'id': 'fixed', 'name': 'Fixed Amount (৳)'},
                                  {
                                    'id': 'free_shipping',
                                    'name': 'Free Shipping'
                                  },
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() {
                                      discountType = v.toString();
                                      if (discountType == 'free_shipping') {
                                        valCtrl.text = '0';
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MarketingUi.textField(
                                t: t,
                                label: valueLabel,
                                controller: valCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                hint: '15',
                              ),
                            ),
                          ],
                        )
                      else ...[
                        MarketingUi.dropdownField(
                          t: t,
                          label: 'Discount Type',
                          value: discountType,
                          items: const [
                            {'id': 'percentage', 'name': 'Percentage (%)'},
                            {'id': 'fixed', 'name': 'Fixed Amount (৳)'},
                            {'id': 'free_shipping', 'name': 'Free Shipping'},
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() {
                                discountType = v.toString();
                                if (discountType == 'free_shipping') {
                                  valCtrl.text = '0';
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        MarketingUi.textField(
                          t: t,
                          label: valueLabel,
                          controller: valCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          hint: '15',
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Row 4: Min Order Amount (৳) & Max Discount Cap (৳)
                      Row(
                        children: [
                          Expanded(
                            child: MarketingUi.textField(
                              t: t,
                              label: 'Min Order Amount (৳)',
                              controller: minOrderCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              hint: '500',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MarketingUi.textField(
                              t: t,
                              label: 'Max Discount Cap (৳)',
                              controller: maxDiscCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              hint: '300',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Row 5: Usage Limit (Total) & Per Customer Limit
                      Row(
                        children: [
                          Expanded(
                            child: MarketingUi.textField(
                              t: t,
                              label: 'Usage Limit (Total)',
                              controller: limitCtrl,
                              keyboardType: TextInputType.number,
                              hint: '50',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MarketingUi.textField(
                              t: t,
                              label: 'Per Customer Limit',
                              controller: perUserCtrl,
                              keyboardType: TextInputType.number,
                              hint: '1',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Row 6: Valid From & Valid To (Expiry)
                      if (twoCol)
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => pickDateTime(isFrom: true),
                                child: AbsorbPointer(
                                  child: MarketingUi.textField(
                                    t: t,
                                    label: 'Valid From',
                                    controller: validFromCtrl,
                                    hint: 'MM/DD/YYYY, hh:mm AM',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => pickDateTime(isFrom: false),
                                child: AbsorbPointer(
                                  child: MarketingUi.textField(
                                    t: t,
                                    label: 'Valid To (Expiry)',
                                    controller: validToCtrl,
                                    hint: 'MM/DD/YYYY, hh:mm AM',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        GestureDetector(
                          onTap: () => pickDateTime(isFrom: true),
                          child: AbsorbPointer(
                            child: MarketingUi.textField(
                              t: t,
                              label: 'Valid From',
                              controller: validFromCtrl,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => pickDateTime(isFrom: false),
                          child: AbsorbPointer(
                            child: MarketingUi.textField(
                              t: t,
                              label: 'Valid To (Expiry)',
                              controller: validToCtrl,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Row 7: Status Dropdown
                      MarketingUi.dropdownField(
                        t: t,
                        label: 'Status',
                        value: couponStatus,
                        items: const [
                          {'id': 'active', 'name': 'Active'},
                          {'id': 'paused', 'name': 'Paused'},
                          {'id': 'draft', 'name': 'Draft'},
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => couponStatus = v.toString());
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Row 8: Description (Optional)
                      MarketingUi.textField(
                        t: t,
                        label: 'Description (Optional)',
                        controller: descCtrl,
                        maxLines: 2,
                        hint:
                            'Special promotion for our valuable store customers',
                      ),
                      const SizedBox(height: 18),

                      // Bottom Cancel & Create Coupon Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MarketingUi.textColor(t),
                                side: BorderSide(
                                  color: MarketingUi.fieldBorder(t),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final String cleanCode = codeCtrl.text
                                          .trim()
                                          .toUpperCase();
                                      final String cleanName =
                                          nameCtrl.text.trim().isEmpty
                                              ? 'Special Discount Offer'
                                              : nameCtrl.text.trim();
                                      if (cleanCode.isEmpty) {
                                        setModalState(() {
                                          modalError =
                                              'অনুগ্রহ করে একটি Coupon Code দিন।';
                                        });
                                        return;
                                      }

                                      setModalState(() {
                                        saving = true;
                                        modalError = null;
                                      });

                                      if (!validToDt.isAfter(validFromDt)) {
                                        validToDt = validFromDt
                                            .add(const Duration(days: 7));
                                      }

                                      final double discVal = double.tryParse(
                                            valCtrl.text.trim(),
                                          ) ??
                                          0.0;
                                      final double? minOrd = double.tryParse(
                                        minOrderCtrl.text.trim(),
                                      );
                                      final double? maxCap = double.tryParse(
                                        maxDiscCtrl.text.trim(),
                                      );
                                      final int? totalLimit = int.tryParse(
                                        limitCtrl.text.trim(),
                                      );
                                      final int perCustomer = int.tryParse(
                                            perUserCtrl.text.trim(),
                                          ) ??
                                          1;

                                      final bool isNewOnly =
                                          targetAudience == 'new_only';
                                      final List segments =
                                          (targetAudience != 'all' &&
                                                  targetAudience != 'new_only')
                                              ? [targetAudience]
                                              : [];

                                      final Map payload = {
                                        'code': cleanCode,
                                        'name': cleanName,
                                        'description': descCtrl.text.trim(),
                                        'discount_type': discountType,
                                        'discount_value':
                                            discVal.toStringAsFixed(2),
                                        'minimum_order_amount': minOrd != null
                                            ? minOrd.toStringAsFixed(2)
                                            : null,
                                        'max_discount_amount': maxCap != null
                                            ? maxCap.toStringAsFixed(2)
                                            : null,
                                        'usage_limit': totalLimit,
                                        'per_user_limit': perCustomer,
                                        'valid_from': validFromDt
                                            .toUtc()
                                            .toIso8601String(),
                                        'valid_to':
                                            validToDt.toUtc().toIso8601String(),
                                        'status': couponStatus,
                                        'show_on_checkout': true,
                                        'is_public': true,
                                        'new_customers_only': isNewOnly,
                                        'first_order_only': isNewOnly,
                                        'applicable_customer_segments':
                                            segments,
                                      };

                                      final http.Response res =
                                          await _requestApi(
                                        method: existing != null
                                            ? 'PATCH'
                                            : 'POST',
                                        path: existing != null
                                            ? '/api/v1/coupons/${existing['id']}/'
                                            : '/api/v1/coupons/',
                                        body: payload,
                                      );

                                      if (res.statusCode == 200 ||
                                          res.statusCode == 201) {
                                        if (ctx.mounted) {
                                          Navigator.of(ctx).pop();
                                        }
                                        if (mounted) {
                                          MarketingUi.showToast(
                                            context,
                                            t,
                                            existing != null
                                                ? 'কুপন "$cleanCode" সফলভাবে আপডেট হয়েছে!'
                                                : 'নতুন কুপন "$cleanCode" সফলভাবে তৈরি হয়েছে!',
                                          );
                                        }
                                        await _fetchCoupons();
                                        final dynamic curW = widget;
                                        if (curW.onDataChanged != null) {
                                          curW.onDataChanged();
                                        }
                                      } else {
                                        setModalState(() {
                                          saving = false;
                                          modalError =
                                              'Error (${res.statusCode}): ${res.body}';
                                        });
                                      }
                                    },
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                saving
                                    ? 'Creating...'
                                    : (existing != null
                                        ? 'Save Changes'
                                        : 'Create Coupon'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;

    final int totalCoupons = _coupons.length;
    final int activeNow = _coupons
        .where((c) => c is Map && _effectiveStatus(c) == 'active')
        .length;
    final int expiredCount = _coupons
        .where((c) => c is Map && _effectiveStatus(c) == 'expired')
        .length;
    int totalRedemptions = 0;
    for (int i = 0; _coupons.length > i; i++) {
      final dynamic raw = _coupons[i];
      if (raw is Map) {
        totalRedemptions +=
            int.tryParse((raw['used_count'] ?? 0).toString()) ?? 0;
      }
    }

    final String q = _searchCtrl.text.trim().toLowerCase();
    final List filtered = _coupons.where((raw) {
      if (raw is! Map) return false;
      final String effStatus = _effectiveStatus(raw);
      final bool matchStatus = _statusTab == 'all' || effStatus == _statusTab;
      final bool matchType = _typeFilter == 'all' ||
          (raw['discount_type'] ?? 'percentage').toString() == _typeFilter;
      final bool matchSearch = q.isEmpty ||
          (raw['code'] ?? '').toString().toLowerCase().contains(q) ||
          (raw['name'] ?? '').toString().toLowerCase().contains(q) ||
          (raw['description'] ?? '').toString().toLowerCase().contains(q);
      return matchStatus && matchType && matchSearch;
    }).toList();

    final int totalPages = filtered.isEmpty
        ? 1
        : ((filtered.length + _itemsPerPage - 1) ~/ _itemsPerPage);
    if (_currentPage > totalPages) _currentPage = totalPages;
    final int startIdx = (_currentPage - 1) * _itemsPerPage;
    final int endIdx = (startIdx + _itemsPerPage) > filtered.length
        ? filtered.length
        : (startIdx + _itemsPerPage);
    final List paginated =
        filtered.isEmpty ? [] : filtered.sublist(startIdx, endIdx);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final bool twoColAi = maxW >= 720;
        final bool showTable = maxW >= 820;

        Widget buildAiRetentionCard() {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE11D48).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFF43F5E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11D48),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AI RETENTION',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            'Win-Back Promo for At-Risk Buyers',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: MarketingUi.textColor(t),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Target at-risk customers with a 20% reactivation discount.',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _openCouponModal(
                    t,
                    presetCode: _generateRandomCode('WIN20'),
                    presetName: 'Win-Back Promo for At-Risk Buyers',
                    presetAudience: 'At Risk',
                    presetDiscountType: 'percentage',
                    presetValue: '20',
                    presetDesc:
                        'Target at-risk customers with a 20% reactivation discount.',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Create Offer',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildAiClearanceCard() {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF9333EA).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF9333EA).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9333EA).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFFA855F7),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9333EA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AI CLEARANCE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            'Overstock Inventory Flash Sale',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: MarketingUi.textColor(t),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Clear slow-moving inventory with a 25% surplus liquidation discount.',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _openCouponModal(
                    t,
                    presetCode: _generateRandomCode('FLASH25'),
                    presetName: 'Overstock Inventory Flash Sale',
                    presetAudience: 'all',
                    presetDiscountType: 'percentage',
                    presetValue: '25',
                    presetDesc:
                        'Clear slow-moving inventory with a 25% surplus liquidation discount.',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9333EA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Create Offer',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top 2 AI Campaign Quick Action Cards
            if (twoColAi)
              Row(
                children: [
                  Expanded(child: buildAiRetentionCard()),
                  const SizedBox(width: 12),
                  Expanded(child: buildAiClearanceCard()),
                ],
              )
            else ...[
              buildAiRetentionCard(),
              const SizedBox(height: 10),
              buildAiClearanceCard(),
            ],
            const SizedBox(height: 14),

            // 2. 4 KPI Cards Row (TOTAL COUPONS, ACTIVE NOW, EXPIRED, TOTAL REDEMPTIONS)
            MarketingUi.buildKpiGrid4(
              maxW,
              MarketingUi.kpiCard(
                t: t,
                label: 'TOTAL COUPONS',
                value: '$totalCoupons',
                subtext: 'All Storefront Vouchers',
                icon: Icons.confirmation_number_outlined,
                accentColor: const Color(0xFF10B981),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: 'ACTIVE NOW',
                value: '$activeNow',
                subtext: 'Live on Checkout',
                icon: Icons.check_circle_outline_rounded,
                accentColor: const Color(0xFF10B981),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: 'EXPIRED',
                value: '$expiredCount',
                subtext: 'Past Validity Window',
                icon: Icons.schedule_rounded,
                accentColor: const Color(0xFFF43F5E),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: 'TOTAL REDEMPTIONS',
                value: '$totalRedemptions',
                subtext: 'Total Orders Redeemed',
                icon: Icons.monetization_on_outlined,
                accentColor: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Status Filter Tabs + Generate Excel / Generate PDF / + Create Coupon
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Status Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      {'id': 'all', 'label': 'All Coupons'},
                      {'id': 'active', 'label': 'Active'},
                      {'id': 'expired', 'label': 'Expired'},
                      {'id': 'paused', 'label': 'Paused'},
                      {'id': 'draft', 'label': 'Draft'},
                    ].map((tab) {
                      final String id = tab['id'].toString();
                      final bool sel = _statusTab == id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() {
                            _statusTab = id;
                            _currentPage = 1;
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF10B981)
                                  : t.cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF10B981)
                                    : MarketingUi.fieldBorder(t),
                              ),
                            ),
                            child: Text(
                              tab['label'].toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: sel
                                    ? Colors.white
                                    : MarketingUi.textColor(t),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Right Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _exportCsv(filtered),
                      icon: const Icon(
                        Icons.table_chart_outlined,
                        size: 15,
                        color: Color(0xFF10B981),
                      ),
                      label: const Text(
                        'Generate Excel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPdfReportDialog(t, filtered),
                      icon: const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 15,
                        color: Color(0xFFF43F5E),
                      ),
                      label: const Text(
                        'Generate PDF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF43F5E),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openCouponModal(t),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(
                        '+ Create Coupon',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Search & Discount Type Filter Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.cardBorder),
              ),
              child: maxW >= 580
                  ? Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: MarketingUi.textField(
                            t: t,
                            label: '',
                            controller: _searchCtrl,
                            hint:
                                'Search voucher code, campaign name or description...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: t.secondaryText,
                            ),
                            onChanged: (_) => setState(() => _currentPage = 1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: MarketingUi.dropdownField(
                            t: t,
                            label: '',
                            value: _typeFilter,
                            items: const [
                              {'id': 'all', 'name': 'All Discount Types'},
                              {'id': 'percentage', 'name': 'Percentage (%)'},
                              {'id': 'fixed', 'name': 'Fixed Amount (৳)'},
                              {'id': 'free_shipping', 'name': 'Free Shipping'},
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _typeFilter = v.toString();
                                  _currentPage = 1;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        MarketingUi.textField(
                          t: t,
                          label: '',
                          controller: _searchCtrl,
                          hint:
                              'Search voucher code, campaign name or description...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: t.secondaryText,
                          ),
                          onChanged: (_) => setState(() => _currentPage = 1),
                        ),
                        const SizedBox(height: 8),
                        MarketingUi.dropdownField(
                          t: t,
                          label: '',
                          value: _typeFilter,
                          items: const [
                            {'id': 'all', 'name': 'All Discount Types'},
                            {'id': 'percentage', 'name': 'Percentage (%)'},
                            {'id': 'fixed', 'name': 'Fixed Amount (৳)'},
                            {'id': 'free_shipping', 'name': 'Free Shipping'},
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _typeFilter = v.toString();
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),

            // 5. Coupons Table (Desktop/Tablet) or Cards (Mobile)
            Container(
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.cardBorder),
              ),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      child: Center(
                        child: CircularProgressIndicator(color: t.primaryColor),
                      ),
                    )
                  : paginated.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 45),
                          child: Center(
                            child: Text(
                              'No coupons found.',
                              style: TextStyle(
                                color: t.secondaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            if (showTable) ...[
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: MarketingUi.sectionBg(t),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: MarketingUi.fieldBorder(t),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'COUPON CODE & NAME',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'DISCOUNT',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'MINIMUM ORDER',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'TARGET AUDIENCE',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'USAGE',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'VALIDITY',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'STATUS',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        'ACTIONS',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Table Rows
                              ...paginated.map((raw) {
                                final Map c = raw is Map ? raw : {};
                                final String code =
                                    (c['code'] ?? '').toString();
                                final String name =
                                    (c['name'] ?? 'Special Discount Offer')
                                        .toString();
                                final String desc =
                                    (c['description'] ?? '').toString();
                                final String dType =
                                    (c['discount_type'] ?? 'percentage')
                                        .toString();
                                final String dVal =
                                    _cleanNum(c['discount_value']);
                                final String maxCap =
                                    _cleanNum(c['max_discount_amount'], '');
                                final String minOrd =
                                    _cleanNum(c['minimum_order_amount'], '');
                                final String effStatus = _effectiveStatus(c);
                                final bool isActive = effStatus == 'active';

                                String discText = '৳$dVal OFF';
                                if (dType == 'percentage') {
                                  discText = '$dVal% OFF';
                                } else if (dType == 'free_shipping') {
                                  discText = 'FREE SHIPPING';
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: MarketingUi.fieldBorder(t)
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // 1. Code & Name
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                            0xFF10B981)
                                                        .withValues(alpha: 0.14),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                      color: const Color(
                                                              0xFF10B981)
                                                          .withValues(
                                                              alpha: 0.4),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    code,
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontFamily: 'monospace',
                                                      color: Color(0xFF10B981),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                InkWell(
                                                  onTap: () {
                                                    Clipboard.setData(
                                                      ClipboardData(text: code),
                                                    );
                                                    MarketingUi.showToast(
                                                      context,
                                                      t,
                                                      'Copied "$code"!',
                                                    );
                                                  },
                                                  child: Icon(
                                                    Icons.copy_rounded,
                                                    size: 14,
                                                    color: t.secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: MarketingUi.textColor(t),
                                              ),
                                            ),
                                            if (desc.isNotEmpty)
                                              Text(
                                                desc,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: t.secondaryText,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // 2. Discount
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              discText,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w900,
                                                fontFamily: 'monospace',
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                            if (dType == 'percentage' &&
                                                maxCap.isNotEmpty &&
                                                maxCap != '0')
                                              Text(
                                                'Max: ৳$maxCap',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: t.secondaryText,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // 3. Minimum Order
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          minOrd.isNotEmpty && minOrd != '0'
                                              ? '৳$minOrd'
                                              : 'No Min',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'monospace',
                                            color: MarketingUi.textColor(t),
                                          ),
                                        ),
                                      ),

                                      // 4. Target Audience
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _resolveAudienceLabel(c),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: t.secondaryText,
                                          ),
                                        ),
                                      ),

                                      // 5. Usage
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${c['used_count'] ?? 0} / ${c['usage_limit'] ?? '∞'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'monospace',
                                            color: MarketingUi.textColor(t),
                                          ),
                                        ),
                                      ),

                                      // 6. Validity
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatDisplayDateShort(
                                                c['valid_to'],
                                              ),
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: MarketingUi.textColor(t),
                                              ),
                                            ),
                                            Text(
                                              'From: ${_formatDisplayDateShort(c['valid_from'], includeYear: false)}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: t.secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 7. Status Pill
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? const Color(0xFF10B981)
                                                      .withValues(alpha: 0.14)
                                                  : const Color(0xFFF59E0B)
                                                      .withValues(alpha: 0.14),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isActive
                                                    ? const Color(0xFF10B981)
                                                        .withValues(alpha: 0.4)
                                                    : const Color(0xFFF59E0B)
                                                        .withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Text(
                                              '⊙ ${effStatus.toUpperCase()}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: isActive
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 8. Actions (Power, Edit, Delete)
                                      SizedBox(
                                        width: 110,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  _toggleCouponPower(c),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  color:
                                                      MarketingUi.sectionBg(t),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: MarketingUi
                                                        .fieldBorder(t),
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons
                                                      .power_settings_new_rounded,
                                                  size: 14,
                                                  color: isActive
                                                      ? const Color(0xFF10B981)
                                                      : t.secondaryText,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _openCouponModal(
                                                t,
                                                existing: c,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  color:
                                                      MarketingUi.sectionBg(t),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: MarketingUi
                                                        .fieldBorder(t),
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.edit_outlined,
                                                  size: 14,
                                                  color:
                                                      MarketingUi.textColor(t),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _deleteCoupon(c),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(
                                                            0xFFEF4444)
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 14,
                                                  color: Color(0xFFEF4444),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ] else
                              // Mobile & Compact Tablet Responsive Cards
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: MarketingUi.buildResponsiveGrid(
                                  maxWidth: maxW - 24,
                                  items: paginated,
                                  itemBuilder: (raw) {
                                    final Map c = raw is Map ? raw : {};
                                    final String code =
                                        (c['code'] ?? '').toString();
                                    final String name = (c['name'] ??
                                            'Special Discount Offer')
                                        .toString();
                                    final String dType =
                                        (c['discount_type'] ?? 'percentage')
                                            .toString();
                                    final String dVal =
                                        _cleanNum(c['discount_value']);
                                    final String minOrd = _cleanNum(
                                      c['minimum_order_amount'],
                                      '0',
                                    );
                                    final String effStatus =
                                        _effectiveStatus(c);
                                    final bool isActive = effStatus == 'active';

                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: MarketingUi.sectionBg(t),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isActive
                                              ? const Color(0xFF10B981)
                                              : MarketingUi.fieldBorder(t),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  Clipboard.setData(
                                                    ClipboardData(text: code),
                                                  );
                                                  MarketingUi.showToast(
                                                    context,
                                                    t,
                                                    'Copied "$code"!',
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 9,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                            0xFF10B981)
                                                        .withValues(alpha: 0.14),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFF10B981),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        code,
                                                        style: const TextStyle(
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontFamily:
                                                              'monospace',
                                                          color: Color(
                                                              0xFF10B981),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      const Icon(
                                                        Icons.copy_rounded,
                                                        size: 12,
                                                        color:
                                                            Color(0xFF10B981),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                dType == 'percentage'
                                                    ? '$dVal% OFF'
                                                    : '৳$dVal OFF',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: MarketingUi.textColor(t),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Min: ৳$minOrd • Audience: ${_resolveAudienceLabel(c)} • Usage: ${c['used_count'] ?? 0}/${c['usage_limit'] ?? '∞'}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: t.secondaryText,
                                            ),
                                          ),
                                          Text(
                                            'Valid: ${_formatDisplayDateShort(c['valid_from'], includeYear: false)} → ${_formatDisplayDateShort(c['valid_to'])}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: t.secondaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isActive
                                                      ? const Color(0xFF10B981)
                                                          .withValues(
                                                              alpha: 0.14)
                                                      : t.cardBg,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '⊙ ${effStatus.toUpperCase()}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: isActive
                                                        ? const Color(
                                                            0xFF10B981)
                                                        : t.secondaryText,
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    onPressed: () =>
                                                        _toggleCouponPower(c),
                                                    icon: Icon(
                                                      Icons
                                                          .power_settings_new_rounded,
                                                      size: 18,
                                                      color: isActive
                                                          ? const Color(
                                                              0xFF10B981)
                                                          : t.secondaryText,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () =>
                                                        _openCouponModal(
                                                      t,
                                                      existing: c,
                                                    ),
                                                    icon: Icon(
                                                      Icons.edit_outlined,
                                                      size: 18,
                                                      color: MarketingUi
                                                          .textColor(t),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () =>
                                                        _deleteCoupon(c),
                                                    icon: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 18,
                                                      color: Color(0xFFEF4444),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                            // Pagination Bar
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Showing ${startIdx + 1} to $endIdx of ${filtered.length} coupons',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: t.secondaryText,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _currentPage > 1
                                            ? () => setState(
                                                  () => _currentPage -= 1,
                                                )
                                            : null,
                                        icon: Icon(
                                          Icons.chevron_left_rounded,
                                          color: MarketingUi.textColor(t),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$_currentPage',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: totalPages > _currentPage
                                            ? () => setState(
                                                  () => _currentPage += 1,
                                                )
                                            : null,
                                        icon: Icon(
                                          Icons.chevron_right_rounded,
                                          color: MarketingUi.textColor(t),
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
          ],
        );
      },
    );
  }
}