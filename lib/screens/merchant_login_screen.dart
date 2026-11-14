// lib/screens/merchant_login_screen.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  String _activeDomain = '';
  String _activeSubdomain = '';
  String _resolvedWorkingApiBase = '';

  String _storeName = const String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Merchant Portal',
  );
  String? _logoUrl;
  Color _brandColor = const Color(0xFF059669);

  late AnimationController _pulseController;
  late Animation _scaleAnimation;
  late Animation _glowAnimation;

  static const String _envSubdomain = String.fromEnvironment(
    'TENANT_SUBDOMAIN',
    defaultValue: '',
  );
  static const String _envAppName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: '',
  );
  static const String _envAppIconUrl = String.fromEnvironment(
    'APP_ICON_URL',
    defaultValue: '',
  );
  static const String _envPrimaryColor = String.fromEnvironment(
    'PRIMARY_COLOR',
    defaultValue: '',
  );

  static const String _platformRootDomain = 'shop.xylotechsolution.com';

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

    _initLockedTenantAndFetchBranding();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Color? _parseHexColor(String? rawHex) {
    if (rawHex == null || rawHex.trim().isEmpty) return null;
    final String clean = rawHex.trim().replaceAll('#', '');
    if (clean.length == 6) {
      final int? v = int.tryParse('FF$clean', radix: 16);
      if (v != null) return Color(v);
    }
    return null;
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
      if (parts.length != 1 && firstPart == 'www') {
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

  Future _loadEmbeddedTenantConfigJson() async {
    if (kIsWeb && widget.storeDomain.trim().isNotEmpty) {
      return {};
    }
    for (final path in ['assets/tenant_config.json', 'tenant_config.json']) {
      try {
        final String raw = await rootBundle.loadString(path);
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map.from(decoded);
        }
      } catch (_) {}
    }
    return {};
  }

  Future _initLockedTenantAndFetchBranding() async {
    final prefs = await SharedPreferences.getInstance();
    final dynamic embeddedRaw = await _loadEmbeddedTenantConfigJson();
    final Map embedded = embeddedRaw is Map ? embeddedRaw : {};

    // 1. PRIORITY 1: Explicit --dart-define=STORE_DOMAIN / TENANT_SUBDOMAIN
    String lockedDomain = widget.storeDomain.trim();
    String lockedSub = _envSubdomain.trim().toLowerCase();

    if (lockedDomain.isNotEmpty && lockedSub.isEmpty) {
      lockedSub = _extractSubdomain(lockedDomain);
    } else if (lockedSub.isNotEmpty && lockedDomain.isEmpty) {
      lockedDomain = '$lockedSub.$_platformRootDomain';
    }

    // 2. PRIORITY 2: Embedded tenant_config.json (used in patched APKs when --dart-define wasn't passed)
    final String embSub =
        (embedded['subdomain'] ?? '').toString().trim().toLowerCase();
    final String embDom = (embedded['store_domain'] ?? '').toString().trim();

    if (lockedDomain.isEmpty && embDom.isNotEmpty) {
      lockedDomain = embDom;
    }
    if (lockedSub.isEmpty && embSub.isNotEmpty) {
      lockedSub = embSub;
    }

    // 3. PRIORITY 3: Saved SharedPreferences fallback
    if (lockedDomain.isEmpty) {
      final String savedDom = prefs.getString('locked_tenant_domain') ?? '';
      if (savedDom.isNotEmpty) {
        lockedDomain = savedDom;
        lockedSub = _extractSubdomain(savedDom);
      }
    }

    // Only use embedded branding (name/icon/color) if embedded subdomain matches our active lockedSub!
    final bool useEmbeddedBranding =
        embSub.isNotEmpty && lockedSub.isNotEmpty && embSub == lockedSub;

    String lockedName = _envAppName.trim();
    if (lockedName.isEmpty && useEmbeddedBranding) {
      lockedName = (embedded['store_name'] ?? embedded['app_name'] ?? '')
          .toString()
          .trim();
    }

    String lockedIcon = _envAppIconUrl.trim();
    if (lockedIcon.isEmpty && useEmbeddedBranding) {
      lockedIcon = (embedded['app_icon_url'] ?? '').toString().trim();
    }

    String lockedColorHex = _envPrimaryColor.trim();
    if (lockedColorHex.isEmpty && useEmbeddedBranding) {
      lockedColorHex = (embedded['primary_color'] ?? '').toString().trim();
    }

    if (lockedDomain.isNotEmpty) {
      await prefs.setString('locked_tenant_domain', _cleanHost(lockedDomain));
    }
    if (lockedSub.isNotEmpty) {
      await prefs.setString('active_subdomain', lockedSub);
      await prefs.setString('locked_tenant_subdomain', lockedSub);
    }

    if (mounted) {
      setState(() {
        _activeDomain = _cleanHost(lockedDomain);
        _activeSubdomain = lockedSub;
        if (lockedName.isNotEmpty) {
          _storeName = lockedName;
        } else if (_activeSubdomain.isNotEmpty) {
          _storeName = _activeSubdomain.toUpperCase();
        }
        _logoUrl = lockedIcon.isNotEmpty ? lockedIcon : null;
        final Color? parsedColor = _parseHexColor(lockedColorHex);
        if (parsedColor != null) {
          _brandColor = parsedColor;
        }
      });
    }

    await _fetchStoreBranding();
  }

  List _buildCandidateApiBases() {
    final List candidates = [];

    void addCandidate(String raw) {
      final String norm = _normalizeUrl(raw);
      if (norm.isNotEmpty && !candidates.contains(norm)) {
        candidates.add(norm);
      }
    }

    if (widget.apiBaseOverride.trim().isNotEmpty) {
      addCandidate(widget.apiBaseOverride);
    }
    if (_resolvedWorkingApiBase.isNotEmpty) {
      addCandidate(_resolvedWorkingApiBase);
    }
    if (_activeDomain.isNotEmpty) {
      addCandidate(_activeDomain);
    }
    if (_activeSubdomain.isNotEmpty) {
      addCandidate('https://$_activeSubdomain.$_platformRootDomain');
    }
    addCandidate('https://$_platformRootDomain');
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

  _buildTenantHeaders({bool isJsonPost = false}) {
    final h = {
      'Accept': 'application/json',
      'User-Agent': _browserUserAgent,
    };
    if (isJsonPost) {
      h['Content-Type'] = 'application/json';
    }
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

    for (final dynamic cand in candidates) {
      final String base = cand.toString();
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
            final Map appDist = (data['app_distribution'] is Map)
                ? Map.from(data['app_distribution'] as Map)
                : {};
            final dynamic rawLogo =
                appDist['app_icon_url'] ?? data['logo'] ?? data['store_logo'];
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
                final String fetchedName =
                    (data['store_name'] ?? appDist['app_name'] ?? '')
                        .toString()
                        .trim();
                if (fetchedName.isNotEmpty) {
                  _storeName = fetchedName;
                }
                if (resolvedLogo != null && resolvedLogo.isNotEmpty) {
                  _logoUrl = resolvedLogo;
                }
                final Color? parsedColor = _parseHexColor(
                  (data['primary_color'] ?? appDist['primary_color'] ?? '')
                      .toString(),
                );
                if (parsedColor != null) {
                  _brandColor = parsedColor;
                }
              });
            }
            return null;
          }
        }
      } catch (_) {}
    }
    return null;
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
    if (formState != null && !formState.validate()) return null;

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
      'strict_tenant_lock': true,
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

    for (final dynamic baseObj in candidateBases) {
      final String base = baseObj.toString();

      for (final dynamic pathObj in loginPaths) {
        final String path = pathObj.toString();
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
            final Map user =
                (data['user'] is Map) ? Map.from(data['user'] as Map) : {};
            final Map storeObj =
                (data['store'] is Map) ? Map.from(data['store'] as Map) : {};

            final String returnedSubdomain = (data['subdomain'] ??
                    storeObj['subdomain'] ??
                    user['subdomain'] ??
                    '')
                .toString()
                .trim()
                .toLowerCase();

            // Strict Tenant Check: Only the owner of this locked store can log in
            if (_activeSubdomain.isNotEmpty &&
                returnedSubdomain.isNotEmpty &&
                returnedSubdomain != _activeSubdomain.toLowerCase()) {
              serverAuthError =
                  'এই অ্যাপটি শুধুমাত্র $_storeName ($_activeSubdomain) স্টোরের জন্য জেনারেট করা হয়েছে! অন্য কোনো মার্চেন্ট অ্যাকাউন্ট দিয়ে এখানে লগইন করা যাবে না।';
              break;
            }

            final String token =
                (data['access'] ?? data['token'] ?? '').toString();
            final String refreshToken = (data['refresh'] ?? '').toString();

            final String finalSubdomain = _activeSubdomain.isNotEmpty
                ? _activeSubdomain
                : returnedSubdomain;

            final String finalStoreName = _storeName.isNotEmpty
                ? _storeName
                : (storeObj['name'] ??
                        storeObj['store_name'] ??
                        finalSubdomain.toUpperCase())
                    .toString()
                    .trim();

            final String finalDomain = _activeDomain.isNotEmpty
                ? _activeDomain
                : '$finalSubdomain.$_platformRootDomain';

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

            if (!mounted) return null;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminDashboardShell(),
              ),
            );
            return null;
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
              'Server connection failed ($_primaryApiBase). ${lastNetworkError ?? "Internet check korun."}';
        }
      });
    }
    return null;
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
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                            Icons.lock_outline_rounded,
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
                                fontWeight: FontWeight.w800,
                                color: _brandColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                              child: _logoUrl != null && _logoUrl!.isNotEmpty
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
                    'Exclusive Merchant Portal Login',
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
