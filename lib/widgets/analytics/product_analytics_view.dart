import 'package:flutter/material.dart';

class ProductAnalyticsView extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color brandGreen;
  final VoidCallback onRefresh;

  const ProductAnalyticsView({
    super.key,
    required this.data,
    required this.brandGreen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> demandVsStock =
        (data['ai_demand_vs_stock'] is List) ? data['ai_demand_vs_stock'] : [];
    final List<dynamic> bestSellers =
        (data['best_sellers'] is List) ? data['best_sellers'] : [];
    final List<dynamic> reviewDist =
        (data['review_dist'] is List) ? data['review_dist'] : [];
    final Map<String, dynamic> targetGauge = (data['target_gauge'] is Map)
        ? Map<String, dynamic>.from(data['target_gauge'])
        : {};

    final int totalProducts =
        int.tryParse((data['total_products_count'] ?? demandVsStock.length).toString()) ?? 0;

    int criticalCount = 0;
    int warningCount = 0;
    int totalPredicted7d = 0;

    for (var item in demandVsStock) {
      if (item is Map) {
        if (item['alert'] == 'critical') criticalCount++;
        if (item['alert'] == 'warning') warningCount++;
        totalPredicted7d += int.tryParse((item['predicted_7d_units'] ?? 0).toString()) ?? 0;
      }
    }

    final double achievedPct =
        double.tryParse((targetGauge['achieved_pct'] ?? 0).toString()) ?? 0.0;
    final double currentSales =
        double.tryParse((targetGauge['current_sales'] ?? 0).toString()) ?? 0.0;
    final double targetSales =
        double.tryParse((targetGauge['target_sales'] ?? 500000).toString()) ?? 500000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 4 KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Tracked Catalog',
                '$totalProducts Items',
                '1-SQL Annotated Sync',
                Icons.inventory_2_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'GRU/Prophet +7d',
                '$totalPredicted7d Pcs',
                'Next 7d AI Demand',
                Icons.memory_rounded,
                Colors.amber.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Stockout Risk (≤7d)',
                '$criticalCount Critical',
                '+$warningCount running low',
                Icons.warning_amber_rounded,
                Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Monthly Goal Gauge',
                '$achievedPct%',
                '৳${currentSales.toStringAsFixed(0)} / ৳${(targetSales / 1000).toStringAsFixed(0)}k',
                Icons.speed_rounded,
                brandGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Physical Stock vs 30d Sold & +7d AI Demand Forecast
        if (demandVsStock.isNotEmpty) ...[
          _buildSectionCard(
            title: 'Physical Stock vs 30d Sold & +7d AI Forecast',
            subtitle: 'Prophet/GRU seasonal velocity & runout days countdown',
            icon: Icons.analytics_outlined,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: demandVsStock.length > 8 ? 8 : demandVsStock.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 16, color: Color(0xFFF1F6F0)),
              itemBuilder: (context, idx) {
                final p = demandVsStock[idx];
                final name = (p['name'] ?? 'Product').toString();
                final stock = int.tryParse((p['stock'] ?? 0).toString()) ?? 0;
                final sold30d = int.tryParse((p['demand_30d'] ?? 0).toString()) ?? 0;
                final pred7d = int.tryParse((p['predicted_7d_units'] ?? 0).toString()) ?? 0;
                final daysLeft = int.tryParse((p['days_left'] ?? 99).toString()) ?? 99;
                final alert = (p['alert'] ?? 'healthy').toString();

                final isCrit = alert == 'critical';

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF1E3A1A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Stock: $stock pcs • 30d Sold: $sold30d pcs • +7d AI: $pred7d pcs',
                            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCrit
                            ? Colors.red.shade50
                            : brandGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '~${daysLeft}d left',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isCrit ? Colors.red.shade700 : brandGreen,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Top Best Selling Products Leaderboard
        _buildSectionCard(
          title: 'Top Best Selling Products (Qty & Revenue)',
          subtitle: 'Live aggregation directly from OrderItem model',
          icon: Icons.emoji_events_outlined,
          child: bestSellers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Kono best-seller record paoa jayni.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bestSellers.length > 8 ? 8 : bestSellers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 16, color: Color(0xFFF1F6F0)),
                  itemBuilder: (context, idx) {
                    final prod = bestSellers[idx];
                    final name = (prod['name'] ?? 'Product').toString();
                    final sold = int.tryParse((prod['sold'] ?? 0).toString()) ?? 0;
                    final rev = double.tryParse((prod['revenue'] ?? 0).toString()) ?? 0.0;

                    return Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: brandGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${idx + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: brandGreen,
                            ),
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF1E3A1A),
                                ),
                              ),
                              Text(
                                '$sold Units Sold',
                                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '৳${rev.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: brandGreen,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),

        // 4. Review Ratings vs Return Correlation
        if (reviewDist.isNotEmpty)
          _buildSectionCard(
            title: 'Review Ratings vs Return Correlation',
            subtitle: 'Ratings distribution from Review model vs returns',
            icon: Icons.star_outline_rounded,
            child: Column(
              children: reviewDist.map((r) {
                final stars = (r['stars'] ?? '').toString();
                final orders = int.tryParse((r['orders'] ?? 0).toString()) ?? 0;
                final returns = (r['returns'] ?? '').toString();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  title: Text(
                    stars,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                  subtitle: Text(
                    '$orders Verified Customer Reviews',
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                  trailing: Text(
                    returns,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildKpiCard(
      String title, String value, String sub, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE0)),
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E3A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
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
                  color: brandGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: brandGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Color(0xFF1E3A1A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}