// lib/screens/merchant_login_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_dashboard_shell.dart';

class MerchantLoginScreen extends StatefulWidget {
  final String storeDomain;
  final String apiBaseOverride;

  const MerchantLoginScreen({
    super.key,
    this.storeDomain = const String.fromEnvironment(
      'STORE_DOMAIN',
      defaultValue: String.fromEnvironment(
        'DEFAULT_TENANT_DOMAIN',
        defaultValue: '',
      ),
    ),
    this.apiBaseOverride = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    ),
  });

  @override
  State createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State
    with SingleTickerProviderStateMixin {
  @override
  MerchantLoginScreen get widget => super.widget as MerchantLoginScreen;

  final GlobalKey _formKey = GlobalKey();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Dynamic Tenant Domain & API Base State
  String _activeDomain = '';
  String _activeSubdomain = '';
  String _customApiBase = '';
  String _resolvedWorkingApiBase = '';

  String _storeName = 'Merchant Admin';
  String? _logoUrl;
  Color _brandColor = const Color(0xFF5B9A42);

  late AnimationController _pulseController;
  late Animation _scaleAnimation;
  late Animation _glowAnimation;

  static const String _envSubdomain = String.fromEnvironment(
    'TENANT_SUBDOMAIN',
    defaultValue: '',
  );

  static const String _platformRootDomain = 'shop.xylotechsolution.com';

  // Standard Chrome Mobile User-Agent so Cloudflare never blocks Flutter requests
  static const String _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _glowAnimation = Tween(begin: 4.0, end: 20.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _initTenantAndFetchBranding();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _cleanHost(String raw) {
    String d = raw.trim().toLowerCase();
    d = d.replaceAll('https://', '').replaceAll('http://', '');
    if (d.contains('/')) {
      d = d.split('/').first;
    }
    return d.trim();
  }

  String _extractSubdomain(String rawDomain) {
    final String clean = _cleanHost(rawDomain);
    if (clean.isEmpty) {
      return _envSubdomain.isNotEmpty ? _envSubdomain.toLowerCase() : '';
    }
    final String withoutPort = clean.split(':').first;
    final List parts = withoutPort.split('.');
    if (parts.isNotEmpty && parts.first.toString().isNotEmpty) {
      final String firstPart = parts.first.toString();
      if (firstPart != 'www' &&
          firstPart != 'shop' &&
          firstPart != 'api' &&
          firstPart != 'localhost' &&
          firstPart != '127' &&
          firstPart != '10' &&
          firstPart != '192') {
        return firstPart;
      }
      if (parts.length >= 2 && firstPart == 'www') {
        return parts[1].toString();
      }
    }
    return _envSubdomain.isNotEmpty ? _envSubdomain.toLowerCase() : withoutPort;
  }

  String _normalizeUrl(String rawUrl) {
    String clean = rawUrl.trim();
    if (clean.isEmpty) return '';
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      final bool isLocalIp = clean.contains('localhost') ||
          clean.startsWith('127.0.0.1') ||
          clean.startsWith('10.0.2.2') ||
          clean.startsWith('192.168.') ||
          clean.startsWith('10.') ||
          clean.startsWith('172.') ||
          clean.contains(':8000');
      clean = '${isLocalIp ? "http" : "https"}://$clean';
    }
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  // Candidate API Bases: tries Tenant Domain + Caddy Root Domains + Custom Server
  List _buildCandidateApiBases() {
    final List candidates = [];

    void addCandidate(String raw) {
      final String norm = _normalizeUrl(raw);
      if (norm.isNotEmpty && !candidates.contains(norm)) {
        candidates.add(norm);
      }
    }

    if (_customApiBase.isNotEmpty) {
      addCandidate(_customApiBase);
    }
    if (widget.apiBaseOverride.trim().isNotEmpty) {
      addCandidate(widget.apiBaseOverride);
    }
    if (_resolvedWorkingApiBase.isNotEmpty) {
      addCandidate(_resolvedWorkingApiBase);
    }

    // 1. Tenant's own domain (e.g. nextlook.shop.xylotechsolution.com, buynarabd.com)
    if (_activeDomain.isNotEmpty &&
        !_activeDomain.contains('localhost') &&
        !_activeDomain.startsWith('127.0.0.1')) {
      addCandidate(_activeDomain);
    }

    // 2. Tenant's *.shop.xylotechsolution.com domain
    if (_activeSubdomain.isNotEmpty) {
      addCandidate('https://$_activeSubdomain.$_platformRootDomain');
    }

    // 3. Direct Caddy 1st-level Cloudflare domains (always valid SSL on mobile!)
    addCandidate('https://$_platformRootDomain');
    addCandidate('https://buynarabd.com');
    addCandidate('https://bestbdbazar.com');

    // 4. Local development fallbacks
    if (_activeDomain.isNotEmpty) {
      addCandidate(_activeDomain);
    }
    addCandidate('http://127.0.0.1:8000');
    addCandidate('http://10.0.2.2:8000');

    return candidates;
  }

  String get _primaryApiBase {
    final List list = _buildCandidateApiBases();
    return list.isNotEmpty
        ? list.first.toString()
        : 'https://$_platformRootDomain';
  }

  Future _initTenantAndFetchBranding() async {
    final prefs = await SharedPreferences.getInstance();

    final String savedDomain = prefs.getString('locked_tenant_domain') ?? '';
    final String savedSub = prefs.getString('active_subdomain') ?? '';
    final String savedApiBase = prefs.getString('custom_api_base_url') ?? '';
    final String lastWorkingApi = prefs.getString('api_base_url') ?? '';

    String initialDomain = widget.storeDomain.trim();
    if (initialDomain.isEmpty) {
      initialDomain = savedDomain;
    }
    if (initialDomain.isEmpty && _envSubdomain.isNotEmpty) {
      initialDomain = '$_envSubdomain.$_platformRootDomain';
    }
    if (initialDomain.isEmpty && savedSub.isNotEmpty) {
      initialDomain = '$savedSub.$_platformRootDomain';
    }
    if (initialDomain.isEmpty) {
      initialDomain = _platformRootDomain;
    }

    String initialSub = _extractSubdomain(initialDomain);
    if (initialSub.isEmpty && savedSub.isNotEmpty) {
      initialSub = savedSub;
    }

    setState(() {
      _activeDomain = _cleanHost(initialDomain);
      _activeSubdomain = initialSub;
      _customApiBase = savedApiBase;
      if (lastWorkingApi.isNotEmpty &&
          !lastWorkingApi.contains('127.0.0.1') &&
          !lastWorkingApi.contains('localhost')) {
        _resolvedWorkingApiBase = lastWorkingApi;
      }
      _storeName = _activeSubdomain.isNotEmpty
          ? _activeSubdomain.toUpperCase()
          : 'MERCHANT PORTAL';
    });

    await _fetchStoreBranding();
  }

  Map<String, String> _buildTenantHeaders({bool isJsonPost = false}) {
    final Map<String, String> h = {
      'Accept': 'application/json',
      'User-Agent': _browserUserAgent,
      if (isJsonPost) 'Content-Type': 'application/json',
    };
    if (_activeSubdomain.isNotEmpty) {
      h['X-Tenant-Subdomain'] = _activeSubdomain;
      h['x-subdomain'] = _activeSubdomain;
      h['X-Tenant-Slug'] = _activeSubdomain;
    }
    if (_activeDomain.isNotEmpty) {
      h['X-Tenant-Domain'] = _activeDomain;
    }
    return h;
  }

  Future _fetchStoreBranding() async {
    final List candidates = _buildCandidateApiBases();

    for (int i = 0; candidates.length > i; i++) {
      final String base = candidates[i].toString();
      try {
        final String subQuery = _activeSubdomain.isNotEmpty
            ? '?subdomain=${Uri.encodeComponent(_activeSubdomain)}'
            : '';
        final Uri settingsUri =
            Uri.parse('$base/api/v1/stores/settings/$subQuery');

        final res = await http
            .get(settingsUri, headers: _buildTenantHeaders())
            .timeout(const Duration(seconds: 6));

        if (res.statusCode == 200) {
          final dynamic data = _safeJsonDecode(res.body);
          if (data is Map) {
            _resolvedWorkingApiBase = base;
            final rawLogo = data['logo'] ?? data['store_logo'];
            String? resolvedLogo;

            if (rawLogo is String && rawLogo.isNotEmpty) {
              resolvedLogo =
                  rawLogo.startsWith('http') ? rawLogo : '$base$rawLogo';
            } else if (rawLogo is Map && rawLogo['url'] != null) {
              final String urlStr = rawLogo['url'].toString();
              resolvedLogo =
                  urlStr.startsWith('http') ? urlStr : '$base$urlStr';
            }

            if (mounted) {
              setState(() {
                if (data['store_name'] != null &&
                    data['store_name'].toString().trim().isNotEmpty) {
                  _storeName = data['store_name'].toString().trim();
                } else if (_activeSubdomain.isNotEmpty) {
                  _storeName = _activeSubdomain.toUpperCase();
                }
                if (data['subdomain'] != null &&
                    data['subdomain'].toString().trim().isNotEmpty) {
                  _activeSubdomain = data['subdomain'].toString().trim();
                }
                _logoUrl = resolvedLogo;
                if (data['primary_color'] != null) {
                  final String hex =
                      data['primary_color'].toString().replaceAll('#', '');
                  if (hex.length == 6) {
                    final int? parsed = int.tryParse('FF$hex', radix: 16);
                    if (parsed != null) _brandColor = Color(parsed);
                  }
                }
              });
            }
            return;
          }
        }
      } catch (_) {
        // Try next candidate URL
      }
    }
  }

  dynamic _safeJsonDecode(String rawBody) {
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return null;
    }
  }

  Future _handleLogin() async {
    final FormState? formState = _formKey.currentState as FormState?;
    if (formState != null && !formState.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text;

    final Map payloadMap = {
      'email': email,
      'password': password,
      if (_activeSubdomain.isNotEmpty) 'subdomain': _activeSubdomain,
      if (_activeDomain.isNotEmpty) 'domain': _activeDomain,
    };
    final String body = jsonEncode(payloadMap);

    final List candidateBases = _buildCandidateApiBases();
    final String subParam = _activeSubdomain.isNotEmpty
        ? '?subdomain=${Uri.encodeComponent(_activeSubdomain)}'
        : '';
    final List loginPaths = [
      '/api/v1/auth/merchant-login/$subParam',
      '/api/v1/users/merchant-login/$subParam',
      '/api/v1/tenants/merchant-login/$subParam',
    ];

    String? serverAuthError;
    String? lastNetworkError;

    for (int b = 0; candidateBases.length > b; b++) {
      final String base = candidateBases[b].toString();

      for (int p = 0; loginPaths.length > p; p++) {
        final String path = loginPaths[p].toString();
        final String fullUrl = '$base$path';

        try {
          final http.Response response = await http
              .post(
                Uri.parse(fullUrl),
                headers: _buildTenantHeaders(isJsonPost: true),
                body: body,
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 404) {
            continue;
          }

          final dynamic data = _safeJsonDecode(response.body);
          if (data is! Map) {
            continue;
          }

          if (response.statusCode == 200) {
            final String token =
                (data['access'] ?? data['token'] ?? '').toString();
            final String refreshToken = (data['refresh'] ?? '').toString();
            final Map user =
                (data['user'] is Map) ? Map.from(data['user'] as Map) : {};
            final Map storeObj =
                (data['store'] is Map) ? Map.from(data['store'] as Map) : {};

            String finalSubdomain = (data['subdomain'] ??
                    storeObj['subdomain'] ??
                    user['subdomain'] ??
                    _activeSubdomain)
                .toString()
                .trim();
            if (finalSubdomain.isEmpty) {
              finalSubdomain = _extractSubdomain(_activeDomain);
            }

            String finalStoreName =
                (storeObj['name'] ?? storeObj['store_name'] ?? _storeName)
                    .toString()
                    .trim();
            if (finalStoreName.isEmpty && finalSubdomain.isNotEmpty) {
              finalStoreName = finalSubdomain.toUpperCase();
            }

            String finalDomain = _activeDomain;
            if (storeObj['domain'] != null &&
                storeObj['domain'].toString().trim().isNotEmpty) {
              finalDomain = _cleanHost(storeObj['domain'].toString());
            } else if (finalDomain.isEmpty && finalSubdomain.isNotEmpty) {
              finalDomain = '$finalSubdomain.$_platformRootDomain';
            }

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('merchant_token', token);
            await prefs.setString('merchant_jwt_token', token);
            await prefs.setString('merchant_refresh_token', refreshToken);
            await prefs.setString('active_subdomain', finalSubdomain);
            await prefs.setString('locked_tenant_subdomain', finalSubdomain);
            await prefs.setString('locked_tenant_domain', finalDomain);
            await prefs.setString('api_base_url', base);
            await prefs.setString('locked_api_base_url', base);
            await prefs.setString('store_name', finalStoreName);
            if (_logoUrl != null) {
              await prefs.setString('store_logo', _logoUrl!);
            }
            await prefs.setString('merchant_user', jsonEncode(user));

            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminDashboardShell(),
              ),
            );
            return;
          } else {
            final String err = (data['detail'] ??
                    data['error'] ??
                    data['message'] ??
                    'Email othoba password sothik noy!')
                .toString();
            serverAuthError = err;
            break;
          }
        } catch (err) {
          lastNetworkError = err.toString();
        }
      }

      if (serverAuthError != null) {
        break;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (serverAuthError != null) {
          _errorMessage = serverAuthError;
        } else {
          _errorMessage =
              'Server connection failed ($_primaryApiBase). ${lastNetworkError ?? "Internet ba Domain check korun."}';
        }
      });
    }
  }

  Future _openDomainAndServerConfigModal() async {
    final TextEditingController domainCtrl =
        TextEditingController(text: _activeDomain);
    final TextEditingController serverCtrl =
        TextEditingController(text: _customApiBase);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.dns_rounded, color: _brandColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Store Domain & Server Config',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A1A),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Tenant Store Domain / Subdomain:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: domainCtrl,
                    style: const TextStyle(
                      color: Color(0xFF1E3A1A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. nextlook.shop.xylotechsolution.com or buynarabd.com',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                      prefixIcon:
                          Icon(Icons.storefront, color: _brandColor, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF7FAF6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '2. Backend Server / Custom Host (Optional):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'খালি রাখলে স্টোরের নিজস্ব ডোমেইন ও ক্লাউডফ্লেয়ার রাউটিং অটোমেটিক কাজ করবে:',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: serverCtrl,
                    style: const TextStyle(
                      color: Color(0xFF1E3A1A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Leave empty for automatic tenant routing',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                      prefixIcon: Icon(
                        Icons.cloud_done_outlined,
                        color: _brandColor,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7FAF6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final String rawDom = domainCtrl.text.trim();
                final String rawSrv = serverCtrl.text.trim();

                final String cleanedDom = rawDom.isNotEmpty
                    ? (rawDom.contains('.') || rawDom.contains(':')
                        ? _cleanHost(rawDom)
                        : '${_cleanHost(rawDom)}.$_platformRootDomain')
                    : _platformRootDomain;
                final String extractedSub = _extractSubdomain(cleanedDom);

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('locked_tenant_domain', cleanedDom);
                await prefs.setString('active_subdomain', extractedSub);
                await prefs.setString('custom_api_base_url', rawSrv);
                if (rawSrv.isNotEmpty) {
                  await prefs.setString('api_base_url', _normalizeUrl(rawSrv));
                } else {
                  await prefs.setString(
                      'api_base_url', _normalizeUrl(cleanedDom));
                }

                setState(() {
                  _activeDomain = cleanedDom;
                  _activeSubdomain = extractedSub;
                  _customApiBase = rawSrv;
                  _resolvedWorkingApiBase = '';
                  _logoUrl = null;
                  _storeName = extractedSub.isNotEmpty
                      ? extractedSub.toUpperCase()
                      : 'MERCHANT PORTAL';
                  _errorMessage = null;
                });

                if (ctx.mounted) Navigator.of(ctx).pop();
                await _fetchStoreBranding();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text(
                'Save & Load Store',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6F0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 410),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFE2EBE0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _brandColor.withValues(alpha: 0.08),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: _openDomainAndServerConfigModal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _brandColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  size: 13,
                                  color: _brandColor,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _activeDomain.isNotEmpty
                                        ? _activeDomain
                                        : _platformRootDomain,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _brandColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Change Store Domain or Server URL',
                        onPressed: _openDomainAndServerConfigModal,
                        icon: Icon(
                          Icons.settings_ethernet_rounded,
                          color: _brandColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 🌟 ANIMATED STORE LOGO WITH PULSING GLOW
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final double scaleVal =
                            (_scaleAnimation.value as num).toDouble();
                        final double glowVal =
                            (_glowAnimation.value as num).toDouble();
                        return Transform.scale(
                          scale: scaleVal,
                          child: Container(
                            width: 96,
                            height: 96,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: _brandColor.withValues(alpha: 0.35),
                                  blurRadius: glowVal,
                                  spreadRadius: glowVal * 0.35,
                                ),
                              ],
                              border: Border.all(
                                color: _brandColor.withValues(alpha: 0.85),
                                width: 3.0,
                              ),
                            ),
                            child: ClipOval(
                              child: _logoUrl != null
                                  ? Image.network(
                                      _logoUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          _buildFallbackIcon(),
                                    )
                                  : _buildFallbackIcon(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    _storeName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E3A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Merchant Portal Login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _brandColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      color: Color(0xFF1E3A1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Merchant Email',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      hintText: 'admin@store.com',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: _brandColor,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7FAF6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: _brandColor, width: 2),
                      ),
                    ),
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Valid email din' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      color: Color(0xFF1E3A1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      hintText: '••••••••',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.amber,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7FAF6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: _brandColor, width: 2),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Password din' : null,
                  ),
                  const SizedBox(height: 26),

                  // Login Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sign In to Dashboard',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: _brandColor.withValues(alpha: 0.12),
      child: Center(
        child: Icon(Icons.storefront_rounded, color: _brandColor, size: 40),
      ),
    );
  }
}