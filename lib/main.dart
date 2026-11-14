// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/admin_provider.dart';
import 'screens/merchant_login_screen.dart';
import 'screens/admin_dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String envDomain = String.fromEnvironment(
    'STORE_DOMAIN',
    defaultValue: String.fromEnvironment(
      'DEFAULT_TENANT_DOMAIN',
      defaultValue: '',
    ),
  );
  const String envSub = String.fromEnvironment(
    'TENANT_SUBDOMAIN',
    defaultValue: '',
  );

  final prefs = await SharedPreferences.getInstance();

  // Jodi --dart-define=STORE_DOMAIN dewa thake, tobe ager onno store-er cache clear kore ei store lock korbe
  if (envDomain.trim().isNotEmpty || envSub.trim().isNotEmpty) {
    String cleanDom = envDomain
        .trim()
        .toLowerCase()
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .split('/')
        .first;
    String newSub = envSub.trim().toLowerCase();
    if (newSub.isEmpty && cleanDom.isNotEmpty) {
      newSub = cleanDom.split('.').first;
    }
    if (cleanDom.isEmpty && newSub.isNotEmpty) {
      cleanDom = '$newSub.shop.xylotechsolution.com';
    }

    final String prevSub =
        (prefs.getString('active_subdomain') ?? '').trim().toLowerCase();
    if (prevSub.isNotEmpty && newSub.isNotEmpty && prevSub != newSub) {
      await prefs.remove('merchant_token');
      await prefs.remove('merchant_jwt_token');
      await prefs.remove('merchant_refresh_token');
      await prefs.remove('store_name');
      await prefs.remove('store_logo');
    }
    if (cleanDom.isNotEmpty) {
      await prefs.setString('locked_tenant_domain', cleanDom);
    }
    if (newSub.isNotEmpty) {
      await prefs.setString('active_subdomain', newSub);
      await prefs.setString('locked_tenant_subdomain', newSub);
    }
  }

  final String? token = prefs.getString('merchant_token');
  final bool isLoggedIn = token != null && token.isNotEmpty;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MerchantPortalApp(
        isLoggedIn: isLoggedIn,
        storeDomain: envDomain,
      ),
    ),
  );
}

class MerchantPortalApp extends StatelessWidget {
  final bool isLoggedIn;
  final String storeDomain;

  const MerchantPortalApp({
    super.key,
    required this.isLoggedIn,
    required this.storeDomain,
  });

  static const String _envAppName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Merchant Portal',
  );

  static const String _envPrimaryHex = String.fromEnvironment(
    'PRIMARY_COLOR',
    defaultValue: '#059669',
  );

  static Color _parseColor(String hex) {
    String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : const Color(0xFF059669);
  }

  @override
  Widget build(BuildContext context) {
    final Color brandColor = _parseColor(_envPrimaryHex);
    return MaterialApp(
      title: _envAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F7F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandColor,
          primary: brandColor,
        ),
      ),
      home: isLoggedIn
          ? const AdminDashboardShell()
          : MerchantLoginScreen(storeDomain: storeDomain),
    );
  }
}
