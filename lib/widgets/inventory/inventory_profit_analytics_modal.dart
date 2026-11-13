// lib/widgets/inventory/inventory_profit_analytics_modal.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../catalog/catalog_theme_scope.dart';
import 'inventory_modals.dart';

class InventoryProfitAnalyticsModal extends StatefulWidget {
  final Map item;
  final CatalogThemeConfig theme;
  final VoidCallback onUpdated;

  const InventoryProfitAnalyticsModal({
    super.key,
    required this.item,
    required this.theme,
    required this.onUpdated,
  });

  @override
  State<InventoryProfitAnalyticsModal> createState() =>
      _InventoryProfitAnalyticsModalState();
}

class _InventoryProfitAnalyticsModalState
    extends State<InventoryProfitAnalyticsModal> {
  String _subTab = 'pnl'; // 'pnl', 'buyers', 'locations', 'restocks'
  bool _isLoadingAnalytics = true;
  bool _isSavingPricing = false;
  Map _analytics = {};

  late TextEditingController _tpCtrl;
  late TextEditingController _sellCtrl;
  late TextEditingController _warehouseCtrl;
  late TextEditingController _shelfCtrl;
  late TextEditingController _reorderCtrl;

  @override
  void initState() {
    super.initState();
    _tpCtrl = TextEditingController(
      text: (widget.item['trade_price'] ?? 0).toString(),
    );
    _sellCtrl = TextEditingController(
      text: (widget.item['selling_price'] ?? 0).toString(),
    );
    _warehouseCtrl = TextEditingController(
      text: (widget.item['warehouse_location'] ?? 'Main Warehouse').toString(),
    );
    _shelfCtrl = TextEditingController(
      text: (widget.item['shelf_location'] ?? 'A1').toString(),
    );
    _reorderCtrl = TextEditingController(
      text: (widget.item['reorder_point'] ?? 10).toString(),
    );
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _tpCtrl.dispose();
    _sellCtrl.dispose();
    _warehouseCtrl.dispose();
    _shelfCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final t = widget.theme;
      final id = widget.item['id'];
      final res = await http.get(
        Uri.parse(
          '${t.apiBase}/api/v1/inventory/$id/sales-analytics/?subdomain=${t.subdomain}',
        ),
        headers: {...t.headers, 'X-Branch-ID': 'all'},
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) _analytics = decoded;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingAnalytics = false);
    }
  }

  Future<void> _savePricingAndWarehouse() async {
    setState(() => _isSavingPricing = true);
    try {
      final t = widget.theme;
      final id = widget.item['id'];
      final res = await http.post(
        Uri.parse(
          '${t.apiBase}/api/v1/inventory/$id/update-pricing/?subdomain=${t.subdomain}',
        ),
        headers: {...t.headers, 'X-Branch-ID': 'all'},
        body: jsonEncode({
          'trade_price': _tpCtrl.text.trim(),
          'selling_price': _sellCtrl.text.trim(),
          'warehouse_location': _warehouseCtrl.text.trim(),
          'shelf_location': _shelfCtrl.text.trim(),
          'reorder_point': _reorderCtrl.text.trim(),
        }),
      );

      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _fetchAnalytics();
        widget.onUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'TP (কেনা দাম), Selling Price ও Warehouse সফলভাবে আপডেট হয়েছে!',
              ),
              backgroundColor: t.primaryColor,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed (${res.statusCode})'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPricing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final prodName = (widget.item['product_name'] ?? 'Product').toString();
    final sku = (widget.item['sku'] ?? '').toString();
    final summary = (_analytics['profit_summary'] is Map)
        ? (_analytics['profit_summary'] as Map)
        : {};
    final buyers = (_analytics['buyers'] is List)
        ? (_analytics['buyers'] as List)
        : [];
    final locations = (_analytics['top_locations'] is List)
        ? (_analytics['top_locations'] as List)
        : [];
    final stockAdds = (_analytics['stock_add_logs'] is List)
        ? (_analytics['stock_add_logs'] as List)
        : [];

    final double liveTp = double.tryParse(_tpCtrl.text.trim()) ??
        (double.tryParse((widget.item['trade_price'] ?? 0).toString()) ?? 0.0);
    final double liveSell = double.tryParse(_sellCtrl.text.trim()) ??
        (double.tryParse((widget.item['selling_price'] ?? 0).toString()) ??
            0.0);
    final int curStock =
        int.tryParse((widget.item['stock_quantity'] ?? 0).toString()) ?? 0;

    final double unitProfit = liveTp > 0 ? (liveSell - liveTp) : 0.0;
    final double unitMargin =
        (liveSell > 0 && liveTp > 0) ? ((unitProfit / liveSell) * 100.0) : 0.0;
    final double projStockProfit = curStock * unitProfit;

    final double netProfit = double.tryParse(
          (summary['net_realized_profit'] ??
                  widget.item['net_realized_profit'] ??
                  0)
              .toString(),
        ) ??
        0.0;
    final double netRev = double.tryParse(
          (summary['total_sales_revenue'] ??
                  widget.item['total_sales_revenue'] ??
                  0)
              .toString(),
        ) ??
        0.0;
    final double couponDisc = double.tryParse(
          (summary['total_coupon_discount'] ??
                  widget.item['coupon_discount_amount'] ??
                  0)
              .toString(),
        ) ??
        0.0;
    final double capRecovered = double.tryParse(
          (summary['capital_recovered_percent'] ?? 0).toString(),
        ) ??
        0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: t.cardBorder,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: invPrimaryDecoration(t, radius: 12),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 19,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    Text(
                      'Profit & Loss, TP Editor & Buyer Analytics${sku.isNotEmpty ? " • $sku" : ""}',
                      style: TextStyle(fontSize: 11, color: t.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: t.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabBtn('pnl', 'P&L & TP Edit'),
                const SizedBox(width: 6),
                _buildTabBtn('buyers', 'Buyers (${buyers.length})'),
                const SizedBox(width: 6),
                _buildTabBtn('locations', 'Top Cities (${locations.length})'),
                const SizedBox(width: 6),
                _buildTabBtn('restocks', 'Restock Money (${stockAdds.length})'),
              ],
            ),
          ),
          const Divider(height: 18),
          Expanded(
            child: _isLoadingAnalytics
                ? Center(
                    child: CircularProgressIndicator(color: t.primaryColor),
                  )
                : SingleChildScrollView(
                    child: _subTab == 'pnl'
                        ? _buildPnlAndTpEditor(
                            t: t,
                            unitProfit: unitProfit,
                            unitMargin: unitMargin,
                            projStockProfit: projStockProfit,
                            netProfit: netProfit,
                            netRev: netRev,
                            couponDisc: couponDisc,
                            capRecovered: capRecovered,
                            summary: summary,
                          )
                        : _subTab == 'buyers'
                            ? _buildBuyersTab(buyers, t)
                            : _subTab == 'locations'
                                ? _buildLocationsTab(locations, t)
                                : _buildRestocksTab(stockAdds, t),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String key, String label) {
    final active = _subTab == key;
    final t = widget.theme;
    return GestureDetector(
      onTap: () => setState(() => _subTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: active
            ? invPrimaryDecoration(t, radius: 10)
            : BoxDecoration(
                color: t.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.cardBorder),
              ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : t.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildPnlAndTpEditor({
    required CatalogThemeConfig t,
    required double unitProfit,
    required double unitMargin,
    required double projStockProfit,
    required double netProfit,
    required double netRev,
    required double couponDisc,
    required double capRecovered,
    required Map summary,
  }) {
    final bool isProfit = (netProfit != 0 ? netProfit : unitProfit) >= 0;
    final Color profCol =
        isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: profCol.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: profCol.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROFIT PER PIECE (${unitMargin.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: profCol,
                        ),
                      ),
                      Text(
                        '${unitProfit >= 0 ? "+" : ""}৳${unitProfit.toStringAsFixed(0)} / pc',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: profCol,
                        ),
                      ),
                      Text(
                        'Projected Stock Profit: +৳${projStockProfit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Realized Sold P&L: ${netProfit >= 0 ? "+" : ""}৳${netProfit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: profCol,
                        ),
                      ),
                      Text(
                        'Net Sales: ৳${netRev.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      Text(
                        'Coupon Cut: -৳${couponDisc.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (capRecovered / 100.0).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: t.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(profCol),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Capital Recovered: ${capRecovered.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10.5, color: t.secondaryText),
                  ),
                  Text(
                    'Break-even Left: ${summary['break_even_units_left'] ?? 0} pcs',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Update TP (কেনা দাম), Selling Price & Warehouse',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: t.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tpCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'TP / কেনা দাম (৳)',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 11.5),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _sellCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Selling Price (৳)',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 11.5),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _warehouseCtrl,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Warehouse',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 11.5),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _shelfCtrl,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Shelf',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 11.5),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _reorderCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Reorder Pt',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 11.5),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _isSavingPricing ? null : _savePricingAndWarehouse,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: invPrimaryDecoration(t, radius: 14),
            alignment: Alignment.center,
            child: Text(
              _isSavingPricing
                  ? 'Saving TP & Pricing...'
                  : 'Save TP, Selling Price & Location',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBuyersTab(List<dynamic> buyers, CatalogThemeConfig t) {
    if (buyers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'No customer purchases recorded for this product yet.',
            style: TextStyle(color: t.secondaryText, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      children: buyers.map((b) {
        if (b is! Map) return const SizedBox.shrink();
        final prof = double.tryParse((b['net_profit'] ?? 0).toString()) ?? 0.0;
        final disc =
            double.tryParse((b['coupon_discount'] ?? 0).toString()) ?? 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${b['customer_name']} (#${b['order_id']})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                  Text(
                    'Profit: ৳${prof.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: prof >= 0
                          ? const Color(0xFF10B981)
                          : Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Qty: ${b['quantity']} • Collected: ৳${b['total_revenue']}${disc > 0 ? " (Coupon -৳$disc)" : ""}',
                style: TextStyle(fontSize: 11, color: t.primaryColor),
              ),
              Text(
                '${b['location']} • ${b['date']}',
                style: TextStyle(fontSize: 10, color: t.secondaryText),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationsTab(List<dynamic> locations, CatalogThemeConfig t) {
    if (locations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'No delivery location data available yet.',
            style: TextStyle(color: t.secondaryText, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      children: locations.map((loc) {
        if (loc is! Map) return const SizedBox.shrink();
        final pct =
            double.tryParse((loc['percentage'] ?? 0).toString()) ?? 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (loc['location'] ?? 'City').toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                  Text(
                    '${loc['total_orders']} units (${pct.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: t.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (pct / 100.0).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: t.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(t.primaryColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRestocksTab(List<dynamic> stockAdds, CatalogThemeConfig t) {
    if (stockAdds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'No stock restock logs recorded yet.',
            style: TextStyle(color: t.secondaryText, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      children: stockAdds.map((lg) {
        if (lg is! Map) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '+${lg['quantity_added']} pcs Restocked',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    'TP Value: ৳${lg['tp_money_added']}',
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
                'Stock: ${lg['stock_before']} ➔ ${lg['stock_after']} • Retail Value: ৳${lg['retail_money_added']}',
                style: TextStyle(fontSize: 11, color: t.primaryText),
              ),
              Text(
                (lg['date'] ?? '').toString(),
                style: TextStyle(fontSize: 10, color: t.secondaryText),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}