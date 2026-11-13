// lib/widgets/inventory/inventory_modals.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../catalog/catalog_theme_scope.dart';

BoxDecoration invPrimaryDecoration(
  CatalogThemeConfig theme, {
  double radius = 14,
}) {
  return BoxDecoration(
    gradient: theme.useGradient ? theme.brandGradient : null,
    color: theme.useGradient ? null : theme.primaryColor,
    borderRadius: BorderRadius.circular(radius),
  );
}

// ============================================================================
// 1. STOCK ADJUSTMENT MODAL (+ Restock, - Deduct, Damage, Physical Audit Set)
// ============================================================================
class InventoryAdjustStockModal extends StatefulWidget {
  final Map item;
  final CatalogThemeConfig theme;
  final VoidCallback onSuccess;

  const InventoryAdjustStockModal({
    super.key,
    required this.item,
    required this.theme,
    required this.onSuccess,
  });

  @override
  State<InventoryAdjustStockModal> createState() =>
      _InventoryAdjustStockModalState();
}

class _InventoryAdjustStockModalState extends State<InventoryAdjustStockModal> {
  String _adjustType = 'add'; // 'add', 'remove', 'damage', 'set'
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAdjustment() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সঠিক পরিমাণ (Quantity >= 1) লিখুন।'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final t = widget.theme;
      final id = widget.item['id'];
      final res = await http.post(
        Uri.parse(
          '${t.apiBase}/api/v1/inventory/$id/adjust-stock/?subdomain=${t.subdomain}',
        ),
        headers: {...t.headers, 'X-Branch-ID': 'all'},
        body: jsonEncode({
          'adjustment_type': _adjustType,
          'quantity': qty,
          'notes': _notesCtrl.text.trim(),
        }),
      );

