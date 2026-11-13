// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/admin_provider.dart';
import 'screens/merchant_login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: const MerchantPortalApp(),
    ),
  );
}

class MerchantPortalApp extends StatelessWidget {
  const MerchantPortalApp({super.key});

  static const String _envDomain = String.fromEnvironment(
    'STORE_DOMAIN',
    defaultValue: String.fromEnvironment(
      'DEFAULT_TENANT_DOMAIN',
      defaultValue: 'buynarabd.shop.xylotechsolution.com',
    ),
  );

  static const String _envAppName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Merchant Portal',
  );

  static const String _envPrimaryHex = String.fromEnvironment(
    'PRIMARY_COLOR',
    defaultValue: '#5B9A42',
  );

  static Color _parseColor(String hex) {
    String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : const Color(0xFF5B9A42);
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
      home: const MerchantLoginScreen(storeDomain: _envDomain),
    );
  }
}