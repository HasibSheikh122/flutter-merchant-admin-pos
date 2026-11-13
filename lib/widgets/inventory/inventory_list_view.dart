// lib/widgets/inventory/inventory_list_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../catalog/catalog_theme_scope.dart';
import 'inventory_modals.dart';
import 'inventory_profit_analytics_modal.dart';

class InventoryListView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onDataChanged;

  const InventoryListView({
    super.key,
    required this.isDarkMode,
    this.brandGreen = const Color(0xFF5B9A42),
    this.onDataChanged,
  });

  @override
  State<InventoryListView> createState() => _InventoryListViewState();
}

class _InventoryListViewState extends State<InventoryListView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;

  List<dynamic> _inventories = [];
  String _searchQuery = '';
  String _filterType = 'all';
  // 'all', 'low_stock', 'reorder', 'high_profit', 'loss_makers', 'dead_stock', 'coupon_discounted'
  String _sortBy = 'default';
  // 'default', 'profit_desc', 'unit_profit_desc', 'capital_desc', 'stock_asc'

  final TextEditingController _barcodeScanCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant InventoryListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _loadTheme();
    }
  }

  @override
  void dispose() {
    _barcodeScanCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) setState(() => _theme = t);
  }

  Future<void> _initAndFetch() async {
    await _loadTheme();
    await _fetchInventories();
  }

  String _resolveMediaUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final clean = raw.trim();
    if (clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('data:')) {
      return clean;
    }
    if (clean.startsWith('/')) return '${_theme.apiBase}$clean';
    return '${_theme.apiBase}/$clean';
  }

  // Helper: safely extracts or computes unit profit, margin, stock capital & projected profit
  Map<String, double> _extractFinancials(Map item) {
    final int stockQty =
        int.tryParse((item['stock_quantity'] ?? 0).toString()) ?? 0;
    final int soldQty =
        int.tryParse((item['total_sold_qty'] ?? 0).toString()) ?? 0;
    final int damagedQty =
        int.tryParse((item['damaged_quantity'] ?? 0).toString()) ?? 0;

    final double tp =
        double.tryParse((item['trade_price'] ?? 0).toString()) ?? 0.0;
    final double sell =
        double.tryParse((item['selling_price'] ?? 0).toString()) ?? 0.0;

    double unitProfit =
        double.tryParse((item['unit_profit'] ?? 0).toString()) ?? 0.0;
    if (unitProfit == 0.0 && tp > 0 && sell > 0) {
      unitProfit = sell - tp;
    }

    double marginPct =
        double.tryParse((item['margin_percent'] ?? 0).toString()) ?? 0.0;
    if (marginPct == 0.0 && sell > 0 && tp > 0) {
      marginPct = ((sell - tp) / sell) * 100.0;
    }

    double stockCost =
        double.tryParse((item['stock_cost_value'] ?? 0).toString()) ?? 0.0;
    if (stockCost == 0.0 && stockQty > 0 && tp > 0) {
      stockCost = stockQty * tp;
    }

    double stockRetail =
        double.tryParse((item['stock_retail_value'] ?? 0).toString()) ?? 0.0;
    if (stockRetail == 0.0 && stockQty > 0 && sell > 0) {
      stockRetail = stockQty * sell;
    }

    double projectedProfit =
        double.tryParse((item['projected_stock_profit'] ?? 0).toString()) ??
            0.0;
    if (projectedProfit == 0.0 && stockQty > 0 && tp > 0) {
      projectedProfit = stockQty * unitProfit;
    }

    final double netSalesRev =
        double.tryParse((item['total_sales_revenue'] ?? 0).toString()) ?? 0.0;
    final double totalCogs =
        double.tryParse((item['total_cogs'] ?? 0).toString()) ??
            (soldQty * tp);
    final double couponCut =
        double.tryParse((item['coupon_discount_amount'] ?? 0).toString()) ??
            0.0;
    final double damageLoss =
        double.tryParse((item['damage_loss_amount'] ?? 0).toString()) ??
            (damagedQty * (tp > 0 ? tp : sell));
    final double netRealizedProfit =
        double.tryParse((item['net_realized_profit'] ?? 0).toString()) ?? 0.0;

    return {
      'tp': tp,
      'sell': sell,
      'unit_profit': unitProfit,
      'margin_pct': marginPct,
      'stock_cost': stockCost,
      'stock_retail': stockRetail,
      'projected_profit': projectedProfit,
      'net_sales_rev': netSalesRev,
      'total_cogs': totalCogs,
      'coupon_cut': couponCut,
      'damage_loss': damageLoss,
      'net_realized_profit': netRealizedProfit,
    };
  }

  Future<void> _fetchInventories() async {
    setState(() => _isLoading = true);
    try {
      final t = _theme;
      final res = await http.get(
        Uri.parse(
          '${t.apiBase}/api/v1/inventory/?subdomain=${t.subdomain}&all_branches=true',
        ),
        headers: {...t.headers, 'X-Branch-ID': 'all'},
      );
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        if (raw is List) {
          _inventories = raw;
        } else if (raw is Map && raw['results'] is List) {
          _inventories = raw['results'];
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scanBarcodeLookup() async {
    final code = _barcodeScanCtrl.text.trim();
    if (code.isEmpty) return;

    try {
      final t = _theme;
      final res = await http.get(
        Uri.parse(
          '${t.apiBase}/api/v1/inventory/scan/?code=${Uri.encodeComponent(code)}&subdomain=${t.subdomain}',
        ),
        headers: {...t.headers, 'X-Branch-ID': 'all'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final item = jsonDecode(res.body);
        if (item is Map) {
          _openAdjustStockModal(item);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'$code' কোডের কোনো প্রোডাক্ট খুঁজে পাওয়া যায়নি।"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (_) {}
  }

  void _openAdjustStockModal(Map item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryAdjustStockModal(
        item: item,
        theme: _theme,
        onSuccess: () {
          _fetchInventories();
          widget.onDataChanged?.call();
        },
      ),
    );
  }

  void _openProfitAndTpModal(Map item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryProfitAnalyticsModal(
        item: item,
        theme: _theme,
        onUpdated: () {
          _fetchInventories();
          widget.onDataChanged?.call();
        },
      ),
    );
  }

  void _openAuditLogsModal(Map item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryLogsModal(
        item: item,
        theme: _theme,
      ),
    );
  }

  void _openFinancialLedgerModal(String tab) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryFinancialLedgerModal(
        initialTab: tab,
        theme: _theme,
      ),
    );
  }

  List<dynamic> get _filteredInventories {
    final list = _inventories.where((raw) {
      if (raw is! Map) return false;

      final fin = _extractFinancials(raw);
      final bool isLow = raw['is_low_stock'] == true;
      final bool needsReorder = raw['needs_reorder'] == true;
      final double netProf = fin['net_realized_profit'] ?? 0.0;
      final double unitProf = fin['unit_profit'] ?? 0.0;
      final double couponCut = fin['coupon_cut'] ?? 0.0;
      final String abc = (raw['abc_category'] ?? '').toString();

      if (_filterType == 'low_stock' && !isLow) return false;
      if (_filterType == 'reorder' && !needsReorder) return false;
      if (_filterType == 'high_profit' && netProf <= 0 && unitProf <= 0) {
        return false;
      }
      if (_filterType == 'loss_makers' &&
          netProf >= 0 &&
          unitProf >= 0 &&
          abc != 'loss_maker') {
        return false;
      }
      if (_filterType == 'dead_stock' && abc != 'dead_stock') return false;
      if (_filterType == 'coupon_discounted' && couponCut <= 0) return false;

      final q = _searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        final name = (raw['product_name'] ?? '').toString().toLowerCase();
        final sku = (raw['sku'] ?? '').toString().toLowerCase();
        final bar = (raw['barcode'] ?? '').toString().toLowerCase();
        final wh = (raw['warehouse_location'] ?? '').toString().toLowerCase();
        if (!name.contains(q) &&
            !sku.contains(q) &&
            !bar.contains(q) &&
            !wh.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) {
      final ma = a as Map;
      final mb = b as Map;
      final fa = _extractFinancials(ma);
      final fb = _extractFinancials(mb);

      if (_sortBy == 'profit_desc') {
        final pa = (fa['net_realized_profit'] ?? 0.0) != 0
            ? (fa['net_realized_profit'] ?? 0.0)
            : (fa['projected_profit'] ?? 0.0);
        final pb = (fb['net_realized_profit'] ?? 0.0) != 0
            ? (fb['net_realized_profit'] ?? 0.0)
            : (fb['projected_profit'] ?? 0.0);
        return pb.compareTo(pa);
      }
      if (_sortBy == 'unit_profit_desc') {
        return (fb['unit_profit'] ?? 0.0).compareTo(fa['unit_profit'] ?? 0.0);
      }
      if (_sortBy == 'capital_desc') {
        return (fb['stock_cost'] ?? 0.0).compareTo(fa['stock_cost'] ?? 0.0);
      }
      if (_sortBy == 'stock_asc') {
        final sa =
            int.tryParse((ma['available_quantity'] ?? 0).toString()) ?? 0;
        final sb =
            int.tryParse((mb['available_quantity'] ?? 0).toString()) ?? 0;
        return sa.compareTo(sb);
      }
      return 0;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    int totalUnits = 0;
    int lowStockCount = 0;
    int damagedProductsCount = 0;
    double totalTpCapital = 0.0;
    double totalRetailValue = 0.0;
    double totalProjectedProfit = 0.0;
    double totalNetSalesRev = 0.0;
    double totalCogs = 0.0;
    double totalNetProfit = 0.0;
    double totalCouponCuts = 0.0;
    double totalDamageLoss = 0.0;

    for (final item in _inventories) {
      if (item is Map) {
        final fin = _extractFinancials(item);
        totalUnits +=
            int.tryParse((item['stock_quantity'] ?? 0).toString()) ?? 0;
        if (item['is_low_stock'] == true) lowStockCount++;
        final dmgQty =
            int.tryParse((item['damaged_quantity'] ?? 0).toString()) ?? 0;
        if (dmgQty > 0) damagedProductsCount++;

        totalTpCapital += fin['stock_cost'] ?? 0.0;
        totalRetailValue += fin['stock_retail'] ?? 0.0;
        totalProjectedProfit += fin['projected_profit'] ?? 0.0;
        totalNetSalesRev += fin['net_sales_rev'] ?? 0.0;
        totalCogs += fin['total_cogs'] ?? 0.0;
        totalNetProfit += fin['net_realized_profit'] ?? 0.0;
        totalCouponCuts += fin['coupon_cut'] ?? 0.0;
        totalDamageLoss += fin['damage_loss'] ?? 0.0;
      }
    }

    final filtered = _filteredInventories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopHeroCard(
          totalSkus: _inventories.length,
          totalUnits: totalUnits,
          lowStockCount: lowStockCount,
          damagedProductsCount: damagedProductsCount,
          totalTpCapital: totalTpCapital,
          totalRetailValue: totalRetailValue,
          totalProjectedProfit: totalProjectedProfit,
          totalNetSalesRev: totalNetSalesRev,
          totalCogs: totalCogs,
          totalNetProfit: totalNetProfit,
          totalCouponCuts: totalCouponCuts,
          totalDamageLoss: totalDamageLoss,
        ),
        const SizedBox(height: 14),
        _buildSearchAndBarcodeCard(t),
        const SizedBox(height: 14),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: t.primaryColor),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 38,
                  color: t.primaryColor,
                ),
                const SizedBox(height: 10),
                Text(
                  'No Inventory Items Found',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              return _buildInventoryCard(filtered[idx] as Map);
            },
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTopHeroCard({
    required int totalSkus,
    required int totalUnits,
    required int lowStockCount,
    required int damagedProductsCount,
    required double totalTpCapital,
    required double totalRetailValue,
    required double totalProjectedProfit,
    required double totalNetSalesRev,
    required double totalCogs,
    required double totalNetProfit,
    required double totalCouponCuts,
    required double totalDamageLoss,
  }) {
    final t = _theme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: invPrimaryDecoration(t, radius: 24),
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
                  Icons.shelves,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Warehouse, Profit/Loss & Coupon Ledger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$totalSkus Items • $totalUnits Units in Stock • $lowStockCount Low Stock',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _fetchInventories,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row 1 of Web KPI Cards: Stock Capital (TP), Projected Profit, Net Sold Revenue
          Row(
            children: [
              _buildHeroMetricBox(
                title: 'STOCK CAPITAL (TP)',
                value: '৳${totalTpCapital.toStringAsFixed(0)}',
                subtitle: 'Purchase Capital',
                valueColor: const Color(0xFFFDE047),
              ),
              const SizedBox(width: 8),
              _buildHeroMetricBox(
                title: 'PROJECTED PROFIT',
                value: '+৳${totalProjectedProfit.toStringAsFixed(0)}',
                subtitle: 'Retail: ৳${totalRetailValue.toStringAsFixed(0)}',
                valueColor: const Color(0xFF6EE7B7),
              ),
              const SizedBox(width: 8),
              _buildHeroMetricBox(
                title: 'NET SOLD REVENUE',
                value: '৳${totalNetSalesRev.toStringAsFixed(0)}',
                subtitle: 'COGS: ৳${totalCogs.toStringAsFixed(0)}',
                valueColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2 of Web KPI Cards: Actual Net Profit/Loss, Coupon Discount, Damage & Loss
          Row(
            children: [
              _buildHeroMetricBox(
                title: 'ACTUAL NET PROFIT',
                value:
                    '${totalNetProfit >= 0 ? "+" : ""}৳${totalNetProfit.toStringAsFixed(0)}',
                subtitle: 'Realized from Sales',
                valueColor: totalNetProfit >= 0
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFFFCA5A5),
              ),
              const SizedBox(width: 8),
              _buildHeroMetricBox(
                title: 'COUPON DISCOUNT',
                value: '-৳${totalCouponCuts.toStringAsFixed(0)}',
                subtitle: 'Deducted on Orders',
                valueColor: const Color(0xFFF9A8D4),
              ),
              const SizedBox(width: 8),
              _buildHeroMetricBox(
                title: 'DAMAGE & LOSS',
                value: '-৳${totalDamageLoss.toStringAsFixed(0)}',
                subtitle: '$damagedProductsCount Damaged SKUs',
                valueColor: const Color(0xFFFCA5A5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openFinancialLedgerModal('daily_stock'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: t.primaryColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Daily Stock Money Log',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openFinancialLedgerModal('coupons'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_offer_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Coupon Calculation (-৳${totalCouponCuts.toStringAsFixed(0)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
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

  Widget _buildHeroMetricBox({
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndBarcodeCard(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: t.primaryText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search product, SKU, barcode or shelf...',
                    hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: t.primaryColor,
                      size: 19,
                    ),
                    filled: true,
                    fillColor: t.inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _sortBy = v),
                color: t.cardBg,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: t.cardBorder),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'default',
                    child: Text(
                      'Latest Updated',
                      style: TextStyle(
                        color: t.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'unit_profit_desc',
                    child: Text(
                      'Highest Profit per Piece',
                      style: TextStyle(
                        color: t.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'profit_desc',
                    child: Text(
                      'Highest Total Profit',
                      style: TextStyle(
                        color: t.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'capital_desc',
                    child: Text(
                      'Highest TP Capital First',
                      style: TextStyle(
                        color: t.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'stock_asc',
                    child: Text(
                      'Lowest Stock First',
                      style: TextStyle(
                        color: t.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: t.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.sort_rounded,
                    color: t.primaryColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeScanCtrl,
                  onSubmitted: (_) => _scanBarcodeLookup(),
                  style: TextStyle(color: t.primaryText, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Scan Barcode / SKU...',
                    hintStyle:
                        TextStyle(color: t.secondaryText, fontSize: 11.5),
                    prefixIcon: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: t.primaryColor,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: t.inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
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
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _scanBarcodeLookup,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: invPrimaryDecoration(t, radius: 12),
                  child: const Text(
                    'Scan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Items'),
                const SizedBox(width: 6),
                _buildFilterChip('high_profit', 'Profitable Stars'),
                const SizedBox(width: 6),
                _buildFilterChip('coupon_discounted', 'Coupon Used'),
                const SizedBox(width: 6),
                _buildFilterChip('loss_makers', 'Loss & Damage'),
                const SizedBox(width: 6),
                _buildFilterChip('dead_stock', 'Dead Stock Trap'),
                const SizedBox(width: 6),
                _buildFilterChip('low_stock', 'Low Stock Alerts'),
                const SizedBox(width: 6),
                _buildFilterChip('reorder', 'Needs Reorder'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final active = _filterType == key;
    return GestureDetector(
      onTap: () => setState(() => _filterType = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: active
            ? invPrimaryDecoration(_theme, radius: 10)
            : BoxDecoration(
                color: _theme.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _theme.cardBorder),
              ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : _theme.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCard(Map item) {
    final t = _theme;
    final fin = _extractFinancials(item);

    final prodName = (item['product_name'] ?? 'Product').toString();
    final sku = (item['sku'] ?? '').toString();
    final imgUrl = _resolveMediaUrl(item['product_image']?.toString());
    final wh = (item['warehouse_location'] ?? 'Main Warehouse').toString();
    final shelf = (item['shelf_location'] ?? 'A1').toString();
    final bin = (item['bin_number'] ?? 'B1').toString();

    final stockQty =
        int.tryParse((item['stock_quantity'] ?? 0).toString()) ?? 0;
    final availQty =
        int.tryParse((item['available_quantity'] ?? 0).toString()) ?? 0;
    final soldQty =
        int.tryParse((item['total_sold_qty'] ?? 0).toString()) ?? 0;
    final damagedQty =
        int.tryParse((item['damaged_quantity'] ?? 0).toString()) ?? 0;
    final isLow = item['is_low_stock'] == true;

    final double tp = fin['tp'] ?? 0.0;
    final double sell = fin['sell'] ?? 0.0;
    final double unitProfit = fin['unit_profit'] ?? 0.0;
    final double marginPct = fin['margin_pct'] ?? 0.0;
    final double stockCost = fin['stock_cost'] ?? 0.0;
    final double projProfit = fin['projected_profit'] ?? 0.0;
    final double netProfit = fin['net_realized_profit'] ?? 0.0;
    final double couponCut = fin['coupon_cut'] ?? 0.0;

    final Color stockColor = availQty <= 0
        ? Colors.redAccent
        : (isLow ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLow
              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
              : t.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Image + Name + SKU + Purchased Capital + Stock Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  color: t.inputBg,
                  child: imgUrl.isNotEmpty
                      ? Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory_2_rounded,
                            color: t.primaryColor,
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_rounded,
                          color: t.primaryColor,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${sku.isNotEmpty ? sku : "N/A"} | Purchased Capital: ৳${stockCost.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: t.secondaryText,
                      ),
                    ),
                    Text(
                      '$wh • Shelf: $shelf • Bin: $bin',
                      style: TextStyle(fontSize: 10, color: t.secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: stockColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '$availQty in stock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: stockColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Web-matched TP vs Sell Price & Profit per Piece Banner
          GestureDetector(
            onTap: () => _openProfitAndTpModal(item),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: t.inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: TP -> Sell + Profit per piece (Just like Web!)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'TP: ৳${tp.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: t.secondaryText,
                                  ),
                                ),
                                Text(
                                  '৳${sell.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: t.primaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tp > 0
                                  ? 'Profit per piece ${unitProfit >= 0 ? "+" : ""}৳${unitProfit.toStringAsFixed(0)} (${marginPct.toStringAsFixed(1)}%)'
                                  : 'TP not set — Tap to set TP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: unitProfit >= 0
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right: Projected Stock Profit & Realized Profit/Loss pill
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (netProfit > 0 || projProfit > 0)
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.12)
                                  : t.cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (netProfit > 0 || projProfit > 0)
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.35)
                                    : t.cardBorder,
                              ),
                            ),
                            child: Text(
                              soldQty > 0 || netProfit != 0
                                  ? 'Sold P&L: ${netProfit >= 0 ? "+" : ""}৳${netProfit.toStringAsFixed(0)}'
                                  : 'Stock Profit: +৳${projProfit.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: (netProfit >= 0 && projProfit >= 0)
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            soldQty > 0
                                ? 'Sold: $soldQty pcs'
                                : '৳0 (Break-even • Sold: 0 pcs)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Sub-row: Total, Sold, Damaged & Coupon Cut
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Total: $stockQty pcs • Sold: $soldQty pcs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.secondaryText,
                ),
              ),
              if (damagedQty > 0)
                Text(
                  '• Damaged: $damagedQty pcs',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
              if (couponCut > 0)
                Text(
                  '• Coupon Cut: -৳${couponCut.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF59E0B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: t.cardBorder),
          const SizedBox(height: 10),

          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openAdjustStockModal(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: invPrimaryDecoration(t, radius: 10),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_box_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Adjust Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openProfitAndTpModal(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: t.primaryColor.withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 14,
                          color: t.primaryColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'P&L / TP Edit',
                          style: TextStyle(
                            color: t.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openAuditLogsModal(item),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 14,
                        color: t.primaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Logs',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}