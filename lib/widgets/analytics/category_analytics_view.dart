import 'package:flutter/material.dart';

class CategoryAnalyticsView extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color brandGreen;
  final VoidCallback onRefresh;

  const CategoryAnalyticsView({
    super.key,
    required this.data,
    required this.brandGreen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> categoryRevenue =
        (data['category_revenue_share'] is List) ? data['category_revenue_share'] : [];
    final List<dynamic> fbBenchmarks =
        (data['fb_market_benchmark'] is List) ? data['fb_market_benchmark'] : [];
    final int totalCategories = int.tryParse(
            (data['total_categories_count'] ?? categoryRevenue.length).toString()) ??
        0;

    final String topCategoryName = categoryRevenue.isNotEmpty
        ? (categoryRevenue.first['category'] ?? 'N/A').toString()
        : 'N/A';
    final String topCategoryShare = categoryRevenue.isNotEmpty
        ? '${categoryRevenue.first['share'] ?? 0}%'
        : '0%';

    double totalAttributedRev = 0.0;
    for (var c in categoryRevenue) {
      if (c is Map) {
        totalAttributedRev +=
            double.tryParse((c['raw_amount'] ?? 0).toString()) ?? 0.0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 4 KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Tracked Taxonomies',
                '$totalCategories Cats',
                'Category & Product Sync',
                Icons.category_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Dominant Category',
                topCategoryName,
                '$topCategoryShare of gross sales',
                Icons.emoji_events_rounded,
                brandGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Department Revenue',
                '৳${totalAttributedRev.toStringAsFixed(0)}',
                'OrderItem & Category Sync',
                Icons.payments_rounded,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Price Competitiveness',
                '${fbBenchmarks.length} SKUs',
                'Lower than retail avg',
                Icons.trending_down_rounded,
                Colors.amber.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Sales Contribution Ranking
        _buildSectionCard(
          title: 'Category Sales Contribution Ranking',
          subtitle: 'Proportional revenue share per department from OrderItem',
          icon: Icons.pie_chart_outline_rounded,
          child: categoryRevenue.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Kono category bikroy data paoa jayni.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                )
              : Column(
                  children: List.generate(
                    categoryRevenue.length > 10 ? 10 : categoryRevenue.length,
                    (idx) {
                      final c = categoryRevenue[idx];
                      final catName = (c['category'] ?? 'Category').toString();
                      final amount = (c['amount'] ?? '৳0').toString();
                      final share =
                          double.tryParse((c['share'] ?? 0).toString()) ?? 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '#${idx + 1} $catName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: Color(0xFF1E3A1A),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$amount ($share%)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: brandGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (share / 100.0).clamp(0.04, 1.0),
                                minHeight: 7,
                                backgroundColor: const Color(0xFFE2EBE0),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(brandGreen),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // 3. Store Selling Price vs Regular Retail / Market Price Benchmark
        if (fbBenchmarks.isNotEmpty)
          _buildSectionCard(
            title: 'Store Price vs Regular Retail Benchmark',
            subtitle: 'Product.price (Green) vs Product.compare_price (Amber)',
            icon: Icons.compare_arrows_rounded,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fbBenchmarks.length > 8 ? 8 : fbBenchmarks.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 16, color: Color(0xFFF1F6F0)),
              itemBuilder: (context, idx) {
                final b = fbBenchmarks[idx];
                final product = (b['product'] ?? 'Product').toString();
                final storePrice =
                    double.tryParse((b['store_price'] ?? 0).toString()) ?? 0.0;
                final fbPrice =
                    double.tryParse((b['fb_price'] ?? 0).toString()) ?? 0.0;
                final pos = (b['position'] ?? '').toString();

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF1E3A1A),
                            ),
                          ),
                          Text(
                            pos,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: brandGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Store: ৳${storePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            color: brandGreen,
                          ),
                        ),
                        Text(
                          'Retail: ৳${fbPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
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