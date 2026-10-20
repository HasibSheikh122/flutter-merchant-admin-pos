// lib/core/services/tenant_resolver_service.dart
// Technical Spec V2.4 — Slack-Model Dynamic Domain Resolver & Session Isolation
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tenant_config.dart';

class TenantResolverService {
  static const String _keyDomain = 'locked_tenant_domain';
  static const String _keySubdomain = 'locked_tenant_subdomain';
  static const String _keyApiBase = 'locked_api_base_url';
  static const String _keyTenantConfig = 'locked_tenant_config';
  static const String _keyAuthToken = 'merchant_jwt_token';

  /// Resolves a merchant store domain or subdomain via /api/v1/stores/tenant/resolve/
  static Future<Map<String, dynamic>> resolveTenantDomain({
    required String domainOrSubdomain,
    String? customServerUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String cleanInput = domainOrSubdomain.trim().toLowerCase();
    final String sub = cleanInput.contains('.') ? cleanInput.split('.').first : cleanInput;

    // Determine server base URL
    String baseUrl = customServerUrl?.trim() ?? '';
    if (baseUrl.isEmpty) {
      if (cleanInput.contains('localhost') || cleanInput.contains(':8000') || cleanInput.startsWith('10.0.2.2')) {
        baseUrl = TenantConfig.normalizeBaseUrl(cleanInput);
      } else if (cleanInput.contains('.')) {
        baseUrl = 'https://$cleanInput';
      } else {
        baseUrl = TenantConfig.normalizeBaseUrl('$sub.localhost:8000');
      }
    } else {
      baseUrl = TenantConfig.normalizeBaseUrl(baseUrl);
    }

    final Uri uri = Uri.parse(
      '$baseUrl/api/v1/stores/tenant/resolve/?domain=${Uri.encodeComponent(cleanInput)}&subdomain=${Uri.encodeComponent(sub)}',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Tenant-Domain': cleanInput,
        'X-Tenant-Subdomain': sub,
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final String resolvedSub = (data['subdomain'] ?? sub).toString();
      final String resolvedDomain = (data['domain'] ?? cleanInput).toString();
      final String resolvedApiBase = (data['endpoints']?['api_base_url'] ?? baseUrl).toString();

      await prefs.setString(_keyDomain, resolvedDomain);
      await prefs.setString(_keySubdomain, resolvedSub);
      await prefs.setString(_keyApiBase, resolvedApiBase);
      await prefs.setString(_keyTenantConfig, jsonEncode(data));
      return data;
    } else {
      throw Exception('স্টোর ডোমেইন খুঁজে পাওয়া যায়নি (Status ${response.statusCode})');
    }
  }

  /// Returns persistent headers for every API call.
  /// Spec V2.4 Section 3: Tenant domain lock survives staff/merchant logout!
  static Future<Map<String, String>> getIsolatedHeaders({String? overrideSubdomain}) async {
    final prefs = await SharedPreferences.getInstance();
    final String domain = prefs.getString(_keyDomain) ?? TenantConfig.defaultTenantDomain;
    final String subdomain = overrideSubdomain ?? prefs.getString(_keySubdomain) ?? TenantConfig.defaultSubdomain;
    final String? token = prefs.getString(_keyAuthToken);

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Tenant-Domain': domain,
      'X-Tenant-Subdomain': subdomain,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiBase) ?? TenantConfig.normalizeBaseUrl(TenantConfig.defaultTenantDomain);
  }

  static Future<String> getSubdomain() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySubdomain) ?? TenantConfig.defaultSubdomain;
  }

  static Future<Map<String, dynamic>?> getSavedTenantConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_keyTenantConfig);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthToken, token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAuthToken);
  }

  /// Clears JWT token on logout while preserving locked_tenant_domain (Spec Section 3)
  static Future<void> logoutKeepingTenantLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
  }
}
