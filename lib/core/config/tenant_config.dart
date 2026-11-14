// lib/core/config/tenant_config.dart
import 'package:flutter/material.dart';

class TenantConfig {
  static const String storeDomain = String.fromEnvironment(
    'STORE_DOMAIN',
    defaultValue: String.fromEnvironment(
      'DEFAULT_TENANT_DOMAIN',
      defaultValue: 'bestbdbazar.shop.xylotechsolution.com',
    ),
  );

  static const String defaultTenantDomain = storeDomain;

  static const String defaultSubdomain = String.fromEnvironment(
    'TENANT_SUBDOMAIN',
    defaultValue: 'bestbdbazar',
  );

  static const String defaultAppName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'BestBDbazar',
  );

  static const String defaultAppSlogan = String.fromEnvironment(
    'APP_SLOGAN',
    defaultValue: 'Authentic Online Shopping',
  );

  static const String defaultAppIconUrl = String.fromEnvironment(
    'APP_ICON_URL',
    defaultValue: '',
  );

  static const String defaultAppIconBase64 = '';

  static const String defaultPrimaryColorHex = String.fromEnvironment(
    'PRIMARY_COLOR',
    defaultValue: '#059669',
  );

  static const String defaultSecondaryColorHex = String.fromEnvironment(
    'SECONDARY_COLOR',
    defaultValue: '#047857',
  );

  static const String defaultBundleId = String.fromEnvironment(
    'BUNDLE_ID',
    defaultValue: 'com.xylosaas.bestbdbazar.admin',
  );

  static const bool isMerchantAdmin = bool.fromEnvironment(
    'IS_MERCHANT_ADMIN',
    defaultValue: true,
  );

  static const String compileTimeStoreDomain = storeDomain;
  static const String compileTimeSubdomain = defaultSubdomain;
  static const int compileTimeTenantId =
      int.fromEnvironment('TENANT_ID', defaultValue: 0);
  static const String compileTimeAppName = defaultAppName;
  static const String compileTimePrimaryColor = defaultPrimaryColorHex;
  static const String compileTimeAppIconUrl = defaultAppIconUrl;

  static String normalizeBaseUrl(String rawDomainOrUrl) {
    String clean = rawDomainOrUrl.trim().toLowerCase();
    if (clean.isEmpty) clean = storeDomain;
    clean = clean.replaceAll('https://', '').replaceAll('http://', '');
    if (clean.contains('/')) clean = clean.split('/').first;
    if (clean.startsWith('localhost') ||
        clean.startsWith('127.0.0.1') ||
        clean.startsWith('10.0.2.2')) {
      return 'http://$clean';
    }
    return 'https://$clean';
  }

  static Color parseHexColor(String? hex,
      {Color fallback = const Color(0xFF059669)}) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }
}