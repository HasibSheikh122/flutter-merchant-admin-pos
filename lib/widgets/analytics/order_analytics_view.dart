import 'package:flutter/material.dart';

class OrderAnalyticsView extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color brandGreen;
  final VoidCallback onRefresh;

  const OrderAnalyticsView({
    super.key,
    required this.data,
    required this.brandGreen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final int totalOrders = int.tryParse((data['total_orders'] ?? 0).toString()) ?? 0;
    final Map<String, dynamic> discountBurn = (data['discount_burn'] is Map)
        ? Map<String, dynamic>.from(data['discount_burn'])
        : {};
    final List<dynamic> hourlyHeatmap =
        (data['hourly_heatmap'] is List) ? data['hourly_heatmap'] : [];
    final List<dynamic> paymentMethods =
        (data['payment_methods'] is List) ? data['payment_methods'] : [];
    final List<dynamic> stackedStatus =
        (data['stacked_status'] is List) ? data['stacked_status'] : [];
    final List<dynamic> orderHistogram =
        (data['order_histogram'] is List) ? data['order_histogram'] : [];
    final List<dynamic> geoDistribution =
        (data['geo_distribution'] is List) ? data['geo_distribution'] : [];

    final double netRevenue =
        double.tryParse((discountBurn['net_revenue'] ?? 0).toString()) ?? 0.0;
    final double burnedAmount =
        double.tryParse((discountBurn['discount_burned'] ?? 0).toString()) ?? 0.0;
    final double burnRatio =
        double.tryParse((discountBurn['burn_ratio'] ?? 0).toString()) ?? 0.0;
    final int aov = totalOrders > 0 ? (netRevenue / totalOrders).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 4 KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Total Order Volume',
                '$totalOrders',
                '1-Query Snapshot',
                Icons.shopping_bag_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Net Realized Sales',
                '৳${netRevenue.toStringAsFixed(0)}',
                'Avg ৳$aov / order',
                Icons.payments_rounded,
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
                'Promo Discount Burn',
                '৳${burnedAmount.toStringAsFixed(0)}',
                '$burnRatio% of gross burned',
                Icons.local_offer_rounded,
                Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Payment Channels',
                '${paymentMethods.length} Active',
                'COD & Prepaid Split',
                Icons.credit_card_rounded,
                Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. 24-Hour Hourly Order Rush Column Heatmap
        if (hourlyHeatmap.isNotEmpty) ...[
          _buildSectionCard(
            title: '24-Hour Hourly Order Rush Heatmap',
            subtitle: 'Peak shopping hours computed from Order.created_at',
            icon: Icons.access_time_filled_rounded,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: hourlyHeatmap.map((h) {
                    final hour = (h['hour'] ?? '').toString();
                    final vol = int.tryParse((h['volume'] ?? 0).toString()) ?? 0;
                    final pct = int.tryParse((h['pct'] ?? 0).toString()) ?? 0;
                    final isPeak = pct >= 75;
                    final barH = (85 * (pct / 100.0)).clamp(6.0, 85.0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$vol',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: isPeak ? Colors.amber.shade800 : const Color(0xFF1E3A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 18,
                            height: barH,
                            decoration: BoxDecoration(
                              color: isPeak
                                  ? Colors.amber.shade600
                                  : (vol > 0 ? brandGreen : const Color(0xFFE2EBE0)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hour,
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Order Basket Size Histogram
        if (orderHistogram.isNotEmpty) ...[
          _buildSectionCard(
            title: 'Order Basket Size Histogram',
            subtitle: 'Order frequency distribution across BDT price brackets',
            icon: Icons.bar_chart_rounded,
            child: SizedBox(
              height: 135,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: orderHistogram.map((bar) {
                  final bin = (bar['bin'] ?? '').toString();
                  final cnt = int.tryParse((bar['count'] ?? 0).toString()) ?? 0;
                  final hStr = (bar['height'] ?? '10%').toString().replaceAll('%', '');
                  final hPct = (double.tryParse(hStr) ?? 10.0) / 100.0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$cnt',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E3A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 36,
                        height: (80 * hPct).clamp(6.0, 80.0),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bin,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 4. Weekly Order Status Pipeline
        if (stackedStatus.isNotEmpty) ...[
          _buildSectionCard(
            title: 'Weekly Order Status Pipeline',
            subtitle: 'Delivered, processing, and cancelled order ratios',
            icon: Icons.layers_outlined,
            child: Column(
              children: stackedStatus.map((wk) {
                final week = (wk['week'] ?? '').toString();
                final del = int.tryParse((wk['delivered'] ?? 0).toString()) ?? 0;
                final pen = int.tryParse((wk['pending'] ?? 0).toString()) ?? 0;
                final can = int.tryParse((wk['cancelled'] ?? 0).toString()) ?? 0;
                final tot = int.tryParse((wk['total_count'] ?? 0).toString()) ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          week,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF1E3A1A),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Delivered: $del% • Pending: $pen% • Cancelled: $can%',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                      Text(
                        '$tot ord',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: brandGreen,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 5. District Parcel Destination Density & Payment Split
        if (geoDistribution.isNotEmpty) ...[
          _buildSectionCard(
            title: 'District Parcel Destination Density',
            subtitle: 'Regional dispatch volume from Order.shipping_address',
            icon: Icons.map_outlined,
            child: Column(
              children: geoDistribution.map((loc) {
                final city = (loc['city'] ?? 'Dhaka').toString();
                final cnt = int.tryParse((loc['count'] ?? 0).toString()) ?? 0;
                final pct = (loc['pct'] ?? '0%').toString();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.location_city_rounded,
                      color: Colors.redAccent, size: 18),
                  title: Text(
                    city,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                  trailing: Text(
                    '$cnt orders ($pct)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 6. Payment Channel Audit
        if (paymentMethods.isNotEmpty)
          _buildSectionCard(
            title: 'Payment Channel Split & Return Audit',
            subtitle: 'Prepaid vs Cash on Delivery risk correlation',
            icon: Icons.account_balance_wallet_outlined,
            child: Column(
              children: paymentMethods.map((pm) {
                final method = (pm['method'] ?? 'COD').toString();
                final count = int.tryParse((pm['count'] ?? 0).toString()) ?? 0;
                final share = (pm['share'] ?? '0%').toString();
                final retRate = (pm['return_rate'] ?? '0%').toString();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    method,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                  subtitle: Text(
                    '$count checkouts ($share share)',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$retRate Returns',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: brandGreen,
                      ),
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