// lib/widgets/order/customers_list_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../catalog/catalog_theme_scope.dart';
import 'order_utils.dart';

class CustomersListView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onDataChanged;

  const CustomersListView({
    super.key,
    required this.isDarkMode,
    this.brandGreen = const Color(0xFF5B9A42),
    this.onDataChanged,
  });

  @override
  State<CustomersListView> createState() => _CustomersListViewState();
}

class _CustomersListViewState extends State<CustomersListView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;

  List<dynamic> _customers = [];
  List<dynamic> _orders = [];

  String _searchQuery = '';
  String _segmentFilter = 'all'; // 'all', 'Champions', 'Loyal Customers', 'New Customers', 'At Risk'
  String _riskFilter = 'all'; // 'all', 'high', 'medium', 'low'

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant CustomersListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _loadTheme();
    }
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
    await _fetchCustomersAndOrders();
  }

  Future<void> _fetchCustomersAndOrders() async {
    setState(() => _isLoading = true);
    try {
      final t = _theme;
      final sub = t.subdomain;
      final headers = {
        ...t.headers,
        'X-Branch-ID': 'all',
      };

      final responses = await Future.wait([
        http
            .get(
              Uri.parse(
                '${t.apiBase}/api/v1/customers/?subdomain=$sub&all_branches=true',
              ),
              headers: headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                '${t.apiBase}/api/v1/orders/?subdomain=$sub&admin=true',
              ),
              headers: headers,
            )
            .catchError((_) => http.Response('[]', 500)),
      ]);

      if (responses[0].statusCode == 200) {
        final raw = jsonDecode(responses[0].body);
        if (raw is List) {
          _customers = raw;
        } else if (raw is Map && raw['results'] is List) {
          _customers = raw['results'];
        }
      }

      if (responses[1].statusCode == 200) {
        final rawOrd = jsonDecode(responses[1].body);
        if (rawOrd is List) {
          _orders = rawOrd;
        } else if (rawOrd is Map && rawOrd['results'] is List) {
          _orders = rawOrd['results'];
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map _evaluateCustomerRfmAndChurn(Map cust) {
    final custId = cust['id'];
    final custEmail = (cust['email'] ?? '').toString().trim().toLowerCase();
    final custPhone = (cust['phone'] ?? '')
        .toString()
        .replaceAll(RegExp(r'[^0-9+]'), '')
        .trim();

    int orderCount = int.tryParse((cust['total_orders'] ?? 0).toString()) ?? 0;
    double totalSpent =
        double.tryParse((cust['total_spent'] ?? 0).toString()) ?? 0.0;

    // Cross-check with live orders if total_orders is 0
    if (orderCount == 0 && _orders.isNotEmpty) {
      int matchedOrders = 0;
      double matchedSpent = 0.0;
      for (final o in _orders) {
        if (o is Map) {
          final oPhone = OrderUtils.customerPhone(o);
          final oEmail = OrderUtils.customerEmail(o).toLowerCase();
          final oCustId = o['customer'];
          if ((custId != null && oCustId == custId) ||
              (custPhone.isNotEmpty && oPhone == custPhone) ||
              (custEmail.isNotEmpty && oEmail == custEmail)) {
            matchedOrders++;
            matchedSpent += OrderUtils.orderTotal(o);
          }
        }
      }
      if (matchedOrders > 0) {
        orderCount = matchedOrders;
        totalSpent = matchedSpent;
      }
    }

    int daysSinceLast = 15;
    final rawLast =
        (cust['last_active'] ?? cust['last_order_date'] ?? cust['created_at'] ?? '')
            .toString();
    final parsedLast = DateTime.tryParse(rawLast);
    if (parsedLast != null) {
      daysSinceLast =
          DateTime.now().difference(parsedLast).inDays.clamp(0, 999);
    }

    String segment = 'Potential Loyalists';
    String rfmScore = '333';

    if (totalSpent >= 10000 || orderCount >= 10) {
      segment = 'Champions';
      rfmScore = '555';
    } else if (orderCount >= 3 || totalSpent >= 2000) {
      if (daysSinceLast > 30) {
        segment = 'At Risk';
        rfmScore = '244';
      } else {
        segment = 'Loyal Customers';
        rfmScore = '444';
      }
    } else if (orderCount == 1) {
      if (daysSinceLast <= 15) {
        segment = 'New Customers';
        rfmScore = '511';
      } else if (daysSinceLast > 45) {
        segment = 'At Risk';
        rfmScore = '211';
      } else {
        segment = 'Potential Loyalists';
        rfmScore = '311';
      }
    } else if (orderCount == 0) {
      segment = daysSinceLast > 45 ? 'Lost / Inactive' : 'New Customers';
      rfmScore = daysSinceLast > 45 ? '111' : '411';
    }

    String riskLevel = 'low';
    double churnProb = 0.15;
    String strategyHeadline = 'Loyalty Engagement';
    String strategyAction =
        'নিয়মিত যোগাযোগ রাখুন এবং নতুন কালেকশনের আপডেট দিন।';
    String recommendedCoupon = 'FREESHIP';

    if (daysSinceLast > 45 || (orderCount <= 1 && daysSinceLast > 30)) {
      riskLevel = 'high';
      churnProb = (0.65 + (daysSinceLast / 180) * 0.25).clamp(0.1, 0.94);
      strategyHeadline = 'Immediate Win-Back Campaign';
      strategyAction =
          'গ্রাহক দীর্ঘদিন অনুপস্থিত। অবিলম্বে ১৫%-২০% ছাড়ের কুপন SMS পাঠান।';
      recommendedCoupon = 'WINBACK20 (20% OFF)';
    } else if (daysSinceLast > 25 || (orderCount == 1 && daysSinceLast > 15)) {
      riskLevel = 'medium';
      churnProb = 0.48;
      strategyHeadline = 'Engagement Re-activation';
      strategyAction =
          'নতুন কালেকশন ও ১০% ডিসকাউন্ট ভাউচারসহ বার্তা পাঠান।';
      recommendedCoupon = 'COMEBACK10 (10% OFF)';
    }

    return {
      'segment': segment,
      'rfm_score': rfmScore,
      'orders': orderCount,
      'spent': totalSpent,
      'days_inactive': daysSinceLast,
      'risk_level': riskLevel,
      'churn_prob': churnProb,
      'headline': strategyHeadline,
      'action': strategyAction,
      'coupon': recommendedCoupon,
    };
  }

  Color _segmentColor(String seg) {
    switch (seg) {
      case 'Champions':
        return const Color(0xFF10B981);
      case 'Loyal Customers':
        return const Color(0xFF3B82F6);
      case 'New Customers':
        return const Color(0xFF8B5CF6);
      case 'At Risk':
      case 'Lost / Inactive':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Color _riskColor(String risk) {
    if (risk == 'high') return const Color(0xFFEF4444);
    if (risk == 'medium') return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Future<void> _openAddCustomerModal() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    bool isSaving = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final t = _theme;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
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
                          decoration: OrderUtils.primaryDecoration(t, radius: 12),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
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
                                'Add New Customer',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryText,
                                ),
                              ),
                              Text(
                                'Create a customer profile in your store CRM',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: t.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: Icon(Icons.close_rounded, color: t.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        labelStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
                        prefixIcon:
                            Icon(Icons.person_outline, color: t.primaryColor),
                        filled: true,
                        fillColor: t.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Mobile Number (11 Digits) *',
                        labelStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
                        prefixIcon:
                            Icon(Icons.phone_outlined, color: t.primaryColor),
                        filled: true,
                        fillColor: t.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Email Address (Optional)',
                        labelStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
                        prefixIcon:
                            Icon(Icons.email_outlined, color: t.primaryColor),
                        filled: true,
                        fillColor: t.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: isSaving
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty &&
                                  phoneCtrl.text.trim().isEmpty) {
                                return;
                              }
                              setModalState(() => isSaving = true);
                              try {
                                final res = await http.post(
                                  Uri.parse(
                                    '${t.apiBase}/api/v1/customers/?subdomain=${t.subdomain}',
                                  ),
                                  headers: t.headers,
                                  body: jsonEncode({
                                    'full_name': nameCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'email': emailCtrl.text.trim(),
                                  }),
                                );
                                if (res.statusCode >= 200 &&
                                    res.statusCode < 300) {
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                }
                              } catch (_) {}
                              if (ctx.mounted) {
                                setModalState(() => isSaving = false);
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: OrderUtils.primaryDecoration(t, radius: 14),
                        alignment: Alignment.center,
                        child: Text(
                          isSaving ? 'Saving...' : 'Save Customer Profile',
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
          },
        );
      },
    );

    if (created == true) {
      await _fetchCustomersAndOrders();
      widget.onDataChanged?.call();
    }
  }

  Future<void> _deleteCustomer(int id, String name) async {
    final t = _theme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Customer?',
          style: TextStyle(
            color: t.primaryText,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "$name" from your customer list?',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(
        Uri.parse(
          '${t.apiBase}/api/v1/customers/$id/?subdomain=${t.subdomain}',
        ),
        headers: t.headers,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchCustomersAndOrders();
        widget.onDataChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer deleted successfully.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _sendWinbackSms(Map cust, Map rfm) async {
    final t = _theme;
    final phone = (cust['phone'] ?? '')
        .toString()
        .replaceAll(RegExp(r'[^0-9+]'), '')
        .trim();
    final name = (cust['full_name'] ?? cust['first_name'] ?? 'Customer')
        .toString()
        .trim();
    final coupon = (rfm['coupon'] ?? 'WINBACK20').toString();

    if (phone.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('এই গ্রাহকের বৈধ ১১ ডিজিটের মোবাইল নম্বর নেই।'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final msg =
        'Dear $name, we miss you at ${t.subdomain.toUpperCase()}! Use code $coupon on your next order for a special discount!';

    try {
      final res = await http.post(
        Uri.parse(
          '${t.apiBase}/api/v1/sms/send-individual/?subdomain=${t.subdomain}',
        ),
        headers: t.headers,
        body: jsonEncode({
          'numbers': phone,
          'phone': phone,
          'message': msg,
        }),
      );
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Win-Back SMS পাঠানো হয়েছে ($phone)!'),
            backgroundColor: t.primaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS পাঠানো যায়নি (${res.statusCode})'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (_) {}
  }

  void _openCustomerDetailModal(Map cust, Map rfm) {
    final t = _theme;
    final name = (cust['full_name'] ?? cust['first_name'] ?? 'Customer')
        .toString()
        .trim();
    final email = (cust['email'] ?? '').toString().trim();
    final phone = (cust['phone'] ?? '').toString().trim();
    final seg = rfm['segment'].toString();
    final segCol = _segmentColor(seg);
    final risk = rfm['risk_level'].toString();
    final riskCol = _riskColor(risk);

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
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: OrderUtils.primaryDecoration(t, radius: 14),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          '${phone.isNotEmpty ? phone : "No phone"}${email.isNotEmpty && !email.endsWith(".local") ? " • $email" : ""}',
                          style: TextStyle(fontSize: 11.5, color: t.secondaryText),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatMiniBox(
                      'Total Orders',
                      '${rfm['orders']}',
                      Icons.shopping_bag_outlined,
                      t.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatMiniBox(
                      'Total Spent',
                      '৳${(rfm['spent'] as double).toStringAsFixed(0)}',
                      Icons.payments_outlined,
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatMiniBox(
                      'RFM Score',
                      '${rfm['rfm_score']}',
                      Icons.auto_graph_rounded,
                      segCol,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: riskCol.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: riskCol.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AI Churn & Retention Strategy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: riskCol,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: riskCol.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${risk.toUpperCase()} CHURN (${((rfm['churn_prob'] as double) * 100).toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: riskCol,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rfm['action'].toString(),
                      style: TextStyle(fontSize: 12, color: t.primaryText),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Suggested Coupon: ${rfm['coupon']}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: t.primaryColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _sendWinbackSms(cust, rfm);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: OrderUtils.primaryDecoration(
                              t,
                              radius: 10,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sms_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Send Offer SMS',
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
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatMiniBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final t = _theme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: t.secondaryText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    int highRiskCount = 0;
    int loyalCount = 0;
    double revenueAtRisk = 0.0;

    final List<dynamic> enrichedList = [];
    for (final c in _customers) {
      if (c is Map) {
        final rfm = _evaluateCustomerRfmAndChurn(c);
        if (rfm['risk_level'] == 'high') {
          highRiskCount++;
          revenueAtRisk += (rfm['spent'] as double);
        }
        if (rfm['segment'] == 'Champions' ||
            rfm['segment'] == 'Loyal Customers') {
          loyalCount++;
        }

        final q = _searchQuery.trim().toLowerCase();
        final name =
            (c['full_name'] ?? c['first_name'] ?? '').toString().toLowerCase();
        final email = (c['email'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();

        bool matchesSearch = q.isEmpty ||
            name.contains(q) ||
            email.contains(q) ||
            phone.contains(q);
        bool matchesSeg =
            _segmentFilter == 'all' || rfm['segment'] == _segmentFilter;
        bool matchesRisk =
            _riskFilter == 'all' || rfm['risk_level'] == _riskFilter;

        if (matchesSearch && matchesSeg && matchesRisk) {
          enrichedList.add({'customer': c, 'rfm': rfm});
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
                      Icons.people_alt_rounded,
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
                          'Customers & AI RFM Retention',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${_customers.length} Registered • ৳${revenueAtRisk.toStringAsFixed(0)} Revenue at Churn Risk',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _openAddCustomerModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 14,
                            color: t.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildHeroPill('Total Base', '${_customers.length}', 'all'),
                  const SizedBox(width: 8),
                  _buildHeroPill('Champions/Loyal', '$loyalCount', 'low'),
                  const SizedBox(width: 8),
                  _buildHeroPill('High Churn Risk', '$highRiskCount', 'high'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Search & Segment Filter Bar
        Container(
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
                        hintText: 'Search customer by name, phone or email...',
                        hintStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
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
                  InkWell(
                    onTap: _fetchCustomersAndOrders,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: t.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        color: t.primaryColor,
                        size: 20,
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
                    _buildSegChip('all', 'All Segments'),
                    const SizedBox(width: 6),
                    _buildSegChip('Champions', 'Champions'),
                    const SizedBox(width: 6),
                    _buildSegChip('Loyal Customers', 'Loyal'),
                    const SizedBox(width: 6),
                    _buildSegChip('New Customers', 'New'),
                    const SizedBox(width: 6),
                    _buildSegChip('At Risk', 'At Risk'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: t.primaryColor),
            ),
          )
        else if (enrichedList.isEmpty)
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
                  Icons.people_outline_rounded,
                  size: 38,
                  color: t.primaryColor,
                ),
                const SizedBox(height: 10),
                Text(
                  'No Customers Found',
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
            itemCount: enrichedList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = enrichedList[index] as Map;
              return _buildCustomerCard(
                entry['customer'] as Map,
                entry['rfm'] as Map,
              );
            },
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHeroPill(String label, String val, String riskKey) {
    final active = _riskFilter == riskKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _riskFilter = riskKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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

  Widget _buildSegChip(String key, String label) {
    final active = _segmentFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _segmentFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: active
            ? OrderUtils.primaryDecoration(_theme, radius: 10)
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

  Widget _buildCustomerCard(Map cust, Map rfm) {
    final t = _theme;
    final id = int.tryParse((cust['id'] ?? 0).toString()) ?? 0;
    final name = (cust['full_name'] ?? cust['first_name'] ?? 'Customer')
        .toString()
        .trim();
    final email = (cust['email'] ?? '').toString().trim();
    final phone = (cust['phone'] ?? '').toString().trim();
    final isOnline = cust['is_online'] == true;
    final seg = rfm['segment'].toString();
    final segCol = _segmentColor(seg);
    final risk = rfm['risk_level'].toString();
    final riskCol = _riskColor(risk);
    final orders = rfm['orders'] as int;
    final spent = rfm['spent'] as double;

    return GestureDetector(
      onTap: () => _openCustomerDetailModal(cust, rfm),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                Stack(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: OrderUtils.primaryDecoration(t, radius: 12),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: t.cardBg, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: segCol.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              seg,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: segCol,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${phone.isNotEmpty ? phone : "No Phone"}${email.isNotEmpty && !email.endsWith(".local") ? " • $email" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: t.secondaryText),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '৳${spent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryColor,
                      ),
                    ),
                    Text(
                      '$orders Orders',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: t.cardBorder),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: riskCol.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Churn Risk: ${risk.toUpperCase()} • Code: ${rfm['coupon']}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: riskCol,
                    ),
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _sendWinbackSms(cust, rfm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.sms_outlined,
                          size: 17,
                          color: t.primaryColor,
                        ),
                      ),
                    ),
                    if (id > 0)
                      InkWell(
                        onTap: () => _deleteCustomer(id, name),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}