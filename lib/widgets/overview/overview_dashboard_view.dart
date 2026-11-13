// lib/widgets/overview/overview_dashboard_view.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'overview_charts.dart';

class OverviewDashboardView extends StatelessWidget {
  final String storeName;
  final bool isDarkMode;
  final Color brandGreen;
  final Color secondaryBrandColor;
  final bool useGradient;

  final double totalSales;
  final int totalOrders;
  final int totalCustomers;
  final int totalProducts;
  final int totalCategories;
  final int totalReviews;
  final int pendingOrders;
  final int completedOrders;
  final double salesGrowth;

  final List<int> monthlyOrderCounts;
  final List<double> monthlyRevenueTotals;
  final int selectedMonthIndex;
  final ValueChanged<int> onSelectMonth;

  final List<dynamic> purchasedProductTimeline;
  final List<dynamic> categoriesList;
  final ValueChanged<String> onNavigateMenu;

  const OverviewDashboardView({
    super.key,
    required this.storeName,
    required this.isDarkMode,
    required this.brandGreen,
    required this.secondaryBrandColor,
    required this.useGradient,
    required this.totalSales,
    required this.totalOrders,
    required this.totalCustomers,
    required this.totalProducts,
    required this.totalCategories,
    required this.totalReviews,
    required this.pendingOrders,
    required this.completedOrders,
    required this.salesGrowth,
    required this.monthlyOrderCounts,
    required this.monthlyRevenueTotals,
    required this.selectedMonthIndex,
    required this.onSelectMonth,
    required this.purchasedProductTimeline,
    required this.categoriesList,
    required this.onNavigateMenu,
  });

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  Color get _cardBg => isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get _cardBorder =>
      isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2EBE0);
  Color get _primaryText =>
      isDarkMode ? Colors.white : const Color(0xFF1E3A1A);
  Color get _secondaryText =>
      isDarkMode ? const Color(0xFF94A3B8) : Colors.grey.shade600;
  Color get _tileBg =>
      isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE4EDE1);
  Color get _softBoxBg =>
      isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F6F0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopMetricsRow(),
        const SizedBox(height: 16),
        _buildTotalSalesHeroCard(),
        const SizedBox(height: 16),
        _buildMonthlyOrdersBarCard(),
        const SizedBox(height: 16),
        _buildProductPurchaseDateCard(),
        const SizedBox(height: 16),
        _buildRevenueGeneratedCard(),
        const SizedBox(height: 16),
        _buildFourGridMetrics(),
        const SizedBox(height: 16),
        _buildRecentlySoldProductsCard(),
        const SizedBox(height: 16),
        _buildCategoryShortlistCard(),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Copyright ©2026, $storeName 💚\nConnected to XyloSaaS Multi-Tenant Backend',
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryText, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTopMetricsRow() {
    final int readyPct = totalOrders > 0
        ? (((totalOrders - pendingOrders) / totalOrders) * 100)
            .round()
            .clamp(0, 100)
        : 100;
    final int donePct = totalOrders > 0
        ? ((completedOrders / totalOrders) * 100).round().clamp(0, 100)
        : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildProgressCircle('$readyPct%', 'Active', brandGreen),
          GestureDetector(
            onTap: () => onNavigateMenu('orders'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orders',
                    style: TextStyle(fontSize: 11, color: _secondaryText)),
                Text(
                  '$totalOrders',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _primaryText),
                ),
                Row(
                  children: [
                    Icon(Icons.arrow_drop_up, color: brandGreen, size: 16),
                    Text(
                      '${salesGrowth.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: brandGreen),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildProgressCircle('$donePct%', 'Done', Colors.pinkAccent),
          GestureDetector(
            onTap: () => onNavigateMenu('orders'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending',
                    style: TextStyle(fontSize: 11, color: _secondaryText)),
                Text(
                  '$pendingOrders',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _primaryText),
                ),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: Colors.amber, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      'Queue',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700),
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
            style: TextStyle(
                fontSize: 10,
                color: _secondaryText,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTotalSalesHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '৳${totalSales.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _primaryText,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: useGradient
                      ? LinearGradient(
                          colors: [brandGreen, secondaryBrandColor],
                        )
                      : null,
                  color: useGradient
                      ? null
                      : brandGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'LIVE REVENUE',
                  style: TextStyle(
                      color: useGradient ? Colors.white : brandGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Total Sales',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _primaryText),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalOrders total orders • $completedOrders completed & $pendingOrders awaiting processing',
            style: TextStyle(
                fontSize: 12,
                color: _secondaryText,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyOrdersBarCard() {
    final int maxOrders =
        monthlyOrderCounts.isNotEmpty ? monthlyOrderCounts.reduce(math.max) : 1;
    final int safeMax = maxOrders > 0 ? maxOrders : 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.bar_chart_rounded, color: brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary (Monthly Orders)',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _primaryText),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_monthNames[selectedMonthIndex]} Orders: ${monthlyOrderCounts[selectedMonthIndex]}',
                          style: TextStyle(
                              fontSize: 11,
                              color: _secondaryText,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_drop_up, color: brandGreen, size: 16),
                        Text(
                          'Total: $totalOrders',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: brandGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.calendar_month_outlined,
                  size: 18, color: _secondaryText),
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
                    final int count = monthlyOrderCounts[index];
                    final bool isSelected = index == selectedMonthIndex;
                    final double heightFactor = count > 0
                        ? (count / safeMax).clamp(0.15, 1.0)
                        : 0.06;
                    final double barHeight = 95 * heightFactor;

                    return GestureDetector(
                      onTap: () => onSelectMonth(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandGreen
                                  : (count > 0
                                      ? brandGreen.withValues(alpha: 0.15)
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
                                        ? _primaryText
                                        : _secondaryText),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: math.max(10.0, barWidth),
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: (isSelected && useGradient)
                                  ? LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        brandGreen,
                                        secondaryBrandColor
                                      ],
                                    )
                                  : null,
                              color: (isSelected && useGradient)
                                  ? null
                                  : (isSelected
                                      ? brandGreen
                                      : (count > 0
                                          ? brandGreen.withValues(alpha: 0.55)
                                          : (isDarkMode
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFE5EFE2)))),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _monthNames[index],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: isSelected ? _primaryText : _secondaryText,
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
    final purchaseItems = purchasedProductTimeline;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_available_rounded,
                    color: brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Purchase History',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _primaryText),
                    ),
                    Text(
                      'Kon product kon date-e kena hoyeche (${purchaseItems.length} records)',
                      style: TextStyle(fontSize: 11, color: _secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (purchaseItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Kono product purchase record paoa jayni.',
                  style: TextStyle(fontSize: 12, color: _secondaryText),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: purchaseItems.length > 5 ? 5 : purchaseItems.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 16, color: _cardBorder),
              itemBuilder: (context, idx) {
                final item = purchaseItems[idx] as Map;
                final double itemPrice =
                    double.tryParse((item['price'] ?? 0).toString()) ?? 0.0;
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _softBoxBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: brandGreen.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12, color: brandGreen),
                          const SizedBox(height: 2),
                          Text(
                            item['date'].toString(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _primaryText,
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
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: _primaryText,
                            ),
                          ),
                          Text(
                            'Buyer: ${item['customer']} • ${item['order_id']}',
                            style:
                                TextStyle(fontSize: 10, color: _secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '৳${itemPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: brandGreen,
                          ),
                        ),
                        Text(
                          'Qty: ${item['qty']}',
                          style:
                              TextStyle(fontSize: 10, color: _secondaryText),
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
    final List<double> activeRevs = monthlyRevenueTotals;
    final int currentMonth = DateTime.now().month - 1;
    final double thisMonthRev =
        activeRevs.length > currentMonth ? activeRevs[currentMonth] : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_balance_wallet_outlined,
                    color: brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Generated',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _primaryText),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_monthNames[currentMonth]} Revenue: ৳${thisMonthRev.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: _secondaryText,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.trending_up_rounded,
                            color: brandGreen, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '৳${totalSales.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _primaryText),
          ),
          Text(
            'Realized from $totalOrders backend orders',
            style: TextStyle(fontSize: 11, color: _secondaryText),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 85,
            width: double.infinity,
            child: CustomPaint(
              painter: DynamicRevenueChartPainter(
                monthlyRevenues: activeRevs,
                color: brandGreen,
                labelColor: _primaryText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _monthNames
                  .map((m) => Text(m,
                      style: TextStyle(
                          fontSize: 8.5,
                          color: _secondaryText,
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
                onTap: () => onNavigateMenu('customers'),
                child: _buildMetricTile(
                  'Total Customer',
                  'Registered & Buyers',
                  '$totalCustomers',
                  'Tap to Manage',
                  Icons.people_alt_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigateMenu('products'),
                child: _buildMetricTile(
                  'Total Product',
                  'Store Catalog SKUs',
                  '$totalProducts',
                  'Tap to Manage',
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
                onTap: () => onNavigateMenu('categories'),
                child: _buildMetricTile(
                  'Total Category',
                  'Active Taxonomies',
                  '$totalCategories',
                  'Tap to Manage',
                  Icons.category_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigateMenu('orders'),
                child: _buildMetricTile(
                  'Total Orders',
                  'Pending: $pendingOrders',
                  '$totalOrders',
                  'Completed: $completedOrders',
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
        color: _tileBg,
        borderRadius: BorderRadius.circular(20),
        border: isDarkMode ? Border.all(color: _cardBorder) : null,
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
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _primaryText),
                ),
              ),
              Icon(icon, size: 16, color: brandGreen),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: _secondaryText)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _primaryText),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: brandGreen, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  badgeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: brandGreen),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlySoldProductsCard() {
    final recentSoldList = purchasedProductTimeline;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_mall_outlined,
                    color: brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Selling Products (Recent Orders)',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _primaryText),
                    ),
                    Text(
                      'Recently sold product & order shortlist (${recentSoldList.length} items)',
                      style: TextStyle(fontSize: 11, color: _secondaryText),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onNavigateMenu('orders'),
                child: Text(
                  'All Orders',
                  style: TextStyle(
                    color: brandGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentSoldList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Kono recent sold order paoa jayni.',
                    style: TextStyle(color: _secondaryText, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  recentSoldList.length > 6 ? 6 : recentSoldList.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 18, color: _cardBorder),
              itemBuilder: (context, i) {
                final item = recentSoldList[i] as Map;
                final status = item['status'].toString().toUpperCase();
                final double itemPrice =
                    double.tryParse((item['price'] ?? 0).toString()) ?? 0.0;

                return Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _softBoxBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.shopping_bag_outlined,
                          color: brandGreen, size: 20),
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
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _primaryText),
                          ),
                          Text(
                            '${item['order_id']} • ${item['customer']} • ${item['date']}',
                            style:
                                TextStyle(fontSize: 10, color: _secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '৳${itemPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: _primaryText),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: brandGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: brandGreen),
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
    final cats = categoriesList;
    final colors = [
      brandGreen,
      secondaryBrandColor,
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
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.category_outlined,
                    color: brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Categories (Category Shortlist)',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _primaryText),
                    ),
                    Text(
                      'Total $totalCategories active categories in store',
                      style: TextStyle(fontSize: 11, color: _secondaryText),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onNavigateMenu('categories'),
                child: Text(
                  'Manage All',
                  style: TextStyle(
                    color: brandGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Kono category paoa jayni.',
                    style: TextStyle(color: _secondaryText, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cats.length > 6 ? 6 : cats.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 14, color: _cardBorder),
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
                        color:
                            colors[idx % colors.length].withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        iconStr.isNotEmpty
                            ? iconStr
                            : name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _primaryText),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _primaryText),
                          ),
                          if (shopName.isNotEmpty)
                            Text('Shop: $shopName',
                                style: TextStyle(
                                    fontSize: 10, color: _secondaryText)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _softBoxBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$prodCount Products',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _primaryText),
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