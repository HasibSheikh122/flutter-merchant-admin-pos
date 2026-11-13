import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class AnalyticsBiView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final ValueChanged? onNavigateMenu;

  const AnalyticsBiView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'analytics_customer',
    this.onNavigateMenu,
  });

  @override
  State<AnalyticsBiView> createState() => _AnalyticsBiViewState();
}

class _AnalyticsBiViewState extends State<AnalyticsBiView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  late String _activeTab;
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Master Payload from /api/v1/ai/analytics/dashboard/
  Map _healthScore = {
    'health_score': 92,
    'grade': 'A+ (Excellent)',
    'status_text': 'Store operating at peak efficiency.',
  };
  Map _peakWindow = {
    'peak_window': '7:00 PM - 10:00 PM',
    'volume': 0,
  };
  List _insights = [];
  List _next7dProjections = [];

  Map _customerAnalytics = {};
  Map _ordersAnalytics = {};
  Map _productsAnalytics = {};
  Map _categoriesAnalytics = {};

  @override
  void initState() {
    super.initState();
    _activeTab = _normalizeTab(widget.initialTab);
    _initAnalyticsModule();
  }

  @override
  void didUpdateWidget(covariant AnalyticsBiView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _activeTab = _normalizeTab(widget.initialTab);
      });
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
    }
  }

  String _normalizeTab(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('order') || lower.contains('cash')) {
      return 'analytics_orders';
    }
    if (lower.contains('product') || lower.contains('curve')) {
      return 'analytics_products';
    }
    if (lower.contains('categor') || lower.contains('fb')) {
      return 'analytics_categories';
    }
    return 'analytics_customer';
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

  Future _initAnalyticsModule() async {
    setState(() => _isLoading = true);
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = loaded);
    }

    await _loadCachedSnapshot();
    await _fetchBackendAnalytics(forceRefresh: false);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future _loadCachedSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached =
          prefs.getString('xylo_ai_analytics_v5_${_theme.subdomain}');
      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          _applyDashboardPayload(decoded, saveCache: false);
        }
      }
    } catch (_) {}
  }

  Future _saveCachedSnapshot(Map data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'xylo_ai_analytics_v5_${_theme.subdomain}',
        jsonEncode(data),
      );
    } catch (_) {}
  }

  Future _fetchBackendAnalytics({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() => _isRefreshing = true);
    }
    final base = _theme.apiBase;
    final sub = _theme.subdomain;
    final headers = _theme.headers;
    final refreshParam = forceRefresh ? '&force_refresh=true' : '';

    final candidateUrls = [
      '$base/api/v1/ai/analytics/dashboard/?subdomain=$sub$refreshParam',
      '$base/api/v1/ai-engine/analytics/dashboard/?subdomain=$sub$refreshParam',
    ];

    bool loadedFromMaster = false;
    for (final url in candidateUrls) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          final dataNode =
              (body is Map && body['data'] is Map) ? body['data'] : body;
          if (dataNode is Map) {
            _applyDashboardPayload(dataNode, saveCache: true);
            loadedFromMaster = true;
            break;
          }
        }
      } catch (_) {}
    }

    // Fallback: try individual deep-dive section if master wasn't reached
    if (!loadedFromMaster) {
      await _fetchDeepDiveSectionsFallback(forceRefresh: forceRefresh);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future _fetchDeepDiveSectionsFallback({bool forceRefresh = false}) async {
    final base = _theme.apiBase;
    final sub = _theme.subdomain;
    final headers = _theme.headers;
    final rf = forceRefresh ? '&force_refresh=true' : '';

    for (final sec in ['customer', 'orders', 'products', 'categories']) {
      try {
        final uri = Uri.parse(
          '$base/api/v1/ai/analytics/deep-dive/?section=$sec&subdomain=$sub$rf',
        );
        final res = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final parsed = jsonDecode(res.body);
          final secData =
              (parsed is Map && parsed['data'] is Map) ? parsed['data'] : parsed;
          if (secData is Map && mounted) {
            setState(() {
              if (sec == 'customer') _customerAnalytics = Map.from(secData);
              if (sec == 'orders') _ordersAnalytics = Map.from(secData);
              if (sec == 'products') _productsAnalytics = Map.from(secData);
              if (sec == 'categories') _categoriesAnalytics = Map.from(secData);
            });
          }
        }
      } catch (_) {}
    }
  }

  void _applyDashboardPayload(Map data, {bool saveCache = false}) {
    setState(() {
      if (data['health_score'] is Map) {
        _healthScore = Map.from(data['health_score']);
      }
      if (data['peak_shopping_window'] is Map) {
        _peakWindow = Map.from(data['peak_shopping_window']);
      }
      if (data['insights'] is List) {
        _insights = List.from(data['insights']);
      }
      if (data['next_7d_projections'] is List) {
        _next7dProjections = List.from(data['next_7d_projections']);
      }
      if (data['customer_analytics'] is Map) {
        _customerAnalytics = Map.from(data['customer_analytics']);
      }
      if (data['orders_analytics'] is Map) {
        _ordersAnalytics = Map.from(data['orders_analytics']);
      }
      if (data['products_analytics'] is Map) {
        _productsAnalytics = Map.from(data['products_analytics']);
      }
      if (data['categories_analytics'] is Map) {
        _categoriesAnalytics = Map.from(data['categories_analytics']);
      }
    });

    if (saveCache) {
      _saveCachedSnapshot(data);
    }
  }

  Color _parseHexOrDefault(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final v = int.tryParse('FF$clean', radix: 16);
      if (v != null) return Color(v);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExecutiveHeroHeader(t),
        const SizedBox(height: 14),
        _buildSubTabsBar(t),
        const SizedBox(height: 16),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 70),
            child: Center(
              child: CircularProgressIndicator(color: t.primaryColor),
            ),
          )
        else ...[
          if (_activeTab == 'analytics_customer')
            _buildCustomerIntelligenceSection(t),
          if (_activeTab == 'analytics_orders')
            _buildOrdersCashflowSection(t),
          if (_activeTab == 'analytics_products')
            _buildProductAiCurvesSection(t),
          if (_activeTab == 'analytics_categories')
            _buildCategoryFbMarketSection(t),
        ],
      ],
    );
  }

  // ===========================================================================
  // EXECUTIVE HERO HEADER (Store Health Score + AI Engine Status)
  // ===========================================================================
  Widget _buildExecutiveHeroHeader(CatalogThemeConfig t) {
    final score =
        int.tryParse((_healthScore['health_score'] ?? '92').toString()) ?? 92;
    final grade = (_healthScore['grade'] ?? 'A+ (Excellent)').toString();
    final statusText = (_healthScore['status_text'] ??
            'Store operating at peak efficiency.')
        .toString();
    final peakWin =
        (_peakWindow['peak_window'] ?? '7:00 PM - 10:00 PM').toString();

    final churnSummary = _customerAnalytics['churn_ai_summary'] is Map
        ? _customerAnalytics['churn_ai_summary'] as Map
        : {};
    final revAtRisk = double.tryParse(
            (churnSummary['potential_revenue_at_risk'] ?? '0').toString()) ??
        0.0;

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
            color: t.primaryColor.withValues(alpha: 0.25),
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
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 26,
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
                            'Neural AI Analytics & BI Engine',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'HEALTH $score/100 • $grade',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$statusText (GRU-Seasonal + XGBoost/ANN Churn + 1-SQL Snapshot)',
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
                onPressed: _isRefreshing
                    ? null
                    : () => _fetchBackendAnalytics(forceRefresh: true),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(
                  _isRefreshing ? 'Computing...' : 'Re-Run AI',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
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
                Icons.schedule_rounded,
                'Peak Shopping: $peakWin',
              ),
              _buildHeroStatPill(
                Icons.shield_outlined,
                'CLV At Risk: ৳${revAtRisk.toStringAsFixed(0)}',
              ),
              _buildHeroStatPill(
                Icons.people_alt_outlined,
                'Analyzed Buyers: ${_customerAnalytics['total_customers'] ?? 0}',
              ),
              _buildHeroStatPill(
                Icons.shopping_bag_outlined,
                '30d Orders: ${_ordersAnalytics['total_orders'] ?? 0}',
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
  // 4 SUB-TABS BAR
  // ===========================================================================
  Widget _buildSubTabsBar(CatalogThemeConfig t) {
    final tabs = [
      {
        'key': 'analytics_customer',
        'label': 'Customer Intelligence',
        'icon': Icons.insights_rounded,
        'badge': 'ANN Churn',
      },
      {
        'key': 'analytics_orders',
        'label': 'Orders & Cashflow',
        'icon': Icons.show_chart_rounded,
        'badge': '24h Heat',
      },
      {
        'key': 'analytics_products',
        'label': 'Product & AI Curves',
        'icon': Icons.trending_up_rounded,
        'badge': 'GRU 7d',
      },
      {
        'key': 'analytics_categories',
        'label': 'Category & FB Market',
        'icon': Icons.pie_chart_outline_rounded,
        'badge': 'Treemap',
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
                setState(() => _activeTab = tab['key'] as String);
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
  // TAB 1: CUSTOMER INTELLIGENCE (analytics_customer)
  // ===========================================================================
  Widget _buildCustomerIntelligenceSection(CatalogThemeConfig t) {
    final churnSummary = _customerAnalytics['churn_ai_summary'] is Map
        ? _customerAnalytics['churn_ai_summary'] as Map
        : {};
    final loginActivity = _customerAnalytics['login_activity'] is List
        ? List.from(_customerAnalytics['login_activity'])
        : [];
    final funnelSteps = _customerAnalytics['conversion_funnel'] is List
        ? List.from(_customerAnalytics['conversion_funnel'])
        : [];
    final topBuyers = _customerAnalytics['top_buyers_volume'] is List
        ? List.from(_customerAnalytics['top_buyers_volume'])
        : [];
    final hotspots = _customerAnalytics['area_hotspots'] is List
        ? List.from(_customerAnalytics['area_hotspots'])
        : [];
    final retention = _customerAnalytics['retention'] is Map
        ? _customerAnalytics['retention'] as Map
        : {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ANN / XGBoost Churn & Retention Summary Card
        Container(
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
                  Icon(Icons.psychology_rounded,
                      color: t.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upgrade B: ${churnSummary['model_engine'] ?? 'ANN / XGBoost'} Customer Churn & CLV',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Avg Churn: ${churnSummary['avg_churn_score_pct'] ?? 14.2}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...loginActivity.map((tier) {
                if (tier is! Map) return const SizedBox.shrink();
                final pct =
                    double.tryParse((tier['pct'] ?? '0').toString()) ?? 0.0;
                final barColor = _parseHexOrDefault(
                    tier['color']?.toString(), t.primaryColor);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (tier['label'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            '${tier['count'] ?? 0} Users ($pct%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: barColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (pct / 100.0).clamp(0.03, 1.0),
                          minHeight: 7,
                          backgroundColor: t.inputBg,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricMiniBox(
                      t,
                      label: 'Repeat Buyers',
                      value:
                          '${retention['repeat_count'] ?? 0} (${retention['repeat_pct'] ?? 0}%)',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricMiniBox(
                      t,
                      label: 'First-Time Buyers',
                      value:
                          '${retention['new_count'] ?? 0} (${retention['new_pct'] ?? 0}%)',
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. 5-Stage Conversion Funnel
        Container(
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
                  Icon(Icons.filter_alt_outlined,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Storefront Conversion Funnel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...funnelSteps.asMap().entries.map((entry) {
                final idx = entry.key;
                final st = entry.value;
                if (st is! Map) return const SizedBox.shrink();
                final ratio = (1.0 - (idx * 0.16)).clamp(0.22, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${idx + 1}. ${st['stage'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            '${st['count'] ?? 0} (${st['pct'] ?? ''})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            gradient:
                                t.useGradient ? t.brandGradient : null,
                            color: t.useGradient ? null : t.primaryColor,
                            borderRadius: BorderRadius.circular(6),
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
        const SizedBox(height: 16),

        // 3. Top Buyers by CLV & Spend
        Container(
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
                  Icon(Icons.workspace_premium_rounded,
                      color: const Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Top VIP Buyers & AI Predicted CLV',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (topBuyers.isEmpty)
                Text(
                  'No buyer volume records yet.',
                  style: TextStyle(color: t.secondaryText, fontSize: 12.5),
                )
              else
                ...topBuyers.map((b) {
                  if (b is! Map) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (b['name'] ?? 'Verified Buyer').toString(),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${b['phone'] ?? 'N/A'} • ${b['order_count'] ?? 1} Orders (${b['items'] ?? 1} Items)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: t.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Churn Risk: ${b['churn_risk_pct'] ?? '12%'}  |  Predicted CLV: ৳${b['predicted_clv'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: t.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '৳${b['spent'] ?? 0}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: t.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),

        if (hotspots.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
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
                    Icon(Icons.location_on_outlined,
                        color: t.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Geo-Demand & Delivery Area Hotspots',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...hotspots.take(6).map((h) {
                  if (h is! Map) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${h['area']} (${h['unique_buyers'] ?? 1} Buyers)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                        Text(
                          '${h['orders']} Orders • ৳${h['revenue']} (${h['share_pct']}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: t.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // TAB 2: ORDERS & CASHFLOW (analytics_orders)
  // ===========================================================================
  Widget _buildOrdersCashflowSection(CatalogThemeConfig t) {
    final hourly = _ordersAnalytics['hourly_heatmap'] is List
        ? List.from(_ordersAnalytics['hourly_heatmap'])
        : [];
    final payMethods = _ordersAnalytics['payment_methods'] is List
        ? List.from(_ordersAnalytics['payment_methods'])
        : [];
    final histogram = _ordersAnalytics['order_histogram'] is List
        ? List.from(_ordersAnalytics['order_histogram'])
        : [];
    final geoDist = _ordersAnalytics['geo_distribution'] is List
        ? List.from(_ordersAnalytics['geo_distribution'])
        : [];
    final discBurn = _ordersAnalytics['discount_burn'] is Map
        ? _ordersAnalytics['discount_burn'] as Map
        : {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Upgrade A: Next 7-Day Prophet / GRU Sales Forecast
        if (_next7dProjections.isNotEmpty) ...[
          Container(
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
                    Icon(Icons.auto_graph_rounded,
                        color: t.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Upgrade A: Next 7-Days Sales Forecast (GRU / Prophet)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _next7dProjections.map((proj) {
                      if (proj is! Map) return const SizedBox.shrink();
                      final isWknd = proj['is_weekend'] == true;
                      return Container(
                        width: 122,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isWknd
                              ? t.primaryColor.withValues(alpha: 0.12)
                              : t.inputBg,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: isWknd ? t.primaryColor : t.cardBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${proj['day_name'] ?? ''} (${proj['date'] ?? ''})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: t.secondaryText,
                                  ),
                                ),
                                if (isWknd)
                                  Icon(Icons.local_fire_department_rounded,
                                      size: 14, color: t.primaryColor),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '৳${proj['projected_sales'] ?? 0}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isWknd ? 'Weekend Surge' : 'Standard Day',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isWknd
                                    ? t.primaryColor
                                    : t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. Cashflow & Discount Burn Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cashflow, AOV Histogram & Discount Burn',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricMiniBox(
                      t,
                      label: 'Net Order Revenue',
                      value: '৳${discBurn['net_revenue'] ?? 0}',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricMiniBox(
                      t,
                      label: 'Discount Burned',
                      value:
                          '৳${discBurn['discount_burned'] ?? 0} (${discBurn['burn_ratio'] ?? 0}%)',
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              if (histogram.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Order Basket Size Distribution:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: histogram.map((b) {
                    if (b is! Map) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: t.inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Text(
                            (b['bin'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: t.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${b['count'] ?? 0} Orders',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. 24-Hour Shopping Heatmap & Payment Channels
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Methods & Return Rate Analysis',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              ...payMethods.map((pm) {
                if (pm is! Map) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${pm['method']} (${pm['count']} Orders)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      Text(
                        'Share: ${pm['share']}  |  Return Rate: ${pm['return_rate']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: t.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (hourly.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '24-Hour Order Activity Peaks:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: hourly
                      .where((h) =>
                          h is Map &&
                          (int.tryParse((h['volume'] ?? '0').toString()) ?? 0) >
                              0)
                      .map((h) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: t.primaryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${h['hour']}: ${h['volume']} ord',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: t.primaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (geoDist.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Top Order Cities:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                ...geoDist.map((g) {
                  if (g is! Map) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          (g['city'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          '${g['count']} Orders (${g['pct']})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: t.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: PRODUCT & AI CURVES (analytics_products)
  // ===========================================================================
  Widget _buildProductAiCurvesSection(CatalogThemeConfig t) {
    final demandVsStock = _productsAnalytics['ai_demand_vs_stock'] is List
        ? List.from(_productsAnalytics['ai_demand_vs_stock'])
        : [];
    final bestSellers = _productsAnalytics['best_sellers'] is List
        ? List.from(_productsAnalytics['best_sellers'])
        : [];
    final reviewDist = _productsAnalytics['review_dist'] is List
        ? List.from(_productsAnalytics['review_dist'])
        : [];
    final targetGauge = _productsAnalytics['target_gauge'] is Map
        ? _productsAnalytics['target_gauge'] as Map
        : {};

    final achievedPct = double.tryParse(
            (targetGauge['achieved_pct'] ?? '0').toString()) ??
        0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Monthly Revenue Target Gauge
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monthly Revenue Target Progress',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                  Text(
                    '$achievedPct% Achieved',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: t.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (achievedPct / 100.0).clamp(0.02, 1.0),
                  minHeight: 10,
                  backgroundColor: t.inputBg,
                  color: t.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Month: ৳${targetGauge['current_sales'] ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.secondaryText,
                    ),
                  ),
                  Text(
                    'Target: ৳${targetGauge['target_sales'] ?? 500000}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. AI 7-Day Item Demand Forecast vs Stock Depletion
        Container(
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
                  Icon(Icons.trending_up_rounded,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI 7-Day Item Demand Forecast vs Current Stock (${demandVsStock.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...demandVsStock.take(15).map((item) {
                if (item is! Map) return const SizedBox.shrink();
                final alert =
                    (item['alert'] ?? 'healthy').toString().toLowerCase();
                Color alertColor = const Color(0xFF10B981);
                if (alert == 'critical') alertColor = Colors.redAccent;
                if (alert == 'warning') alertColor = const Color(0xFFF59E0B);

                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['name'] ?? 'Product').toString(),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: t.primaryText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Stock: ${item['stock']} pcs • 30d Sold: ${item['demand_30d']} • 7d AI Forecast: ${item['predicted_7d_units']} pcs',
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
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: alertColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item['days_left']}d left • ${alert.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: alertColor,
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
        const SizedBox(height: 16),

        // 3. Best Sellers & Review-Return Correlation
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Best-Selling Products & Review Return Correlation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              ...bestSellers.take(8).map((bs) {
                if (bs is! Map) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          (bs['name'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: t.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '${bs['sold']} Sold • ৳${bs['revenue']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: t.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (reviewDist.isNotEmpty) ...[
                Divider(color: t.cardBorder, height: 22),
                ...reviewDist.map((rv) {
                  if (rv is! Map) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          (rv['stars'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          '${rv['orders']} Reviews • ${rv['returns']}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: CATEGORY & FB MARKET BENCHMARK (analytics_categories)
  // ===========================================================================
  Widget _buildCategoryFbMarketSection(CatalogThemeConfig t) {
    final catShare = _categoriesAnalytics['category_revenue_share'] is List
        ? List.from(_categoriesAnalytics['category_revenue_share'])
        : [];
    final fbBenchmark = _categoriesAnalytics['fb_market_benchmark'] is List
        ? List.from(_categoriesAnalytics['fb_market_benchmark'])
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Category Revenue Share Treemap List
        Container(
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
                  Icon(Icons.pie_chart_outline_rounded,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Department & Category Revenue Share (${catShare.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (catShare.isEmpty)
                Text(
                  'No category revenue distribution data yet.',
                  style: TextStyle(color: t.secondaryText, fontSize: 12.5),
                )
              else
                ...catShare.map((c) {
                  if (c is! Map) return const SizedBox.shrink();
                  final share =
                      double.tryParse((c['share'] ?? '0').toString()) ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              (c['category'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              '${c['amount']} ($share%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: t.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (share / 100.0).clamp(0.04, 1.0),
                            minHeight: 7,
                            backgroundColor: t.inputBg,
                            color: t.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Facebook & Retail Market Price Benchmark
        Container(
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
                  Icon(Icons.compare_arrows_rounded,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Facebook & Retail Market Price Benchmark',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...fbBenchmark.map((fb) {
                if (fb is! Map) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: t.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (fb['product'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Store: ৳${fb['store_price']}  |  FB / Retail Avg: ৳${fb['fb_price']}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              (fb['position'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: t.primaryColor,
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
        ),

        // 3. Executive AI Recommendations
        if (_insights.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
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
                    Icon(Icons.auto_awesome_rounded,
                        color: const Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Executive AI Recommendations',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._insights.map((ins) {
                  if (ins is! Map) return const SizedBox.shrink();
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                '${ins['type'] ?? 'AI Insight'} • ${ins['confidence'] ?? 95}% Confidence',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryColor,
                                ),
                              ),
                            ),
                            if (ins['action_tab'] != null &&
                                widget.onNavigateMenu != null)
                              TextButton(
                                onPressed: () {
                                  widget.onNavigateMenu!(
                                      ins['action_tab'].toString());
                                },
                                child: Text(
                                  'Take Action →',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: t.primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (ins['title'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: t.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (ins['description'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: t.secondaryText,
                          ),
                        ),
                        if ((ins['recommendation'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Action: ${ins['recommendation']}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricMiniBox(
    CatalogThemeConfig t, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
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
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: t.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}