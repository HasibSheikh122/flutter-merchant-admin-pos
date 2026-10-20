// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/admin_provider.dart';
import 'screens/workspace_domain_screen.dart';
import 'screens/merchant_login_screen.dart';
import 'screens/admin_dashboard_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AdminProvider()..initialize(),
      child: const XyloMerchantAdminApp(),
    ),
  );
}

class XyloMerchantAdminApp extends StatelessWidget {
  const XyloMerchantAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return MaterialApp(
      title: provider.storeName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: provider.primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      home: provider.isInitializing
          ? const Scaffold(
              backgroundColor: Color(0xFF020617),
              body: Center(child: CircularProgressIndicator()),
            )
          : !provider.isDomainResolved
              ? const WorkspaceDomainScreen()
              : !provider.isAuthenticated
                  ? const MerchantLoginScreen()
                  : const AdminDashboardShell(),
    );
  }
}
