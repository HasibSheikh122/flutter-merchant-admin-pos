import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/admin_provider.dart';
import 'screens/merchant_login_screen.dart';
import 'screens/admin_dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌟 Read STORE_DOMAIN passed from flutter run --dart-define
  const String storeDomain = String.fromEnvironment(
    'STORE_DOMAIN',
    defaultValue: 'bestbdbazar.shop.xylotechsolution.com',
  );

  // Check existing session
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('merchant_token');
  final bool isLoggedIn = token != null && token.isNotEmpty;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: XyloMerchantAdminApp(
        isLoggedIn: isLoggedIn,
        storeDomain: storeDomain,
      ),
    ),
  );
}

class XyloMerchantAdminApp extends StatelessWidget {
  final bool isLoggedIn;
  final String storeDomain;

  const XyloMerchantAdminApp({
    super.key,
    required this.isLoggedIn,
    required this.storeDomain,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merchant Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B14),
        primaryColor: const Color(0xFF059669),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF059669),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF0F172A),
        ),
        fontFamily: 'Roboto',
      ),
      home: isLoggedIn
          ? const AdminDashboardShell()
          : MerchantLoginScreen(storeDomain: storeDomain),
    );
  }
}