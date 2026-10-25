import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'merchant_login_screen.dart';
import '../widgets/admin_top_navbar.dart';
import '../widgets/admin_side_drawer.dart';
import '../widgets/admin_bottom_navbar.dart';
import '../widgets/analytics/customer_analytics_view.dart';
import '../widgets/analytics/order_analytics_view.dart';
import '../widgets/analytics/product_analytics_view.dart';
import '../widgets/analytics/category_analytics_view.dart';

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedBottomNavIndex = 3;
  String _activeDrawerMenu = 'overview';
  bool _isLoading = true;

  // Store Branding & Plan Info
  String _storeName = 'Store Admin';
  String? _storeLogo;
  final Color _brandGreen = const Color(0xFF5B9A42);
  String _planName = 'Growth Spark';
  int _maxProducts = 100;

  // Live Backend KPIs
  double _totalSales = 0.0;
  int _totalOrders = 0;
  int _totalCustomers = 0;
  int _totalProducts = 0;
  int _totalCategories = 0;
  int _totalReviews = 0;
  int _totalShops = 0;
  int _pendingOrders = 0;
  int _completedOrders = 0;
  double _salesGrowth = 0.0;

  // Backend Collections
  List<dynamic> _ordersList = [];
  List<dynamic> _productsList = [];
  List<dynamic> _categoriesList = [];
  List<Map<String, dynamic>> _purchasedProductTimeline = [];

  // Unified AI Analytics Payloads
  Map<String, dynamic> _healthScore = {};
  List<dynamic> _aiInsights = [];
  Map<String, dynamic> _customerAnalytics = {};
  Map<String, dynamic> _ordersAnalytics = {};
  Map<String, dynamic> _productsAnalytics = {};
  Map<String, dynamic> _categoriesAnalytics = {};

  // Monthly Aggregation (Jan - Dec)
  final List<String> _monthNames = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  List<int> _monthlyOrderCounts = List.filled(12, 0);
  List<double> _monthlyRevenueTotals = List.filled(12, 0.0);
  int _selectedMonthIndex = DateTime.now().month - 1;

  @override
  void initState() {
    super.initState();
    _fetchAllBackendData();
  }

  Future<void> _fetchAllBackendData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('merchant_token') ?? '';
    final subdomain = prefs.getString('active_subdomain') ?? 'bestbdbazar';
    String apiBase =
        prefs.getString('api_base_url') ?? 'http://127.0.0.1:8000';

    if (apiBase.endsWith('/')) {
      apiBase = apiBase.substring(0, apiBase.length - 1);
    }

    _storeName = prefs.getString('store_name') ?? subdomain.toUpperCase();
    _storeLogo = prefs.getString('store_logo');

    final headers = {
      'Accept': 'application/json',
      'X-Tenant-Subdomain': subdomain,
      'x-subdomain': subdomain,
      'X-Tenant-Domain': subdomain,
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final refreshQuery = forceRefresh ? '&force_refresh=true' : '';

    try {
      final futures = await Future.wait([
        // 0: Orders List
        http
            .get(Uri.parse('$apiBase/api/v1/orders/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        // 1: Products List
        http
            .get(Uri.parse('$apiBase/api/v1/products/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        // 2: Categories List
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/products/categories/?subdomain=$subdomain&all_shops=true'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        // 3: Customers List
        http
            .get(Uri.parse('$apiBase/api/v1/customers/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('[]', 500)),
        // 4: Master AI Analytics Dashboard
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/ai/analytics/dashboard/?subdomain=$subdomain$refreshQuery'),
                headers: headers)
            .catchError((_) => http.Response('{}', 500)),
        // 5: Store Settings
        http
            .get(
                Uri.parse(
                    '$apiBase/api/v1/stores/settings/?subdomain=$subdomain'),
                headers: headers)
            .catchError((_) => http.Response('{}', 500)),
      ]);

      // 5. Store Settings
      if (futures[5].statusCode == 200) {
        final sData = jsonDecode(futures[5].body);
        if (sData is Map) {
          if (sData['store_name'] != null &&
              sData['store_name'].toString().isNotEmpty) {
            _storeName = sData['store_name'].toString();
          }
          final rawLogo = sData['logo'] ?? sData['store_logo'];
          if (rawLogo is String && rawLogo.isNotEmpty) {
            _storeLogo =
                rawLogo.startsWith('http') ? rawLogo : '$apiBase$rawLogo';
          }
          if (sData['plan_name'] != null) {
            _planName = sData['plan_name'].toString();
          }
          if (sData['max_products'] != null) {
            _maxProducts =
                int.tryParse(sData['max_products'].toString()) ?? 100;
          }
        }
      }

      // 1. Products
      if (futures[1].statusCode == 200) {
        final pData = jsonDecode(futures[1].body);
        if (pData is Map && pData['results'] is List) {
          _productsList = pData['results'];
          _totalProducts = pData['count'] ?? _productsList.length;
        } else if (pData is List) {
          _productsList = pData;
          _totalProducts = _productsList.length;
        }
      }

      // 2. Categories
      if (futures[2].statusCode == 200) {
        final cData = jsonDecode(futures[2].body);
        if (cData is Map && cData['results'] is List) {
          _categoriesList = cData['results'];
          _totalCategories = cData['count'] ?? _categoriesList.length;
        } else if (cData is List) {
          _categoriesList = cData;
          _totalCategories = _categoriesList.length;
        }
      }

      // 3. Customers
      if (futures[3].statusCode == 200) {
        final custData = jsonDecode(futures[3].body);
        if (custData is Map && custData['results'] is List) {
          _totalCustomers =
              custData['count'] ?? (custData['results'] as List).length;
        } else if (custData is List) {
          _totalCustomers = custData.length;
        }
      }

      // 0. Orders
      if (futures[0].statusCode == 200) {
        final oData = jsonDecode(futures[0].body);
        if (oData is Map && oData['results'] is List) {
          _ordersList = oData['results'];
          _totalOrders = oData['count'] ?? _ordersList.length;
        } else if (oData is List) {
          _ordersList = oData;
          _totalOrders = _ordersList.length;
        }
        _computeMonthlyStatsFromOrders();
      }

      // 4. Unified AI Analytics Payload
      if (futures[4].statusCode == 200) {
        final aData = jsonDecode(futures[4].body);
        final payload =
            (aData is Map && aData['data'] is Map) ? aData['data'] : aData;
        if (payload is Map) {
          if (payload['health_score'] is Map) {
            _healthScore = Map<String, dynamic>.from(payload['health_score']);
          }
          if (payload['insights'] is List) {
            _aiInsights = payload['insights'];
          }
          if (payload['customer_analytics'] is Map) {
            _customerAnalytics =
                Map<String, dynamic>.from(payload['customer_analytics']);
            if (_totalCustomers == 0 &&
                _customerAnalytics['total_customers'] != null) {
              _totalCustomers = int.tryParse(
                      _customerAnalytics['total_customers'].toString()) ??
                  0;
            }
          }
          if (payload['orders_analytics'] is Map) {
            _ordersAnalytics =
                Map<String, dynamic>.from(payload['orders_analytics']);
          }
          if (payload['products_analytics'] is Map) {
            _productsAnalytics =
                Map<String, dynamic>.from(payload['products_analytics']);
            if (_totalProducts == 0 &&
                _productsAnalytics['total_products_count'] != null) {
              _totalProducts = int.tryParse(
                      _productsAnalytics['total_products_count'].toString()) ??
                  0;
            }
          }
          if (payload['categories_analytics'] is Map) {
            _categoriesAnalytics =
                Map<String, dynamic>.from(payload['categories_analytics']);
            if (_totalCategories == 0 &&
                _categoriesAnalytics['total_categories_count'] != null) {
              _totalCategories = int.tryParse(_categoriesAnalytics[
                          'total_categories_count']
                      .toString()) ??
                  0;
            }
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _computeMonthlyStatsFromOrders() {
    double salesSum = 0.0;
    int pending = 0;
    int completed = 0;
    final Set<String> uniqueBuyers = {};

    final List<int> monthOrders = List.filled(12, 0);
    final List<double> monthRev = List.filled(12, 0.0);
    final List<Map<String, dynamic>> timeline = [];

    for (var i = 0; i < _ordersList.length; i++) {
      final ord = _ordersList[i];
      if (ord is! Map) continue;

      final double amount = double.tryParse(
            (ord['total_amount'] ??
                    ord['total_price'] ??
                    ord['grand_total'] ??
                    ord['total'] ??
                    ord['amount'] ??
                    '0')
                .toString(),
          ) ??
          0.0;

      salesSum += amount;

      final String status =
          (ord['status'] ?? 'pending').toString().toLowerCase();
      if (status == 'completed' || status == 'delivered') {
        completed++;
      } else if (status != 'cancelled') {
        pending++;
      }

      final String buyer = (ord['customer_name'] ??
              ord['customer_phone'] ??
              ord['customer'] ??
              '')
          .toString()
          .trim();
      if (buyer.isNotEmpty) {
        uniqueBuyers.add(buyer);
      }

      final String rawDate =
          (ord['created_at'] ?? ord['date'] ?? '').toString();
      DateTime? parsedDate = DateTime.tryParse(rawDate);
      parsedDate ??= DateTime.now();

      final int mIdx = (parsedDate.month - 1).clamp(0, 11);
      monthOrders[mIdx] += 1;
      monthRev[mIdx] += amount;

      final String formattedDate =
          '${parsedDate.day.toString().padLeft(2, '0')} ${_monthNames[mIdx]} ${parsedDate.year}';

      final rawItems = ord['items'] ?? ord['order_items'] ?? ord['products'];
      if (rawItems is List && rawItems.isNotEmpty) {
        for (var item in rawItems) {
          if (item is Map) {
            final prodName = (item['product_name'] ??
                    item['name'] ??
                    (item['product'] is Map ? item['product']['name'] : null) ??
                    'Product')
                .toString();
            final qty =
                int.tryParse((item['quantity'] ?? item['qty'] ?? 1).toString()) ??
                    1;
            final itemPrice = double.tryParse(
                    (item['price'] ?? item['total'] ?? amount).toString()) ??
                amount;

            timeline.add({
              'product_name': prodName,
              'order_id': ord['order_number'] ?? '#ORD-${ord['id'] ?? i}',
              'customer': buyer.isNotEmpty ? buyer : 'Customer',
              'date': formattedDate,
              'qty': qty,
              'price': itemPrice,
              'status': status,
            });
          }
        }
      } else {
        String fallbackProdName =
            (ord['product_name'] ?? ord['title'] ?? '').toString();
        if (fallbackProdName.isEmpty && _productsList.isNotEmpty) {
          final matchedProd = _productsList[i % _productsList.length];
          fallbackProdName = (matchedProd['name'] ?? 'Order Item').toString();
        } else if (fallbackProdName.isEmpty) {
          fallbackProdName =
              'Order #${ord['order_number'] ?? ord['id'] ?? (i + 1)}';
        }

        timeline.add({
          'product_name': fallbackProdName,
          'order_id': ord['order_number'] ?? '#ORD-${ord['id'] ?? i}',
          'customer': buyer.isNotEmpty ? buyer : 'Guest Customer',
          'date': formattedDate,
          'qty': 1,
          'price': amount,
          'status': status,
        });
      }
    }

    _totalSales = salesSum;
    _pendingOrders = pending;
    _completedOrders = completed;
    if (_totalCustomers == 0 && uniqueBuyers.isNotEmpty) {
      _totalCustomers = uniqueBuyers.length;
    }

    _monthlyOrderCounts = monthOrders;
    _monthlyRevenueTotals = monthRev;
    _purchasedProductTimeline = timeline;

    for (int m = 11; m >= 0; m--) {
      if (_monthlyOrderCounts[m] > 0) {
        _selectedMonthIndex = m;
        break;
      }
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('merchant_token');
    await prefs.remove('merchant_refresh_token');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MerchantLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgSage = Color(0xFFF1F6F0);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgSage,
      drawer: AdminSideDrawer(
        storeName: _storeName,
        storeLogo: _storeLogo,
        brandGreen: _brandGreen,
        totalOrders: _totalOrders,
        totalCustomers: _totalCustomers,
        totalProducts: _totalProducts,
        totalCategories: _totalCategories,
        totalReviews: _totalReviews,
        totalShops: _totalShops,
        maxProducts: _maxProducts,
        planName: _planName,
        activeMenu: _activeDrawerMenu,
        onMenuSelected: (menuId) {
          setState(() => _activeDrawerMenu = menuId);
        },
        onLogout: _handleLogout,
      ),
      appBar: AdminTopNavbar(
        storeName: _storeName,
        storeLogo: _storeLogo,
        brandGreen: _brandGreen,
        pendingOrders: _pendingOrders,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onRefreshTap: () => _fetchAllBackendData(forceRefresh: true),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _brandGreen))
          : RefreshIndicator(
              onRefresh: () => _fetchAllBackendData(forceRefresh: true),
              color: _brandGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quick Horizontal Section Switcher Pills
                    _buildAnalyticsSectionSwitcher(),
                    const SizedBox(height: 14),

                    // Dynamic Body View Based on Selected Sidebar Menu
                    _buildActiveBodyContent(),

                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Copyright ©2026, $_storeName 💚\nConnected to XyloSaaS AI Analytics Engine',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: AdminBottomNavbar(
        selectedIndex: _selectedBottomNavIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedBottomNavIndex = index;
            if (index == 0) _activeDrawerMenu = 'products';
            if (index == 1) _activeDrawerMenu = 'analytics_orders';
            if (index == 2) _activeDrawerMenu = 'analytics_customer';
            if (index == 3) _activeDrawerMenu = 'overview';
          });
        },
      ),
    );
  }

  Widget _buildAnalyticsSectionSwitcher() {
    final tabs = [
      {'id': 'overview', 'label': 'Overview', 'icon': Icons.dashboard_rounded},
      {
        'id': 'analytics_customer',
        'label': 'Customers AI',
        'icon': Icons.people_alt_rounded
      },
      {
        'id': 'analytics_orders',
        'label': 'Orders BI',
        'icon': Icons.shopping_bag_rounded
      },
      {
        'id': 'analytics_products',
        'label': 'Products 7d',
        'icon': Icons.inventory_2_rounded
      },
      {
        'id': 'analytics_categories',
        'label': 'Categories',
        'icon': Icons.category_rounded
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSelected = _activeDrawerMenu == t['id'] ||
              (t['id'] == 'overview' && _activeDrawerMenu == 'dashboard');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              onSelected: (_) =>
                  setState(() => _activeDrawerMenu = t['id'] as String),
              selectedColor: _brandGreen,
              backgroundColor: Colors.white,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    t['icon'] as IconData,
                    size: 15,
                    color: isSelected ? Colors.white : const Color(0xFF1E3A1A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? Colors.white : const Color(0xFF1E3A1A),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveBodyContent() {
    switch (_activeDrawerMenu) {
      case 'analytics_customer':
      case 'customers':
      case 'report_customers':
        return CustomerAnalyticsView(
          data: _customerAnalytics,
          brandGreen: _brandGreen,
          onRefresh: () => _fetchAllBackendData(forceRefresh: true),
        );
      case 'analytics_orders':
      case 'orders':
      case 'report_orders':
        return OrderAnalyticsView(
          data: _ordersAnalytics,
          brandGreen: _brandGreen,
          onRefresh: () => _fetchAllBackendData(forceRefresh: true),
        );
      case 'analytics_products':
      case 'products':
      case 'inventory':
        return ProductAnalyticsView(
          data: _productsAnalytics,
          brandGreen: _brandGreen,
          onRefresh: () => _fetchAllBackendData(forceRefresh: true),
        );
      case 'analytics_categories':
      case 'categories':
        return CategoryAnalyticsView(
          data: _categoriesAnalytics,
          brandGreen: _brandGreen,
          onRefresh: () => _fetchAllBackendData(forceRefresh: true),
        );
      case 'overview':
      case 'dashboard':
      default:
        return _buildMainOverviewContent();
    }
  }

  Widget _buildMainOverviewContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_healthScore.isNotEmpty) ...[
          _buildExecutiveHealthCard(),
          const SizedBox(height: 16),
        ],

        _buildTopMetricsRow(),
        const SizedBox(height: 16),

        // 1. Total Sales Card
        _buildTotalSalesHeroCard(),
        const SizedBox(height: 16),

        // 2. Summary Monthly Orders Bar Chart
        _buildMonthlyOrdersBarCard(),
        const SizedBox(height: 16),

        // 3. Product Purchase History
        _buildProductPurchaseDateCard(),
        const SizedBox(height: 16),

        // 4. Revenue Generated
        _buildRevenueGeneratedCard(),
        const SizedBox(height: 16),

        // 5, 6, 7, 8. Four-Grid KPI Cards
        _buildFourGridMetrics(),
        const SizedBox(height: 16),

        // Unified AI Insights
        if (_aiInsights.isNotEmpty) ...[
          _buildAiInsightsCard(),
          const SizedBox(height: 16),
        ],

        // 9. Top Selling Products (Recent Orders Shortlist)
        _buildRecentlySoldProductsCard(),
        const SizedBox(height: 16),

        // 10. Top Categories Shortlist
        _buildCategoryShortlistCard(),
      ],
    );
  }

  Widget _buildExecutiveHealthCard() {
    final score =
        int.tryParse((_healthScore['health_score'] ?? 94).toString()) ?? 94;
    final grade = (_healthScore['grade'] ?? 'A+ (Excellent)').toString();
    final statusText =
        (_healthScore['status_text'] ?? 'Store operating at peak efficiency.')
            .toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'HEALTH',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Executive AI Audit: $grade',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _brandGreen, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Unified AI Insights & Recommendations',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: Color(0xFF1E3A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._aiInsights.map((ins) {
            final type = (ins['type'] ?? 'AI Insight').toString();
            final confidence = (ins['confidence'] ?? 95).toString();
            final title = (ins['title'] ?? '').toString();
            final desc = (ins['description'] ?? '').toString();
            final rec = (ins['recommendation'] ?? '').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2EBE0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          type.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _brandGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$confidence% Confidence',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(desc,
                      style:
                          const TextStyle(fontSize: 11.5, color: Colors.black87)),
                  const SizedBox(height: 6),
                  Text(
                    '💡 $rec',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _brandGreen,
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

  Widget _buildTopMetricsRow() {
    final int readyPct = _totalOrders > 0
        ? (((_totalOrders - _pendingOrders) / _totalOrders) * 100)
            .round()
            .clamp(0, 100)
        : 100;
    final int donePct = _totalOrders > 0
        ? ((_completedOrders / _totalOrders) * 100).round().clamp(0, 100)
        : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildProgressCircle('$readyPct%', 'Active', _brandGreen),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Orders',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  '$_totalOrders',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E3A1A)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_drop_up, color: _brandGreen, size: 16),
                    Flexible(
                      child: Text(
                        '${_salesGrowth.toStringAsFixed(1)}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildProgressCircle('$donePct%', 'Done', Colors.pinkAccent),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pending',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  '$_pendingOrders',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E3A1A)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: Colors.amber, size: 12),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'Queue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCircle(String percentage, String label, Color color) {
    final val = (double.tryParse(percentage.replaceAll('%', '')) ?? 0) / 100;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: val,
                strokeWidth: 3.5,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              percentage,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTotalSalesHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '৳${_totalSales.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A1A),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'LIVE REVENUE',
                  style: TextStyle(
                      color: _brandGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Total Sales',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E3A1A)),
          ),
          const SizedBox(height: 4),
          Text(
            '$_totalOrders total orders • $_completedOrders completed & $_pendingOrders awaiting processing',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyOrdersBarCard() {
    final int maxOrders = _monthlyOrderCounts.reduce(math.max);
    final int safeMax = maxOrders > 0 ? maxOrders : 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.bar_chart_rounded, color: _brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Summary (Monthly Orders)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E3A1A)),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${_monthNames[_selectedMonthIndex]} Orders: ${_monthlyOrderCounts[_selectedMonthIndex]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_up, color: _brandGreen, size: 16),
                        Text(
                          'Total: $_totalOrders',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_month_outlined,
                  size: 18, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 155,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double barWidth = (constraints.maxWidth / 12) - 5;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(12, (index) {
                    final int count = _monthlyOrderCounts[index];
                    final bool isSelected = index == _selectedMonthIndex;
                    final double heightFactor = count > 0
                        ? (count / safeMax).clamp(0.15, 1.0)
                        : 0.06;
                    final double barHeight = 95 * heightFactor;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedMonthIndex = index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1E293B)
                                  : (count > 0
                                      ? _brandGreen.withValues(alpha: 0.12)
                                      : Colors.transparent),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.white
                                    : (count > 0
                                        ? const Color(0xFF1E3A1A)
                                        : Colors.grey.shade400),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: math.max(10.0, barWidth),
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4D8837)
                                  : (count > 0
                                      ? const Color(0xFF9CD67D)
                                      : const Color(0xFFE5EFE2)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _monthNames[index],
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF1E3A1A)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPurchaseDateCard() {
    final purchaseItems = _purchasedProductTimeline;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_available_rounded,
                    color: _brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Purchase History',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E3A1A)),
                    ),
                    Text(
                      'Kon product kon date-e kena hoyeche (${purchaseItems.length} records)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (purchaseItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Kono product purchase record paoa jayni.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: purchaseItems.length > 5 ? 5 : purchaseItems.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 16, color: Color(0xFFF1F6F0)),
              itemBuilder: (context, idx) {
                final item = purchaseItems[idx];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _brandGreen.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12, color: _brandGreen),
                          const SizedBox(height: 2),
                          Text(
                            item['date'].toString(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E3A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF1E3A1A),
                            ),
                          ),
                          Text(
                            'Buyer: ${item['customer']} • ${item['order_id']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '৳${(item['price'] as double).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: _brandGreen,
                          ),
                        ),
                        Text(
                          'Qty: ${item['qty']}',
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRevenueGeneratedCard() {
    final List<double> activeRevs = _monthlyRevenueTotals;
    final int currentMonth = DateTime.now().month - 1;
    final double thisMonthRev = activeRevs[currentMonth];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_balance_wallet_outlined,
                    color: _brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue Generated',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E3A1A)),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${_monthNames[currentMonth]} Revenue: ৳${thisMonthRev.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.trending_up_rounded,
                            color: _brandGreen, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '৳${_totalSales.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E3A1A)),
          ),
          Text(
            'Realized from $_totalOrders backend orders',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 85,
            width: double.infinity,
            child: CustomPaint(
              painter: DynamicRevenueChartPainter(
                monthlyRevenues: activeRevs,
                color: _brandGreen,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _monthNames
                  .map((m) => Text(m,
                      style: const TextStyle(
                          fontSize: 8.5,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourGridMetrics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _activeDrawerMenu = 'analytics_customer'),
                child: _buildMetricTile(
                  'Total Customer',
                  'Tap for ANN Churn AI',
                  '$_totalCustomers',
                  'View Customer BI →',
                  Icons.people_alt_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _activeDrawerMenu = 'analytics_products'),
                child: _buildMetricTile(
                  'Total Product',
                  'Tap for +7d Demand AI',
                  '$_totalProducts',
                  'View Product BI →',
                  Icons.inventory_2_rounded,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _activeDrawerMenu = 'analytics_categories'),
                child: _buildMetricTile(
                  'Total Category',
                  'Tap for Market Benchmark',
                  '$_totalCategories',
                  'View Category BI →',
                  Icons.category_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _activeDrawerMenu = 'analytics_orders'),
                child: _buildMetricTile(
                  'Total Orders',
                  'Pending: $_pendingOrders',
                  '$_totalOrders',
                  'View Order Cashflow →',
                  Icons.shopping_bag_rounded,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    String title,
    String subtitle,
    String value,
    String badgeText,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EDE1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A1A)),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: _brandGreen),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E3A1A)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  color: Colors.green.shade700, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  badgeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlySoldProductsCard() {
    final recentSoldList = _purchasedProductTimeline;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_mall_outlined,
                    color: _brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Selling Products (Recent Orders)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E3A1A)),
                    ),
                    Text(
                      'Recently sold product & order shortlist (${recentSoldList.length} items)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentSoldList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Kono recent sold order paoa jayni.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  recentSoldList.length > 6 ? 6 : recentSoldList.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 18, color: Color(0xFFF1F6F0)),
              itemBuilder: (context, i) {
                final item = recentSoldList[i];
                final status = item['status'].toString().toUpperCase();

                return Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.shopping_bag_outlined,
                          color: _brandGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E3A1A)),
                          ),
                          Text(
                            '${item['order_id']} • ${item['customer']} • ${item['date']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '৳${(item['price'] as double).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF1E3A1A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _brandGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: _brandGreen),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryShortlistCard() {
    final cats = _categoriesList;
    final colors = [
      const Color(0xFFC3E88D),
      const Color(0xFF86EFAC),
      const Color(0xFF65A30D),
      const Color(0xFF4D8837),
      const Color(0xFF2E631F),
    ];

    final List<double> shares = [];
    int totalCatProducts = 0;
    for (var c in cats) {
      if (c is Map) {
        totalCatProducts +=
            int.tryParse((c['product_count'] ?? 1).toString()) ?? 1;
      }
    }
    for (var c in cats.take(5)) {
      if (c is Map) {
        final cnt = int.tryParse((c['product_count'] ?? 1).toString()) ?? 1;
        shares.add(totalCatProducts > 0 ? cnt / totalCatProducts : 0.2);
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.category_outlined,
                    color: _brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Categories (Category Shortlist)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E3A1A)),
                    ),
                    Text(
                      'Total $_totalCategories active categories in store',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (cats.isNotEmpty) ...[
            Center(
              child: SizedBox(
                width: 125,
                height: 125,
                child: CustomPaint(
                  painter:
                      DynamicDonutChartPainter(shares: shares, colors: colors),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (cats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Kono category paoa jayni.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cats.length > 6 ? 6 : cats.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 14, color: Color(0xFFF1F6F0)),
              itemBuilder: (context, idx) {
                final cat = cats[idx];
                final name = (cat['name'] ?? 'Category').toString();
                final iconStr = (cat['icon'] ?? '').toString();
                final prodCount =
                    int.tryParse((cat['product_count'] ?? 0).toString()) ?? 0;
                final shopName = (cat['shop_name'] ?? '').toString();

                return Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors[idx % colors.length].withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        iconStr.isNotEmpty
                            ? iconStr
                            : name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A1A)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A1A)),
                          ),
                          if (shopName.isNotEmpty)
                            Text('Shop: $shopName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$prodCount Products',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A1A)),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class DynamicRevenueChartPainter extends CustomPainter {
  final List<double> monthlyRevenues;
  final Color color;

  DynamicRevenueChartPainter({
    required this.monthlyRevenues,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (monthlyRevenues.isEmpty) return;

    final double maxRev = monthlyRevenues.reduce(math.max);
    final double safeMax = maxRev > 0 ? maxRev : 1.0;

    final List<Offset> points = [];
    for (int i = 0; i < monthlyRevenues.length; i++) {
      final double x = (i / (monthlyRevenues.length - 1)) * size.width;
      final double normalizedY = (monthlyRevenues[i] / safeMax).clamp(0.0, 1.0);
      final double y = size.height - (normalizedY * (size.height - 22)) - 6;
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (var p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var p in points) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = color;
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      canvas.drawCircle(p, 3.8, dotPaint);

      if (monthlyRevenues[i] > 0) {
        final textSpan = TextSpan(
          text: '৳${monthlyRevenues[i].toStringAsFixed(0)}',
          style: const TextStyle(
            color: Color(0xFF1E3A1A),
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
          ),
        );
        final tp =
            TextPainter(text: textSpan, textDirection: TextDirection.ltr)
              ..layout();
        tp.paint(
          canvas,
          Offset(
              (p.dx - tp.width / 2).clamp(0.0, size.width - tp.width), p.dy - 14),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DynamicRevenueChartPainter oldDelegate) => true;
}

class DynamicDonutChartPainter extends CustomPainter {
  final List<double> shares;
  final List<Color> colors;

  DynamicDonutChartPainter({required this.shares, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 26.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final activeShares = shares.isNotEmpty ? shares : [0.4, 0.3, 0.3];
    double startAngle = -math.pi / 2;

    for (int i = 0; i < activeShares.length; i++) {
      final sweep = activeShares[i] * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DynamicDonutChartPainter oldDelegate) => true;
}