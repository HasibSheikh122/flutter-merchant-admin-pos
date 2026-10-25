import 'package:flutter/material.dart';

class CustomerAnalyticsView extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color brandGreen;
  final VoidCallback onRefresh;

  const CustomerAnalyticsView({
    super.key,
    required this.data,
    required this.brandGreen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final int totalCustomers =
        int.tryParse((data['total_customers'] ?? 0).toString()) ?? 0;
    final Map<String, dynamic> retention = (data['retention'] is Map)
        ? Map<String, dynamic>.from(data['retention'])
        : {};
    final Map<String, dynamic> churnSummary = (data['churn_ai_summary'] is Map)
        ? Map<String, dynamic>.from(data['churn_ai_summary'])
        : {};
    final List<dynamic> loginActivity =
        (data['login_activity'] is List) ? data['login_activity'] : [];
    final List<dynamic> conversionFunnel =
        (data['conversion_funnel'] is List) ? data['conversion_funnel'] : [];
    final List<dynamic> topBuyers =
        (data['top_buyers_volume'] is List) ? data['top_buyers_volume'] : [];
    final List<dynamic> areaHotspots =
        (data['area_hotspots'] is List) ? data['area_hotspots'] : [];

    final double repeatPct =
        double.tryParse((retention['repeat_pct'] ?? 0).toString()) ?? 0.0;
    final int repeatCount =
        int.tryParse((retention['repeat_count'] ?? 0).toString()) ?? 0;
    final int newCount =
        int.tryParse((retention['new_count'] ?? 0).toString()) ?? 0;

    final String modelEngine =
        (churnSummary['model_engine'] ?? 'XGBoost + ANN (MLP)').toString();
    final double avgChurnPct =
        double.tryParse((churnSummary['avg_churn_score_pct'] ?? 0).toString()) ??
            0.0;
    final int highRiskCount =
        int.tryParse((churnSummary['high_risk_count'] ?? 0).toString()) ?? 0;
    final double revAtRisk = double.tryParse(
            (churnSummary['potential_revenue_at_risk'] ?? 0).toString()) ??
        0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Cyber-Matrix Neural Behavioral Telemetry Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1410),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEURAL BEHAVIORAL TELEMETRY',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          modelEngine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(
                      Icons.sync_rounded,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildHudBadge(
                      'AVG CHURN: $avgChurnPct%', const Color(0xFF10B981)),
                  _buildHudBadge(
                      'RISK CLV: ৳${revAtRisk.toStringAsFixed(0)}',
                      Colors.redAccent),
                  _buildHudBadge(
                      'AT-RISK ACCOUNTS: $highRiskCount', Colors.amber),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. 4 KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Total Customers',
                '$totalCustomers',
                '1-SQL Annotated Sync',
                Icons.people_alt_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Repeat Retention',
                '$repeatPct%',
                '$repeatCount repeat / $newCount new',
                Icons.autorenew_rounded,
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
                'CLV Revenue at Risk',
                '৳${revAtRisk.toStringAsFixed(0)}',
                'ANN Lifetime Projection',
                Icons.trending_down_rounded,
                Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'AI Churn Risk (>50%)',
                '$highRiskCount Acc',
                'Avg Score: $avgChurnPct%',
                Icons.warning_amber_rounded,
                Colors.redAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Full Customer Conversion Funnel
        if (conversionFunnel.isNotEmpty) ...[
          _buildSectionCard(
            title: 'Full Customer Conversion Funnel',
            subtitle: 'Visitors → Views → Cart → Checkout → Delivered',
            icon: Icons.filter_alt_outlined,
            child: Column(
              children: conversionFunnel.map((step) {
                final stage = (step['stage'] ?? '').toString();
                final count = int.tryParse((step['count'] ?? 0).toString()) ?? 0;
                final pct = (step['pct'] ?? '0%').toString();
                final widthStr =
                    (step['width'] ?? '50%').toString().replaceAll('%', '');
                final widthPct = (double.tryParse(widthStr) ?? 50.0) / 100.0;

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
                              stage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A1A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count ($pct)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: brandGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: widthPct.clamp(0.05, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2EBE0),
                          valueColor: AlwaysStoppedAnimation<Color>(brandGreen),
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

        // 4. ANN / XGBoost Churn Probability Cohorts
        if (loginActivity.isNotEmpty) ...[
          _buildSectionCard(
            title: 'ANN / XGBoost Churn Probability Cohorts',
            subtitle: '0% to 100% Neural Churn Score based on RFM, AOV & Returns',
            icon: Icons.psychology_outlined,
            child: Column(
              children: loginActivity.map((tier) {
                final label = (tier['label'] ?? '').toString();
                final count = int.tryParse((tier['count'] ?? 0).toString()) ?? 0;
                final pct =
                    double.tryParse((tier['pct'] ?? 0).toString()) ?? 0.0;
                final hex =
                    (tier['color'] ?? '#10b981').toString().replaceAll('#', '');
                final barColor = Color(int.tryParse('0xFF$hex') ?? 0xFF10B981);

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
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E3A1A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count users ($pct%)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E3A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (pct / 100.0).clamp(0.04, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2EBE0),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
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

        // 5. Area Demand Hotspots
        if (areaHotspots.isNotEmpty) ...[
          _buildSectionCard(
            title: 'Geographic Customer & Order Hotspots',
            subtitle: 'Regional buyer concentration & realized revenue',
            icon: Icons.location_on_outlined,
            child: Column(
              children: areaHotspots.take(5).map((area) {
                final areaName = (area['area'] ?? 'Dhaka').toString();
                final orders =
                    int.tryParse((area['orders'] ?? 0).toString()) ?? 0;
                final revenue =
                    double.tryParse((area['revenue'] ?? 0).toString()) ?? 0.0;
                final sharePct =
                    double.tryParse((area['share_pct'] ?? 0).toString()) ?? 0.0;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: brandGreen.withValues(alpha: 0.12),
                    child: Icon(Icons.place_rounded, color: brandGreen, size: 18),
                  ),
                  title: Text(
                    areaName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                  subtitle: Text(
                    '$orders Orders • Share: $sharePct%',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Text(
                    '৳${revenue.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: brandGreen,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 6. Top High-Value Buyers Leaderboard (Fixed lowercase workspace_premium_outlined)
        _buildSectionCard(
          title: 'Top High-Value Buyers & Predicted CLV',
          subtitle: 'Live customer ranking with AI Churn Score & Lifetime Value',
          icon: Icons.workspace_premium_outlined,
          child: topBuyers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Kono buyer data paoa jayni.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topBuyers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 18, color: Color(0xFFF1F6F0)),
                  itemBuilder: (context, idx) {
                    final b = topBuyers[idx];
                    final name = (b['name'] ?? 'Buyer').toString();
                    final phone = (b['phone'] ?? 'N/A').toString();
                    final orders = b['order_count'] ?? 1;
                    final spent =
                        double.tryParse((b['spent'] ?? 0).toString()) ?? 0.0;
                    final clv =
                        double.tryParse((b['predicted_clv'] ?? 0).toString()) ??
                            0.0;
                    final churnStr = (b['churn_risk_pct'] ?? '12.5%').toString();

                    return Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: brandGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '#${idx + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
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
                                '$phone • $orders Orders • Churn: $churnStr',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey,
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
                              '৳${spent.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF1E3A1A),
                              ),
                            ),
                            Text(
                              'CLV: ৳${clv.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                color: Colors.amber.shade800,
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

  Widget _buildHudBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E3A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
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
                  color: brandGreen.withValues(alpha: 0.12),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Color(0xFF1E3A1A),
                      ),
                    ),
                    Text(
                      subtitle,
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
          child,
        ],
      ),
    );
  }
}