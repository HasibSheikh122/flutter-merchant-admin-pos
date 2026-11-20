// lib/widgets/shops/shops_outlets_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class ShopsOutletsView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialMode; // 'list' or 'add'
  final VoidCallback? onShopsChanged;

  const ShopsOutletsView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialMode = 'list',
    this.onShopsChanged,
  });

  @override
  State createState() => _ShopsOutletsViewState();
}

class _ShopsOutletsViewState extends State {
  static const MethodChannel _nativeChannel =
      MethodChannel('com.xylosaas.xylo_merchant_admin/alerts');

  static String _cachedSubdomain = '';
  static List _cachedShops = [];
  static List _cachedProducts = [];
  static List _cachedCategories = [];

  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;
  bool _isSaving = false;

  // 'list' = Shop List, 'add' = Add / Edit Shop Form
  String _activeTab = 'list';

  // 'grid' = Vertical Cards/Grid, '1_row' = 1 Row Horizontal Scroll
  String _layoutMode = 'grid';

  List _shops = [];
  List _allProducts = [];
  List _allCategories = [];

  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'
  final TextEditingController _searchCtrl = TextEditingController();

  // Add / Edit Form Controllers & Image Bytes
  Map? _editingShop;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _slugCtrl = TextEditingController();
  final TextEditingController _categoryLabelCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  bool _formIsActive = true;

  Uint8List? _pickedLogoBytes;
  String _pickedLogoName = '';
  Uint8List? _pickedBannerBytes;
  String _pickedBannerName = '';

  final List _categoryPresets = const [
    'Footwear & Shoes',
    'Clothing & Fashion',
    'Fast Food & Dining',
    'Baby Care & Toys',
    'Electronics & Gadgets',
    'Grocery & Daily Needs',
    'Cosmetics & Beauty',
  ];

