// lib/widgets/inventory/daily_collection_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';
import 'inventory_modals.dart';
import '../../core/config/tenant_config.dart';

class DailyCollectionView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;

  const DailyCollectionView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
  });

  @override
  State<DailyCollectionView> createState() => _DailyCollectionViewState();
}

class _DailyCollectionViewState extends State<DailyCollectionView> {
  CatalogThemeConfig? _theme;
  bool _isLoading = true;
  String? _errorMsg;

  String _datePreset = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedPayment = 'all';
  String _sortBy = 'newest';

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List _rawOrders = [];
  Map _apiSummary = {};

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
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant DailyCollectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadThemeOnly();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadThemeOnly() async {
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = t);
    }
  }

  Future<void> _initAndFetch() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    _theme = t;

    await _fetchCollectionData();
  }

  String _formatApiDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatReadableDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _datePreset = preset;
      if (preset == 'all') {
        _fromDate = null;
        _toDate = null;
      } else if (preset == 'today') {
        _fromDate = today;
        _toDate = today;
      } else if (preset == 'yesterday') {
        final yest = today.subtract(const Duration(days: 1));
        _fromDate = yest;
        _toDate = yest;
      } else if (preset == '7days') {
        _fromDate = today.subtract(const Duration(days: 6));
        _toDate = today;
      } else if (preset == 'month') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = today;
      }
    });

    _fetchCollectionData();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialStart = _fromDate ?? now.subtract(const Duration(days: 7));
    final initialEnd = _toDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (ctx, child) {
        return Theme(
          data: (_t.isDarkMode ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _t.primaryColor,
              brightness: _t.isDarkMode ? Brightness.dark : Brightness.light,
              primary: _t.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _datePreset = 'custom';
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _fetchCollectionData();
    }
  }

  Future<void> _fetchCollectionData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final t = _t;
    final fromParam = _fromDate != null ? _formatApiDate(_fromDate!) : 'all';
    final toParam = _toDate != null ? _formatApiDate(_toDate!) : 'all';
    final paymentParam = _selectedPayment == 'all' ? 'all' : _selectedPayment;
    final searchParam = Uri.encodeQueryComponent(_searchQuery.trim());

    final url = Uri.parse(
      '${t.apiBase}/api/v1/orders/daily-collection/?subdomain=${t.subdomain}'
      '&all_branches=true'
      '&from_date=$fromParam'
      '&to_date=$toParam'
      '&payment_method=$paymentParam'
      '&search=$searchParam',
    );

    try {
      final res = await http.get(url, headers: t.headers).timeout(
        const Duration(seconds: 12),
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map) {
          final rawList = (decoded['orders'] as List?) ?? [];
          final summaryMap = (decoded['summary'] as Map?) ?? {};

          if (mounted) {
            setState(() {
              _rawOrders = rawList;
              _apiSummary = summaryMap;
              _isLoading = false;
            });
          }
          return;
        }
      }

      await _fetchFallbackFromOrdersApi();
    } catch (e) {
      await _fetchFallbackFromOrdersApi(originalError: e.toString());
    }
  }

  Future<void> _fetchFallbackFromOrdersApi({String? originalError}) async {
    final t = _t;
    try {
      final fallbackUrl = Uri.parse(
        '${t.apiBase}/api/v1/orders/?subdomain=${t.subdomain}&admin=true',
      );
      final res = await http.get(fallbackUrl, headers: t.headers).timeout(
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

        final List converted = [];
        double totalAmt = 0;
        int totalItems = 0;

        for (final item in list) {
          if (item is! Map) continue;
          final status = (item['status'] ?? '').toString().toLowerCase();
          if (status != 'delivered' && status != 'completed') continue;

          final amt = _toDouble(item['total_amount'] ?? item['amount']);
          final orderItems = (item['items'] as List?) ?? [];
          int qtySum = 0;
          final List prodNames = [];

          for (final oi in orderItems) {
            if (oi is Map) {
              final q = _toInt(oi['quantity'], fallback: 1);
              qtySum += q;
              final pName =
                  (oi['product_name'] ?? oi['name'] ?? 'Product').toString();
              prodNames.add('$pName (x$q)');
            }
          }
          if (qtySum == 0) {
            qtySum = _toInt(item['items_count'], fallback: 1);
          }

          totalAmt += amt;
          totalItems += qtySum;

          converted.add({
            'id': item['id'],
            'order_number':
                (item['order_number'] ?? 'ORD-${item['id']}').toString(),
            'date': (item['created_at'] ?? item['date'] ?? 'Recent').toString(),
            'customer_name': (item['customer_name'] ??
                    item['shipping_name'] ??
                    'Walk-in Customer')
                .toString(),
            'customer_phone':
                (item['customer_phone'] ?? item['shipping_phone'] ?? 'POS-Direct')
                    .toString(),
            'products': prodNames.isNotEmpty
                ? prodNames.join(', ')
                : (item['products'] ?? 'Order Items').toString(),
            'items_count': qtySum,
            'amount': amt,
            'payment_method':
                (item['payment_method'] ?? 'CASH').toString().toUpperCase(),
            'status': 'Delivered',
          });
        }

        if (mounted) {
          setState(() {
            _rawOrders = converted;
            _apiSummary = {
              'total_delivered_orders': converted.length,
              'total_collected': totalAmt,
              'total_items_sold': totalItems,
            };
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _errorMsg = originalError ??
              'Failed to load Daily Collection (${res.statusCode})';
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMsg = originalError ?? err.toString();
          _isLoading = false;
        });
      }
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? 0.0;
  }

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  String _formatMoney(double amount) {
    final isNeg = amount < 0;
    final absVal = amount.abs();
    final parts = absVal.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      final posFromRight = parts.length - i;
      buffer.write(parts[i]);
      if (posFromRight > 1 && posFromRight % 3 == 1) {
        buffer.write(',');
      }
    }
    return '${isNeg ? '-' : ''}৳$buffer';
  }

  String _channelType(Map order) {
    final pm = (order['payment_method'] ?? '').toString().toUpperCase();
    final ordNo = (order['order_number'] ?? '').toString().toUpperCase();
    final phone = (order['customer_phone'] ?? '').toString().toUpperCase();

    if (pm.contains('COUNTER') ||
        pm.contains('POS') ||
        pm == 'CASH' ||
        ordNo.startsWith('POS-') ||
        phone.contains('POS')) {
      return 'pos_cash';
    }
    if (pm.contains('BKASH') ||
        pm.contains('NAGAD') ||
        pm.contains('ROCKET') ||
        pm.contains('SSL') ||
        pm.contains('ONLINE') ||
        pm.contains('CARD')) {
      return 'online_mfs';
    }
    return 'courier_cod';
  }

  List get _filteredAndSortedOrders {
    final q = _searchQuery.trim().toLowerCase();
    final pFilter = _selectedPayment.toLowerCase();

    final filtered = _rawOrders.where((raw) {
      if (raw is! Map) return false;

      if (pFilter != 'all') {
        final pm = (raw['payment_method'] ?? '').toString().toLowerCase();
        final ch = _channelType(raw);
        if (pFilter == 'cash' && ch != 'pos_cash' && !pm.contains('cash')) {
          return false;
        } else if (pFilter == 'cod' &&
            ch != 'courier_cod' &&
            !pm.contains('cod')) {
          return false;
        } else if (pFilter == 'online' && ch != 'online_mfs') {
          return false;
        } else if ((pFilter == 'bkash' || pFilter == 'nagad') &&
            !pm.contains(pFilter)) {
          return false;
        }
      }

      if (q.isNotEmpty) {
        final ordNo = (raw['order_number'] ?? '').toString().toLowerCase();
        final cName = (raw['customer_name'] ?? '').toString().toLowerCase();
        final cPhone = (raw['customer_phone'] ?? '').toString().toLowerCase();
        final prods = (raw['products'] ?? '').toString().toLowerCase();
        if (!ordNo.contains(q) &&
            !cName.contains(q) &&
            !cPhone.contains(q) &&
            !prods.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final ma = a as Map;
      final mb = b as Map;

      if (_sortBy == 'amount_high') {
        return _toDouble(mb['amount']).compareTo(_toDouble(ma['amount']));
      } else if (_sortBy == 'amount_low') {
        return _toDouble(ma['amount']).compareTo(_toDouble(mb['amount']));
      } else if (_sortBy == 'items_high') {
        return _toInt(mb['items_count']).compareTo(_toInt(ma['items_count']));
      }
      return _toInt(mb['id']).compareTo(_toInt(ma['id']));
    });

    return filtered;
  }

  Map _computeMetrics(List list) {
    double totalCash = 0;
    double posCash = 0;
    double courierCod = 0;
    double onlineMfs = 0;
    int totalItems = 0;

    for (final raw in list) {
      if (raw is! Map) continue;
      final amt = _toDouble(raw['amount']);
      final items = _toInt(raw['items_count'], fallback: 1);

      totalCash += amt;
      totalItems += items;

      final ch = _channelType(raw);
      if (ch == 'pos_cash') {
        posCash += amt;
      } else if (ch == 'online_mfs') {
        onlineMfs += amt;
      } else {
        courierCod += amt;
      }
    }

    if (_searchQuery.isEmpty &&
        _selectedPayment == 'all' &&
        _apiSummary.isNotEmpty &&
        list.length == _rawOrders.length) {
      final apiTotal = _toDouble(_apiSummary['total_collected']);
      if (apiTotal > 0 && totalCash == 0) {
        totalCash = apiTotal;
      }
      final apiItems = _toInt(_apiSummary['total_items_sold']);
      if (apiItems > 0 && totalItems == 0) {
        totalItems = apiItems;
      }
    }

    final avgOrder = list.isNotEmpty ? (totalCash / list.length) : 0.0;

    return {
      'total_cash': totalCash,
      'orders_count': list.length.toDouble(),
      'total_items': totalItems.toDouble(),
      'avg_order': avgOrder,
      'pos_cash': posCash,
      'courier_cod': courierCod,
      'online_mfs': onlineMfs,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final displayOrders = _filteredAndSortedOrders;
    final metrics = _computeMetrics(displayOrders);

    return Padding(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader(t),
          const SizedBox(height: 16),
          _buildHeroCollectionBanner(t, metrics),
          const SizedBox(height: 14),
          _buildChannelBreakdownRow(t, metrics),
          const SizedBox(height: 16),
          _buildDateFilterCard(t),
          const SizedBox(height: 12),
          _buildSearchAndPaymentBar(t),
          const SizedBox(height: 16),
          _buildSectionHeader(t, displayOrders.length),
          const SizedBox(height: 10),
          if (_isLoading)
            _buildLoadingSkeleton(t)
          else if (_errorMsg != null)
            _buildErrorCard(t)
          else if (displayOrders.isEmpty)
            _buildEmptyState(t)
          else
            ...displayOrders.map((raw) {
              return _buildCollectionOrderCard(t, raw as Map);
            }),
        ],
      ),
    );
  }

  Widget _buildTopHeader(CatalogThemeConfig t) {
    String dateRangeLabel = 'All Delivered Orders';
    if (_fromDate != null && _toDate != null) {
      final f = _formatReadableDate(_fromDate!);
      final to = _formatReadableDate(_toDate!);
      dateRangeLabel = f == to ? 'Date: $f' : '$f  →  $to';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: invPrimaryDecoration(t, radius: 14),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
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
                  Flexible(
                    child: Text(
                      'Daily Order Collection',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: t.primaryColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      'AUDIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: t.primaryColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                dateRangeLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.secondaryText,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: _fetchCollectionData,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.cardBorder),
            ),
            child: Icon(
              Icons.refresh_rounded,
              color: t.primaryColor,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCollectionBanner(CatalogThemeConfig t, Map metrics) {
    final totalCash = _toDouble(metrics['total_cash']);
    final ordersCount = _toInt(metrics['orders_count']);
    final totalItems = _toInt(metrics['total_items']);
    final avgOrder = _toDouble(metrics['avg_order']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: invPrimaryDecoration(t, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'TOTAL COLLECTED REVENUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  final summaryText = 'Daily Collection Report\n'
                      'Total Collected: ${_formatMoney(totalCash)}\n'
                      'Delivered Orders: $ordersCount\n'
                      'Items Sold: $totalItems pcs\n'
                      'Avg. Order Value: ${_formatMoney(avgOrder)}';
                  Clipboard.setData(ClipboardData(text: summaryText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Collection summary copied to clipboard!'),
                      backgroundColor: t.primaryColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Copy Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _formatMoney(totalCash),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Verified cash & digital collection from $ordersCount delivered orders',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeroMiniStat(
                    icon: Icons.task_alt_rounded,
                    label: 'DELIVERED',
                    value: '$ordersCount',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withOpacity(0.22),
                ),
                Expanded(
                  child: _buildHeroMiniStat(
                    icon: Icons.shopping_bag_outlined,
                    label: 'ITEMS SOLD',
                    value: '$totalItems pcs',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withOpacity(0.22),
                ),
                Expanded(
                  child: _buildHeroMiniStat(
                    icon: Icons.insights_rounded,
                    label: 'AVG / ORDER',
                    value: _formatMoney(avgOrder),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMiniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.85), size: 13),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBreakdownRow(CatalogThemeConfig t, Map metrics) {
    final posCash = _toDouble(metrics['pos_cash']);
    final courierCod = _toDouble(metrics['courier_cod']);
    final onlineMfs = _toDouble(metrics['online_mfs']);

    return Row(
      children: [
        Expanded(
          child: _buildChannelCard(
            t: t,
            title: 'POS / Counter',
            amount: _formatMoney(posCash),
            subtitle: 'Walk-in Cash',
            icon: Icons.point_of_sale_rounded,
            accent: t.primaryColor,
            isSelected: _selectedPayment == 'cash',
            onTap: () {
              setState(() {
                _selectedPayment = _selectedPayment == 'cash' ? 'all' : 'cash';
              });
              _fetchCollectionData();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildChannelCard(
            t: t,
            title: 'Courier COD',
            amount: _formatMoney(courierCod),
            subtitle: 'Cash on Delivery',
            icon: Icons.local_shipping_rounded,
            accent: const Color(0xFF3B82F6),
            isSelected: _selectedPayment == 'cod',
            onTap: () {
              setState(() {
                _selectedPayment = _selectedPayment == 'cod' ? 'all' : 'cod';
              });
              _fetchCollectionData();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildChannelCard(
            t: t,
            title: 'MFS / Online',
            amount: _formatMoney(onlineMfs),
            subtitle: 'bKash • Nagad • SSL',
            icon: Icons.qr_code_2_rounded,
            accent: const Color(0xFF8B5CF6),
            isSelected: _selectedPayment == 'online',
            onTap: () {
              setState(() {
                _selectedPayment =
                    _selectedPayment == 'online' ? 'all' : 'online';
              });
              _fetchCollectionData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChannelCard({
    required CatalogThemeConfig t,
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.12) : t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : t.cardBorder,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 16),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 15),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: t.primaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: t.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterCard(CatalogThemeConfig t) {
    final List presets = [
      {'key': 'all', 'label': 'All Dates'},
      {'key': 'today', 'label': 'Today'},
      {'key': 'yesterday', 'label': 'Yesterday'},
      {'key': '7days', 'label': 'Last 7 Days'},
      {'key': 'month', 'label': 'This Month'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
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
                  Icon(Icons.calendar_month_rounded,
                      size: 16, color: t.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'COLLECTION PERIOD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: t.secondaryText,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _pickCustomDateRange,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _datePreset == 'custom'
                        ? t.primaryColor
                        : t.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 14,
                        color: _datePreset == 'custom'
                            ? Colors.white
                            : t.primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _datePreset == 'custom' &&
                                _fromDate != null &&
                                _toDate != null
                            ? '${_formatReadableDate(_fromDate!)} - ${_formatReadableDate(_toDate!)}'
                            : 'Custom Range',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _datePreset == 'custom'
                              ? Colors.white
                              : t.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((p) {
                final item = p as Map;
                final key = item['key'].toString();
                final label = item['label'].toString();
                final active = _datePreset == key;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _applyDatePreset(key),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: active
                          ? invPrimaryDecoration(t, radius: 11)
                          : BoxDecoration(
                              color: t.inputBg,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: t.cardBorder),
                            ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : t.primaryText,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndPaymentBar(CatalogThemeConfig t) {
    final List paymentChips = [
      {'key': 'all', 'label': 'All Methods'},
      {'key': 'cash', 'label': 'POS / Cash'},
      {'key': 'cod', 'label': 'Courier COD'},
      {'key': 'bkash', 'label': 'bKash'},
      {'key': 'nagad', 'label': 'Nagad'},
      {'key': 'online', 'label': 'Online / Card'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      color: t.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                    onSubmitted: (_) => _fetchCollectionData(),
                    decoration: InputDecoration(
                      hintText: 'Search Order #, Customer, Phone, Product...',
                      hintStyle: TextStyle(
                        color: t.secondaryText,
                        fontSize: 12.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: t.primaryColor,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: t.secondaryText,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                                _fetchCollectionData();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton(
                tooltip: 'Sort Collection',
                color: t.cardBg,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: t.cardBorder),
                ),
                onSelected: (val) {
                  setState(() => _sortBy = val.toString());
                },
                itemBuilder: (ctx) => [
                  _buildSortMenuItem(t, 'newest', 'Newest Delivered First',
                      Icons.schedule_rounded),
                  _buildSortMenuItem(t, 'amount_high', 'Highest Amount (৳)',
                      Icons.trending_up_rounded),
                  _buildSortMenuItem(t, 'amount_low', 'Lowest Amount (৳)',
                      Icons.trending_down_rounded),
                  _buildSortMenuItem(t, 'items_high', 'Most Items Sold',
                      Icons.inventory_2_outlined),
                ],
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sort_rounded,
                          color: t.primaryColor, size: 19),
                      const SizedBox(width: 5),
                      Text(
                        'Sort',
                        style: TextStyle(
                          fontSize: 12.5,
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
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: paymentChips.map((chip) {
                final item = chip as Map;
                final key = item['key'].toString();
                final label = item['label'].toString();
                final selected = _selectedPayment == key;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedPayment = key);
                      _fetchCollectionData();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? t.primaryColor.withOpacity(0.15)
                            : t.inputBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? t.primaryColor : t.cardBorder,
                          width: selected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: t.primaryColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  selected ? t.primaryColor : t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem _buildSortMenuItem(
    CatalogThemeConfig t,
    String value,
    String title,
    IconData icon,
  ) {
    final active = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? t.primaryColor : t.secondaryText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: active ? t.primaryColor : t.primaryText,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (active)
            Icon(Icons.check_rounded, size: 16, color: t.primaryColor),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(CatalogThemeConfig t, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'Collected Orders Ledger',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: t.primaryText,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: t.primaryColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryColor,
                ),
              ),
            ),
          ],
        ),
        if (_datePreset != 'all' ||
            _selectedPayment != 'all' ||
            _searchQuery.isNotEmpty)
          InkWell(
            onTap: () {
              _searchCtrl.clear();
              setState(() {
                _datePreset = 'all';
                _fromDate = null;
                _toDate = null;
                _selectedPayment = 'all';
                _searchQuery = '';
              });
              _fetchCollectionData();
            },
            child: Text(
              'Reset Filters',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: t.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCollectionOrderCard(CatalogThemeConfig t, Map order) {
    final orderNumber = (order['order_number'] ?? 'ORD-000').toString();
    final dateStr = (order['date'] ?? '').toString();
    final customerName =
        (order['customer_name'] ?? 'Walk-in Customer').toString();
    final customerPhone =
        (order['customer_phone'] ?? 'POS-Direct').toString();
    final productsStr = (order['products'] ?? 'Items').toString();
    final itemsCount = _toInt(order['items_count'], fallback: 1);
    final amount = _toDouble(order['amount']);
    final paymentMethod =
        (order['payment_method'] ?? 'CASH').toString().toUpperCase();
    final channel = _channelType(order);

    Color methodBadgeColor = t.primaryColor;
    IconData methodIcon = Icons.payments_rounded;
    if (channel == 'courier_cod') {
      methodBadgeColor = const Color(0xFF3B82F6);
      methodIcon = Icons.local_shipping_rounded;
    } else if (channel == 'online_mfs') {
      methodBadgeColor = const Color(0xFF8B5CF6);
      methodIcon = Icons.qr_code_2_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDarkMode ? 0.22 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showOrderReceiptModal(t, order),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: methodBadgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      methodIcon,
                      color: methodBadgeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '#$orderNumber',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF10B981).withOpacity(0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'DELIVERED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: t.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: t.secondaryText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatMoney(amount),
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w900,
                          color: t.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: methodBadgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: methodBadgeColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          paymentMethod,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: methodBadgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: t.cardBorder),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: t.secondaryText,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                customerPhone,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: t.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: t.inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              productsStr,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: t.primaryText,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: invPrimaryDecoration(t, radius: 7),
                            child: Text(
                              '$itemsCount pcs',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
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
        ),
      ),
    );
  }

  void _showOrderReceiptModal(CatalogThemeConfig t, Map order) {
    final orderNumber = (order['order_number'] ?? 'ORD-000').toString();
    final dateStr = (order['date'] ?? '').toString();
    final customerName =
        (order['customer_name'] ?? 'Walk-in Customer').toString();
    final customerPhone =
        (order['customer_phone'] ?? 'POS-Direct').toString();
    final productsStr = (order['products'] ?? 'Items').toString();
    final itemsCount = _toInt(order['items_count'], fallback: 1);
    final amount = _toDouble(order['amount']);
    final paymentMethod =
        (order['payment_method'] ?? 'CASH').toString().toUpperCase();

    final productLines = productsStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.secondaryText.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: invPrimaryDecoration(t, radius: 12),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Collection Audit Receipt',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            '#$orderNumber',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close_rounded, color: t.secondaryText),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: invPrimaryDecoration(t, radius: 18),
                child: Column(
                  children: [
                    const Text(
                      'COLLECTED CASH AMOUNT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatMoney(amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$paymentMethod  •  DELIVERED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildReceiptRow(t, 'Date & Time', dateStr),
              _buildReceiptRow(t, 'Customer Name', customerName),
              _buildReceiptRow(t, 'Phone / Channel', customerPhone),
              _buildReceiptRow(t, 'Total Quantity', '$itemsCount pcs'),
              const SizedBox(height: 10),
              Text(
                'SOLD PRODUCTS BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: t.secondaryText,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: productLines.map((line) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 15,
                            color: t.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: t.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.primaryText,
                        side: BorderSide(color: t.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: orderNumber));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Order #$orderNumber copied!'),
                            backgroundColor: t.primaryColor,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: const Text(
                        'Copy Order #',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(CatalogThemeConfig t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: t.secondaryText,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: t.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(CatalogThemeConfig t) {
    return Column(
      children: List.generate(4, (idx) {
        return Container(
          height: 112,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: t.secondaryText.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 210,
                      height: 11,
                      decoration: BoxDecoration(
                        color: t.secondaryText.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildErrorCard(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'Could not load Daily Collection',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _errorMsg ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: t.secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _fetchCollectionData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: t.primaryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: t.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Delivered Orders Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No collected cash records match your selected date range or payment filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: t.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          if (_datePreset != 'all' ||
              _selectedPayment != 'all' ||
              _searchQuery.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _datePreset = 'all';
                  _fromDate = null;
                  _toDate = null;
                  _selectedPayment = 'all';
                  _searchQuery = '';
                });
                _fetchCollectionData();
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
              label: const Text(
                'Show All Delivered Orders',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}