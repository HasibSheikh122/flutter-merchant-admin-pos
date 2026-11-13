// lib/widgets/order/cod_fraud_shield_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../catalog/catalog_theme_scope.dart';
import 'order_utils.dart';

class CodFraudShieldView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;

  const CodFraudShieldView({
    super.key,
    required this.isDarkMode,
    this.brandGreen = const Color(0xFF5B9A42),
  });

  @override
  State<CodFraudShieldView> createState() => _CodFraudShieldViewState();
}

class _CodFraudShieldViewState extends State<CodFraudShieldView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;
  List<dynamic> _orders = [];

  String _riskFilter = 'all'; // 'all', 'high', 'medium', 'low'
  String _searchQuery = '';

  // Live Scanner Controllers
  final TextEditingController _testPhoneCtrl = TextEditingController();
  final TextEditingController _testAddressCtrl = TextEditingController();
  final TextEditingController _testAmountCtrl =
      TextEditingController(text: '1250');
  bool _isScanning = false;
  Map? _liveScanResult;

  static const Map<String, String> _bdPrefixes = {
    '013': 'Grameenphone',
    '017': 'Grameenphone',
    '014': 'Banglalink',
    '019': 'Banglalink',
    '018': 'Robi',
    '016': 'Airtel',
    '015': 'Teletalk',
  };

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant CodFraudShieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _loadTheme();
    }
  }

  @override
  void dispose() {
    _testPhoneCtrl.dispose();
    _testAddressCtrl.dispose();
    _testAmountCtrl.dispose();
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
    await _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final t = _theme;
      final res = await http.get(
        Uri.parse(
          '${t.apiBase}/api/v1/orders/?subdomain=${t.subdomain}&admin=true',
        ),
        headers: {...t.headers, 'X-Branch-ID': 'all'},
      );
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        if (raw is List) {
          _orders = raw;
        } else if (raw is Map && raw['results'] is List) {
          _orders = raw['results'];
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map _evaluateFraudForOrder(Map ord) {
    if (ord['fraud_analysis'] is Map &&
        (ord['fraud_analysis'] as Map)['risk_score'] != null) {
      return ord['fraud_analysis'] as Map;
    }

    final rawPhone = OrderUtils.customerPhone(ord).replaceAll(RegExp(r'[^0-9]'), '');
    final cleanPhone =
        rawPhone.startsWith('880') ? rawPhone.substring(2) : rawPhone;
    final address = OrderUtils.deliveryAddress(ord);
    final total = OrderUtils.orderTotal(ord);
    final pay = (ord['payment_method'] ?? 'cod').toString().toLowerCase();

    return _runHeuristicEvaluation(
      phone: cleanPhone,
      address: address,
      amount: total,
      paymentMethod: pay,
    );
  }

  Map _runHeuristicEvaluation({
    required String phone,
    required String address,
    required double amount,
    String paymentMethod = 'cod',
  }) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized =
        clean.startsWith('880') ? clean.substring(2) : clean;
    final prefix =
        normalized.length >= 3 ? normalized.substring(0, 3) : '';
    final operatorName = _bdPrefixes[prefix] ?? 'Unknown Operator';
    final isPrepaid = [
      'bkash',
      'nagad',
      'rocket',
      'sslcommerz',
      'online',
      'stripe'
    ].contains(paymentMethod);

    double score = 5.0;
    final List<String> flags = [];

    if (normalized.length != 11 || !_bdPrefixes.containsKey(prefix)) {
      score += 45.0;
      flags.add(
        'Invalid Bangladeshi mobile number or unsupported operator prefix.',
      );
    } else if (RegExp(r'(\d)\1{6,}').hasMatch(normalized) ||
        normalized.contains('0000000') ||
        normalized == '01234567890') {
      score += 40.0;
      flags.add('Suspicious dummy or repeating digits in phone number.');
    }

    if (address.trim().length < 6 ||
        RegExp(r'([a-zA-Z0-9])\1{4,}').hasMatch(address)) {
      score += 30.0;
      flags.add('Delivery address is gibberish or excessively short.');
    } else if (address.trim().length < 12) {
      score += 15.0;
      flags.add('Delivery address lacks street or area details.');
    }

    if (!isPrepaid && amount >= 8000) {
      score += 20.0;
      flags.add(
        'High-value COD order (৳${amount.toStringAsFixed(0)}) requires phone verification.',
      );
    }

    if (isPrepaid) {
      score = (score - 20.0).clamp(0.0, 100.0);
    }

    final finalScore = score.clamp(0.0, 100.0);
    String level = 'low';
    String rec =
        'Order is safe. Ready for packaging and courier booking.';

    if (finalScore > 65) {
      level = 'high';
      rec =
          'High risk of parcel return/RTO. Collect delivery fee upfront or cancel.';
    } else if (finalScore > 30) {
      level = 'medium';
      rec = 'Call customer to verify address and phone before dispatch.';
    }

    return {
      'risk_score': finalScore,
      'risk_level': level,
      'operator': operatorName,
      'recommendation': rec,
      'flags': flags,
    };
  }

  Future<void> _handleRunLiveScanner() async {
    final phone = _testPhoneCtrl.text.trim();
    final address = _testAddressCtrl.text.trim();
    final amount =
        double.tryParse(_testAmountCtrl.text.trim()) ?? 1200.0;

    if (phone.isEmpty && address.isEmpty) return;

    setState(() => _isScanning = true);
    try {
      final t = _theme;
      final res = await http.post(
        Uri.parse(
          '${t.apiBase}/api/v1/orders/fraud/analyze-order/?subdomain=${t.subdomain}',
        ),
        headers: t.headers,
        body: jsonEncode({
          'phone': phone,
          'address': address,
          'total_amount': amount,
          'payment_method': 'cod',
        }),
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['risk_score'] != null) {
          setState(() => _liveScanResult = decoded);
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _liveScanResult = _runHeuristicEvaluation(
          phone: phone,
          address: address,
          amount: amount,
        );
      });
    }
    if (mounted) setState(() => _isScanning = false);
  }

  Color _riskColor(String level) {
    if (level == 'high') return const Color(0xFFEF4444);
    if (level == 'medium') return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  void _openFraudModal(Map ord, Map analysis) {
    final t = _theme;
    final ordNum = OrderUtils.orderNumber(ord);
    final phone = OrderUtils.customerPhone(ord);
    final address = OrderUtils.deliveryAddress(ord);
    final total = OrderUtils.orderTotal(ord);
    final level = (analysis['risk_level'] ?? 'low').toString().toLowerCase();
    final score =
        double.tryParse((analysis['risk_score'] ?? 5).toString()) ?? 5.0;
    final col = _riskColor(level);
    final flags =
        (analysis['flags'] is List) ? (analysis['flags'] as List) : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.shield_rounded, color: col, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Fraud Assessment • #$ordNum',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          'Bangladesh COD Return (RTO) Shield',
                          style: TextStyle(fontSize: 11, color: t.secondaryText),
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
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: col.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${level.toUpperCase()} RISK PROBABILITY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: col,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (analysis['recommendation'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: t.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${score.toStringAsFixed(0)}/100',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: col,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone & Operator',
                            style: TextStyle(
                              fontSize: 10,
                              color: t.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            phone.isNotEmpty ? phone : 'N/A',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            (analysis['operator'] ?? 'BD Mobile').toString(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bill Amount',
                            style: TextStyle(
                              fontSize: 10,
                              color: t.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '৳${total.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            (ord['payment_method'] ?? 'COD')
                                .toString()
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Text(
                  'Delivery Address: $address',
                  style: TextStyle(fontSize: 12, color: t.primaryText),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Detection Flags & Heuristic Rules',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              if (flags.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No suspicious patterns found in phone, address, or velocity.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...flags.map((f) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.toString(),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    int lowCount = 0;
    int medCount = 0;
    int highCount = 0;

    final List<dynamic> evaluatedOrders = [];
    for (final o in _orders) {
      if (o is Map) {
        final analysis = _evaluateFraudForOrder(o);
        final lv = (analysis['risk_level'] ?? 'low').toString().toLowerCase();
        if (lv == 'high') {
          highCount++;
        } else if (lv == 'medium') {
          medCount++;
        } else {
          lowCount++;
        }

        final q = _searchQuery.trim().toLowerCase();
        final ordNum = OrderUtils.orderNumber(o).toLowerCase();
        final phone = OrderUtils.customerPhone(o).toLowerCase();
        final cust = OrderUtils.customerName(o).toLowerCase();

        final matchesSearch = q.isEmpty ||
            ordNum.contains(q) ||
            phone.contains(q) ||
            cust.contains(q);
        final matchesRisk = _riskFilter == 'all' || lv == _riskFilter;

        if (matchesSearch && matchesRisk) {
          evaluatedOrders.add({'order': o, 'analysis': analysis});
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Hero Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: OrderUtils.primaryDecoration(t, radius: 24),
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
                      Icons.shield_rounded,
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
                          'AI COD Fraud Shield',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'BD Mobile Operator, Fake Order & RTO Risk Protection',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _fetchOrders,
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
              Row(
                children: [
                  _buildRiskHeroPill('All Scanned', '${_orders.length}', 'all'),
                  const SizedBox(width: 6),
                  _buildRiskHeroPill('Safe (Low)', '$lowCount', 'low'),
                  const SizedBox(width: 6),
                  _buildRiskHeroPill('Verify (Med)', '$medCount', 'medium'),
                  const SizedBox(width: 6),
                  _buildRiskHeroPill('High Risk', '$highCount', 'high'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Live Fraud Test Scanner Card
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    color: t.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Instant Phone & Address Fraud Scanner',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _testPhoneCtrl,
                      style: TextStyle(color: t.primaryText, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Phone (e.g. 01712...)',
                        hintStyle:
                            TextStyle(color: t.secondaryText, fontSize: 11.5),
                        filled: true,
                        fillColor: t.inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _testAmountCtrl,
                      style: TextStyle(color: t.primaryText, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Amount ৳',
                        hintStyle:
                            TextStyle(color: t.secondaryText, fontSize: 11.5),
                        filled: true,
                        fillColor: t.inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
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
                      controller: _testAddressCtrl,
                      style: TextStyle(color: t.primaryText, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Delivery Address (e.g. House 12, Road 5, Dhaka)',
                        hintStyle:
                            TextStyle(color: t.secondaryText, fontSize: 11.5),
                        filled: true,
                        fillColor: t.inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isScanning ? null : _handleRunLiveScanner,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: OrderUtils.primaryDecoration(t, radius: 12),
                      child: Text(
                        _isScanning ? 'Scanning...' : 'Scan Risk',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_liveScanResult != null) ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final lv = (_liveScanResult!['risk_level'] ?? 'low')
                        .toString()
                        .toLowerCase();
                    final sc = double.tryParse(
                          (_liveScanResult!['risk_score'] ?? 5).toString(),
                        ) ??
                        5.0;
                    final col = _riskColor(lv);
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: col.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_rounded, color: col, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${lv.toUpperCase()} RISK (${sc.toStringAsFixed(0)}/100) • ${_liveScanResult!['operator'] ?? "BD"} — ${_liveScanResult!['recommendation'] ?? ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: t.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: t.primaryText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Filter scanned orders by Order #, Phone or Customer...',
              hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: t.primaryColor,
                size: 19,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: t.primaryColor),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: evaluatedOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final item = evaluatedOrders[idx] as Map;
              return _buildFraudOrderCard(
                item['order'] as Map,
                item['analysis'] as Map,
              );
            },
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildRiskHeroPill(String label, String val, String key) {
    final active = _riskFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _riskFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color:
                active ? Colors.white : Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                val,
                style: TextStyle(
                  color: active ? _theme.primaryColor : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? _theme.primaryColor
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFraudOrderCard(Map ord, Map analysis) {
    final t = _theme;
    final ordNum = OrderUtils.orderNumber(ord);
    final custName = OrderUtils.customerName(ord);
    final phone = OrderUtils.customerPhone(ord);
    final address = OrderUtils.deliveryAddress(ord);
    final total = OrderUtils.orderTotal(ord);
    final level = (analysis['risk_level'] ?? 'low').toString().toLowerCase();
    final score =
        double.tryParse((analysis['risk_score'] ?? 5).toString()) ?? 5.0;
    final col = _riskColor(level);
    final op = (analysis['operator'] ?? 'BD Mobile').toString();

    return GestureDetector(
      onTap: () => _openFraudModal(ord, analysis),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: col.withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: col,
                    ),
                  ),
                  Text(
                    level.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: col,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#$ordNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: t.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '• $custName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${phone.isNotEmpty ? phone : "No Phone"} ($op) • $address',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: t.secondaryText),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (analysis['recommendation'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: col,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '৳${total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: t.secondaryText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}