// lib/providers/admin_provider.dart
import 'package:flutter/material.dart';
import '../core/config/tenant_config.dart';
import '../core/services/tenant_resolver_service.dart';
import '../core/services/admin_api_service.dart';

class AdminProvider extends ChangeNotifier {
  bool isInitializing = true;
  bool isLoading = false;
  bool isDomainResolved = false;
  bool isAuthenticated = false;

  String subdomain = TenantConfig.defaultSubdomain;
  String storeName = TenantConfig.defaultAppName;
  String storeDomain = TenantConfig.defaultTenantDomain;
  Color primaryColor = TenantConfig.parseHexColor(TenantConfig.defaultPrimaryColorHex);

  Map<String, dynamic> metrics = {};
  List<dynamic> products = [];
  List<dynamic> orders = [];
  Map<String, dynamic> appBuilderConfig = {};

  Future<void> initialize() async {
    isInitializing = true;
    notifyListeners();

    try {
      final savedConfig = await TenantResolverService.getSavedTenantConfig();
      if (savedConfig != null) {
        _applyTenantPayload(savedConfig);
        isDomainResolved = true;
      }
      final token = await TenantResolverService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        isAuthenticated = true;
        await refreshAllData();
      }
    } catch (_) {}

    isInitializing = false;
    notifyListeners();
  }

  void _applyTenantPayload(Map<String, dynamic> payload) {
    subdomain = (payload['subdomain'] ?? subdomain).toString();
    storeName = (payload['store_name'] ?? payload['branding']?['app_name'] ?? storeName).toString();
    storeDomain = (payload['domain'] ?? storeDomain).toString();
    final String? hex = payload['branding']?['primary_color']?.toString();
    primaryColor = TenantConfig.parseHexColor(hex, fallback: const Color(0xFF059669));
  }

  Future<void> connectWorkspaceDomain(String domainInput, {String? serverUrl}) async {
    isLoading = true;
    notifyListeners();
    try {
      final payload = await TenantResolverService.resolveTenantDomain(
        domainOrSubdomain: domainInput,
        customServerUrl: serverUrl,
      );
      _applyTenantPayload(payload);
      isDomainResolved = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await AdminApiService.loginMerchant(email: email, password: password);
      if (res['requires_2fa'] != true) {
        isAuthenticated = true;
        await refreshAllData();
      }
      return res;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAllData() async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        AdminApiService.fetchDashboardSummary().catchError((_) => <String, dynamic>{}),
        AdminApiService.fetchProducts().catchError((_) => <dynamic>[]),
        AdminApiService.fetchOrders().catchError((_) => <dynamic>[]),
        AdminApiService.fetchAppBuilderConfig().catchError((_) => <String, dynamic>{}),
      ]);
      metrics = results[0] as Map<String, dynamic>;
      products = results[1] as List<dynamic>;
      orders = results[2] as List<dynamic>;
      appBuilderConfig = results[3] as Map<String, dynamic>;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await TenantResolverService.logoutKeepingTenantLock();
    isAuthenticated = false;
    notifyListeners();
  }

  Future<void> switchWorkspace() async {
    await TenantResolverService.logoutKeepingTenantLock();
    isAuthenticated = false;
    isDomainResolved = false;
    notifyListeners();
  }
}
