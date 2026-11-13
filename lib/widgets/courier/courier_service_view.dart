// lib/widgets/courier/courier_service_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../catalog/catalog_theme_scope.dart';

class CourierServiceView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab; // 'setup', 'booking', 'tracking', 'settlement'
  final VoidCallback? onDataChanged;

  const CourierServiceView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'setup',
    this.onDataChanged,
  });

  @override
  State<CourierServiceView> createState() => _CourierServiceViewState();
}

class _CourierServiceViewState extends State<CourierServiceView> {
  String _activeTab = 'setup';
  bool _isLoading = true;
  bool _isSavingConfig = false;
  bool _isBookingOrder = false;

  CatalogThemeConfig _theme = const CatalogThemeConfig();

  String _apiBase = 'https://nextlook.shop.xylotechsolution.com';
  String _subdomain = 'buynarabd';
  String _token = '';

  // 1. Courier Provider Configs State
  List _configs = [];
  String _selectedProviderCode = 'steadfast';
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _secretKeyCtrl = TextEditingController();
  final TextEditingController _accessTokenCtrl = TextEditingController();
  final TextEditingController _storeIdCtrl = TextEditingController();
  final TextEditingController _clientIdCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _cfgIsActive = true;
  bool _cfgIsDefault = true;
  bool _cfgAutoSendSms = true;
  final bool _obscureSecret = true;

  // 2. Order Booking State
  List _orders = [];
  Map _bookedMap = {};
  String _bookingCourierProvider = 'steadfast';
  final Set _selectedOrderNumbersForBulk = {};
  String _orderSearchQuery = '';
  String _orderFilterMode = 'unbooked'; // 'unbooked', 'all', 'booked'

  // Manual / Custom Quick Parcel Booking Controllers
  final TextEditingController _manualOrderNumCtrl = TextEditingController();
  final TextEditingController _manualCustNameCtrl = TextEditingController();
  final TextEditingController _manualCustPhoneCtrl = TextEditingController();
  final TextEditingController _manualAddressCtrl = TextEditingController();
  final TextEditingController _manualCodCtrl = TextEditingController();
  final TextEditingController _manualNoteCtrl = TextEditingController();

  // 3. Consignments & Live Tracking State
  List _consignments = [];
  Map _summary = {
    'total_parcels': 0,
    'in_transit_count': 0,
    'delivered_count': 0,
    'returned_count': 0,
    'cod_in_transit': 0.0,
    'cod_delivered_settled': 0.0,
  };
  String _trackingStatusFilter = 'all';
  String _trackingSearchQuery = '';
  int? _updatingConsignmentId;

  // 4. Fraud Shield Quick Check State
  final TextEditingController _fraudPhoneCtrl = TextEditingController();
  Map? _fraudResult;
  bool _isCheckingFraud = false;

  @override
  void initState() {
    super.initState();
    _activeTab = _normalizeTab(widget.initialTab);
    _initAndLoad();
  }

  @override
  void didUpdateWidget(covariant CourierServiceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTab = _normalizeTab(widget.initialTab);
    if (oldWidget.initialTab != widget.initialTab && nextTab != _activeTab) {
      setState(() => _activeTab = nextTab);
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _loadTheme();
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _secretKeyCtrl.dispose();
    _accessTokenCtrl.dispose();
    _storeIdCtrl.dispose();
    _clientIdCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _manualOrderNumCtrl.dispose();
    _manualCustNameCtrl.dispose();
    _manualCustPhoneCtrl.dispose();
    _manualAddressCtrl.dispose();
    _manualCodCtrl.dispose();
    _manualNoteCtrl.dispose();
    _fraudPhoneCtrl.dispose();
    super.dispose();
  }

  String _normalizeTab(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('book')) return 'booking';
    if (lower.contains('track')) return 'tracking';
    if (lower.contains('settle') || lower.contains('cod')) return 'settlement';
    return 'setup';
  }

