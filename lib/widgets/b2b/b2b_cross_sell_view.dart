// lib/widgets/b2b/b2b_cross_sell_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../catalog/catalog_theme_scope.dart';

class B2BCrossSellView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab; // 'credentials', 'partners', 'catalog', 'ledger'
  final VoidCallback? onDataChanged;

  const B2BCrossSellView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'credentials',
    this.onDataChanged,
  });

  @override
  State<B2BCrossSellView> createState() => _B2BCrossSellViewState();
}

class _B2BCrossSellViewState extends State<B2BCrossSellView> {
  String _activeTab = 'credentials';
  bool _isLoading = true;
  bool _isSubmitting = false;

  CatalogThemeConfig _theme = const CatalogThemeConfig();

  String _apiBase = 'https://nextlook.shop.xylotechsolution.com';
  String _subdomain = 'nextlook';
  String _token = '';

  // =========================================================================
  // 1. API KEYS & PLATFORM % STATE
  // =========================================================================
  String _publicCatalogEndpoint = '';
  double _platformCommissionPercent = 5.0;
  int _totalApiShops = 0;
  int _activeApiShops = 0;
  int _totalApiCalls = 0;
  double _totalMerchantEarnings = 0.0;
  double _totalDeveloperCommission = 0.0;
  List _apiShops = [];
  final Set _visibleSecrets = {};

  final TextEditingController _companyNameCtrl = TextEditingController();
  final TextEditingController _companyDomainCtrl = TextEditingController();
  final TextEditingController _companyPhoneCtrl = TextEditingController();

  // =========================================================================
  // 2. PARTNER STORES & MARKUP % STATE
  // =========================================================================
  List _partners = [];
  List _internalShops = [];
  final TextEditingController _partnerNameCtrl = TextEditingController();
  final TextEditingController _partnerApiKeyCtrl = TextEditingController();
  final TextEditingController _partnerSecretKeyCtrl = TextEditingController();
  final TextEditingController _partnerSenderIdCtrl = TextEditingController();
  final TextEditingController _partnerEndpointCtrl = TextEditingController();
  final TextEditingController _partnerMarkupCtrl =
      TextEditingController(text: '10');
  int? _selectedTargetShopId;
  final double _simulatorBasePrice = 450.0;

  // =========================================================================
  // 3. CATALOG IMPORT & SYNC STATE
  // =========================================================================
  int? _selectedPartnerConnId;
  String _catalogPartnerName = '';
  String _catalogSupplierSubdomain = '';
  String _catalogSenderId = '';
  double _catalogMarkupPct = 10.0;
  double _catalogPlatformPct = 5.0;
  List _remoteCatalogProducts = [];
  final Set _selectedRemoteProductIds = {};
  String _catalogSearchQuery = '';
  bool _isFetchingCatalog = false;
  bool _isImportingCatalog = false;

  // =========================================================================
  // 4. 3-WAY COMMISSION LEDGER STATE
  // =========================================================================
  List _ledgerRecords = [];
  List _syncedProducts = [];
  Map _ledgerSummary = {
    'total_gmv': 0.0,
    'total_reseller_profit': 0.0,
    'total_platform_commission': 0.0,
    'total_supplier_payable': 0.0,
  };
  int? _selectedTestSyncedProdId;
  final int _testOrderQty = 1;
  bool _isSimulatingOrder = false;

  @override
  void initState() {
    super.initState();
    _activeTab = _normalizeTab(widget.initialTab);
    _initAndLoad();
  }

  @override
  void didUpdateWidget(covariant B2BCrossSellView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTab = _normalizeTab(widget.initialTab);
    if (oldWidget.initialTab != widget.initialTab && nextTab != _activeTab) {
      setState(() => _activeTab = nextTab);
      if (nextTab == 'catalog' &&
          _selectedPartnerConnId != null &&
          _remoteCatalogProducts.isEmpty) {
        _fetchPartnerCatalog(_selectedPartnerConnId!);
      }
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _loadTheme();
    }
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyDomainCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _partnerNameCtrl.dispose();
    _partnerApiKeyCtrl.dispose();
    _partnerSecretKeyCtrl.dispose();
    _partnerSenderIdCtrl.dispose();
    _partnerEndpointCtrl.dispose();
    _partnerMarkupCtrl.dispose();
    super.dispose();
  }

  String _normalizeTab(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('partner') || lower.contains('markup')) {
      return 'partners';
    }
    if (lower.contains('catalog') ||
        lower.contains('import') ||
        lower.contains('sync')) {
      return 'catalog';
    }
    if (lower.contains('ledger') ||
        lower.contains('commission') ||
        lower.contains('split')) {
      return 'ledger';
    }
    return 'credentials';
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
    _subdomain = prefs.getString('active_subdomain') ?? 'nextlook';
    String base = prefs.getString('api_base_url') ?? 'https://nextlook.shop.xylotechsolution.com';
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    _apiBase = base;

