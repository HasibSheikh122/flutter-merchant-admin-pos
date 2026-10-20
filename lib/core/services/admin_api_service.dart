// lib/core/services/admin_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tenant_resolver_service.dart';

class AdminApiService {
  /// 1. Central Merchant Login (supports 2FA challenge)
  static Future<Map<String, dynamic>> loginMerchant({
    required String email,
    required String password,
  }) async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/tenants/merchant-login/?subdomain=$sub');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'subdomain': sub,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final String? token = (data['access'] ?? data['token'])?.toString();
      if (token != null && token.isNotEmpty) {
        await TenantResolverService.saveAuthToken(token);
      }
      return data;
    }
    throw Exception(data['detail'] ?? data['error'] ?? 'লগইন ব্যর্থ হয়েছে। ইমেইল ও পাসওয়ার্ড চেক করুন।');
  }

  /// 2. Verify 2FA OTP
  static Future<Map<String, dynamic>> verify2FA({
    required String email,
    required String otpCode,
  }) async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/tenants/verify-2fa/?subdomain=$sub');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'email': email.trim(),
        'otp': otpCode.trim(),
        'subdomain': sub,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final String? token = (data['access'] ?? data['token'])?.toString();
      if (token != null && token.isNotEmpty) {
        await TenantResolverService.saveAuthToken(token);
      }
      return data;
    }
    throw Exception(data['detail'] ?? data['error'] ?? 'ভুল OTP কোড।');
  }

  /// 3. Fetch Dashboard Overview Metrics & Analytics
  static Future<Map<String, dynamic>> fetchDashboardSummary() async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/analytics/summary/?subdomain=$sub');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }

  /// 4. Fetch Store Products (for Catalog & POS Barcode Counter)
  static Future<List<dynamic>> fetchProducts() async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/products/?subdomain=$sub');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['results'] is List) return decoded['results'] as List<dynamic>;
    }
    return [];
  }

  /// 5. POS Barcode Stock Out / Deduction
  static Future<Map<String, dynamic>> deductBarcodeStock({
    required String barcodeOrSku,
    required int quantity,
  }) async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/inventory/barcode-stock-deduct/?subdomain=$sub');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'barcode': barcodeOrSku.trim(),
        'sku': barcodeOrSku.trim(),
        'quantity': quantity,
        'subdomain': sub,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map<String, dynamic> ? decoded : {'status': 'success'};
    }
    throw Exception(decoded['detail'] ?? decoded['error'] ?? 'স্টক আউট সম্পন্ন করা যায়নি।');
  }

  /// 6. Fetch Merchant Orders
  static Future<List<dynamic>> fetchOrders() async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/orders/?subdomain=$sub');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['results'] is List) return decoded['results'] as List<dynamic>;
    }
    return [];
  }

  /// 7. Update Order Status
  static Future<void> updateOrderStatus({
    required dynamic orderId,
    required String status,
  }) async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/orders/$orderId/?subdomain=$sub');
    await http.patch(
      uri,
      headers: headers,
      body: jsonEncode({'status': status}),
    );
  }

  /// 8. Fetch & Trigger App Builder (Spec V2.4)
  static Future<Map<String, dynamic>> fetchAppBuilderConfig() async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/stores/app-builder/?subdomain=$sub');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }

  static Future<Map<String, dynamic>> triggerAppBuild({String buildTarget = 'all'}) async {
    final String baseUrl = await TenantResolverService.getApiBaseUrl();
    final String sub = await TenantResolverService.getSubdomain();
    final headers = await TenantResolverService.getIsolatedHeaders();

    final Uri uri = Uri.parse('$baseUrl/api/v1/stores/app-builder/generate/?subdomain=$sub');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'action': 'generate',
        'build_target': buildTarget,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('অ্যাপ বিল্ড ট্রিগার ব্যর্থ হয়েছে।');
  }
}