  BoxDecoration _primaryDecoration(CatalogThemeConfig t, {double radius = 14}) {
    return BoxDecoration(
      color: t.useGradient ? null : t.primaryColor,
      gradient: t.useGradient ? t.brandGradient : null,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  @override
  void initState() {
    super.initState();
    final dynamic w = widget;
    _activeTab = w.initialMode == 'add' ? 'add' : 'list';
    _initAndFetch(forceRefresh: false);
  }

  @override
  void didUpdateWidget(covariant StatefulWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dynamic oldW = oldWidget;
    final dynamic curW = widget;
    if (oldW.initialMode != curW.initialMode) {
      setState(() {
        _activeTab = curW.initialMode == 'add' ? 'add' : 'list';
        if (_activeTab == 'add' && _editingShop == null) {
          _resetForm();
        }
      });
    }
    if (oldW.isDarkMode != curW.isDarkMode ||
        oldW.brandGreen != curW.brandGreen) {
      _reloadTheme();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _categoryLabelCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future _reloadTheme() async {
    final dynamic curW = widget;
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: curW.isDarkMode == true,
      fallbackBrandGreen: curW.brandGreen as Color,
    );
    if (mounted) setState(() => _theme = loaded);
  }

  // Automatic JWT Refresh if 401 occurs
  Future _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String refresh = prefs.getString('merchant_refresh_token') ?? '';
      if (refresh.isEmpty) return false;

      for (final path in [
        '/api/v1/auth/token/refresh/',
        '/api/v1/users/token/refresh/',
        '/api/token/refresh/',
      ]) {
        try {
          final res = await http
              .post(
                Uri.parse('${_theme.apiBase}$path'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'X-Tenant-Subdomain': _theme.subdomain,
                  'X-Tenant-Domain': _theme.subdomain,
                },
                body: jsonEncode({'refresh': refresh}),
              )
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final String newAccess =
                (data['access'] ?? data['token'] ?? '').toString();
            if (newAccess.isNotEmpty) {
              await prefs.setString('merchant_token', newAccess);
              await _reloadTheme();
              return true;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return false;
  }

  String _resolveMediaUrl(dynamic raw) {
    if (raw == null) return '';
    String s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    if (s.contains('127.0.0.1:8000')) {
      s = s.replaceFirst('http://127.0.0.1:8000', _theme.apiBase);
    } else if (s.contains('localhost:8000')) {
      s = s.replaceFirst('http://localhost:8000', _theme.apiBase);
    }
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return '${_theme.apiBase}${s.startsWith('/') ? '' : '/'}$s';
  }

  Future _initAndFetch({bool forceRefresh = false}) async {
    final dynamic curW = widget;
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: curW.isDarkMode == true,
      fallbackBrandGreen: curW.brandGreen as Color,
    );
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final String savedLayout =
        prefs.getString('shops_layout_mode_${loaded.subdomain}') ?? 'grid';

    if (!forceRefresh &&
        _cachedSubdomain == loaded.subdomain &&
        _cachedShops.isNotEmpty) {
      setState(() {
        _theme = loaded;
        _layoutMode = savedLayout;
        _shops = List.from(_cachedShops);
        _allProducts = List.from(_cachedProducts);
        _allCategories = List.from(_cachedCategories);
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _theme = loaded;
      _layoutMode = savedLayout;
      _isLoading = true;
    });

    await _loadCachedShops();
    await Future.wait([
      _fetchShopsFromBackend(),
      _fetchAllProducts(),
      _fetchAllCategories(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future _setLayoutMode(String mode) async {
    setState(() => _layoutMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shops_layout_mode_${_theme.subdomain}', mode);
    } catch (_) {}
  }

  Future _loadCachedShops() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_internal_shops_${_theme.subdomain}');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty && mounted) {
          setState(() {
            _shops = decoded;
            _isLoading = false;
          });
        }
      }
    } catch (_) {}
  }

  Future _fetchShopsFromBackend() async {
    final t = _theme;
    final String sub = Uri.encodeComponent(t.subdomain);
    try {
      final res = await http
          .get(
            Uri.parse('${t.apiBase}/api/v1/stores/shops/?subdomain=$sub'),
            headers: t.headers,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        List list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          list = decoded['results'] as List;
        }

        _cachedSubdomain = t.subdomain;
        _cachedShops = List.from(list);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'cached_internal_shops_${t.subdomain}',
          jsonEncode(list),
        );

        if (mounted) {
          setState(() => _shops = list);
        }
      }
    } catch (_) {}
  }

  Future _fetchAllProducts() async {
    final t = _theme;
    final String sub = Uri.encodeComponent(t.subdomain);
    try {
      final res = await http
          .get(
            Uri.parse(
              '${t.apiBase}/api/v1/products/?subdomain=$sub&admin=true&all_branches=true&include_inactive=true',
            ),
            headers: t.headers,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        List list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          list = decoded['results'] as List;
        }
        _cachedProducts = List.from(list);
        if (mounted) {
          setState(() => _allProducts = list);
        }
      }
    } catch (_) {}
  }

  Future _fetchAllCategories() async {
    final t = _theme;
    final String sub = Uri.encodeComponent(t.subdomain);
    try {
      final res = await http
          .get(
            Uri.parse(
              '${t.apiBase}/api/v1/products/categories/?subdomain=$sub&all_shops=true',
            ),
            headers: t.headers,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        List list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          list = decoded['results'] as List;
        }
        _cachedCategories = List.from(list);
        if (mounted) {
          setState(() => _allCategories = list);
        }
      }
    } catch (_) {}
  }

  Future _pickImageFromDeviceOrUrl() async {
    try {
      final dynamic res = await _nativeChannel.invokeMethod('pickImage');
      if (res is Map && res['base64'] != null) {
        final Uint8List bytes = base64Decode(res['base64'].toString());
        final String name = (res['name'] ?? 'shop_image.png').toString();
        return {'bytes': bytes, 'name': name};
      }
    } catch (_) {}

    if (!mounted) return null;
    final TextEditingController urlCtrl = TextEditingController();
    final String? enteredUrl = await showDialog(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          backgroundColor: _theme.cardBg,
          title: Text(
            'Select Image or Paste URL',
            style: TextStyle(
              color: _theme.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                style: TextStyle(color: _theme.primaryText),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  filled: true,
                  fillColor: _theme.inputBg,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dCtx).pop(urlCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Load Image'),
            ),
          ],
        );
      },
    );