    await _fetchAllB2BData();
  }

  Future _fetchAllB2BData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/cross-sell/credentials/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/cross-sell/partners/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/cross-sell/ledger/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
              Uri.parse('$_apiBase/api/v1/stores/shops/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 6))
            .catchError((_) => http.Response('[]', 500)),
      ]);

      // 1. Parse Credentials & Platform Rate
      if (results[0].statusCode == 200) {
        final cData = jsonDecode(utf8.decode(results[0].bodyBytes));
        if (cData is Map) {
          _publicCatalogEndpoint = (cData['public_catalog_endpoint'] ??
                  '$_apiBase/api/v1/stores/cross-sell/public-catalog/')
              .toString();
          _platformCommissionPercent = double.tryParse(
                  (cData['platform_commission_percent'] ?? 5.0).toString()) ??
              5.0;
          _totalApiShops =
              int.tryParse((cData['total_api_shops'] ?? 0).toString()) ?? 0;
          _activeApiShops =
              int.tryParse((cData['active_api_shops'] ?? 0).toString()) ?? 0;
          _totalApiCalls =
              int.tryParse((cData['total_api_calls'] ?? 0).toString()) ?? 0;
          _totalMerchantEarnings = double.tryParse(
                  (cData['total_merchant_earnings'] ?? 0.0).toString()) ??
              0.0;
          _totalDeveloperCommission = double.tryParse(
                  (cData['total_developer_commission'] ?? 0.0).toString()) ??
              0.0;
          if (cData['api_shops'] is List) {
            _apiShops = cData['api_shops'];
          }
        }
      }

      // 2. Parse Partner Connections
      if (results[1].statusCode == 200) {
        final pData = jsonDecode(utf8.decode(results[1].bodyBytes));
        if (pData is List) {
          _partners = pData;
        } else if (pData is Map && pData['results'] is List) {
          _partners = pData['results'];
        }
        if (_partners.isNotEmpty && _selectedPartnerConnId == null) {
          _selectedPartnerConnId =
              int.tryParse((_partners.first['id'] ?? '').toString());
        }
      }

      // 3. Parse Ledger & Synced Products
      if (results[2].statusCode == 200) {
        final lData = jsonDecode(utf8.decode(results[2].bodyBytes));
        if (lData is Map) {
          if (lData['records'] is List) {
            _ledgerRecords = lData['records'];
          }
          if (lData['synced_products'] is List) {
            _syncedProducts = lData['synced_products'];
            if (_syncedProducts.isNotEmpty &&
                _selectedTestSyncedProdId == null) {
              _selectedTestSyncedProdId =
                  int.tryParse((_syncedProducts.first['id'] ?? '').toString());
            }
          }
          if (lData['summary'] is Map) {
            _ledgerSummary = Map.from(lData['summary']);
          }
        }
      }

      // 4. Parse Internal Shops
      if (results[3].statusCode == 200) {
        final sData = jsonDecode(utf8.decode(results[3].bodyBytes));
        if (sData is List) {
          _internalShops = sData;
        } else if (sData is Map && sData['results'] is List) {
          _internalShops = sData['results'];
        }
      }

      if (_activeTab == 'catalog' &&
          _selectedPartnerConnId != null &&
          _remoteCatalogProducts.isEmpty) {
        await _fetchPartnerCatalog(_selectedPartnerConnId!);
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  // =========================================================================
  // TAB 1 ACTIONS: API CREDENTIALS CRUD
  // =========================================================================
  Future _createApiShopCredential() async {
    final compName = _companyNameCtrl.text.trim();
    if (compName.isEmpty) {
      _showSnack('যে কোম্পানি বা দোকানকে API দিচ্ছেন তার নাম লিখুন।',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/credentials/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'action': 'create_api_shop',
          'company_name': compName,
          'company_domain': _companyDomainCtrl.text.trim(),
          'contact_phone': _companyPhoneCtrl.text.trim(),
        }),
      );

      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201 || res.statusCode == 200) {
        _companyNameCtrl.clear();
        _companyDomainCtrl.clear();
        _companyPhoneCtrl.clear();
        _showSnack((dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'নতুন API Key ও Sender ID তৈরি হয়েছে!');
        await _fetchAllB2BData(silent: true);
      } else {
        _showSnack(
          (dec is Map && dec['detail'] != null)
              ? dec['detail'].toString()
              : 'API Key তৈরি করতে সমস্যা হয়েছে।',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future _regenerateApiKey(int credId) async {
    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/credentials/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'action': 'regenerate',
          'cred_id': credId,
        }),
      );
      if (res.statusCode == 200) {
        _showSnack('নতুন API Key এবং Secret Key জেনারেট হয়েছে!');
        await _fetchAllB2BData(silent: true);
      }
    } catch (_) {}
  }

  Future _toggleApiShopSyndication(Map shop, bool nextVal) async {
    final credId = shop['id'];
    setState(() => shop['allow_catalog_syndication'] = nextVal);

    try {
      final res = await http.patch(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/credentials/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'action': 'update_shop',
          'cred_id': credId,
          'allow_catalog_syndication': nextVal,
        }),
      );
      if (res.statusCode == 200) {
        _showSnack(nextVal
            ? '${shop['company_name']} API সক্রিয় করা হয়েছে!'
            : '${shop['company_name']} API সাময়িকভাবে পজ করা হয়েছে।');
        await _fetchAllB2BData(silent: true);
      } else {
        setState(() => shop['allow_catalog_syndication'] = !nextVal);
      }
    } catch (_) {
      setState(() => shop['allow_catalog_syndication'] = !nextVal);
    }
  }

  Future _deleteApiShopCredential(Map shop) async {
    final credId = shop['id'];
    final dynamic confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key ডিলিট করবেন?'),
        content: Text(
            'আপনি কি "${shop['company_name']}" (${shop['sender_id']}) এর API সংযোগ ডিলিট করতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ডিলিট করুন'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/credentials/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'action': 'delete_shop',
          'cred_id': credId,
        }),
      );
      _showSnack('API Key ডিলিট করা হয়েছে।');
      await _fetchAllB2BData(silent: true);
    } catch (_) {}
  }

  // =========================================================================
  // TAB 2 ACTIONS: PARTNER CONNECTION & MARKUP %
  // =========================================================================
  Future _connectPartnerStore() async {
    final apiKey = _partnerApiKeyCtrl.text.trim();
    final secretKey = _partnerSecretKeyCtrl.text.trim();
    final senderId = _partnerSenderIdCtrl.text.trim();
    final markup = double.tryParse(_partnerMarkupCtrl.text.trim()) ?? 10.0;

    if (apiKey.isEmpty || secretKey.isEmpty || senderId.isEmpty) {
      _showSnack('API Key, Secret Key এবং Sender ID পূরণ করা আবশ্যক।',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/partners/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'partner_name': _partnerNameCtrl.text.trim(),
          'api_key': apiKey,
          'secret_key': secretKey,
          'sender_id': senderId,
          'endpoint_url': _partnerEndpointCtrl.text.trim(),
          'markup_percentage': markup,
          'target_shop': _selectedTargetShopId,
        }),
      );

      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201 || res.statusCode == 200) {
        _partnerNameCtrl.clear();
        _partnerApiKeyCtrl.clear();
        _partnerSecretKeyCtrl.clear();
        _partnerSenderIdCtrl.clear();
        _partnerEndpointCtrl.clear();
        _showSnack((dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'পার্টনার স্টোর সফলভাবে কানেক্ট হয়েছে!');
        await _fetchAllB2BData(silent: true);
      } else {
        _showSnack(
          (dec is Map && dec['detail'] != null)
              ? dec['detail'].toString()
              : 'কানেক্ট করতে সমস্যা হয়েছে।',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future _updatePartnerMarkup(Map partner) async {
    final connId = partner['id'];
    final ctrl = TextEditingController(
      text: (partner['markup_percentage'] ?? 10).toString(),
    );

    final dynamic newMarkupStr = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Markup % — ${partner['partner_name']}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Your Profit Markup % (e.g. 15)',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Update & Recalculate Prices'),
          ),
        ],
      ),
    );

    if (newMarkupStr == null || newMarkupStr.toString().isEmpty) return;

    try {
      final res = await http.patch(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/partners/$connId/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'markup_percentage': double.tryParse(newMarkupStr.toString()) ?? 10.0,
        }),
      );
      if (res.statusCode == 200) {
        _showSnack(
            'Markup % আপডেট হয়েছে এবং ইমপোর্ট করা সব প্রোডাক্টের দাম অটো-আপডেট হয়েছে!');
        await _fetchAllB2BData(silent: true);
        widget.onDataChanged?.call();
      }
    } catch (_) {}
  }

  Future _deletePartnerConnection(Map partner) async {
    final connId = partner['id'];
    try {
      final res = await http.delete(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/partners/$connId/?subdomain=$_subdomain'),
        headers: _headers(),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _showSnack('পার্টনার কানেকশন ডিলিট করা হয়েছে।');
        await _fetchAllB2BData(silent: true);
      }
    } catch (_) {}
  }

  // =========================================================================
  // TAB 3 ACTIONS: FETCH PARTNER CATALOG & 1-CLICK IMPORT
  // =========================================================================
  Future _fetchPartnerCatalog(int connId) async {
    setState(() {
      _selectedPartnerConnId = connId;
      _isFetchingCatalog = true;
      _selectedRemoteProductIds.clear();
    });

    try {
      final res = await http.get(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/partners/$connId/catalog/?subdomain=$_subdomain'),
        headers: _headers(),
      );
      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && dec is Map) {
        setState(() {
          _catalogPartnerName = (dec['partner_name'] ?? '').toString();
          _catalogSupplierSubdomain =
              (dec['supplier_subdomain'] ?? '').toString();
          _catalogSenderId = (dec['sender_id'] ?? '').toString();
          _catalogMarkupPct = double.tryParse(
                  (dec['markup_percentage'] ?? 10.0).toString()) ??
              10.0;
          _catalogPlatformPct = double.tryParse(
                  (dec['platform_commission_percent'] ?? 5.0).toString()) ??
              5.0;
          _remoteCatalogProducts =
              (dec['products'] is List) ? dec['products'] : [];
        });
      } else {
        setState(() => _remoteCatalogProducts = []);
        final detail = (dec is Map && dec['detail'] != null)
            ? dec['detail'].toString()
            : 'পার্টনার ক্যাটালগ লোড করা যায়নি।';
        _showSnack(detail, isError: true);
      }
    } catch (e) {
      _showSnack('ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isFetchingCatalog = false);
    }
  }

  Future _importSelectedPartnerProducts({bool importAll = false}) async {
    if (_selectedPartnerConnId == null) return;

    List idsToSend = [];
    if (!importAll) {
      idsToSend = _selectedRemoteProductIds.map((e) => e.toString()).toList();
      if (idsToSend.isEmpty) {
        _showSnack('ইমপোর্ট করার জন্য অন্তত ১টি প্রোডাক্ট সিলেক্ট করুন।',
            isError: true);
        return;
      }
    }

    setState(() => _isImportingCatalog = true);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/partners/$_selectedPartnerConnId/import/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'product_ids': idsToSend,
          'markup_percentage': _catalogMarkupPct,
        }),
      );
      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final msg = (dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'প্রোডাক্ট সফলভাবে আপনার স্টোরে ইমপোর্ট ও সিঙ্ক হয়েছে!';
        _showSnack(msg);
        await _fetchPartnerCatalog(_selectedPartnerConnId!);
        await _fetchAllB2BData(silent: true);
        widget.onDataChanged?.call();
      } else {
        _showSnack(
          (dec is Map && dec['detail'] != null)
              ? dec['detail'].toString()
              : 'ইমপোর্ট ব্যর্থ হয়েছে।',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isImportingCatalog = false);
    }
  }

  // =========================================================================
  // TAB 4 ACTIONS: SIMULATE / TEST 3-WAY B2B ORDER SPLIT
  // =========================================================================
  Future _simulateB2BOrderSplit() async {
    setState(() => _isSimulatingOrder = true);
    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/cross-sell/ledger/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'synced_product_id': _selectedTestSyncedProdId,
          'quantity': _testOrderQty,
        }),
      );
      final dec = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201 || res.statusCode == 200) {
        _showSnack((dec is Map && dec['message'] != null)
            ? dec['message'].toString()
            : 'B2B Order Split সফল হয়েছে!');
        await _fetchAllB2BData(silent: true);
        widget.onDataChanged?.call();
      } else {
        _showSnack(
          (dec is Map && dec['detail'] != null)
              ? dec['detail'].toString()
              : 'অর্ডার টেস্ট করার আগে অন্তত ১টি প্রোডাক্ট পার্টনার স্টোর থেকে ইমপোর্ট করুন।',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSimulatingOrder = false);
    }
  }

  // =========================================================================
  // BUILD UI
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final t = _theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroBanner(t),
        const SizedBox(height: 14),
        _buildSubNavigationBar(t),
        const SizedBox(height: 16),
        if (_isLoading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: t.primaryColor),
          )
        else ...[
          if (_activeTab == 'credentials') _buildCredentialsTab(t),
          if (_activeTab == 'partners') _buildPartnersTab(t),
          if (_activeTab == 'catalog') _buildCatalogImportTab(t),
          if (_activeTab == 'ledger') _buildCommissionLedgerTab(t),
        ],
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildHeroBanner(CatalogThemeConfig t) {
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
                  Icons.hub_rounded,
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
                      'B2B Multi-Tenant Cross-Sell Network',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '3-Way Additive Split: Supplier 100% + Partner Profit % + Platform ${_platformCommissionPercent.toStringAsFixed(1)}%',
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
                onPressed: () => _fetchAllB2BData(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh B2B Network',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroPill(Icons.vpn_key_rounded,
                  'API Keys: $_activeApiShops/$_totalApiShops'),
              _buildHeroPill(Icons.handshake_rounded,
                  'Connected Partners: ${_partners.length}'),
              _buildHeroPill(Icons.sync_rounded,
                  'Synced Products: ${_syncedProducts.length}'),
              _buildHeroPill(Icons.bolt_rounded, 'API Calls: $_totalApiCalls'),
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

  Widget _buildSubNavigationBar(CatalogThemeConfig t) {
    final List tabs = [
      {
        'id': 'credentials',
        'label': 'API Keys & Platform %',
        'icon': Icons.vpn_key_rounded,
      },
      {
        'id': 'partners',
        'label': 'Partner & Markup %',
        'icon': Icons.percent_rounded,
      },
      {
        'id': 'catalog',
        'label': 'Catalog Import',
        'icon': Icons.cloud_download_rounded,
      },
      {
        'id': 'ledger',
        'label': 'Commission Ledger',
        'icon': Icons.account_balance_wallet_rounded,
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
              onTap: () {
                setState(() => _activeTab = id);
                if (id == 'catalog' &&
                    _selectedPartnerConnId != null &&
                    _remoteCatalogProducts.isEmpty) {
                  _fetchPartnerCatalog(_selectedPartnerConnId!);
                }
              },
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
  // TAB 1 UI: API KEYS & PLATFORM %
  // =========================================================================
  Widget _buildCredentialsTab(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildKpiTile(
              t,
              title: 'Platform Fee %',
              value: '${_platformCommissionPercent.toStringAsFixed(1)}%',
              subtitle: 'Admin Controlled',
              icon: Icons.verified_user_rounded,
              color: const Color(0xFF7C3AED),
            ),
            _buildKpiTile(
              t,
              title: 'Supplier 100% Receivable',
              value: '৳${_totalMerchantEarnings.toStringAsFixed(0)}',
              subtitle: 'Zero deduction on base',
              icon: Icons.payments_rounded,
              color: const Color(0xFF059669),
            ),
            _buildKpiTile(
              t,
              title: 'Developer Commission',
              value: '৳${_totalDeveloperCommission.toStringAsFixed(0)}',
              subtitle: 'From B2B sales',
              icon: Icons.auto_graph_rounded,
              color: const Color(0xFF2563EB),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Public Headless Endpoint Box
        Container(
          padding: const EdgeInsets.all(14),
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
                  Icon(Icons.public_rounded, color: t.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your Public Headless Catalog API Endpoint',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _publicCatalogEndpoint));
                      _showSnack('Public Catalog Endpoint কপি করা হয়েছে!');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Copy URL'),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Text(
                  _publicCatalogEndpoint.isNotEmpty
                      ? _publicCatalogEndpoint
                      : '$_apiBase/api/v1/stores/cross-sell/public-catalog/',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: t.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Generate New Company API Key Form
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
                'Generate New Partner Company API Key & Sender ID',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'অন্য যে দোকান বা মার্চেন্ট আপনার প্রোডাক্ট বিক্রি করতে চায়, তাদের জন্য আলাদা API Key, Secret Key ও Sender ID তৈরি করুন।',
                style: TextStyle(fontSize: 11.5, color: t.secondaryText),
              ),
              const SizedBox(height: 12),
              _buildField(
                t,
                label: 'Partner Company / Store Name *',
                hint: 'e.g., Daraz Reseller Hub / Best BD Shop',
                controller: _companyNameCtrl,
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: 10),
              _buildField(
                t,
                label: 'Company Domain / Website (Optional)',
                hint: 'e.g., bestbdbazar.com',
                controller: _companyDomainCtrl,
                icon: Icons.language_rounded,
              ),
              const SizedBox(height: 10),
              _buildField(
                t,
                label: 'Contact Phone (Optional)',
                hint: '+880 1700-000000',
                controller: _companyPhoneCtrl,
                icon: Icons.phone_rounded,
              ),
              const SizedBox(height: 14),
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
                  onPressed: _isSubmitting ? null : _createApiShopCredential,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_moderator_rounded, size: 18),
                  label: const Text(
                    '+ Generate API Key & Sender ID',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Issued Partner API Credentials (${_apiShops.length})',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: t.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        if (_apiShops.isEmpty)
          _buildEmptyBox(
            t,
            'এখনো কোনো কোম্পানির জন্য API Key তৈরি করা হয়নি। উপরের ফর্ম থেকে তৈরি করুন।',
          )
        else
          ..._apiShops.map((shop) => _buildApiShopCard(shop as Map, t)),
      ],
    );
  }

  Widget _buildApiShopCard(Map shop, CatalogThemeConfig t) {
    final int id = int.tryParse((shop['id'] ?? 0).toString()) ?? 0;
    final String compName = (shop['company_name'] ?? 'Partner').toString();
    final String senderId = (shop['sender_id'] ?? '').toString();
    final String apiKey = (shop['api_key'] ?? '').toString();
    final String secretKey = (shop['secret_key'] ?? '').toString();
    final bool isActive = shop['allow_catalog_syndication'] != false;
    final bool secretVisible = _visibleSecrets.contains(id);

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
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: t.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.vpn_key_rounded,
                    color: t.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    Text(
                      'Sender ID: $senderId • Platform Fee: ${shop['commission_percent'] ?? _platformCommissionPercent}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: t.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeColor: t.primaryColor,
                onChanged: (v) => _toggleApiShopSyndication(shop, v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: t.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCredentialLine(t, 'X-SENDER-ID', senderId),
                const SizedBox(height: 6),
                _buildCredentialLine(t, 'X-API-KEY', apiKey),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'X-API-SECRET: ${secretVisible ? secretKey : '••••••••••••••••••••'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: t.primaryText,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (secretVisible) {
                            _visibleSecrets.remove(id);
                          } else {
                            _visibleSecrets.add(id);
                          }
                        });
                      },
                      child: Icon(
                        secretVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 16,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Orders Synced: ${shop['total_orders_synced'] ?? 0}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              Text(
                'Your 100% Earning: ৳${shop['merchant_net_earning'] ?? 0}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
              Text(
                'Partner Profit: ৳${shop['partner_reseller_profit'] ?? 0}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSmallBtn(
                icon: Icons.copy_all_rounded,
                label: 'Copy All Keys',
                color: t.primaryColor,
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text:
                        'Company: $compName\nEndpoint: $_publicCatalogEndpoint\nX-API-KEY: $apiKey\nX-API-SECRET: $secretKey\nX-SENDER-ID: $senderId',
                  ));
                  _showSnack('সবগুলো API Key ও Sender ID কপি হয়েছে!');
                },
              ),
              _buildSmallBtn(
                icon: Icons.autorenew_rounded,
                label: 'Regenerate Key',
                color: const Color(0xFF2563EB),
                onTap: () => _regenerateApiKey(id),
              ),
              _buildSmallBtn(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: const Color(0xFFDC2626),
                onTap: () => _deleteApiShopCredential(shop),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialLine(
      CatalogThemeConfig t, String keyLabel, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$keyLabel: $value',
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
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            _showSnack('$keyLabel কপি করা হয়েছে!');
          },
          child: Icon(Icons.copy_rounded, size: 14, color: t.primaryColor),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2 UI: PARTNER STORES & ADDITIVE MARKUP %
  // =========================================================================
  Widget _buildPartnersTab(CatalogThemeConfig t) {
    final double markupPct =
        double.tryParse(_partnerMarkupCtrl.text.trim()) ?? 10.0;
    final double partnerProfit = (_simulatorBasePrice * markupPct) / 100.0;
    final double devFee =
        (_simulatorBasePrice * _platformCommissionPercent) / 100.0;
    final double customerSellingPrice =
        _simulatorBasePrice + partnerProfit + devFee;

    final List presetMarkups = ['5', '10', '15', '20', '25', '30'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.primaryColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate_rounded,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Additive 3-Way Pricing Formula Preview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _buildFormulaBadge(
                    'Supplier Gets (100%)',
                    '৳${_simulatorBasePrice.toStringAsFixed(2)}',
                    const Color(0xFF059669),
                  ),
                  _buildFormulaBadge(
                    'Your Profit (+${markupPct.toStringAsFixed(0)}%)',
                    '+৳${partnerProfit.toStringAsFixed(2)}',
                    const Color(0xFFD97706),
                  ),
                  _buildFormulaBadge(
                    'Platform Fee (+${_platformCommissionPercent.toStringAsFixed(0)}%)',
                    '+৳${devFee.toStringAsFixed(2)}',
                    const Color(0xFF7C3AED),
                  ),
                  _buildFormulaBadge(
                    'Customer Selling Price',
                    '৳${customerSellingPrice.toStringAsFixed(2)}',
                    const Color(0xFF2563EB),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

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
                'Connect External Partner Store & Set Your Profit %',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              _buildField(
                t,
                label: 'Partner Store Name (Optional)',
                hint: 'e.g., Buynara Official Supplier',
                controller: _partnerNameCtrl,
                icon: Icons.store_rounded,
              ),
              const SizedBox(height: 10),
              _buildField(
                t,
                label: 'Supplier X-API-KEY *',
                hint: 'xylo_live_...',
                controller: _partnerApiKeyCtrl,
                icon: Icons.vpn_key_rounded,
              ),
              const SizedBox(height: 10),
              _buildField(
                t,
                label: 'Supplier X-API-SECRET *',
                hint: 'xylo_sec_...',
                controller: _partnerSecretKeyCtrl,
                icon: Icons.lock_rounded,
              ),
              const SizedBox(height: 10),
              _buildField(
                t,
                label: 'Supplier X-SENDER-ID *',
                hint: 'SNDR-...',
                controller: _partnerSenderIdCtrl,
                icon: Icons.badge_rounded,
              ),
              const SizedBox(height: 12),
              _buildField(
                t,
                label: 'Your Profit Markup Percentage (%) *',
                hint: '10',
                controller: _partnerMarkupCtrl,
                icon: Icons.percent_rounded,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetMarkups.map((m) {
                  final sel = _partnerMarkupCtrl.text.trim() == m;
                  return InkWell(
                    onTap: () =>
                        setState(() => _partnerMarkupCtrl.text = m.toString()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? t.primaryColor : t.inputBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? t.primaryColor : t.cardBorder),
                      ),
                      child: Text(
                        '+$m% Profit',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : t.primaryText,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_internalShops.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Import Target Internal Shop (Optional)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Main Store'),
                      selected: _selectedTargetShopId == null,
                      selectedColor: t.primaryColor,
                      labelStyle: TextStyle(
                        color: _selectedTargetShopId == null
                            ? Colors.white
                            : t.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedTargetShopId = null),
                    ),
                    ..._internalShops.map((sh) {
                      final sId = int.tryParse((sh['id'] ?? '').toString());
                      final sel = _selectedTargetShopId == sId;
                      return ChoiceChip(
                        label: Text((sh['name'] ?? 'Shop').toString()),
                        selected: sel,
                        selectedColor: t.primaryColor,
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : t.primaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedTargetShopId = sId),
                      );
                    }),
                  ],
                ),
              ],
              const SizedBox(height: 14),
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
                  onPressed: _isSubmitting ? null : _connectPartnerStore,
                  icon: const Icon(Icons.add_link_rounded, size: 19),
                  label: const Text(
                    'Connect Partner Store API',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Connected Supplier Stores (${_partners.length})',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: t.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        if (_partners.isEmpty)
          _buildEmptyBox(
              t, 'কোনো পার্টনার স্টোর কানেক্ট করা হয়নি। উপরের ফর্ম দিয়ে যুক্ত করুন।')
        else
          ..._partners.map((p) {
            final Map partner = p as Map;
            final int connId =
                int.tryParse((partner['id'] ?? 0).toString()) ?? 0;
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
                      Icon(Icons.handshake_rounded,
                          color: t.primaryColor, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (partner['partner_name'] ?? 'Partner Store')
                                  .toString(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              'Sender ID: ${partner['sender_id'] ?? ''} • Target: ${partner['target_shop_name'] ?? 'Main Store'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
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
                          '+${partner['markup_percentage'] ?? 10}% Profit',
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
                  Text(
                    'Synced Products: ${partner['synced_products_count'] ?? 0}  •  Last Synced: ${partner['last_synced_at'] ?? 'Never'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: t.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSmallBtn(
                        icon: Icons.cloud_download_rounded,
                        label: 'Browse & Import Catalog',
                        color: t.primaryColor,
                        onTap: () {
                          setState(() => _activeTab = 'catalog');
                          _fetchPartnerCatalog(connId);
                        },
                      ),
                      _buildSmallBtn(
                        icon: Icons.edit_rounded,
                        label: 'Change Markup %',
                        color: const Color(0xFF2563EB),
                        onTap: () => _updatePartnerMarkup(partner),
                      ),
                      _buildSmallBtn(
                        icon: Icons.delete_outline_rounded,
                        label: 'Disconnect',
                        color: const Color(0xFFDC2626),
                        onTap: () => _deletePartnerConnection(partner),
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
  // TAB 3 UI: CATALOG IMPORT & SYNC
  // =========================================================================
  Widget _buildCatalogImportTab(CatalogThemeConfig t) {
    final filteredCatalog = _remoteCatalogProducts.where((item) {
      if (item is! Map) return false;
      if (_catalogSearchQuery.trim().isEmpty) return true;
      final q = _catalogSearchQuery.toLowerCase().trim();
      final name = (item['name'] ?? '').toString().toLowerCase();
      final sku = (item['sku'] ?? '').toString().toLowerCase();
      return name.contains(q) || sku.contains(q);
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
                'Select Connected Partner Store to Browse Catalog',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              if (_partners.isEmpty)
                _buildEmptyBox(
                  t,
                  'প্রোডাক্ট ইমপোর্ট করার আগে "Partner & Markup %" ট্যাব থেকে অন্তত ১টি পার্টনার স্টোর কানেক্ট করুন।',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _partners.map((p) {
                    final int cId =
                        int.tryParse((p['id'] ?? 0).toString()) ?? 0;
                    final bool sel = _selectedPartnerConnId == cId;
                    return ChoiceChip(
                      label: Text(
                          '${p['partner_name']} (+${p['markup_percentage']}%)'),
                      selected: sel,
                      selectedColor: t.primaryColor,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : t.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      onSelected: (_) => _fetchPartnerCatalog(cId),
                    );
                  }).toList(),
                ),
              if (_selectedPartnerConnId != null) ...[
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _catalogSearchQuery = v),
                  style: TextStyle(color: t.primaryText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search partner catalog product...',
                    hintStyle:
                        TextStyle(color: t.secondaryText, fontSize: 12),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: t.primaryColor),
                    filled: true,
                    fillColor: t.inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isImportingCatalog
                          ? null
                          : () =>
                              _importSelectedPartnerProducts(importAll: false),
                      icon: const Icon(Icons.download_done_rounded, size: 16),
                      label: Text(
                        'Import Selected (${_selectedRemoteProductIds.length})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isImportingCatalog
                          ? null
                          : () =>
                              _importSelectedPartnerProducts(importAll: true),
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text(
                        'Sync All Partner Products',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_isFetchingCatalog)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredCatalog.isEmpty && _selectedPartnerConnId != null)
          _buildEmptyBox(t, 'এই পার্টনার স্টোরে কোনো প্রোডাক্ট পাওয়া যায়নি।')
        else
          ...filteredCatalog.map((prod) {
            final Map item = prod as Map;
            final String remId =
                (item['remote_product_id'] ?? '').toString();
            final bool isChecked =
                _selectedRemoteProductIds.contains(remId);
            final bool alreadySynced = item['is_synced'] == true;

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
                      Checkbox(
                        value: isChecked,
                        activeColor: t.primaryColor,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedRemoteProductIds.add(remId);
                            } else {
                              _selectedRemoteProductIds.remove(remId);
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['name'] ?? 'Product').toString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              'SKU: ${item['sku'] ?? 'N/A'} • Stock: ${item['stock_quantity'] ?? 0} • ${item['category_name'] ?? 'General'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: alreadySynced
                              ? const Color(0xFF059669).withOpacity(0.14)
                              : const Color(0xFF2563EB).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          alreadySynced ? 'Synced' : 'Available',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: alreadySynced
                                ? const Color(0xFF059669)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFormulaBadge(
                        'Supplier Base',
                        '৳${item['supplier_base_price'] ?? 0}',
                        const Color(0xFF059669),
                      ),
                      _buildFormulaBadge(
                        'Your Profit (+${item['markup_percentage'] ?? _catalogMarkupPct}%)',
                        '+৳${item['reseller_profit'] ?? 0}',
                        const Color(0xFFD97706),
                      ),
                      _buildFormulaBadge(
                        'Platform (+${item['platform_commission_percent'] ?? _catalogPlatformPct}%)',
                        '+৳${item['platform_commission_amount'] ?? 0}',
                        const Color(0xFF7C3AED),
                      ),
                      _buildFormulaBadge(
                        'Your Selling Price',
                        '৳${item['selling_price'] ?? 0}',
                        const Color(0xFF2563EB),
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
  // TAB 4 UI: 3-WAY COMMISSION SPLIT LEDGER
  // =========================================================================
  Widget _buildCommissionLedgerTab(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildKpiTile(
              t,
              title: 'Total B2B GMV',
              value: '৳${_ledgerSummary['total_gmv'] ?? 0}',
              subtitle: 'Customer paid total',
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFF2563EB),
            ),
            _buildKpiTile(
              t,
              title: 'Supplier Net (100%)',
              value: '৳${_ledgerSummary['total_supplier_payable'] ?? 0}',
              subtitle: 'Full base price',
              icon: Icons.storefront_rounded,
              color: const Color(0xFF059669),
            ),
            _buildKpiTile(
              t,
              title: 'Partner Profit',
              value: '৳${_ledgerSummary['total_reseller_profit'] ?? 0}',
              subtitle: 'Reseller markup',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFFD97706),
            ),
            _buildKpiTile(
              t,
              title: 'Platform Commission',
              value: '৳${_ledgerSummary['total_platform_commission'] ?? 0}',
              subtitle: 'Developer fee',
              icon: Icons.account_balance_rounded,
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
                'Test Real-Time B2B Order & 3-Way Split Sync',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ইমপোর্ট করা প্রোডাক্টে অর্ডার আসলে সাপ্লায়ার স্টোরের স্টক অটোমেটিক কমবে এবং ৩-ভাগে টাকা ভাগ হবে।',
                style: TextStyle(fontSize: 11.5, color: t.secondaryText),
              ),
              const SizedBox(height: 10),
              if (_syncedProducts.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _syncedProducts.map((sp) {
                    final int sId =
                        int.tryParse((sp['id'] ?? 0).toString()) ?? 0;
                    final bool sel = _selectedTestSyncedProdId == sId;
                    return ChoiceChip(
                      label: Text(
                          '${sp['product_name']} (Sell: ৳${sp['selling_price']})'),
                      selected: sel,
                      selectedColor: t.primaryColor,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : t.primaryText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedTestSyncedProdId = sId),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 10),
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
                  onPressed:
                      _isSimulatingOrder ? null : _simulateB2BOrderSplit,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text(
                    'Simulate B2B Order & Auto-Split Commission',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          '3-Way Commission Split Ledger (${_ledgerRecords.length})',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: t.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        if (_ledgerRecords.isEmpty)
          _buildEmptyBox(
              t, 'এখনো কোনো B2B Cross-Sell অর্ডার ট্রানজেকশন হয়নি।')
        else
          ..._ledgerRecords.map((rec) {
            final Map r = rec as Map;
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
                    children: [
                      Expanded(
                        child: Text(
                          '${r['product_name'] ?? 'Product'} × ${r['quantity'] ?? 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (r['status'] ?? 'SYNCED').toString(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order: #${r['order_number']} • Supplier Ref: ${r['remote_order_ref']} • Sender: ${r['supplier_sender_id']}',
                    style: TextStyle(fontSize: 11, color: t.secondaryText),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFormulaBadge(
                        'Customer Paid',
                        '৳${r['customer_paid_total'] ?? 0}',
                        const Color(0xFF2563EB),
                      ),
                      _buildFormulaBadge(
                        'Supplier (100%)',
                        '৳${r['supplier_net_payable'] ?? 0}',
                        const Color(0xFF059669),
                      ),
                      _buildFormulaBadge(
                        'Partner (+${r['markup_percentage'] ?? 0}%)',
                        '৳${r['reseller_profit_amount'] ?? 0}',
                        const Color(0xFFD97706),
                      ),
                      _buildFormulaBadge(
                        'Platform (${r['platform_commission_percent'] ?? 5}%)',
                        '৳${r['platform_commission_amount'] ?? 0}',
                        const Color(0xFF7C3AED),
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
                    fontSize: 14,
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

  Widget _buildFormulaBadge(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
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
    ValueChanged<String>? onChanged,
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
          onChanged: onChanged,
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