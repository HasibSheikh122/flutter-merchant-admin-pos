// lib/core/config/tenant_config.dart
import 'package:flutter/material.dart';

class TenantConfig {
  static const String defaultTenantDomain = String.fromEnvironment(
    'DEFAULT_TENANT_DOMAIN',
    defaultValue: 'nextlook.localhost:8000',
  );

  static const String defaultSubdomain = String.fromEnvironment(
    'TENANT_SUBDOMAIN',
    defaultValue: 'nextlook',
  );

  static const String defaultAppName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Xylo Merchant Admin & POS',
  );

  static const String defaultPrimaryColorHex = String.fromEnvironment(
    'PRIMARY_COLOR',
    defaultValue: '#059669',
  );

  static const bool isMerchantAdmin = bool.fromEnvironment(
    'IS_MERCHANT_ADMIN',
    defaultValue: true,
  );

  static Color parseHexColor(String? hexString, {Color fallback = const Color(0xFF059669)}) {
    if (hexString == null || hexString.trim().isEmpty) return fallback;
    String clean = hexString.trim().replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  /// Normalizes localhost / Android Emulator (10.0.2.2) / Production URLs
  static String normalizeBaseUrl(String rawDomainOrUrl, {bool isAndroidEmulator = false}) {
    String clean = rawDomainOrUrl.trim();
    if (clean.isEmpty) clean = defaultTenantDomain;
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      final bool isLocal = clean.contains('localhost') ||
          clean.startsWith('127.0.0.1') ||
          clean.startsWith('10.0.2.2') ||
          clean.startsWith('192.168.');
      clean = '${isLocal ? "http" : "https"}://$clean';
    }
    if (isAndroidEmulator && clean.contains('localhost')) {
      clean = clean.replaceAll('localhost', '10.0.2.2');
    }
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }
}
