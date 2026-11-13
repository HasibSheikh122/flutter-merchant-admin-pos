import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class ReportsHubView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final String? initialReportTab;
  final VoidCallback? onDataChanged;

  const ReportsHubView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'report_orders',
    this.initialReportTab,
    this.onDataChanged,
  });

  @override
  State<ReportsHubView> createState() => _ReportsHubViewState();
}

class _ReportsHubViewState extends State<ReportsHubView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  late String _activeTab;
  bool _isLoading = true;

  // Date Range Filter
  String _datePreset = 'all';
  String _startDate = '';
  String _endDate = '';

  // Search & Status Filters
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL';
  String _customerSortBy = 'spent';

  // Unified Backend Data (/api/v1/stores/reports/)
  List _messageRows = [];
  List _reviewRows = [];
  List _customerRows = [];
  List _smsRows = [];
  List _orderRows = [];
  double _smsBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _activeTab = _normalizeTab(widget.initialReportTab ?? widget.initialTab);
    _initReportsModule();
  }

  @override
  void didUpdateWidget(covariant ReportsHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialReportTab ?? widget.initialTab;
    final oldIncoming = oldWidget.initialReportTab ?? oldWidget.initialTab;
    if (incoming != oldIncoming) {
      setState(() {
        _activeTab = _normalizeTab(incoming);
        _statusFilter = 'ALL';
        _searchCtrl.clear();
      });
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
    }
  }

  String _normalizeTab(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('message') || lower.contains('chat')) {
      return 'report_messages';
    }
    if (lower.contains('review') || lower.contains('rating')) {
      return 'report_reviews';
    }
    if (lower.contains('customer') || lower.contains('client')) {
      return 'report_customers';
    }
    if (lower.contains('sms')) {
      return 'report_sms';
    }
    return 'report_orders';
  }

  Future _reloadTheme() async {
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = loaded);
    }
  }

  Future _initReportsModule() async {
    setState(() => _isLoading = true);
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = loaded);
    }

    await _loadCachedReports();
    await _fetchReportsFromBackend();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future _loadCachedReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('xylo_reports_cache_${_theme.subdomain}');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        _applyReportsPayload(decoded, saveCache: false);
      }
    } catch (_) {}
  }

  Future _saveCachedReports(Map payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'xylo_reports_cache_${_theme.subdomain}',
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future _fetchReportsFromBackend() async {
    setState(() => _isLoading = true);
    final base = _theme.apiBase;
    final sub = _theme.subdomain;
    final headers = _theme.headers;

    String query = 'subdomain=$sub';
    if (_startDate.isNotEmpty) {
      query += '&start_date=$_startDate';
    }
    if (_endDate.isNotEmpty) {
      query += '&end_date=$_endDate';
    }

    try {
      final uri = Uri.parse('$base/api/v1/stores/reports/?$query');
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          _applyReportsPayload(decoded, saveCache: true);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyReportsPayload(Map data, {bool saveCache = false}) {
    setState(() {
      if (data['messages'] is List) {
        _messageRows = List.from(data['messages']);
      }
      if (data['reviews'] is List) {
        _reviewRows = List.from(data['reviews']);
      }
      if (data['customers'] is List) {
        _customerRows = List.from(data['customers']);
      }
      if (data['sms'] is List) {
        _smsRows = List.from(data['sms']);
      }
      if (data['orders'] is List) {
        _orderRows = List.from(data['orders']);
      }
      _smsBalance =
          double.tryParse((data['sms_balance'] ?? '0').toString()) ?? 0.0;
    });

    if (saveCache) {
      _saveCachedReports(data);
    }
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    setState(() {
      _datePreset = preset;
      if (preset == 'all') {
        _startDate = '';
        _endDate = '';
      } else if (preset == 'today') {
        _startDate = fmt(now);
        _endDate = fmt(now);
      } else if (preset == '7d') {
        _startDate = fmt(now.subtract(const Duration(days: 7)));
        _endDate = fmt(now);
      } else if (preset == 'month') {
        _startDate = fmt(DateTime(now.year, now.month, 1));
        _endDate = fmt(now);
      }
    });
    _fetchReportsFromBackend();
  }

  Future _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      setState(() {
        _datePreset = 'custom';
        _startDate = fmt(picked.start);
        _endDate = fmt(picked.end);
      });
      _fetchReportsFromBackend();
    }
  }

  void _exportActiveReportCsv() {
    final lines = [];
    if (_activeTab == 'report_orders') {
      lines.add(
          'Order Number,Customer Name,Phone,Outlet,Items,Total BDT,Payment Method,Payment Status,Order Status,Date');
      for (final r in _orderRows) {
        if (r is Map) {
          lines.add(
              '"${r['order_number']}","${r['customer_name']}","${r['customer_phone']}","${r['outlet']}","${r['items_count']}","${r['total']}","${r['payment_method']}","${r['payment_status']}","${r['status']}","${r['created_at']}"');
        }
      }
    } else if (_activeTab == 'report_customers') {
      lines.add(
          'Customer Name,Phone,Email,Address,Total Orders,Total Spent BDT,Last Order Date,Status');
      for (final r in _customerRows) {
        if (r is Map) {
          lines.add(
              '"${r['name']}","${r['phone']}","${r['email']}","${r['address']}","${r['total_orders']}","${r['total_spent']}","${r['last_order_date']}","${r['status']}"');
        }
      }
    } else if (_activeTab == 'report_sms') {
      lines.add(
          'Recipient,Mobile Number,Message,Length,Parts,Cost BDT,Status,Date');
      for (final r in _smsRows) {
        if (r is Map) {
          lines.add(
              '"${r['recipient_name']}","${r['mobile_number']}","${(r['message'] ?? '').toString().replaceAll('"', "'")}","${r['length']}","${r['sms_parts']}","${r['cost']}","${r['status']}","${r['created_at']}"');
        }
      }
    } else if (_activeTab == 'report_reviews') {
      lines.add('Product Name,Customer Name,Rating,Comment,Status,Date');
      for (final r in _reviewRows) {
        if (r is Map) {
          lines.add(
              '"${r['product_name']}","${r['customer_name']}","${r['rating']}","${(r['comment'] ?? '').toString().replaceAll('"', "'")}","${r['status']}","${r['created_at']}"');
        }
      }
    } else {
      lines.add('Sender,Channel,Message,Status,Date');
      for (final r in _messageRows) {
        if (r is Map) {
          lines.add(
              '"${r['sender']}","${r['channel']}","${(r['message'] ?? '').toString().replaceAll('"', "'")}","${r['status']}","${r['created_at']}"');
        }
      }
    }

    final csvContent = lines.join('\n');
    Clipboard.setData(ClipboardData(text: csvContent));
    _showToast(
        'CSV ডেটা (${lines.length - 1} rows) ক্লিপবোর্ডে কপি হয়েছে! Excel বা Google Sheet-এ পেস্ট করতে পারবেন।');
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroHeader(t),
        const SizedBox(height: 14),
        _buildSubTabsBar(t),
        const SizedBox(height: 14),
        _buildDateAndSearchToolbar(t),
        const SizedBox(height: 14),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: t.primaryColor),
            ),
          )
        else ...[
          if (_activeTab == 'report_messages') _buildMessageReportsTab(t),
          if (_activeTab == 'report_reviews') _buildReviewReportsTab(t),
          if (_activeTab == 'report_customers') _buildCustomerReportsTab(t),
          if (_activeTab == 'report_sms') _buildSmsReportsTab(t),
          if (_activeTab == 'report_orders') _buildOrderReportsTab(t),
        ],
      ],
    );
  }

  // ===========================================================================
  // TOP HERO SUMMARY BANNER
  // ===========================================================================
  Widget _buildHeroHeader(CatalogThemeConfig t) {
    double totalOrderRev = 0.0;
    for (final o in _orderRows) {
      if (o is Map) {
        final st = (o['status'] ?? '').toString().toLowerCase();
        if (!st.contains('cancel') && !st.contains('return')) {
          totalOrderRev +=
              double.tryParse((o['total'] ?? '0').toString()) ?? 0.0;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: t.useGradient
            ? t.brandGradient
            : LinearGradient(
                colors: [t.primaryColor, t.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: t.primaryColor.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assessment_rounded,
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
                      'Unified Store Reports & Audit Center',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time Message, Review, Customer, SMS & Sales Order Reports for ${_theme.subdomain}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: t.primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _exportActiveReportCsv,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text(
                  'Copy CSV',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroStatPill(
                Icons.shopping_bag_outlined,
                'Orders: ${_orderRows.length} (৳${totalOrderRev.toStringAsFixed(0)})',
              ),
              _buildHeroStatPill(
                Icons.people_alt_outlined,
                'Customers: ${_customerRows.length}',
              ),
              _buildHeroStatPill(
                Icons.star_rounded,
                'Reviews: ${_reviewRows.length}',
              ),
              _buildHeroStatPill(
                Icons.sms_outlined,
                'SMS Logs: ${_smsRows.length} (Bal: ৳${_smsBalance.toStringAsFixed(0)})',
              ),
              _buildHeroStatPill(
                Icons.chat_bubble_outline_rounded,
                'Messages: ${_messageRows.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5 SUB-TABS NAVIGATION BAR (MATCHING SIDEBAR ORDER)
  // ===========================================================================
  Widget _buildSubTabsBar(CatalogThemeConfig t) {
    final tabs = [
      {
        'key': 'report_messages',
        'label': 'Message Reports',
        'icon': Icons.chat_bubble_outline_rounded,
        'badge': '${_messageRows.length}',
      },
      {
        'key': 'report_reviews',
        'label': 'Review Reports',
        'icon': Icons.star_border_rounded,
        'badge': '${_reviewRows.length}',
      },
      {
        'key': 'report_customers',
        'label': 'Customers Report',
        'icon': Icons.people_alt_outlined,
        'badge': '${_customerRows.length}',
      },
      {
        'key': 'report_sms',
        'label': 'SMS Reports',
        'icon': Icons.sms_outlined,
        'badge': '${_smsRows.length}',
      },
      {
        'key': 'report_orders',
        'label': 'Order Reports',
        'icon': Icons.shopping_bag_outlined,
        'badge': '${_orderRows.length}',
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeTab = tab['key'] as String;
                  _statusFilter = 'ALL';
                  _searchCtrl.clear();
                });
              },
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient:
                      isSelected && t.useGradient ? t.brandGradient : null,
                  color: isSelected
                      ? (t.useGradient ? null : t.primaryColor)
                      : t.cardBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isSelected ? t.primaryColor : t.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : t.secondaryText,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : t.primaryText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.22)
                            : t.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tab['badge'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : t.primaryColor,
                        ),
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

  // ===========================================================================
  // DATE PRESETS & SEARCH TOOLBAR
  // ===========================================================================
  Widget _buildDateAndSearchToolbar(CatalogThemeConfig t) {
    final presets = [
      {'id': 'all', 'label': 'All Time'},
      {'id': 'today', 'label': 'Today'},
      {'id': '7d', 'label': 'Last 7 Days'},
      {'id': 'month', 'label': 'This Month'},
    ];

    return Container(
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
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...presets.map((p) {
                        final id = p['id'] as String;
                        final active = _datePreset == id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _applyDatePreset(id),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: active ? t.primaryColor : t.inputBg,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color:
                                      active ? t.primaryColor : t.cardBorder,
                                ),
                              ),
                              child: Text(
                                p['label'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      active ? Colors.white : t.primaryText,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      InkWell(
                        onTap: _pickCustomDateRange,
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _datePreset == 'custom'
                                ? t.primaryColor
                                : t.inputBg,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: _datePreset == 'custom'
                                  ? t.primaryColor
                                  : t.cardBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: _datePreset == 'custom'
                                    ? Colors.white
                                    : t.primaryColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _datePreset == 'custom' &&
                                        _startDate.isNotEmpty
                                    ? '$_startDate → $_endDate'
                                    : 'Custom Date',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _datePreset == 'custom'
                                      ? Colors.white
                                      : t.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh Reports',
                onPressed: _fetchReportsFromBackend,
                icon: Icon(Icons.refresh_rounded,
                    color: t.primaryColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: t.primaryText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search in current report by name, phone, ID or text...',
              hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 18, color: t.secondaryText),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() => _searchCtrl.clear());
                      },
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: t.secondaryText),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: t.inputBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
      ),
    );
  }

  // ===========================================================================
  // TAB 1: MESSAGE REPORTS (report_messages)
  // ===========================================================================
  Widget _buildMessageReportsTab(CatalogThemeConfig t) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _messageRows.where((m) {
      if (m is! Map) return false;
      final st = (m['status'] ?? 'Read').toString().toUpperCase();
      if (_statusFilter != 'ALL' && st != _statusFilter) return false;
      if (q.isNotEmpty) {
        final s = (m['sender'] ?? '').toString().toLowerCase();
        final ch = (m['channel'] ?? '').toString().toLowerCase();
        final msg = (m['message'] ?? '').toString().toLowerCase();
        return s.contains(q) || ch.contains(q) || msg.contains(q);
      }
      return true;
    }).toList();

    final unreadCount = _messageRows
        .where((m) =>
            m is Map &&
            (m['status'] ?? '').toString().toLowerCase() == 'unread')
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.chat_bubble_outline_rounded,
                  color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Message & Chat Activity Report (${filtered.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
              ),
              Text(
                'Unread: $unreadCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: t.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatusFilterRow(t, ['ALL', 'READ', 'UNREAD']),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _buildEmptyReportBox(t, 'No message or notification logs found.')
          else
            ...filtered.map((m) {
              final isUnread =
                  (m['status'] ?? '').toString().toLowerCase() == 'unread';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isUnread ? t.primaryColor : t.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: t.primaryColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            (m['channel'] ?? 'Chat').toString(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (m['sender'] ?? 'Customer').toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isUnread
                                ? const Color(0xFFD97706).withValues(alpha: 0.16)
                                : const Color(0xFF16A34A).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (m['status'] ?? 'Read').toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isUnread
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      (m['message'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: t.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (m['created_at'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: t.secondaryText,
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

  // ===========================================================================
  // TAB 2: REVIEW REPORTS (report_reviews)
  // ===========================================================================
  Widget _buildReviewReportsTab(CatalogThemeConfig t) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _reviewRows.where((r) {
      if (r is! Map) return false;
      final st = (r['status'] ?? 'Approved').toString().toUpperCase();
      if (_statusFilter != 'ALL' && st != _statusFilter) return false;
      if (q.isNotEmpty) {
        final p = (r['product_name'] ?? '').toString().toLowerCase();
        final c = (r['customer_name'] ?? '').toString().toLowerCase();
        final cm = (r['comment'] ?? '').toString().toLowerCase();
        return p.contains(q) || c.contains(q) || cm.contains(q);
      }
      return true;
    }).toList();

    double avgRating = 5.0;
    if (_reviewRows.isNotEmpty) {
      double sum = 0.0;
      for (final r in _reviewRows) {
        if (r is Map) {
          sum += double.tryParse((r['rating'] ?? '5').toString()) ?? 5.0;
        }
      }
      avgRating = sum / _reviewRows.length;
    }

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.star_rounded,
                  color: const Color(0xFFF59E0B), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Product & Store Review Reports (${filtered.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avg: ${avgRating.toStringAsFixed(1)} ★',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatusFilterRow(
              t, ['ALL', 'APPROVED', 'FEATURED', 'PENDING']),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _buildEmptyReportBox(t, 'No customer reviews matching your filter.')
          else
            ...filtered.map((r) {
              final rating =
                  int.tryParse((r['rating'] ?? '5').toString()) ?? 5;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (r['product_name'] ?? 'Product').toString(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (idx) {
                            return Icon(
                              idx < rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 15,
                              color: const Color(0xFFF59E0B),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${(r['customer_name'] ?? 'Verified Buyer')} • ${(r['status'] ?? 'Approved')}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: t.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (r['comment'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: t.secondaryText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (r['created_at'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: t.secondaryText,
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

  // ===========================================================================
  // TAB 3: CUSTOMERS REPORT (report_customers)
  // ===========================================================================
  Widget _buildCustomerReportsTab(CatalogThemeConfig t) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _customerRows.where((c) {
      if (c is! Map) return false;
      if (q.isNotEmpty) {
        final nm = (c['name'] ?? '').toString().toLowerCase();
        final ph = (c['phone'] ?? '').toString().toLowerCase();
        final em = (c['email'] ?? '').toString().toLowerCase();
        final ad = (c['address'] ?? '').toString().toLowerCase();
        return nm.contains(q) ||
            ph.contains(q) ||
            em.contains(q) ||
            ad.contains(q);
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_customerSortBy == 'orders') {
        final oa = int.tryParse((a['total_orders'] ?? '0').toString()) ?? 0;
        final ob = int.tryParse((b['total_orders'] ?? '0').toString()) ?? 0;
        return ob.compareTo(oa);
      }
      final sa = double.tryParse((a['total_spent'] ?? '0').toString()) ?? 0.0;
      final sb = double.tryParse((b['total_spent'] ?? '0').toString()) ?? 0.0;
      return sb.compareTo(sa);
    });

    double totalCustomerSpend = 0.0;
    int repeatBuyers = 0;
    for (final c in _customerRows) {
      if (c is Map) {
        totalCustomerSpend +=
            double.tryParse((c['total_spent'] ?? '0').toString()) ?? 0.0;
        final ords = int.tryParse((c['total_orders'] ?? '0').toString()) ?? 0;
        if (ords > 1) repeatBuyers++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.people_alt_outlined,
                  color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Customer LTV & Purchase Report (${filtered.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
              ),
              Text(
                'Repeat Buyers: $repeatBuyers  |  Total Spend: ৳${totalCustomerSpend.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: t.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Sort By:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: t.secondaryText,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Highest Spend (BDT)'),
                selected: _customerSortBy == 'spent',
                selectedColor: t.primaryColor.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _customerSortBy = 'spent'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Most Orders'),
                selected: _customerSortBy == 'orders',
                selectedColor: t.primaryColor.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _customerSortBy = 'orders'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _buildEmptyReportBox(t, 'No customer records found.')
          else
            ...filtered.map((c) {
              final phone = (c['phone'] ?? 'N/A').toString();
              final totalOrders =
                  int.tryParse((c['total_orders'] ?? '0').toString()) ?? 0;
              final totalSpent =
                  double.tryParse((c['total_spent'] ?? '0').toString()) ?? 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: t.primaryColor.withValues(alpha: 0.14),
                      child: Text(
                        (c['name'] ?? 'C')
                            .toString()
                            .trim()
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: t.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (c['name'] ?? 'Customer').toString(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$phone • ${(c['address'] ?? 'Bangladesh')}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Last Order: ${(c['last_order_date'] ?? 'N/A')}',
                            style: TextStyle(
                              fontSize: 10.5,
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
                          '৳${totalSpent.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: t.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: t.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$totalOrders Orders',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: phone));
                            _showToast('Phone number copied');
                          },
                          child: Text(
                            'Copy Phone',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: t.secondaryText,
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

  // ===========================================================================
  // TAB 4: SMS REPORTS (report_sms)
  // ===========================================================================
  Widget _buildSmsReportsTab(CatalogThemeConfig t) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _smsRows.where((s) {
      if (s is! Map) return false;
      final st = (s['status'] ?? 'SENT').toString().toUpperCase();
      if (_statusFilter != 'ALL' && st != _statusFilter) return false;
      if (q.isNotEmpty) {
        final mob = (s['mobile_number'] ?? '').toString().toLowerCase();
        final nm = (s['recipient_name'] ?? '').toString().toLowerCase();
        final msg = (s['message'] ?? '').toString().toLowerCase();
        return mob.contains(q) || nm.contains(q) || msg.contains(q);
      }
      return true;
    }).toList();

    double totalSmsCost = 0.0;
    for (final s in filtered) {
      if (s is Map) {
        totalSmsCost += double.tryParse((s['cost'] ?? '0').toString()) ?? 0.0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.sms_outlined, color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SMS Dispatch & Cost Report (${filtered.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
              ),
              Text(
                'Gateway Bal: ৳${_smsBalance.toStringAsFixed(2)}  |  Cost: ৳${totalSmsCost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: t.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatusFilterRow(t, ['ALL', 'SENT', 'FAILED']),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _buildEmptyReportBox(t, 'No SMS report logs found.')
          else
            ...filtered.map((s) {
              final st = (s['status'] ?? 'SENT').toString().toUpperCase();
              final isOk = st == 'SENT';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOk
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 16,
                          color: isOk
                              ? const Color(0xFF16A34A)
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${s['recipient_name'] ?? 'Customer'} (${s['mobile_number']})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                        Text(
                          '${s['sms_parts'] ?? 1} Part • ৳${s['cost'] ?? 0}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: t.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (s['message'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: t.secondaryText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          (s['created_at'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: t.secondaryText,
                          ),
                        ),
                        Text(
                          'Resp: ${(s['provider_response'] ?? 'OK')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: t.secondaryText,
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

  // ===========================================================================
  // TAB 5: ORDER REPORTS (report_orders)
  // ===========================================================================
  Widget _buildOrderReportsTab(CatalogThemeConfig t) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _orderRows.where((o) {
      if (o is! Map) return false;
      final st = (o['status'] ?? 'PENDING').toString().toUpperCase();
      if (_statusFilter != 'ALL' && st != _statusFilter) return false;
      if (q.isNotEmpty) {
        final num = (o['order_number'] ?? '').toString().toLowerCase();
        final nm = (o['customer_name'] ?? '').toString().toLowerCase();
        final ph = (o['customer_phone'] ?? '').toString().toLowerCase();
        final out = (o['outlet'] ?? '').toString().toLowerCase();
        return num.contains(q) ||
            nm.contains(q) ||
            ph.contains(q) ||
            out.contains(q);
      }
      return true;
    }).toList();

    double filteredRevenue = 0.0;
    for (final o in filtered) {
      if (o is Map) {
        final st = (o['status'] ?? '').toString().toLowerCase();
        if (!st.contains('cancel') && !st.contains('return')) {
          filteredRevenue +=
              double.tryParse((o['total'] ?? '0').toString()) ?? 0.0;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.shopping_bag_outlined,
                  color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sales & Order Audit Report (${filtered.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Net Sales: ৳${filteredRevenue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: t.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatusFilterRow(
            t,
            ['ALL', 'PENDING', 'PROCESSING', 'DELIVERED', 'CANCELLED'],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _buildEmptyReportBox(t, 'No order records matching your filter.')
          else
            ...filtered.map((o) {
              final st = (o['status'] ?? 'PENDING').toString().toUpperCase();
              final isDelivered = st == 'DELIVERED' || st == 'COMPLETED';
              final isCancelled = st == 'CANCELLED' || st == 'RETURNED';
              final total =
                  double.tryParse((o['total'] ?? '0').toString()) ?? 0.0;

              Color badgeColor = const Color(0xFFD97706);
              if (isDelivered) badgeColor = const Color(0xFF16A34A);
              if (isCancelled) badgeColor = Colors.redAccent;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${o['order_number']}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: t.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            st,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '৳${total.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${o['customer_name']} (${o['customer_phone']})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                        Icon(Icons.storefront_rounded,
                            size: 13, color: t.secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          (o['outlet'] ?? 'Main Store').toString(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Items: ${o['items_count'] ?? 1} • Pay: ${o['payment_method'] ?? 'COD'} (${o['payment_status'] ?? 'UNPAID'})',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.secondaryText,
                          ),
                        ),
                        Text(
                          (o['created_at'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: t.secondaryText,
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

  Widget _buildStatusFilterRow(CatalogThemeConfig t, List statuses) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((st) {
          final label = st.toString();
          final active = _statusFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _statusFilter = label),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active ? t.primaryColor : t.inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? t.primaryColor : t.cardBorder,
                  ),
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
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyReportBox(CatalogThemeConfig t, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: t.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}