    if (enteredUrl != null && enteredUrl.isNotEmpty) {
      try {
        final r = await http.get(Uri.parse(enteredUrl));
        if (r.statusCode == 200) {
          return {'bytes': r.bodyBytes, 'name': 'remote_shop_img.png'};
        }
      } catch (_) {}
    }
    return null;
  }

  void _resetForm() {
    _editingShop = null;
    _nameCtrl.clear();
    _slugCtrl.clear();
    _categoryLabelCtrl.text = 'Footwear & Shoes';
    _phoneCtrl.text = '01700000000';
    _addressCtrl.text = 'Khulna, Bangladesh';
    _descCtrl.clear();
    _formIsActive = true;
    _pickedLogoBytes = null;
    _pickedLogoName = '';
    _pickedBannerBytes = null;
    _pickedBannerName = '';
  }

  void _startEditingShop(Map shop) {
    setState(() {
      _editingShop = Map.from(shop);
      _nameCtrl.text = (shop['name'] ?? '').toString();
      _slugCtrl.text = (shop['slug'] ?? '').toString();
      _categoryLabelCtrl.text =
          (shop['category_label'] ?? 'Footwear & Shoes').toString();
      _phoneCtrl.text = (shop['phone'] ?? '').toString();
      _addressCtrl.text = (shop['address'] ?? '').toString();
      _descCtrl.text = (shop['description'] ?? '').toString();
      _formIsActive = shop['is_active'] != false;
      _pickedLogoBytes = null;
      _pickedLogoName = '';
      _pickedBannerBytes = null;
      _pickedBannerName = '';
      _activeTab = 'add';
    });
  }

  String _generateSlug(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future _sendShopWriteRequest({
    required bool isEditing,
    required String url,
    required String name,
    required String slug,
  }) async {
    final t = _theme;
    final bool hasFiles =
        _pickedLogoBytes != null || _pickedBannerBytes != null;

    if (hasFiles) {
      final req = http.MultipartRequest(
        isEditing ? 'PATCH' : 'POST',
        Uri.parse(url),
      );
      t.headers.forEach((k, v) {
        if (k.toLowerCase() != 'content-type') {
          req.headers[k] = v;
        }
      });
      req.fields['name'] = name;
      req.fields['slug'] = slug;
      req.fields['category_label'] = _categoryLabelCtrl.text.trim();
      req.fields['phone'] = _phoneCtrl.text.trim();
      req.fields['address'] = _addressCtrl.text.trim();
      req.fields['description'] = _descCtrl.text.trim();
      req.fields['is_active'] = _formIsActive.toString();

      if (_pickedLogoBytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'logo',
            _pickedLogoBytes!,
            filename:
                _pickedLogoName.isNotEmpty ? _pickedLogoName : 'shop_logo.png',
          ),
        );
      }
      if (_pickedBannerBytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'banner',
            _pickedBannerBytes!,
            filename: _pickedBannerName.isNotEmpty
                ? _pickedBannerName
                : 'shop_banner.png',
          ),
        );
      }
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      return http.Response.fromStream(streamed);
    } else {
      final Map payload = {
        'name': name,
        'slug': slug,
        'category_label': _categoryLabelCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'is_active': _formIsActive,
      };
      if (isEditing) {
        return http
            .patch(
              Uri.parse(url),
              headers: t.headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));
      } else {
        return http
            .post(
              Uri.parse(url),
              headers: t.headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));
      }
    }
  }

  Future _submitShopForm() async {
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('অনুগ্রহ করে শপের নাম (Store Name) লিখুন!'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final t = _theme;
    final String sub = Uri.encodeComponent(t.subdomain);
    final String slug = _slugCtrl.text.trim().isNotEmpty
        ? _slugCtrl.text.trim()
        : _generateSlug(name);

    final bool isEditing = _editingShop != null && _editingShop!['id'] != null;
    final String url = isEditing
        ? '${t.apiBase}/api/v1/stores/shops/${_editingShop!['id']}/?subdomain=$sub'
        : '${t.apiBase}/api/v1/stores/shops/?subdomain=$sub';

    try {
      http.Response res = await _sendShopWriteRequest(
        isEditing: isEditing,
        url: url,
        name: name,
        slug: slug,
      );

      // If 401, attempt automatic JWT token refresh and retry once
      if (res.statusCode == 401) {
        final bool refreshed = await _tryRefreshToken();
        if (refreshed) {
          res = await _sendShopWriteRequest(
            isEditing: isEditing,
            url: url,
            name: name,
            slug: slug,
          );
        }
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _resetForm();
        await _fetchShopsFromBackend();
        final dynamic curW = widget;
        curW.onShopsChanged?.call();

        if (mounted) {
          setState(() => _activeTab = 'list');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _theme.primaryColor,
              behavior: SnackBarBehavior.floating,
              content: Text(
                isEditing
                    ? 'শপ সফলভাবে আপডেট করা হয়েছে!'
                    : 'নতুন শপ "$name" সফলভাবে তৈরি হয়েছে!',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          );
        }
      } else {
        throw Exception('Status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Shop save error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future _toggleShopActive(Map shop, bool nextVal) async {
    final t = _theme;
    final shopId = shop['id'];
    if (shopId == null) return;

    setState(() {
      for (int i = 0; _shops.length > i; i++) {
        final s = _shops[i];
        if (s is Map && s['id'] == shopId) {
          final updated = Map.from(s);
          updated['is_active'] = nextVal;
          _shops[i] = updated;
          break;
        }
      }
      _cachedShops = List.from(_shops);
    });

    try {
      final String sub = Uri.encodeComponent(t.subdomain);
      http.Response res = await http.patch(
        Uri.parse(
          '${t.apiBase}/api/v1/stores/shops/$shopId/?subdomain=$sub',
        ),
        headers: t.headers,
        body: jsonEncode({'is_active': nextVal}),
      );
      if (res.statusCode == 401 && await _tryRefreshToken()) {
        await http.patch(
          Uri.parse(
            '${_theme.apiBase}/api/v1/stores/shops/$shopId/?subdomain=$sub',
          ),
          headers: _theme.headers,
          body: jsonEncode({'is_active': nextVal}),
        );
      }
      final dynamic curW = widget;
      curW.onShopsChanged?.call();
    } catch (_) {}
  }

  Future _deleteShop(Map shop) async {
    final t = _theme;
    final shopId = shop['id'];
    final String shopName = (shop['name'] ?? 'Shop').toString();

    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: t.cardBorder),
        ),
        title: Text(
          'Delete "$shopName"?',
          style: TextStyle(color: t.primaryText, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'এই শপটি ডিলিট করলে এর ভেতরের প্রোডাক্টগুলো মেইন স্টোরে অক্ষত থাকবে। আপনি কি নিশ্চিত?',
          style: TextStyle(color: t.secondaryText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: t.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Shop'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final String sub = Uri.encodeComponent(t.subdomain);
      http.Response res = await http.delete(
        Uri.parse(
          '${t.apiBase}/api/v1/stores/shops/$shopId/?subdomain=$sub',
        ),
        headers: t.headers,
      );
      if (res.statusCode == 401 && await _tryRefreshToken()) {
        res = await http.delete(
          Uri.parse(
            '${_theme.apiBase}/api/v1/stores/shops/$shopId/?subdomain=$sub',
          ),
          headers: _theme.headers,
        );
      }
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchShopsFromBackend();
        final dynamic curW = widget;
        curW.onShopsChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: t.primaryColor,
              content: Text('"$shopName" ডিলিট করা হয়েছে।'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Delete error: $e'),
          ),
        );
      }
    }
  }

  void _openShopCategoriesModal(Map shop) {
    final t = _theme;
    final dynamic shopId = shop['id'];
    final String shopName = (shop['name'] ?? 'Shop').toString();
    final TextEditingController newCatCtrl = TextEditingController();
    bool creatingCat = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final List shopCategories = _allCategories.where((c) {
              if (c is! Map) return false;
              final dynamic cShop = c['shop'] ?? c['shop_id'];
              final String cShopName = (c['shop_name'] ?? '').toString();
              return (cShop != null &&
                      cShop.toString() == shopId.toString()) ||
                  (cShopName.isNotEmpty &&
                      cShopName.toLowerCase() == shopName.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.80,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.secondaryText.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$shopName — Categories (${shopCategories.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              'Create or assign categories specifically for $shopName',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: t.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newCatCtrl,
                          style: TextStyle(color: t.primaryText, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'New category name for $shopName...',
                            hintStyle: TextStyle(
                              color: t.secondaryText,
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: t.inputBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: t.cardBorder),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: creatingCat
                            ? null
                            : () async {
                                final String cName = newCatCtrl.text.trim();
                                if (cName.isEmpty) return;
                                setModalState(() => creatingCat = true);
                                try {
                                  final String sub =
                                      Uri.encodeComponent(t.subdomain);
                                  final res = await http.post(
                                    Uri.parse(
                                      '${t.apiBase}/api/v1/products/categories/?subdomain=$sub',
                                    ),
                                    headers: t.headers,
                                    body: jsonEncode({
                                      'name': cName,
                                      'icon':
                                          CatalogThemeConfig.guessCategoryIcon(
                                        cName,
                                      ),
                                      'shop': shopId,
                                      'shop_id': shopId,
                                      'show_on_homepage': true,
                                    }),
                                  );
                                  if (res.statusCode == 200 ||
                                      res.statusCode == 201) {
                                    newCatCtrl.clear();
                                    await _fetchAllCategories();
                                    setModalState(() {});
                                  }
                                } catch (_) {} finally {
                                  setModalState(() => creatingCat = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(creatingCat ? '...' : 'Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _allCategories.isEmpty
                        ? Center(
                            child: Text(
                              'No categories found in store.',
                              style: TextStyle(color: t.secondaryText),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _allCategories.length,
                            itemBuilder: (_, idx) {
                              final Map cat =
                                  _allCategories[idx] is Map
                                      ? _allCategories[idx] as Map
                                      : {};
                              final dynamic cId = cat['id'];
                              final String cName =
                                  (cat['name'] ?? 'Category').toString();
                              final String cIcon =
                                  (cat['icon'] ?? '🛍️').toString();
                              final dynamic curShop =
                                  cat['shop'] ?? cat['shop_id'];
                              final String curShopName =
                                  (cat['shop_name'] ?? 'Main Store').toString();
                              final bool isAssigned = (curShop != null &&
                                      curShop.toString() ==
                                          shopId.toString()) ||
                                  (curShopName.toLowerCase() ==
                                      shopName.toLowerCase());

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isAssigned
                                      ? t.primaryColor.withValues(alpha: 0.1)
                                      : t.inputBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isAssigned
                                        ? t.primaryColor
                                        : t.cardBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      cIcon,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: t.primaryText,
                                            ),
                                          ),
                                          Text(
                                            'Current: ${isAssigned ? shopName : curShopName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: t.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isAssigned
                                            ? Colors.redAccent
                                            : t.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final dynamic nextVal =
                                            isAssigned ? null : shopId;
                                        setModalState(() {
                                          cat['shop'] = nextVal;
                                          cat['shop_id'] = nextVal;
                                          cat['shop_name'] = isAssigned
                                              ? 'Main Store'
                                              : shopName;
                                        });
                                        try {
                                          final String sub =
                                              Uri.encodeComponent(t.subdomain);
                                          await http.patch(
                                            Uri.parse(
                                              '${t.apiBase}/api/v1/products/categories/$cId/?subdomain=$sub',
                                            ),
                                            headers: t.headers,
                                            body: jsonEncode({
                                              'shop': nextVal,
                                              'shop_id': nextVal,
                                            }),
                                          );
                                          await _fetchAllCategories();
                                        } catch (_) {}
                                      },
                                      child: Text(
                                        isAssigned ? 'Detach' : '+ Attach',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  void _openShopProductsModal(Map shop) {
    final t = _theme;
    final dynamic shopId = shop['id'];
    final String shopName = (shop['name'] ?? 'Shop').toString();
    final TextEditingController prodSearchCtrl = TextEditingController();
    bool showAssignedOnly = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final List assignedProducts = _allProducts.where((p) {
              if (p is! Map) return false;
              final dynamic pShop = p['shop'] ?? p['shop_id'];
              final String pShopName = (p['shop_name'] ?? '').toString();
              return (pShop != null &&
                      pShop.toString() == shopId.toString()) ||
                  (pShopName.isNotEmpty &&
                      pShopName.toLowerCase() == shopName.toLowerCase());
            }).toList();

            final String pq = prodSearchCtrl.text.trim().toLowerCase();
            final List displayList = (showAssignedOnly
                    ? assignedProducts
                    : _allProducts)
                .where((p) {
              if (p is! Map) return false;
              if (pq.isEmpty) return true;
              return (p['name'] ?? '').toString().toLowerCase().contains(pq) ||
                  (p['sku'] ?? '').toString().toLowerCase().contains(pq);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.82,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.secondaryText.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$shopName — Products (${assignedProducts.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              'Tap + Assign or Remove to manage products in $shopName',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: t.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: prodSearchCtrl,
                    onChanged: (_) => setModalState(() {}),
                    style: TextStyle(color: t.primaryText, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search products to assign or remove...',
                      prefixIcon:
                          Icon(Icons.search_rounded, color: t.primaryColor),
                      filled: true,
                      fillColor: t.inputBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text('All Catalog (${_allProducts.length})'),
                        selected: !showAssignedOnly,
                        onSelected: (_) =>
                            setModalState(() => showAssignedOnly = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          'Attached to $shopName (${assignedProducts.length})',
                        ),
                        selected: showAssignedOnly,
                        onSelected: (_) =>
                            setModalState(() => showAssignedOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: displayList.isEmpty
                        ? Center(
                            child: Text(
                              'No products found.',
                              style: TextStyle(color: t.secondaryText),
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayList.length,
                            itemBuilder: (_, idx) {
                              final Map prod = displayList[idx] as Map;
                              final dynamic pId = prod['id'];
                              final String pName =
                                  (prod['name'] ?? 'Product').toString();
                              final dynamic pPrice = prod['price'] ?? 0;
                              final dynamic pStock =
                                  prod['stock_quantity'] ?? prod['stock'] ?? 0;
                              final dynamic currentShop =
                                  prod['shop'] ?? prod['shop_id'];
                              final String currentShopName =
                                  (prod['shop_name'] ?? '').toString();
                              final bool isAssigned = (currentShop != null &&
                                      currentShop.toString() ==
                                          shopId.toString()) ||
                                  (currentShopName.isNotEmpty &&
                                      currentShopName.toLowerCase() ==
                                          shopName.toLowerCase());

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isAssigned
                                      ? t.primaryColor.withValues(alpha: 0.1)
                                      : t.inputBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isAssigned
                                        ? t.primaryColor
                                        : t.cardBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: t.primaryText,
                                            ),
                                          ),
                                          Text(
                                            '৳$pPrice • Stock: $pStock pcs',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: t.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isAssigned
                                            ? Colors.redAccent
                                            : t.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final dynamic nextShopVal =
                                            isAssigned ? null : shopId;
                                        setModalState(() {
                                          prod['shop'] = nextShopVal;
                                          prod['shop_id'] = nextShopVal;
                                          prod['shop_name'] =
                                              isAssigned ? '' : shopName;
                                        });

                                        try {
                                          final String sub =
                                              Uri.encodeComponent(t.subdomain);
                                          await http.patch(
                                            Uri.parse(
                                              '${t.apiBase}/api/v1/products/$pId/?subdomain=$sub',
                                            ),
                                            headers: t.headers,
                                            body: jsonEncode({
                                              'shop': nextShopVal,
                                              'shop_id': nextShopVal,
                                            }),
                                          );
                                          await _fetchShopsFromBackend();
                                          if (mounted) setState(() {});
                                        } catch (_) {}
                                      },
                                      child: Text(
                                        isAssigned ? 'Remove' : '+ Assign',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  List get _filteredShops {
    final String q = _searchQuery.trim().toLowerCase();
    return _shops.where((raw) {
      if (raw is! Map) return false;
      final bool isActive = raw['is_active'] != false;
      if (_statusFilter == 'active' && !isActive) return false;
      if (_statusFilter == 'inactive' && isActive) return false;

      if (q.isNotEmpty) {
        final String name = (raw['name'] ?? '').toString().toLowerCase();
        final String cat =
            (raw['category_label'] ?? '').toString().toLowerCase();
        final String addr = (raw['address'] ?? '').toString().toLowerCase();
        final String phone = (raw['phone'] ?? '').toString().toLowerCase();
        if (!name.contains(q) &&
            !cat.contains(q) &&
            !addr.contains(q) &&
            !phone.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final List filtered = _filteredShops;

    int activeCount = 0;
    int totalAssignedProds = 0;
    for (final raw in _shops) {
      if (raw is! Map) continue;
      if (raw['is_active'] != false) activeCount++;
      final int pCnt = int.tryParse(
            (raw['total_products'] ?? raw['products_count'] ?? 0).toString(),
          ) ??
          0;
      totalAssignedProds += pCnt;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Hero Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _primaryDecoration(t, radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Internal Shops & Outlets',
                                  style: TextStyle(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$activeCount ACTIVE STORES',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Create and manage stores of different categories under the same merchant.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _initAndFetch(forceRefresh: true),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildStatBox('Total Shops', '${_shops.length}'),
                    const SizedBox(width: 8),
                    _buildStatBox('Active Shops', '$activeCount'),
                    const SizedBox(width: 8),
                    _buildStatBox('Shop Products', '$totalAssignedProds'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Mode Switcher
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 'list'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: _activeTab == 'list'
                          ? _primaryDecoration(t, radius: 12)
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_mall_directory_rounded,
                            size: 17,
                            color: _activeTab == 'list'
                                ? Colors.white
                                : t.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Shop List (${_shops.length})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: _activeTab == 'list'
                                  ? Colors.white
                                  : t.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _resetForm();
                      setState(() => _activeTab = 'add');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: _activeTab == 'add'
                          ? _primaryDecoration(t, radius: 12)
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_business_rounded,
                            size: 17,
                            color: _activeTab == 'add'
                                ? Colors.white
                                : t.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _editingShop != null ? 'Edit Shop' : '+ Add New Shop',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: _activeTab == 'add'
                                  ? Colors.white
                                  : t.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_activeTab == 'add')
            _buildAddOrEditShopForm(t)
          else ...[
            _buildSearchAndFilterBar(t),
            const SizedBox(height: 14),
            if (_isLoading && _shops.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: t.primaryColor),
                ),
              )
            else if (filtered.isEmpty)
              _buildEmptyShopsState(t)
            else if (_layoutMode == '1_row')
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filtered.map((raw) {
                    final Map shop = Map.from(raw as Map);
                    return Container(
                      width: 325,
                      margin: const EdgeInsets.only(right: 12),
                      child: _buildShopCard(t, shop),
                    );
                  }).toList(),
                ),
              )
            else
              ...filtered.map((raw) {
                final Map shop = Map.from(raw as Map);
                return _buildShopCard(t, shop);
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: t.primaryText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by store name, category, phone or address...',
              hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
              prefixIcon:
                  Icon(Icons.search_rounded, color: t.primaryColor, size: 19),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: t.inputBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.cardBorder),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in [
                  {'k': 'all', 'l': 'All Outlets'},
                  {'k': 'active', 'l': 'Active Only'},
                  {'k': 'inactive', 'l': 'Inactive'},
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () =>
                          setState(() => _statusFilter = f['k'].toString()),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: _statusFilter == f['k']
                            ? _primaryDecoration(t, radius: 10)
                            : BoxDecoration(
                                color: t.inputBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.cardBorder),
                              ),
                        child: Text(
                          f['l'].toString(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _statusFilter == f['k']
                                ? Colors.white
                                : t.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                for (final l in [
                  {'k': '1_row', 'l': '1 Row (Scroll)'},
                  {'k': 'grid', 'l': 'Grid / List'},
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _setLayoutMode(l['k'].toString()),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: _layoutMode == l['k']
                            ? BoxDecoration(
                                color: const Color(0xFF9333EA),
                                borderRadius: BorderRadius.circular(10),
                              )
                            : BoxDecoration(
                                color: t.inputBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.cardBorder),
                              ),
                        child: Text(
                          l['l'].toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _layoutMode == l['k']
                                ? Colors.white
                                : t.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(CatalogThemeConfig t, Map shop) {
    final String name = (shop['name'] ?? 'Shop Outlet').toString();
    final String slug = (shop['slug'] ?? '').toString();
    final String catLabel =
        (shop['category_label'] ?? 'INTERNAL SHOP').toString();
    final String desc = (shop['description'] ?? '').toString();
    final String phone = (shop['phone'] ?? 'Not set').toString();
    final String address =
        (shop['address'] ?? 'Main Store Location').toString();
    final String logoUrl =
        _resolveMediaUrl(shop['logo_url'] ?? shop['logo']);
    final String bannerUrl =
        _resolveMediaUrl(shop['banner_url'] ?? shop['banner']);
    final bool isActive = shop['is_active'] != false;
    final int prodCount = int.tryParse(
          (shop['total_products'] ?? shop['products_count'] ?? 0).toString(),
        ) ??
        0;
    final String emoji =
        CatalogThemeConfig.guessCategoryIcon('$catLabel $name');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? t.cardBorder
              : Colors.redAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bannerUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                bannerUrl,
                height: 75,
                width: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.cardBorder),
                ),
                child: logoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          logoUrl,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      )
                    : Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9333EA)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            catLabel.isEmpty
                                ? 'INTERNAL SHOP'
                                : catLabel.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFA855F7),
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _startEditingShop(shop),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: t.secondaryText,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deleteShop(shop),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: t.secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$prodCount Products Attached',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: t.secondaryText,
                          ),
                        ),
                        if (slug.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '/$slug',
                            style: TextStyle(
                              fontSize: 11,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeColor: t.primaryColor,
                onChanged: (v) => _toggleShopActive(shop, v),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.secondaryText),
            ),
          ],
          const SizedBox(height: 10),
          Divider(color: t.cardBorder, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 13.5,
                color: t.secondaryText,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  address.isEmpty ? 'Main Store Location' : address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: t.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.phone_outlined, size: 13.5, color: t.secondaryText),
              const SizedBox(width: 4),
              Text(
                phone.isEmpty ? 'N/A' : phone,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: t.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openShopCategoriesModal(shop),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9333EA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 14,
                          color: Color(0xFFA855F7),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFA855F7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _openShopProductsModal(shop),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: _primaryDecoration(t, radius: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View Products ($prodCount)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddOrEditShopForm(CatalogThemeConfig t) {
    final bool isEditing = _editingShop != null;
    final String existingLogoUrl = _resolveMediaUrl(
      _editingShop?['logo_url'] ?? _editingShop?['logo'],
    );
    final String existingBannerUrl = _resolveMediaUrl(
      _editingShop?['banner_url'] ?? _editingShop?['banner'],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: _primaryDecoration(t, radius: 12),
                      child: Icon(
                        isEditing
                            ? Icons.edit_note_rounded
                            : Icons.add_business_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit Shop: ${_editingShop!['name']}'
                                : 'Add new shop',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            'Department shop inside your main store (No separate login required)',
                            style: TextStyle(
                              fontSize: 11,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  _resetForm();
                  setState(() => _activeTab = 'list');
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(
            t,
            controller: _nameCtrl,
            label: 'Store name *',
            hint: 'e.g. Nex Shoe, Shopno',
            icon: Icons.storefront_rounded,
            onChanged: (val) {
              if (!isEditing) {
                _slugCtrl.text = _generateSlug(val);
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Category tag (LABEL)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: t.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categoryPresets.map((preset) {
                final bool selected =
                    _categoryLabelCtrl.text.trim() == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(
                      () => _categoryLabelCtrl.text = preset.toString(),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: selected
                          ? _primaryDecoration(t, radius: 10)
                          : BoxDecoration(
                              color: t.inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.cardBorder),
                            ),
                      child: Text(
                        preset.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : t.primaryText,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          _buildInputField(
            t,
            controller: _categoryLabelCtrl,
            label: 'Category tag (LABEL)',
            hint: 'e.g. Footwear & Shoes, Clothing & Fashion',
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  t,
                  controller: _phoneCtrl,
                  label: 'Phone number',
                  hint: '017xxxxxxxx',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInputField(
                  t,
                  controller: _addressCtrl,
                  label: 'Address',
                  hint: 'Khulna, Bangladesh',
                  icon: Icons.location_on_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 14,
                            color: t.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Shop logo',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: t.cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.cardBorder),
                            ),
                            child: _pickedLogoBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.memory(
                                      _pickedLogoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : (existingLogoUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(9),
                                        child: Image.network(
                                          existingLogoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.storefront_rounded,
                                            color: t.secondaryText,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.storefront_rounded,
                                        color: t.secondaryText,
                                      )),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final picked =
                                    await _pickImageFromDeviceOrUrl();
                                if (picked != null &&
                                    picked['bytes'] is Uint8List) {
                                  setState(() {
                                    _pickedLogoBytes =
                                        picked['bytes'] as Uint8List;
                                    _pickedLogoName =
                                        picked['name'].toString();
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9333EA)
                                    .withValues(alpha: 0.2),
                                foregroundColor: const Color(0xFFA855F7),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _pickedLogoBytes != null
                                    ? 'Logo Ready'
                                    : 'Logo upload',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
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
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 14,
                            color: t.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Shop banner',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: t.cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.cardBorder),
                            ),
                            child: _pickedBannerBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.memory(
                                      _pickedBannerBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : (existingBannerUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(9),
                                        child: Image.network(
                                          existingBannerUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.panorama_outlined,
                                            color: t.secondaryText,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.panorama_outlined,
                                        color: t.secondaryText,
                                      )),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final picked =
                                    await _pickImageFromDeviceOrUrl();
                                if (picked != null &&
                                    picked['bytes'] is Uint8List) {
                                  setState(() {
                                    _pickedBannerBytes =
                                        picked['bytes'] as Uint8List;
                                    _pickedBannerName =
                                        picked['name'].toString();
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9333EA)
                                    .withValues(alpha: 0.2),
                                foregroundColor: const Color(0xFFA855F7),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _pickedBannerBytes != null
                                    ? 'Banner Ready'
                                    : 'Banner upload',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
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
            ],
          ),
          const SizedBox(height: 12),
          _buildInputField(
            t,
            controller: _descCtrl,
            label: 'Overview',
            hint: 'Write something about the shop...',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: t.primaryColor,
            title: Text(
              'Shop Active on Storefront',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: t.primaryText,
              ),
            ),
            subtitle: Text(
              'Customers can browse this shop without logging in',
              style: TextStyle(fontSize: 11, color: t.secondaryText),
            ),
            value: _formIsActive,
            onChanged: (v) => setState(() => _formIsActive = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _resetForm();
                    setState(() => _activeTab = 'list');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.secondaryText,
                    side: BorderSide(color: t.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSaving ? null : _submitShopForm,
                  icon: Icon(
                    isEditing
                        ? Icons.check_circle_outline_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 19,
                  ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : (isEditing ? 'Update Shop' : 'Add'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    CatalogThemeConfig t, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    ValueChanged? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: (v) {
            if (onChanged != null) onChanged(v);
          },
          style: TextStyle(
            color: t.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
            prefixIcon: Icon(icon, color: t.primaryColor, size: 18),
            filled: true,
            fillColor: t.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: t.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: t.cardBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyShopsState(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_rounded, size: 46, color: t.primaryColor),
          const SizedBox(height: 10),
          Text(
            'No Internal Shops Found',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create department shops (like Best Shoes, Baby Care, Fast Food) inside your main store.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: t.secondaryText),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              _resetForm();
              setState(() => _activeTab = 'add');
            },
            icon: const Icon(Icons.add_business_rounded, size: 18),
            label: const Text(
              '+ Create First Shop',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}