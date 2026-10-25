import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_dashboard_shell.dart';

class MerchantLoginScreen extends StatefulWidget {
  final String storeDomain;
  const MerchantLoginScreen({
    super.key,
    this.storeDomain = const String.fromEnvironment(
      'STORE_DOMAIN',
      defaultValue: 'bestbdbazar.shop.xylotechsolution.com',
    ),
  });

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  String _storeName = 'eShop Admin';
  String? _logoUrl;
  Color _brandColor = const Color(0xFF5B9A42);

  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 20.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _fetchStoreBranding();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _subdomain {
    String domain = widget.storeDomain.trim().toLowerCase();
    domain = domain.replaceAll('http://', '').replaceAll('https://', '');
    final parts = domain.split('.');
    return parts.isNotEmpty ? parts[0] : 'bestbdbazar';
  }

  String get _apiBase {
    final domain = widget.storeDomain.trim().toLowerCase();
    if (domain.contains('localhost') || domain.contains('127.0.0.1')) {
      return 'http://127.0.0.1:8000';
    }
    if (domain.startsWith('http://') || domain.startsWith('https://')) {
      return domain;
    }
    return 'https://$domain';
  }

  Future<void> _fetchStoreBranding() async {
    setState(() {
      _storeName = _subdomain.toUpperCase();
    });

    final headers = {
      'Accept': 'application/json',
      'X-Tenant-Subdomain': _subdomain,
      'x-subdomain': _subdomain,
      'X-Tenant-Domain': widget.storeDomain,
    };

    try {
      final res = await http.get(
        Uri.parse('$_apiBase/api/v1/stores/settings/?subdomain=$_subdomain'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawLogo = data['logo'] ?? data['store_logo'];
        String? resolvedLogo;

        if (rawLogo is String && rawLogo.isNotEmpty) {
          resolvedLogo = rawLogo.startsWith('http') ? rawLogo : '$_apiBase$rawLogo';
        } else if (rawLogo is Map && rawLogo['url'] != null) {
          final urlStr = rawLogo['url'].toString();
          resolvedLogo = urlStr.startsWith('http') ? urlStr : '$_apiBase$urlStr';
        }

        if (mounted) {
          setState(() {
            if (data['store_name'] != null && data['store_name'].toString().isNotEmpty) {
              _storeName = data['store_name'].toString();
            }
            _logoUrl = resolvedLogo;
            if (data['primary_color'] != null) {
              final hex = data['primary_color'].toString().replaceAll('#', '');
              if (hex.length == 6) {
                _brandColor = Color(int.parse('0xFF$hex'));
              }
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Tenant-Subdomain': _subdomain,
      'x-subdomain': _subdomain,
      'X-Tenant-Domain': widget.storeDomain,
    };

    final body = jsonEncode({
      'email': email,
      'password': password,
      'subdomain': _subdomain,
    });

    try {
      http.Response response = await http.post(
        Uri.parse('$_apiBase/api/v1/auth/merchant-login/'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 404) {
        response = await http.post(
          Uri.parse('$_apiBase/api/v1/users/merchant-login/'),
          headers: headers,
          body: body,
        );
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['access'] ?? data['token'] ?? '';
        final refreshToken = data['refresh'] ?? '';
        final user = data['user'] ?? {};

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('merchant_token', token);
        await prefs.setString('merchant_refresh_token', refreshToken);
        await prefs.setString('active_subdomain', _subdomain);
        await prefs.setString('api_base_url', _apiBase);
        await prefs.setString('store_name', _storeName);
        if (_logoUrl != null) await prefs.setString('store_logo', _logoUrl!);
        await prefs.setString('merchant_user', jsonEncode(user));

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardShell()),
        );
      } else {
        final err = data['detail'] ?? data['error'] ?? 'Email ba password vul hoyeche!';
        setState(() {
          _errorMessage = err.toString();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Server connection failed. Django server ti 127.0.0.1:8000 e run ache kina check korun.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFE2EBE0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _brandColor.withOpacity(0.08),
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
                  // 🌟 ANIMATED STORE LOGO WITH PULSING GLOW
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 96,
                            height: 96,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: _brandColor.withOpacity(0.35),
                                  blurRadius: _glowAnimation.value,
                                  spreadRadius: _glowAnimation.value * 0.35,
                                ),
                              ],
                              border: Border.all(
                                color: _brandColor.withOpacity(0.85),
                                width: 3.0,
                              ),
                            ),
                            child: ClipOval(
                              child: _logoUrl != null
                                  ? Image.network(
                                      _logoUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => _buildFallbackIcon(),
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
                  const SizedBox(height: 28),

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
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600),
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
                    style: const TextStyle(color: Color(0xFF1E3A1A), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Merchant Email',
                      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      hintText: 'admin@store.com',
                      prefixIcon: Icon(Icons.email_outlined, color: _brandColor, size: 20),
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
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email din' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Color(0xFF1E3A1A), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.amber, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                    validator: (v) => v == null || v.isEmpty ? 'Password din' : null,
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
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sign In to Dashboard',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
      color: _brandColor.withOpacity(0.12),
      child: Center(
        child: Icon(Icons.storefront_rounded, color: _brandColor, size: 40),
      ),
    );
  }
}