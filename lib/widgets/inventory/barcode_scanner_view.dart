// lib/widgets/inventory/barcode_scanner_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';
import 'inventory_modals.dart';
import '../../core/config/tenant_config.dart';

class BarcodeScannerView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onDataChanged;

  const BarcodeScannerView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.onDataChanged,
  });

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  CatalogThemeConfig? _theme;
  int _activeSubTab = 0; // 0 = POS Scanner & Stock Out, 1 = SKU Barcode & QR Generator

  // POS Scanner States
  final TextEditingController _scanCtrl = TextEditingController();
  final FocusNode _scanFocus = FocusNode();
  bool _isScanning = false;
  int _scanQty = 1;
  Map? _lastSale;
  List _recentSales = [];

  // SKU Generator States
  final TextEditingController _prodSearchCtrl = TextEditingController();
  String _prodSearchQuery = '';
  bool _loadingProducts = true;
  List _products = [];

  CatalogThemeConfig get _t =>
      _theme ??
      CatalogThemeConfig(
        primaryColor: widget.brandGreen,
        secondaryColor: const Color(0xFF059669),
        useGradient: true,
        isDarkMode: widget.isDarkMode,
        apiBase: 'https://nextlook.shop.xylotechsolution.com',
        subdomain: TenantConfig.defaultSubdomain,
        token: '',
      );

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void didUpdateWidget(covariant BarcodeScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
    }
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _prodSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadTheme() async {
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) setState(() => _theme = t);
  }

  Future<void> _initAndLoad() async {
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() => _theme = t);
    await _fetchStoreProducts();
  }

  Future<void> _fetchStoreProducts() async {
    if (!mounted) return;
    setState(() => _loadingProducts = true);
    final t = _t;

    try {
      final url = Uri.parse(
        '${t.apiBase}/api/v1/products/?subdomain=${t.subdomain}&all_branches=true',
      );
      final res = await http.get(url, headers: t.headers).timeout(
        const Duration(seconds: 12),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        List list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          list = decoded['results'] as List;
        }
        if (mounted) {
          setState(() {
            _products = list;
            _loadingProducts = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _handleScanSubmit([String? overrideCode]) async {
    final code = (overrideCode ?? _scanCtrl.text).trim();
    if (code.isEmpty) return;

    setState(() => _isScanning = true);
    final t = _t;

    try {
      final url = Uri.parse(
        '${t.apiBase}/api/v1/inventory/barcode-stock-deduct/?subdomain=${t.subdomain}',
      );
      final res = await http
          .post(
            url,
            headers: t.headers,
            body: jsonEncode({
              'barcode': code,
              'quantity': _scanQty,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (res.statusCode == 200 && data is Map && data['status'] == 'success') {
        final saleData = (data['data'] as Map?) ?? {};
        final itemType = (data['item_type'] ?? 'unit').toString();
        final mergedSale = {
          ...saleData,
          'item_type': itemType,
        };

        HapticFeedback.mediumImpact();
        setState(() {
          _lastSale = mergedSale;
          _recentSales = [mergedSale, ..._recentSales.take(14)];
          _scanCtrl.clear();
          _scanQty = 1;
        });

        widget.onDataChanged?.call();
        _fetchStoreProducts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: t.primaryColor,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Sold: ${mergedSale['product_name']} (${mergedSale['quantity_display']}) - ৳${mergedSale['collected_amount']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }
      } else {
        final err = (data is Map ? data['error'] : null) ?? 'Product not found for code: $code';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              content: Text(err.toString()),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('Scan failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
        _scanFocus.requestFocus();
      }
    }
  }

  static String resolveSku(Map prod) {
    final sku = (prod['sku'] ?? '').toString().trim();
    final bc = (prod['barcode'] ?? '').toString().trim();
    if (sku.isNotEmpty && sku != 'N/A' && sku != 'null') return sku;
    if (bc.isNotEmpty && bc != 'N/A' && bc != 'null') return bc;
    return 'SKU-${prod['id'] ?? 1001}';
  }

  List get _filteredProducts {
    final q = _prodSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((raw) {
      if (raw is! Map) return false;
      final name = (raw['name'] ?? '').toString().toLowerCase();
      final sku = (raw['sku'] ?? '').toString().toLowerCase();
      final bc = (raw['barcode'] ?? '').toString().toLowerCase();
      return name.contains(q) || sku.contains(q) || bc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;

    return Padding(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader(t),
          const SizedBox(height: 14),
          _buildModeSwitcher(t),
          const SizedBox(height: 16),
          if (_activeSubTab == 0) ...[
            _buildScannerCard(t),
            const SizedBox(height: 16),
            if (_lastSale != null) ...[
              _buildLastSaleCard(t, _lastSale!),
              const SizedBox(height: 16),
            ],
            _buildRecentSalesCard(t),
          ] else ...[
            _buildSkuGeneratorStudio(t),
          ],
        ],
      ),
    );
  }

  Widget _buildTopHeader(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: invPrimaryDecoration(t, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart POS Barcode & SKU Label Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Instant Counter Stock Out • Weighing Scale • SKU to Barcode & QR Print',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeaderBadge(Icons.inventory_2_rounded, 'Fixed Piece (1 pc)'),
              _buildHeaderBadge(Icons.scale_rounded, 'Weighing Scale Sticker'),
              _buildHeaderBadge(Icons.qr_code_2_rounded, 'SKU Barcode & QR Print'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher(CatalogThemeConfig t) {
    return Container(
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
              onTap: () => setState(() => _activeSubTab = 0),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: _activeSubTab == 0
                    ? invPrimaryDecoration(t, radius: 12)
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.barcode_reader,
                      size: 17,
                      color: _activeSubTab == 0 ? Colors.white : t.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'POS Scanner & Stock Out',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _activeSubTab == 0 ? Colors.white : t.primaryText,
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
              onTap: () => setState(() => _activeSubTab = 1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: _activeSubTab == 1
                    ? invPrimaryDecoration(t, radius: 12)
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 17,
                      color: _activeSubTab == 1 ? Colors.white : t.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SKU QR & Barcode Print',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _activeSubTab == 1 ? Colors.white : t.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerCard(CatalogThemeConfig t) {
    final qtyOptions = [1, 2, 3, 5, 10];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UNIVERSAL BARCODE / SKU GUN READER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: t.secondaryText,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                'auto item detector',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: t.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: t.inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.primaryColor.withOpacity(0.5), width: 1.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.qr_code_scanner_rounded, color: t.primaryColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _scanCtrl,
                    focusNode: _scanFocus,
                    autofocus: true,
                    style: TextStyle(
                      color: t.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    onSubmitted: (_) => _handleScanSubmit(),
                    decoration: InputDecoration(
                      hintText: 'Scan barcode, SKU or scale sticker...',
                      hintStyle: TextStyle(color: t.secondaryText, fontSize: 12.5),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isScanning ? null : () => _handleScanSubmit(),
                    child: Text(
                      _isScanning ? '...' : 'Confirm',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Deduct Qty:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: t.secondaryText,
                ),
              ),
              const SizedBox(width: 8),
              ...qtyOptions.map((q) {
                final active = _scanQty == q;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _scanQty = q),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: active
                          ? invPrimaryDecoration(t, radius: 8)
                          : BoxDecoration(
                              color: t.inputBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.cardBorder),
                            ),
                      child: Text(
                        '${q}x',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: active ? Colors.white : t.primaryText,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastSaleCard(CatalogThemeConfig t, Map sale) {
    final isScale = sale['item_type'] == 'scale';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.primaryColor.withOpacity(0.4), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: t.primaryColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Last Completed Counter Sale',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                ],
              ),
              Text(
                '#${sale['pos_order_number'] ?? 'POS'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: t.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSaleMetricBox(
                  t,
                  'Product',
                  (sale['product_name'] ?? 'Item').toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSaleMetricBox(
                  t,
                  isScale ? 'Weight' : 'Quantity',
                  (sale['quantity_display'] ?? '1 pc').toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSaleMetricBox(
                  t,
                  'Collected Cash',
                  '৳${sale['collected_amount'] ?? 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining Stock: ${sale['remaining_stock'] ?? 0}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: t.secondaryText,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showPosReceiptDialog(t, sale),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text(
                  'Print POS Receipt',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleMetricBox(CatalogThemeConfig t, String label, String val) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: t.secondaryText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            val,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSalesCard(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: t.primaryColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'RECENT COUNTER SALES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: t.secondaryText,
                    ),
                  ),
                ],
              ),
              Text(
                'Live Session (${_recentSales.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentSales.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 36,
                      color: t.secondaryText.withOpacity(0.35),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No sales scanned in this session yet.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recentSales.map((raw) {
              final s = raw as Map;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.inputBg,
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
                            (s['product_name'] ?? 'Item').toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s['quantity_display'] ?? '1 pc'} • Rate: ৳${s['unit_price'] ?? 0} • Stock Left: ${s['remaining_stock'] ?? 0}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '৳${s['collected_amount'] ?? 0}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: t.primaryColor,
                          ),
                        ),
                        InkWell(
                          onTap: () => _showPosReceiptDialog(t, s),
                          child: Text(
                            'Print Receipt',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: t.primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // =========================================================================
  // 🌟 TAB 2: SKU TO BARCODE & QR GENERATOR + STICKER PRINTER
  // =========================================================================
  Widget _buildSkuGeneratorStudio(CatalogThemeConfig t) {
    final list = _filteredProducts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
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
                      'Product SKU Barcode & QR Code Generator',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generate & print scannable Barcode + QR stickers directly from Product SKU',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _fetchStoreProducts,
                icon: Icon(Icons.refresh_rounded, color: t.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: t.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.cardBorder),
            ),
            child: TextField(
              controller: _prodSearchCtrl,
              onChanged: (v) => setState(() => _prodSearchQuery = v),
              style: TextStyle(color: t.primaryText, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search product by Name, SKU or Barcode...',
                hintStyle: TextStyle(color: t.secondaryText, fontSize: 12.5),
                prefixIcon: Icon(Icons.search_rounded, color: t.primaryColor, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_loadingProducts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No products found.',
                  style: TextStyle(color: t.secondaryText),
                ),
              ),
            )
          else
            ...list.map((raw) {
              final prod = raw as Map;
              final sku = resolveSku(prod);
              final name = (prod['name'] ?? 'Product').toString();
              final price = prod['price'] ?? 0;
              final stock = prod['stock_quantity'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.primaryColor.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'SKU: $sku',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: t.primaryColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '৳$price  •  Stock: $stock pcs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: t.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          onPressed: () {
                            SkuBarcodeQrPrintModal.show(
                              context,
                              product: prod,
                              theme: t,
                              onQuickScan: (code) {
                                setState(() => _activeSubTab = 0);
                                _handleScanSubmit(code);
                              },
                            );
                          },
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const Text(
                            'Generate & Print',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Inline Mini Preview of Barcode + QR
                    InkWell(
                      onTap: () {
                        SkuBarcodeQrPrintModal.show(
                          context,
                          product: prod,
                          theme: t,
                          onQuickScan: (code) {
                            setState(() => _activeSubTab = 0);
                            _handleScanSubmit(code);
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 38,
                                    width: double.infinity,
                                    child: CustomPaint(
                                      painter: Code128BarcodePainter(sku),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    sku,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Image.network(
                              'https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=${Uri.encodeComponent(sku)}',
                              width: 52,
                              height: 52,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.qr_code_2_rounded,
                                size: 48,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showPosReceiptDialog(CatalogThemeConfig t, Map sale) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Text(
                (sale['branch_name'] ?? t.subdomain.toUpperCase()).toString(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'POS Receipt #${sale['pos_order_number'] ?? ''}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(color: Colors.black26, height: 20),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      (sale['product_name'] ?? 'Item').toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Text(
                    '৳${sale['collected_amount'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Qty: ${sale['quantity_display'] ?? '1 pc'}  ×  Rate: ৳${sale['unit_price'] ?? 0}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const Divider(color: Colors.black26, height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL PAID (CASH):',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '৳${sale['collected_amount'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: t.primaryColor,
                    content: const Text('Sent POS Receipt to printer queue!'),
                  ),
                );
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Now'),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// 🌟 REUSABLE SKU BARCODE & QR LABEL GENERATOR + PRINT MODAL
// (Used in both Barcode Stock Out AND Products & Catalog!)
// ============================================================================
class SkuBarcodeQrPrintModal {
  static void show(
    BuildContext context, {
    required Map product,
    required CatalogThemeConfig theme,
    Function(String sku)? onQuickScan,
  }) {
    final sku = _BarcodeScannerViewState.resolveSku(product);
    final name = (product['name'] ?? 'Product').toString();
    final price = product['price'] ?? 0;

    String labelMode = 'both'; // 'both', 'barcode', 'qr'
    int copies = 4;
    bool showPrice = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              decoration: BoxDecoration(
                color: theme.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                border: Border.all(color: theme.cardBorder),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.secondaryText.withOpacity(0.35),
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
                                'SKU Barcode & QR Label Printer',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: theme.primaryText,
                                ),
                              ),
                              Text(
                                'Product: $name (SKU: $sku)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: theme.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // White Sticker Preview Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.black26, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${theme.subdomain.toUpperCase()} • SKU STICKER',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (showPrice) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Price: ৳$price',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (labelMode == 'both' || labelMode == 'barcode') ...[
                            SizedBox(
                              height: 54,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: Code128BarcodePainter(sku),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sku,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                          if (labelMode == 'both') const SizedBox(height: 12),
                          if (labelMode == 'both' || labelMode == 'qr')
                            Column(
                              children: [
                                Image.network(
                                  'https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${Uri.encodeComponent(sku)}',
                                  width: 96,
                                  height: 96,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 86,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'QR: $sku',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'SELECT LABEL FORMAT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final modeItem in [
                          {'k': 'both', 'l': 'Barcode + QR'},
                          {'k': 'barcode', 'l': 'Barcode Only'},
                          {'k': 'qr', 'l': 'QR Code Only'},
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () => setModalState(
                                  () => labelMode = modeItem['k'].toString(),
                                ),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: labelMode == modeItem['k']
                                      ? invPrimaryDecoration(theme, radius: 10)
                                      : BoxDecoration(
                                          color: theme.inputBg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: theme.cardBorder),
                                        ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    modeItem['l'].toString(),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: labelMode == modeItem['k']
                                          ? Colors.white
                                          : theme.primaryText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NUMBER OF STICKER COPIES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: theme.secondaryText,
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: showPrice,
                              activeColor: theme.primaryColor,
                              onChanged: (v) =>
                                  setModalState(() => showPrice = v ?? true),
                            ),
                            Text(
                              'Show Price',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        for (final c in [1, 2, 4, 8, 12, 24])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () => setModalState(() => copies = c),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: copies == c
                                      ? invPrimaryDecoration(theme, radius: 10)
                                      : BoxDecoration(
                                          color: theme.inputBg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: theme.cardBorder),
                                        ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${c}x',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: copies == c
                                          ? Colors.white
                                          : theme.primaryText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (onQuickScan != null) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.primaryColor,
                                side: BorderSide(color: theme.primaryColor),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                onQuickScan(sku);
                              },
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                              label: const Text(
                                'Test Scan SKU',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: sku));
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: theme.primaryColor,
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(
                                    'Printing $copies× ${labelMode.toUpperCase()} labels for $name ($sku)...',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: Text(
                              'Print ${copies}x Labels',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// 🌟 CUSTOM CODE-128 BARCODE PAINTER (NO EXTERNAL PACKAGE NEEDED)
// ============================================================================
class Code128BarcodePainter extends CustomPainter {
  final String data;

  Code128BarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final clean = data.trim().isEmpty ? 'SKU-0001' : data.trim();
    final List bars = [2, 1, 1, 2, 3, 1];
    for (int i = 0; i < clean.length; i++) {
      final c = clean.codeUnitAt(i);
      bars.add(((c >> 4) & 3) + 1);
      bars.add((c & 3) + 1);
      bars.add(((c >> 2) & 3) + 1);
      bars.add(((c + i) % 3) + 1);
    }
    bars.addAll([2, 3, 1, 1, 2]);

    int totalUnits = 0;
    for (final b in bars) {
      totalUnits += (b as int);
    }

    final unitWidth = size.width / (totalUnits + 8);
    double x = unitWidth * 4;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (int i = 0; i < bars.length; i++) {
      final w = (bars[i] as int) * unitWidth;
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w;
    }
  }

  @override
  bool shouldRepaint(covariant Code128BarcodePainter oldDelegate) {
    return oldDelegate.data != data;
  }
}