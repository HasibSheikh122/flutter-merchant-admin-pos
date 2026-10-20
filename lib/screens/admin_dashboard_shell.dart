// lib/screens/admin_dashboard_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../core/services/admin_api_service.dart';
import '../widgets/metric_stat_card.dart';

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _selectedIndex = 0;
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  String? _posFeedback;

  Future<void> _handleBarcodeDeduct() async {
    if (_barcodeCtrl.text.trim().isEmpty) return;
    try {
      final qty = int.tryParse(_qtyCtrl.text) ?? 1;
      await AdminApiService.deductBarcodeStock(
        barcodeOrSku: _barcodeCtrl.text,
        quantity: qty,
      );
      setState(() => _posFeedback = 'সফলভাবে স্টক আউট হয়েছে: ${_barcodeCtrl.text} (-$qty)');
      _barcodeCtrl.clear();
      if (mounted) {
        context.read<AdminProvider>().refreshAllData();
      }
    } catch (e) {
      setState(() => _posFeedback = e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    final pages = [
      _buildOverviewTab(provider),
      _buildPosCounterTab(provider),
      _buildOrdersTab(provider),
      _buildAppBuilderTab(provider),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.storeName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            Text(
              'Workspace: ${provider.storeDomain}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: provider.refreshAllData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Sync Data',
          ),
          IconButton(
            onPressed: provider.logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout (Keep Domain Lock)',
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: 'POS Counter'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_rounded), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.phone_iphone_rounded), label: 'App Builder'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(AdminProvider provider) {
    final totalRev = provider.metrics['total_revenue'] ?? provider.metrics['revenue'] ?? 0;
    final totalOrders = provider.orders.length;
    final totalProducts = provider.products.length;

    return RefreshIndicator(
      onRefresh: provider.refreshAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MetricStatCard(
                title: 'Total Revenue',
                value: '৳$totalRev',
                subtitle: 'Live Store Sales',
                icon: Icons.payments_rounded,
                accentColor: const Color(0xFF10B981),
              ),
              MetricStatCard(
                title: 'Total Orders',
                value: '$totalOrders',
                subtitle: 'Synced Orders',
                icon: Icons.local_shipping_rounded,
                accentColor: const Color(0xFF38BDF8),
              ),
              MetricStatCard(
                title: 'Catalog SKUs',
                value: '$totalProducts',
                subtitle: 'Active Products',
                icon: Icons.inventory_2_rounded,
                accentColor: const Color(0xFFA855F7),
              ),
              MetricStatCard(
                title: 'Tenant Lock',
                value: provider.subdomain.toUpperCase(),
                subtitle: 'Isolated Schema',
                icon: Icons.verified_user_rounded,
                accentColor: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Recent Catalog Products',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 10),
          ...provider.products.take(10).map((p) {
            final name = p['name'] ?? 'Product';
            final price = p['price'] ?? 0;
            final stock = p['stock_quantity'] ?? p['stock'] ?? 0;
            return Card(
              color: const Color(0xFF0F172A),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                title: Text(name.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: Text('SKU: ${p['sku'] ?? 'N/A'} • Stock: $stock', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                trailing: Text(
                  '৳$price',
                  style: TextStyle(color: provider.primaryColor, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPosCounterTab(AdminProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: provider.primaryColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'POS Barcode Stock-Out & Billing Counter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'বারকোড স্ক্যানার বা SKU দিয়ে সরাসরি স্টোরের ইনভেন্টরি থেকে স্টক ডিডাক্ট করুন।',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _barcodeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Scan Barcode or Enter SKU',
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                  filled: true,
                  fillColor: const Color(0xFF020617),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  filled: true,
                  fillColor: const Color(0xFF020617),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _handleBarcodeDeduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Confirm POS Stock Out', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (_posFeedback != null) ...[
                const SizedBox(height: 12),
                Text(
                  _posFeedback!,
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab(AdminProvider provider) {
    if (provider.orders.isEmpty) {
      return const Center(
        child: Text('কোনো অর্ডার পাওয়া যায়নি।', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.orders.length,
      itemBuilder: (context, idx) {
        final ord = provider.orders[idx];
        final orderNumber = ord['order_number'] ?? 'ORD-${ord['id']}';
        final status = (ord['status'] ?? 'pending').toString();
        final total = ord['total'] ?? ord['total_amount'] ?? 0;

        return Card(
          color: const Color(0xFF0F172A),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            title: Text(orderNumber.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            subtitle: Text('Status: ${status.toUpperCase()} • Total: ৳$total', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (newStatus) async {
                await AdminApiService.updateOrderStatus(orderId: ord['id'], status: newStatus);
                provider.refreshAllData();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'processing', child: Text('Mark Processing')),
                PopupMenuItem(value: 'shipped', child: Text('Mark Shipped')),
                PopupMenuItem(value: 'delivered', child: Text('Mark Delivered')),
                PopupMenuItem(value: 'cancelled', child: Text('Cancel Order')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBuilderTab(AdminProvider provider) {
    final appCfg = provider.appBuilderConfig['app_config'] ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'White-Label App Builder (Spec V2.4)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Admin Repo: ${appCfg['admin_flutter_repo_url'] ?? 'https://github.com/xylosaas/flutter-merchant-admin-pos'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(height: 4),
              Text(
                '2. Store Repo: ${appCfg['store_flutter_repo_url'] ?? 'https://github.com/xylosaas/flutter-customer-storefront'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await AdminApiService.triggerAppBuild(buildTarget: 'all');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CI/CD App Build Triggered Successfully!')),
                    );
                    provider.refreshAllData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text('Trigger Store & Admin App Build'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