  Future _loadTheme() async {
    final cfg = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = cfg);
    }
  }

  Map<String, String> _headers({bool jsonContent = false}) {
    final map = <String, String>{
      'Accept': 'application/json',
      'X-Tenant-Subdomain': _subdomain,
      'x-subdomain': _subdomain,
      'X-Tenant-Domain': _subdomain,
    };
    if (jsonContent) {
      map['Content-Type'] = 'application/json';
    }
    if (_token.isNotEmpty) {
      map['Authorization'] = 'Bearer $_token';
    }
    return map;
  }

  Future _initAndLoad() async {
    await _loadTheme();
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('merchant_token') ?? '';
    _subdomain = prefs.getString('active_subdomain') ?? 'buynarabd';
    String base = prefs.getString('api_base_url') ?? 'https://nextlook.shop.xylotechsolution.com';
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    _apiBase = base;

    await _fetchAllCourierData();
  }

  Future _fetchAllCourierData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/courier/configs/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/courier/consignments/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
              Uri.parse('$_apiBase/api/v1/orders/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('[]', 500)),
      ]);

      // 1. Parse Provider Configs
      if (results[0].statusCode == 200) {
        final dec = jsonDecode(utf8.decode(results[0].bodyBytes));
        if (dec is List) {
          _configs = dec;
        }
        _populateProviderForm(_selectedProviderCode);

        final defaultProv = _configs.firstWhere(
          (c) => c is Map && c['is_default'] == true,
          orElse: () => null,
        );
        if (defaultProv is Map && defaultProv['provider'] != null) {
          _bookingCourierProvider = defaultProv['provider'].toString();
        }
      }

      // 2. Parse Consignments & Summary
      if (results[1].statusCode == 200) {
        final cData = jsonDecode(utf8.decode(results[1].bodyBytes));
        if (cData is Map) {
          if (cData['consignments'] is List) {
            _consignments = cData['consignments'];
          }
          if (cData['booked_map'] is Map) {
            _bookedMap = Map.from(cData['booked_map']);
          }
          if (cData['summary'] is Map) {
            _summary = Map.from(cData['summary']);
          }
        }
      }

      // 3. Parse Store Orders for Booking
      if (results[2].statusCode == 200) {
        final oData = jsonDecode(utf8.decode(results[2].bodyBytes));
        if (oData is List) {
          _orders = oData;
        } else if (oData is Map && oData['results'] is List) {
          _orders = oData['results'];
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateProviderForm(String providerCode) {
    _selectedProviderCode = providerCode;
    final matched = _configs.firstWhere(
      (c) =>
          c is Map &&
          (c['provider'] ?? '').toString().toLowerCase() == providerCode,
      orElse: () => null,
    );

    if (matched is Map) {
      _apiKeyCtrl.text = (matched['api_key'] ?? '').toString();
      _secretKeyCtrl.text = (matched['secret_key'] ?? '').toString();
      _accessTokenCtrl.text = (matched['access_token'] ?? '').toString();
      _storeIdCtrl.text = (matched['store_id'] ?? '').toString();
      _clientIdCtrl.text = (matched['client_id'] ?? '').toString();
      _usernameCtrl.text = (matched['username'] ?? '').toString();
      _passwordCtrl.text = (matched['password'] ?? '').toString();
      _cfgIsActive = matched['is_active'] != false;
      _cfgIsDefault = matched['is_default'] == true;
      _cfgAutoSendSms = matched['auto_send_sms'] != false;
    } else {
      _apiKeyCtrl.clear();
      _secretKeyCtrl.clear();
      _accessTokenCtrl.clear();
      _storeIdCtrl.clear();
      _clientIdCtrl.clear();
      _usernameCtrl.clear();
      _passwordCtrl.clear();
      _cfgIsActive = true;
      _cfgIsDefault = providerCode == 'steadfast';
      _cfgAutoSendSms = true;
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _extractOrderCustomerName(Map ord) {
    if (ord['customer_name'] != null &&
        ord['customer_name'].toString().trim().isNotEmpty) {
      return ord['customer_name'].toString().trim();
    }
    if (ord['shipping_address'] is Map) {
      final s = ord['shipping_address'] as Map;
      final n = s['name'] ?? s['fullName'] ?? s['full_name'];
      if (n != null && n.toString().trim().isNotEmpty) {
        return n.toString().trim();
      }
    }
    if (ord['customer'] is Map) {
      final c = ord['customer'] as Map;
      final full = '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();
      if (full.isNotEmpty) return full;
    }
    return 'Customer';
  }

  String _extractOrderCustomerPhone(Map ord) {
    if (ord['customer_phone'] != null &&
        ord['customer_phone'].toString().trim().isNotEmpty) {
      return ord['customer_phone'].toString().trim();
    }
    if (ord['shipping_address'] is Map) {
      final s = ord['shipping_address'] as Map;
      final p = s['phone'] ?? s['phoneNumber'] ?? s['mobile'];
      if (p != null && p.toString().trim().isNotEmpty) {
        return p.toString().trim();
      }
    }
    if (ord['customer'] is Map) {
      final c = ord['customer'] as Map;
      if (c['phone'] != null) return c['phone'].toString();
    }
    return '01700000000';
  }

  String _extractOrderAddress(Map ord) {
    if (ord['shipping_address'] is Map) {
      final s = ord['shipping_address'] as Map;
      final addr = (s['address'] ?? s['street_address'] ?? '').toString();
      final city = (s['city'] ?? '').toString();
      final combined = '$addr${city.isNotEmpty ? ", $city" : ""}'.trim();
      if (combined.isNotEmpty) return combined;
    } else if (ord['shipping_address'] is String &&
        ord['shipping_address'].toString().trim().isNotEmpty) {
      return ord['shipping_address'].toString().trim();
    }
    return 'Dhaka, Bangladesh';
  }

  double _extractOrderAmount(Map ord) {
    final raw = ord['total'] ??
        ord['total_amount'] ??
        ord['grand_total'] ??
        ord['amount'] ??
        0;
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  String _extractOrderNumber(Map ord) {
    final numStr = (ord['order_number'] ?? '').toString().trim();
    if (numStr.isNotEmpty) return numStr.replaceFirst('#', '');
    return 'ORD-${ord['id'] ?? ''}';
  }

  // =========================================================================
  // 1. SAVE COURIER CONFIG ACTION
  // =========================================================================
  Future _saveCourierConfig() async {
    setState(() => _isSavingConfig = true);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/courier/configs/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'provider': _selectedProviderCode,
          'api_key': _apiKeyCtrl.text.trim(),
          'secret_key': _secretKeyCtrl.text.trim(),
          'access_token': _accessTokenCtrl.text.trim(),
          'store_id': _storeIdCtrl.text.trim(),
          'client_id': _clientIdCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text.trim(),
          'is_active': _cfgIsActive,
          'is_default': _cfgIsDefault,
          'auto_send_sms': _cfgAutoSendSms,
        }),
      );

      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _showSnack((dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'কুরিয়ার কনফিগারেশন সফলভাবে সেভ হয়েছে!');
        await _fetchAllCourierData(silent: true);
      } else {
        _showSnack('কনফিগারেশন সেভ করতে সমস্যা হয়েছে।', isError: true);
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  // =========================================================================
  // 2. BOOK SINGLE OR BULK ORDERS TO COURIER
  // =========================================================================
  Future _bookSingleOrder(Map ord) async {
    final ordNum = _extractOrderNumber(ord);
    setState(() => _isBookingOrder = true);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/courier/book-order/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'provider': _bookingCourierProvider,
          'order_number': ordNum,
          'customer_name': _extractOrderCustomerName(ord),
          'customer_phone': _extractOrderCustomerPhone(ord),
          'delivery_address': _extractOrderAddress(ord),
          'cod_amount': _extractOrderAmount(ord),
        }),
      );

      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201 || res.statusCode == 200) {
        _showSnack((dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'অর্ডার #$ordNum সফলভাবে কুরিয়ারে বুকিং হয়েছে!');
        await _fetchAllCourierData(silent: true);
        widget.onDataChanged?.call();
      } else {
        _showSnack(
          (dec is Map && dec['detail'] != null)
              ? dec['detail'].toString()
              : 'বুকিং ব্যর্থ হয়েছে।',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBookingOrder = false);
    }
  }

  Future _bookSelectedBulkOrders() async {
    if (_selectedOrderNumbersForBulk.isEmpty) {
      _showSnack('বাল্ক বুকিংয়ের জন্য অন্তত ১টি অর্ডার সিলেক্ট করুন।',
          isError: true);
      return;
    }

    setState(() => _isBookingOrder = true);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/courier/book-order/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'provider': _bookingCourierProvider,
          'order_numbers':
              _selectedOrderNumbersForBulk.map((e) => e.toString()).toList(),
        }),
      );

      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201 || res.statusCode == 200) {
        _selectedOrderNumbersForBulk.clear();
        _showSnack((dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'নির্বাচিত অর্ডারগুলো সফলভাবে কুরিয়ারে বুকিং হয়েছে!');
        await _fetchAllCourierData(silent: true);
        widget.onDataChanged?.call();
      } else {
        _showSnack(
          (dec is Map && dec['detail'] != null)
              ? dec['detail'].toString()
              : 'বাল্ক বুকিং ব্যর্থ হয়েছে।',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBookingOrder = false);
    }
  }

  Future _bookManualParcel() async {
    final name = _manualCustNameCtrl.text.trim();
    final phone = _manualCustPhoneCtrl.text.trim();
    final addr = _manualAddressCtrl.text.trim();
    final cod = double.tryParse(_manualCodCtrl.text.trim()) ?? 0.0;
    final ordNum = _manualOrderNumCtrl.text.trim().isNotEmpty
        ? _manualOrderNumCtrl.text.trim()
        : 'MNL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    if (name.isEmpty || phone.isEmpty) {
      _showSnack('কাস্টমারের নাম এবং মোবাইল নম্বর লিখুন।', isError: true);
      return;
    }

    setState(() => _isBookingOrder = true);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/courier/book-order/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'provider': _bookingCourierProvider,
          'order_number': ordNum,
          'customer_name': name,
          'customer_phone': phone,
          'delivery_address': addr.isEmpty ? 'Dhaka, Bangladesh' : addr,
          'cod_amount': cod,
          'note': _manualNoteCtrl.text.trim(),
        }),
      );

      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201 || res.statusCode == 200) {
        _manualOrderNumCtrl.clear();
        _manualCustNameCtrl.clear();
        _manualCustPhoneCtrl.clear();
        _manualAddressCtrl.clear();
        _manualCodCtrl.clear();
        _manualNoteCtrl.clear();
        _showSnack((dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'ম্যানুয়াল পার্সেল বুকিং সফল হয়েছে!');
        await _fetchAllCourierData(silent: true);
      } else {
        _showSnack('পার্সেল বুকিং ব্যর্থ হয়েছে।', isError: true);
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBookingOrder = false);
    }
  }

  // =========================================================================
  // 3. UPDATE CONSIGNMENT STATUS (DELIVERED / RETURNED + AUTO RESTOCK)
  // =========================================================================
  Future _updateConsignmentStatus(Map consignment, String nextStatus) async {
    final int cId = int.tryParse((consignment['id'] ?? 0).toString()) ?? 0;
    setState(() => _updatingConsignmentId = cId);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/courier/update-status/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'id': cId,
          'order_number': consignment['order_number'],
          'status': nextStatus,
        }),
      );

      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        _showSnack((dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'স্ট্যাটাস আপডেট হয়েছে!');
        await _fetchAllCourierData(silent: true);
        widget.onDataChanged?.call();
      } else {
        _showSnack('স্ট্যাটাস আপডেট ব্যর্থ হয়েছে।', isError: true);
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _updatingConsignmentId = null);
    }
  }

  // =========================================================================
  // 4. CHECK CUSTOMER PHONE FRAUD / DELIVERY SUCCESS RATIO
  // =========================================================================
  Future _checkPhoneFraud([String? phoneOverride]) async {
    final phone = (phoneOverride ?? _fraudPhoneCtrl.text).trim();
    if (phone.isEmpty) {
      _showSnack('চেক করার জন্য কাস্টমারের মোবাইল নম্বর লিখুন।', isError: true);
      return;
    }
    if (phoneOverride != null) {
      _fraudPhoneCtrl.text = phoneOverride;
    }

    setState(() => _isCheckingFraud = true);

    try {
      final res = await http.get(
        Uri.parse(
            '$_apiBase/api/v1/stores/courier/fraud-check/?phone=$phone&subdomain=$_subdomain'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final dec = jsonDecode(utf8.decode(res.bodyBytes));
        if (dec is Map) {
          setState(() => _fraudResult = dec);
        }
      } else {
        _showSnack('ফ্রড রেশিও চেক করা যায়নি।', isError: true);
      }
    } catch (e) {
      _showSnack('ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCheckingFraud = false);
    }
  }

  // =========================================================================
  // MAIN UI BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final t = _theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopHeroBanner(t),
        const SizedBox(height: 14),
        _buildSubTabsBar(t),
        const SizedBox(height: 16),
        if (_isLoading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: t.primaryColor),
          )
        else ...[
          if (_activeTab == 'setup') _buildCourierSetupTab(t),
          if (_activeTab == 'booking') _buildOrderBookingTab(t),
          if (_activeTab == 'tracking') _buildLiveTrackingTab(t),
          if (_activeTab == 'settlement') _buildSettlementAndFraudTab(t),
        ],
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildTopHeroBanner(CatalogThemeConfig t) {
    double steadfastBalance = 0.0;
    for (var c in _configs) {
      if (c is Map && c['provider'] == 'steadfast') {
        steadfastBalance =
            double.tryParse((c['live_balance'] ?? 0).toString()) ?? 0.0;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: t.useGradient ? t.brandGradient : null,
        color: t.useGradient ? null : t.primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: t.primaryColor.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Multi-Courier Dispatch & COD Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Steadfast • Pathao • RedX • Paperfly • Custom Rider • Auto Return Restock',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _fetchAllCourierData(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh Courier Data',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroPill(Icons.inventory_2_rounded,
                  'Parcels: ${_summary['total_parcels'] ?? 0}'),
              _buildHeroPill(Icons.local_shipping_outlined,
                  'In Transit: ${_summary['in_transit_count'] ?? 0}'),
              _buildHeroPill(Icons.check_circle_outline_rounded,
                  'Delivered: ${_summary['delivered_count'] ?? 0}'),
              _buildHeroPill(Icons.account_balance_wallet_outlined,
                  'Steadfast Bal: ৳${steadfastBalance.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabsBar(CatalogThemeConfig t) {
    final List tabs = [
      {
        'id': 'setup',
        'label': 'Courier Setup',
        'icon': Icons.settings_input_component_rounded,
      },
      {
        'id': 'booking',
        'label': 'Order Booking',
        'icon': Icons.send_and_archive_rounded,
      },
      {
        'id': 'tracking',
        'label': 'Live Tracking (${_consignments.length})',
        'icon': Icons.track_changes_rounded,
      },
      {
        'id': 'settlement',
        'label': 'COD Settlement & Fraud',
        'icon': Icons.verified_user_rounded,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final String id = tab['id'].toString();
          final bool selected = _activeTab == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _activeTab = id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: (selected && t.useGradient) ? t.brandGradient : null,
                  color: selected
                      ? (t.useGradient ? null : t.primaryColor)
                      : t.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.transparent : t.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: selected ? Colors.white : t.secondaryText,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tab['label'].toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : t.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // TAB 1: COURIER API SETUP & LIVE BALANCE
  // =========================================================================
  Widget _buildCourierSetupTab(CatalogThemeConfig t) {
    final List providers = [
      {
        'code': 'steadfast',
        'name': 'Steadfast Courier',
        'tag': 'Official Packzy API',
        'color': const Color(0xFF059669),
      },
      {
        'code': 'pathao',
        'name': 'Pathao Courier',
        'tag': 'Hermes Aladdin API',
        'color': const Color(0xFFDC2626),
      },
      {
        'code': 'redx',
        'name': 'RedX Courier',
        'tag': 'OpenAPI Bearer Token',
        'color': const Color(0xFFD97706),
      },
      {
        'code': 'paperfly',
        'name': 'Paperfly / eCourier',
        'tag': 'Nationwide High-Speed',
        'color': const Color(0xFF2563EB),
      },
      {
        'code': 'custom',
        'name': 'Custom / In-House Rider',
        'tag': 'Own Delivery Team',
        'color': const Color(0xFF7C3AED),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Courier Provider to Configure',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: t.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: providers.map((p) {
            final String code = p['code'].toString();
            final bool isSel = _selectedProviderCode == code;
            final Color pColor = p['color'] as Color;
            return InkWell(
              onTap: () => setState(() => _populateProviderForm(code)),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? pColor : t.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel ? pColor : t.cardBorder,
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isSel ? Colors.white : t.primaryText,
                      ),
                    ),
                    Text(
                      p['tag'].toString(),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isSel ? Colors.white70 : t.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Provider Credentials Form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.vpn_key_rounded, color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedProviderCode.toUpperCase()} API Credentials Setup',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'API Key না থাকলে খালি রেখেও Sandbox Mode-এ ১-ক্লিক পার্সেল বুকিং ও ট্র্যাকিং কোড জেনারেট করতে পারবেন।',
                style: TextStyle(fontSize: 11.5, color: t.secondaryText),
              ),
              const SizedBox(height: 14),
              if (_selectedProviderCode == 'steadfast' ||
                  _selectedProviderCode == 'paperfly') ...[
                _buildField(
                  t,
                  label: 'API Key',
                  hint: 'Enter Courier API Key...',
                  controller: _apiKeyCtrl,
                  icon: Icons.key_rounded,
                ),
                const SizedBox(height: 10),
                _buildField(
                  t,
                  label: 'Secret Key',
                  hint: 'Enter Courier Secret Key...',
                  controller: _secretKeyCtrl,
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureSecret,
                ),
              ],
              if (_selectedProviderCode == 'pathao') ...[
                _buildField(
                  t,
                  label: 'Pathao Bearer Access Token / API Key',
                  hint: 'Enter Pathao Access Token...',
                  controller: _accessTokenCtrl,
                  icon: Icons.token_rounded,
                ),
                const SizedBox(height: 10),
                _buildField(
                  t,
                  label: 'Pathao Store ID (Default: 1)',
                  hint: 'e.g., 1',
                  controller: _storeIdCtrl,
                  icon: Icons.store_rounded,
                ),
                const SizedBox(height: 10),
                _buildField(
                  t,
                  label: 'Client ID (Optional)',
                  hint: 'Enter Client ID...',
                  controller: _clientIdCtrl,
                  icon: Icons.badge_rounded,
                ),
              ],
              if (_selectedProviderCode == 'redx') ...[
                _buildField(
                  t,
                  label: 'RedX Bearer Access Token',
                  hint: 'Enter RedX API-ACCESS-TOKEN...',
                  controller: _accessTokenCtrl,
                  icon: Icons.token_rounded,
                ),
              ],
              if (_selectedProviderCode == 'paperfly') ...[
                const SizedBox(height: 10),
                _buildField(
                  t,
                  label: 'Merchant Username (Optional)',
                  hint: 'Paperfly Username',
                  controller: _usernameCtrl,
                  icon: Icons.person_outline_rounded,
                ),
              ],
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Set as Default Courier Provider',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
                value: _cfgIsDefault,
                activeColor: t.primaryColor,
                onChanged: (v) => setState(() => _cfgIsDefault = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Auto Send Tracking SMS to Customer on Booking',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
                subtitle: Text(
                  'কুরিয়ারে বুকিং দিলেই কাস্টমারের মোবাইলে ট্র্যাকিং কোডসহ SMS যাবে।',
                  style: TextStyle(fontSize: 11, color: t.secondaryText),
                ),
                value: _cfgAutoSendSms,
                activeColor: t.primaryColor,
                onChanged: (v) => setState(() => _cfgAutoSendSms = v),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSavingConfig ? null : _saveCourierConfig,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    'Save & Connect ${_selectedProviderCode.toUpperCase()} Courier',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: 1-CLICK SINGLE & BULK ORDER BOOKING
  // =========================================================================
  Widget _buildOrderBookingTab(CatalogThemeConfig t) {
    final List courierCodes = [
      'steadfast',
      'pathao',
      'redx',
      'paperfly',
      'custom'
    ];

    final filteredOrders = _orders.where((raw) {
      if (raw is! Map) return false;
      final ordNum = _extractOrderNumber(raw);
      final isBooked = _bookedMap.containsKey(ordNum);

      if (_orderFilterMode == 'unbooked' && isBooked) return false;
      if (_orderFilterMode == 'booked' && !isBooked) return false;

      if (_orderSearchQuery.trim().isNotEmpty) {
        final q = _orderSearchQuery.toLowerCase().trim();
        final name = _extractOrderCustomerName(raw).toLowerCase();
        final phone = _extractOrderCustomerPhone(raw).toLowerCase();
        return ordNum.toLowerCase().contains(q) ||
            name.contains(q) ||
            phone.contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Choose Courier for 1-Click Dispatch',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: courierCodes.map((code) {
                  final sel = _bookingCourierProvider == code;
                  return ChoiceChip(
                    label: Text(code.toString().toUpperCase()),
                    selected: sel,
                    selectedColor: t.primaryColor,
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : t.primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    onSelected: (_) =>
                        setState(() => _bookingCourierProvider = code),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _orderSearchQuery = v),
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search order by #number, customer name or phone...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, color: t.primaryColor),
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Ready to Book'),
                    selected: _orderFilterMode == 'unbooked',
                    selectedColor: t.primaryColor,
                    labelStyle: TextStyle(
                      color: _orderFilterMode == 'unbooked'
                          ? Colors.white
                          : t.primaryText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) =>
                        setState(() => _orderFilterMode = 'unbooked'),
                  ),
                  ChoiceChip(
                    label: const Text('All Orders'),
                    selected: _orderFilterMode == 'all',
                    selectedColor: t.primaryColor,
                    labelStyle: TextStyle(
                      color: _orderFilterMode == 'all'
                          ? Colors.white
                          : t.primaryText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) => setState(() => _orderFilterMode = 'all'),
                  ),
                  if (_selectedOrderNumbersForBulk.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed:
                          _isBookingOrder ? null : _bookSelectedBulkOrders,
                      icon: const Icon(Icons.send_rounded, size: 15),
                      label: Text(
                        'Bulk Book (${_selectedOrderNumbersForBulk.length}) to ${_bookingCourierProvider.toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filteredOrders.isEmpty)
          _buildEmptyBox(
              t, 'বুকিং করার মতো কোনো আন-বুকড অর্ডার পাওয়া যায়নি।')
        else
          ...filteredOrders.take(30).map((raw) {
            final Map ord = raw as Map;
            final String ordNum = _extractOrderNumber(ord);
            final String cName = _extractOrderCustomerName(ord);
            final String cPhone = _extractOrderCustomerPhone(ord);
            final String cAddr = _extractOrderAddress(ord);
            final double codAmt = _extractOrderAmount(ord);
            final Map? bookedInfo = _bookedMap[ordNum] as Map?;
            final bool isChecked =
                _selectedOrderNumbersForBulk.contains(ordNum);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isChecked ? t.primaryColor : t.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (bookedInfo == null)
                        Checkbox(
                          value: isChecked,
                          activeColor: t.primaryColor,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedOrderNumbersForBulk.add(ordNum);
                              } else {
                                _selectedOrderNumbersForBulk.remove(ordNum);
                              }
                            });
                          },
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#$ordNum • $cName',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              'Phone: $cPhone • Address: $cAddr',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '৳${codAmt.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: t.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (bookedInfo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Booked: ${bookedInfo['provider_name']} • Tracking: ${bookedInfo['tracking_code']}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                        )
                      else
                        _buildSmallBtn(
                          icon: Icons.local_shipping_rounded,
                          label:
                              '1-Click Book to ${_bookingCourierProvider.toUpperCase()}',
                          color: t.primaryColor,
                          onTap: () => _bookSingleOrder(ord),
                        ),
                      _buildSmallBtn(
                        icon: Icons.shield_outlined,
                        label: 'Fraud Check Phone',
                        color: const Color(0xFF2563EB),
                        onTap: () {
                          setState(() => _activeTab = 'settlement');
                          _checkPhoneFraud(cPhone);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 16),

        // Manual / Custom Parcel Booking Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manual / Custom Parcel Booking (${_bookingCourierProvider.toUpperCase()})',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              _buildField(
                t,
                label: 'Recipient Name *',
                hint: 'Customer full name',
                controller: _manualCustNameCtrl,
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 8),
              _buildField(
                t,
                label: 'Recipient Phone (11 digits) *',
                hint: '017XXXXXXXX',
                controller: _manualCustPhoneCtrl,
                icon: Icons.phone_rounded,
              ),
              const SizedBox(height: 8),
              _buildField(
                t,
                label: 'Delivery Address *',
                hint: 'Full delivery address',
                controller: _manualAddressCtrl,
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 8),
              _buildField(
                t,
                label: 'COD Amount to Collect (৳)',
                hint: 'e.g., 1250',
                controller: _manualCodCtrl,
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isBookingOrder ? null : _bookManualParcel,
                  icon: const Icon(Icons.send_rounded, size: 17),
                  label: const Text(
                    'Dispatch Manual Parcel Now',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: LIVE PARCEL TRACKING & STATUS MANAGER
  // =========================================================================
  Widget _buildLiveTrackingTab(CatalogThemeConfig t) {
    final List statusFilters = [
      {'id': 'all', 'label': 'All (${_consignments.length})'},
      {'id': 'in_transit', 'label': 'In Transit'},
      {'id': 'delivered', 'label': 'Delivered'},
      {'id': 'returned', 'label': 'Returned'},
      {'id': 'hold', 'label': 'On Hold'},
    ];

    final filtered = _consignments.where((c) {
      if (c is! Map) return false;
      final st = (c['status'] ?? 'in_transit').toString().toLowerCase();
      if (_trackingStatusFilter != 'all' && st != _trackingStatusFilter) {
        return false;
      }
      if (_trackingSearchQuery.trim().isNotEmpty) {
        final q = _trackingSearchQuery.toLowerCase().trim();
        final ord = (c['order_number'] ?? '').toString().toLowerCase();
        final trk = (c['tracking_code'] ?? '').toString().toLowerCase();
        final name = (c['customer_name'] ?? '').toString().toLowerCase();
        final ph = (c['customer_phone'] ?? '').toString().toLowerCase();
        return ord.contains(q) ||
            trk.contains(q) ||
            name.contains(q) ||
            ph.contains(q);
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _trackingSearchQuery = v),
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Search by Tracking Code, Order #, Customer Name or Phone...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, color: t.primaryColor),
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: statusFilters.map((sf) {
                    final String sid = sf['id'].toString();
                    final bool sel = _trackingStatusFilter == sid;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(sf['label'].toString()),
                        selected: sel,
                        selectedColor: t.primaryColor,
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : t.primaryText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                        onSelected: (_) =>
                            setState(() => _trackingStatusFilter = sid),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          _buildEmptyBox(t, 'কোনো কুরিয়ার কনসাইনমেন্ট খুঁজে পাওয়া যায়নি।')
        else
          ...filtered.map((raw) {
            final Map c = raw as Map;
            final int id = int.tryParse((c['id'] ?? 0).toString()) ?? 0;
            final String status =
                (c['status'] ?? 'in_transit').toString().toLowerCase();
            final bool stockRestored = c['stock_restored_on_return'] == true;
            final bool isUpdating = _updatingConsignmentId == id;

            Color stColor = const Color(0xFF2563EB);
            if (status == 'delivered') stColor = const Color(0xFF059669);
            if (status == 'returned' || status == 'cancelled') {
              stColor = const Color(0xFFDC2626);
            }
            if (status == 'hold') stColor = const Color(0xFFD97706);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${c['order_number']} • ${c['provider_name'] ?? c['provider']}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: stColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: stColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tracking: ${c['tracking_code']}  |  CID: ${c['consignment_id']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: t.primaryColor,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text: (c['tracking_code'] ?? '').toString()));
                          _showSnack('ট্র্যাকিং কোড কপি করা হয়েছে!');
                        },
                        child: Icon(Icons.copy_rounded,
                            size: 15, color: t.primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customer: ${c['customer_name']} (${c['customer_phone']}) • COD: ৳${c['cod_amount'] ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.primaryText,
                    ),
                  ),
                  Text(
                    'Address: ${c['delivery_address'] ?? ''} • Booked: ${c['created_at'] ?? ''}',
                    style: TextStyle(fontSize: 11, color: t.secondaryText),
                  ),
                  if (stockRestored) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '✓ Returned Parcel Stock Automatically Restored (+Restocked)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (isUpdating)
                    const LinearProgressIndicator()
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (status != 'delivered')
                          _buildSmallBtn(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Mark Delivered & Settle COD',
                            color: const Color(0xFF059669),
                            onTap: () =>
                                _updateConsignmentStatus(c, 'delivered'),
                          ),
                        if (status != 'returned')
                          _buildSmallBtn(
                            icon: Icons.assignment_return_outlined,
                            label: 'Mark Returned (+Auto Restock)',
                            color: const Color(0xFFDC2626),
                            onTap: () =>
                                _updateConsignmentStatus(c, 'returned'),
                          ),
                        if (status != 'hold')
                          _buildSmallBtn(
                            icon: Icons.pause_circle_outline_rounded,
                            label: 'Hold',
                            color: const Color(0xFFD97706),
                            onTap: () => _updateConsignmentStatus(c, 'hold'),
                          ),
                      ],
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // =========================================================================
  // TAB 4: COD SETTLEMENT & CUSTOMER FRAUD SHIELD
  // =========================================================================
  Widget _buildSettlementAndFraudTab(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildKpiTile(
              t,
              title: 'COD Settled (Delivered)',
              value: '৳${_summary['cod_delivered_settled'] ?? 0}',
              subtitle: '${_summary['delivered_count'] ?? 0} parcels delivered',
              icon: Icons.verified_rounded,
              color: const Color(0xFF059669),
            ),
            _buildKpiTile(
              t,
              title: 'COD In Transit',
              value: '৳${_summary['cod_in_transit'] ?? 0}',
              subtitle: '${_summary['in_transit_count'] ?? 0} active parcels',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF2563EB),
            ),
            _buildKpiTile(
              t,
              title: 'Returned (Auto Restocked)',
              value: '${_summary['returned_count'] ?? 0} Parcels',
              subtitle: 'Inventory auto-restored',
              icon: Icons.autorenew_rounded,
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Customer Phone Fraud & Delivery Ratio Checker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_rounded, color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'COD Fraud Shield & Delivery Success Ratio Checker',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'পার্সেল পাঠানোর আগে কাস্টমারের মোবাইল নম্বর দিয়ে তার পূর্ববর্তী ডেলিভারি সাকসেস ও রিটার্ন রেশিও যাচাই করুন।',
                style: TextStyle(fontSize: 11.5, color: t.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fraudPhoneCtrl,
                      onSubmitted: (_) => _checkPhoneFraud(),
                      style: TextStyle(color: t.primaryText, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Enter customer phone (e.g. 017XXXXXXXX)...',
                        hintStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
                        prefixIcon:
                            Icon(Icons.phone_rounded, color: t.primaryColor),
                        filled: true,
                        fillColor: t.inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        _isCheckingFraud ? null : () => _checkPhoneFraud(),
                    icon: const Icon(Icons.search_rounded, size: 17),
                    label: const Text(
                      'Check Ratio',
                      style:
                          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              if (_fraudResult != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.primaryColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Phone: ${_fraudResult!['phone']} • ${_fraudResult!['risk_level']}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Success: ${_fraudResult!['success_ratio']}%',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Delivered: ${_fraudResult!['total_delivered']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                          Text(
                            'Returned/Cancelled: ${_fraudResult!['total_returned']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          Text(
                            'In Transit: ${_fraudResult!['total_in_transit']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // REUSABLE UI HELPERS
  // =========================================================================
  Widget _buildKpiTile(
    CatalogThemeConfig t, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 162,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: t.primaryText,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: t.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    CatalogThemeConfig t, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: t.primaryText,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(color: t.primaryText, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
            prefixIcon: Icon(icon, color: t.primaryColor, size: 18),
            filled: true,
            fillColor: t.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: t.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: t.cardBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBox(CatalogThemeConfig t, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.cardBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          color: t.secondaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}