      final decoded = jsonDecode(res.body);
      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        Navigator.pop(context, true);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('স্টক সফলভাবে আপডেট করা হয়েছে!'),
            backgroundColor: t.primaryColor,
          ),
        );
      } else {
        final err = (decoded is Map && decoded['error'] != null)
            ? decoded['error'].toString()
            : 'স্টক আপডেট করা যায়নি (${res.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final prodName =
        (widget.item['product_name'] ?? 'Product').toString();
    final curStock =
        int.tryParse((widget.item['stock_quantity'] ?? 0).toString()) ?? 0;
    final tp =
        double.tryParse((widget.item['trade_price'] ?? 0).toString()) ?? 0.0;
    final sell =
        double.tryParse((widget.item['selling_price'] ?? 0).toString()) ?? 0.0;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    final tpTotal = qty * tp;
    final retailTotal = qty * sell;

    return Container(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: t.cardBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: t.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: invPrimaryDecoration(t, radius: 12),
                  child: const Icon(
                    Icons.inventory_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adjust Stock • $prodName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: t.primaryText,
                        ),
                      ),
                      Text(
                        'Current Stock: $curStock pcs • TP: ৳${tp.toStringAsFixed(0)} • Retail: ৳${sell.toStringAsFixed(0)}',
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
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip('add', '+ Restock / Add', const Color(0xFF10B981)),
                _buildTypeChip('remove', '- Deduct Stock', const Color(0xFF3B82F6)),
                _buildTypeChip('damage', 'Mark Damaged', const Color(0xFFEF4444)),
                _buildTypeChip('set', 'Set Exact Audit', const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                color: t.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                labelText: _adjustType == 'set'
                    ? 'New Exact Stock Quantity'
                    : 'Quantity (Pieces)',
                labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                prefixIcon: Icon(Icons.numbers_rounded, color: t.primaryColor),
                filled: true,
                fillColor: t.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (qty > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.primaryColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: t.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TP Value: ৳${tpTotal.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                    Text(
                      'Retail Value: ৳${retailTotal.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: t.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              style: TextStyle(color: t.primaryText, fontSize: 12.5),
              decoration: InputDecoration(
                labelText: 'Audit / Restock Note (Optional)',
                labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                filled: true,
                fillColor: t.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _isSaving ? null : _submitAdjustment,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: invPrimaryDecoration(t, radius: 14),
                alignment: Alignment.center,
                child: Text(
                  _isSaving ? 'Updating Stock...' : 'Confirm Stock Adjustment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String key, String label, Color col) {
    final active = _adjustType == key;
    final t = widget.theme;
    return GestureDetector(
      onTap: () => setState(() => _adjustType = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: active
            ? invPrimaryDecoration(t, radius: 10)
            : BoxDecoration(
                color: col.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: col.withValues(alpha: 0.35)),
              ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : col,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. INVENTORY AUDIT HISTORY LOGS MODAL
// ============================================================================
class InventoryLogsModal extends StatefulWidget {
  final Map item;
  final CatalogThemeConfig theme;

  const InventoryLogsModal({
    super.key,
    required this.item,
    required this.theme,
  });

  @override
  State<InventoryLogsModal> createState() => _InventoryLogsModalState();
}

class _InventoryLogsModalState extends State<InventoryLogsModal> {
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final t = widget.theme;
      final id = widget.item['id'];
      final res = await http.get(
        Uri.parse(
          '${t.apiBase}/api/v1/inventory/$id/logs/?subdomain=${t.subdomain}',
        ),
        headers: {...t.headers, 'X-Branch-ID': 'all'},
      );
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        if (raw is List) _logs = raw;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final prodName = (widget.item['product_name'] ?? 'Product').toString();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.all(9),
                decoration: invPrimaryDecoration(t, radius: 12),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Audit History • $prodName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    Text(
                      'All stock additions, sales, damages & TP values',
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
          const Divider(height: 18),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: t.primaryColor),
                  )
                : _logs.isEmpty
                    ? Center(
                        child: Text(
                          'No stock history logs found.',
                          style: TextStyle(color: t.secondaryText, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final lg = _logs[idx] as Map;
                          final type =
                              (lg['action_type'] ?? 'add').toString();
                          final qty = lg['quantity_changed'] ?? 0;
                          final before = lg['stock_before'] ?? 0;
                          final after = lg['stock_after'] ?? 0;
                          final tpVal = double.tryParse(
                                (lg['added_cost_value'] ?? 0).toString(),
                              ) ??
                              0.0;
                          final notes = (lg['notes'] ?? '').toString();
                          final dateStr =
                              (lg['date_formatted'] ?? lg['created_at'] ?? '')
                                  .toString();

                          final isAdd = type == 'add' || type == 'release';
                          final col = isAdd
                              ? const Color(0xFF10B981)
                              : (type == 'damage'
                                  ? Colors.redAccent
                                  : const Color(0xFF3B82F6));

                          return Container(
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: col.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${type.toUpperCase()} (${isAdd ? "+" : ""}$qty pcs)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: col,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Stock: $before ➔ $after',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: t.primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                if (tpVal > 0) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    'TP Capital Value: ৳${tpVal.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: t.primaryColor,
                                    ),
                                  ),
                                ],
                                if (notes.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    notes,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: t.primaryText,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: t.secondaryText,
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
  }
}

// ============================================================================
// 3. STORE-WIDE FINANCIAL LEDGER MODAL (Daily Stock Money & Coupon Deductions)
// ============================================================================
class InventoryFinancialLedgerModal extends StatefulWidget {
  final String initialTab; // 'daily_stock' or 'coupons'
  final CatalogThemeConfig theme;

  const InventoryFinancialLedgerModal({
    super.key,
    required this.initialTab,
    required this.theme,
  });

  @override
  State<InventoryFinancialLedgerModal> createState() =>
      _InventoryFinancialLedgerModalState();
}

class _InventoryFinancialLedgerModalState
    extends State<InventoryFinancialLedgerModal> {
  late String _tab;
  bool _isLoading = true;
  Map _ledgerData = {};

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    try {
      final t = widget.theme;
      final res = await http.get(
        Uri.parse(
          '${t.apiBase}/api/v1/inventory/financial-ledger/?subdomain=${t.subdomain}',
        ),
        headers: {...t.headers, 'X-Branch-ID': 'all'},
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) _ledgerData = decoded;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final additions = (_ledgerData['daily_stock_additions'] is List)
        ? (_ledgerData['daily_stock_additions'] as List)
        : [];
    final coupons = (_ledgerData['coupon_deductions'] is List)
        ? (_ledgerData['coupon_deductions'] as List)
        : [];
    final totalCouponCut = double.tryParse(
          (_ledgerData['total_coupon_money_deducted'] ?? 0).toString(),
        ) ??
        0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
                padding: const EdgeInsets.all(9),
                decoration: invPrimaryDecoration(t, radius: 12),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Store Financial & Stock Ledger',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: t.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = 'daily_stock'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: _tab == 'daily_stock'
                        ? invPrimaryDecoration(t, radius: 12)
                        : BoxDecoration(
                            color: t.inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.cardBorder),
                          ),
                    alignment: Alignment.center,
                    child: Text(
                      'Daily Stock Added (${additions.length})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _tab == 'daily_stock'
                            ? Colors.white
                            : t.primaryText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = 'coupons'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: _tab == 'coupons'
                        ? invPrimaryDecoration(t, radius: 12)
                        : BoxDecoration(
                            color: t.inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.cardBorder),
                          ),
                    alignment: Alignment.center,
                    child: Text(
                      'Coupon Cuts (-৳${totalCouponCut.toStringAsFixed(0)})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _tab == 'coupons' ? Colors.white : t.primaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: t.primaryColor),
                  )
                : _tab == 'daily_stock'
                    ? (additions.isEmpty
                        ? Center(
                            child: Text(
                              'No stock addition records found.',
                              style: TextStyle(
                                color: t.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: additions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final row = additions[i] as Map;
                              return Container(
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (row['product_name'] ?? 'Product')
                                                .toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: t.primaryText,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '+${row['quantity_added']} pcs',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'TP Capital Added: ৳${row['tp_money_added']} • Retail Value: ৳${row['retail_money_added']}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: t.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${row['datetime']} • Stock: ${row['stock_before']} ➔ ${row['stock_after']}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: t.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ))
                    : (coupons.isEmpty
                        ? Center(
                            child: Text(
                              'No coupon deductions recorded on orders yet.',
                              style: TextStyle(
                                color: t.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: coupons.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final c = coupons[i] as Map;
                              return Container(
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${c['product_name']} (#${c['order_id']})',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: t.primaryText,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '-৳${c['coupon_discount_deducted']}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: ${c['coupon_code']} • Collected: ৳${c['net_collected_amount']} • Net Profit: ৳${c['profit_after_coupon']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: t.primaryColor,
                                      ),
                                    ),
                                    Text(
                                      'Buyer: ${c['customer_name']} • ${c['date']}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: t.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )),
          ),
        ],
      ),
    );
  }
}