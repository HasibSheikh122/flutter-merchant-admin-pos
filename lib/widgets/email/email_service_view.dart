import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class EmailServiceView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final String? initialSubTab;
  final VoidCallback? onDataChanged;

  const EmailServiceView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'email_gateway',
    this.initialSubTab,
    this.onDataChanged,
  });

  @override
  State<EmailServiceView> createState() => _EmailServiceViewState();
}

class _EmailServiceViewState extends State<EmailServiceView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  late String _activeTab;
  bool _isLoading = true;
  bool _isActionBusy = false;

  // Gateway Config State (from /api/v1/emails/gateway/)
  bool _isConnected = false;
  String _statusMessage = 'Email Gateway Not Configured';
  String _selectedProvider = 'gmail';
  final TextEditingController _senderNameCtrl =
      TextEditingController(text: 'Store Admin');
  final TextEditingController _hostUserCtrl = TextEditingController();
  final TextEditingController _hostPasswordCtrl = TextEditingController();
  final TextEditingController _smtpHostCtrl =
      TextEditingController(text: 'smtp.gmail.com');
  final TextEditingController _smtpPortCtrl =
      TextEditingController(text: '587');
  bool _useTls = true;
  bool _useSsl = false;
  bool _obscurePassword = true;

  // Stats & Logs
  int _dailyLimit = 500;
  int _todaysSend = 0;
  int _thisMonthSend = 0;
  int _thisMonthFailed = 0;
  List _recentLogs = [];

  // Quick Test Email Input
  final TextEditingController _testEmailCtrl = TextEditingController();

  // Tab 2: Compose & Order Email (/api/v1/emails/send-order/)
  final TextEditingController _composeToCtrl = TextEditingController();
  final TextEditingController _composeSubjectCtrl = TextEditingController();
  final TextEditingController _composeMessageCtrl = TextEditingController();
  bool _showHtmlPreview = true;

  // Tab 3: Email Logs Filter
  final TextEditingController _logSearchCtrl = TextEditingController();
  String _logStatusFilter = 'ALL';

  static const List _smtpProviders = [
    {
      'id': 'gmail',
      'name': 'Gmail SMTP',
      'badge': 'Free 500/day',
      'host': 'smtp.gmail.com',
      'port': 587,
      'tls': true,
      'ssl': false,
      'hint': 'Use Google 16-digit App Password',
    },
    {
      'id': 'brevo',
      'name': 'Brevo (Sendinblue)',
      'badge': 'Free 300/day',
      'host': 'smtp-relay.brevo.com',
      'port': 587,
      'tls': true,
      'ssl': false,
      'hint': 'Use Brevo SMTP Relay Key',
    },
    {
      'id': 'resend',
      'name': 'Resend SMTP',
      'badge': 'High Delivery',
      'host': 'smtp.resend.com',
      'port': 587,
      'tls': true,
      'ssl': false,
      'hint': 'Use Resend API Key as password',
    },
    {
      'id': 'custom',
      'name': 'Custom SMTP Server',
      'badge': 'cPanel / AWS SES',
      'host': 'mail.yourdomain.com',
      'port': 587,
      'tls': true,
      'ssl': false,
      'hint': 'Any standard SMTP host & port',
    },
  ];

  static const List _quickEmailTemplates = [
    {
      'title': 'Order Confirmation',
      'subject': 'Order Confirmed - Thank you for shopping with us!',
      'body':
          'Hello Valued Customer,\n\nYour order has been received and confirmed. Our team is currently preparing your items for dispatch.\n\nWe will send you another update with courier tracking details shortly.\n\nThank you for choosing our store!',
    },
    {
      'title': 'Courier Dispatched',
      'subject': 'Your Order Has Been Shipped!',
      'body':
          'Hello,\n\nGreat news! Your parcel has been handed over to our courier partner and is on its way to your delivery address.\n\nPlease keep the invoice amount ready if you selected Cash on Delivery.\n\nBest regards,\nCustomer Support Team',
    },
    {
      'title': 'Payment & Invoice Receipt',
      'subject': 'Official Payment Receipt & Invoice Summary',
      'body':
          'Dear Customer,\n\nWe have received your payment. Thank you for settling your invoice promptly.\n\nIf you have any questions regarding your order or warranty, feel free to reply to this email.',
    },
    {
      'title': 'Exclusive VIP Discount',
      'subject': 'Special VIP Offer Just For You!',
      'body':
          'Hello!\n\nAs one of our valued customers, enjoy an exclusive discount on our newest collection this week.\n\nVisit our store today to claim your offer!',
    },
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = _normalizeTab(widget.initialSubTab ?? widget.initialTab);
    _initEmailModule();
  }

  @override
  void didUpdateWidget(covariant EmailServiceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialSubTab ?? widget.initialTab;
    final oldIncoming = oldWidget.initialSubTab ?? oldWidget.initialTab;
    if (incoming != oldIncoming) {
      setState(() {
        _activeTab = _normalizeTab(incoming);
      });
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
    }
  }

  String _normalizeTab(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('log')) {
      return 'email_logs';
    }
    if (lower.contains('compose') || lower.contains('send')) {
      return 'email_compose';
    }
    return 'email_gateway';
  }

  Future _reloadTheme() async {
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = loaded);
    }
  }

  Future _initEmailModule() async {
    setState(() => _isLoading = true);
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = loaded);
    }

    await _loadLocalFallback();
    await _fetchEmailGatewayData();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future _loadLocalFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _theme.subdomain;
      final savedProv = prefs.getString('xylo_email_prov_$sub');
      final savedUser = prefs.getString('xylo_email_user_$sub');
      final savedSender = prefs.getString('xylo_email_sender_$sub');
      final savedHost = prefs.getString('xylo_email_host_$sub');
      final savedPort = prefs.getInt('xylo_email_port_$sub');

      if (savedProv != null && savedProv.isNotEmpty) {
        _selectedProvider = savedProv;
      }
      if (savedUser != null && savedUser.isNotEmpty) {
        _hostUserCtrl.text = savedUser;
        if (_testEmailCtrl.text.isEmpty) {
          _testEmailCtrl.text = savedUser;
        }
      }
      if (savedSender != null && savedSender.isNotEmpty) {
        _senderNameCtrl.text = savedSender;
      } else if (sub.isNotEmpty) {
        _senderNameCtrl.text = sub.toUpperCase();
      }
      if (savedHost != null && savedHost.isNotEmpty) {
        _smtpHostCtrl.text = savedHost;
      }
      if (savedPort != null) {
        _smtpPortCtrl.text = savedPort.toString();
      }
    } catch (_) {}
  }

  Future _saveLocalFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _theme.subdomain;
      await prefs.setString('xylo_email_prov_$sub', _selectedProvider);
      await prefs.setString('xylo_email_user_$sub', _hostUserCtrl.text.trim());
      await prefs.setString(
          'xylo_email_sender_$sub', _senderNameCtrl.text.trim());
      await prefs.setString('xylo_email_host_$sub', _smtpHostCtrl.text.trim());
      await prefs.setInt(
        'xylo_email_port_$sub',
        int.tryParse(_smtpPortCtrl.text.trim()) ?? 587,
      );
    } catch (_) {}
  }

  // ===========================================================================
  // BACKEND API CALLS (/api/v1/emails/gateway/, /send-test/, /send-order/)
  // ===========================================================================
  Future _requestEmailEndpoint(
    String pathSuffix, {
    String method = 'GET',
    Map? bodyMap,
  }) async {
    final base = _theme.apiBase;
    final sub = _theme.subdomain;
    final headers = _theme.headers;

    final candidateUrls = [
      '$base/api/v1/emails/$pathSuffix?subdomain=$sub',
      '$base/api/v1/email/$pathSuffix?subdomain=$sub',
    ];

    http.Response? lastRes;
    for (final url in candidateUrls) {
      try {
        final uri = Uri.parse(url);
        if (method == 'GET') {
          lastRes = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 10));
        } else if (method == 'POST') {
          lastRes = await http
              .post(
                uri,
                headers: headers,
                body: bodyMap != null ? jsonEncode(bodyMap) : null,
              )
              .timeout(const Duration(seconds: 18));
        } else if (method == 'DELETE') {
          lastRes = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 10));
        }
        if (lastRes != null && lastRes.statusCode != 404) {
          return lastRes;
        }
      } catch (_) {}
    }
    return lastRes;
  }

  Future _fetchEmailGatewayData() async {
    final res = await _requestEmailEndpoint('gateway/', method: 'GET');
    if (res != null && res.statusCode == 200) {
      try {
        final decoded = jsonDecode(res.body);
        _applyGatewayPayload(decoded);
      } catch (_) {}
    }
  }

  void _applyGatewayPayload(dynamic data) {
    if (data is! Map) return;
    setState(() {
      _isConnected = data['is_connected'] == true;
      _statusMessage = (data['message'] ??
              (_isConnected
                  ? 'Email Gateway সংযুক্ত রয়েছে'
                  : 'Email Gateway Not Configured'))
          .toString();

      final cfg = data['config'];
      if (cfg is Map) {
        _selectedProvider =
            (cfg['provider'] ?? _selectedProvider).toString().toLowerCase();
        final host = (cfg['email_host'] ?? '').toString();
        final port = cfg['email_port'];
        final user = (cfg['email_host_user'] ?? '').toString();
        final sender = (cfg['sender_name'] ?? '').toString();

        if (host.isNotEmpty) _smtpHostCtrl.text = host;
        if (port != null) _smtpPortCtrl.text = port.toString();
        if (user.isNotEmpty) {
          _hostUserCtrl.text = user;
          if (_testEmailCtrl.text.trim().isEmpty) {
            _testEmailCtrl.text = user;
          }
        }
        if (sender.isNotEmpty) _senderNameCtrl.text = sender;
        _useTls = cfg['email_use_tls'] ?? true;
        _useSsl = cfg['email_use_ssl'] ?? false;
      }

      final st = data['stats'];
      if (st is Map) {
        _dailyLimit =
            int.tryParse((st['daily_limit'] ?? '500').toString()) ?? 500;
        _todaysSend =
            int.tryParse((st['todays_send'] ?? '0').toString()) ?? 0;
        _thisMonthSend =
            int.tryParse((st['this_month_send'] ?? '0').toString()) ?? 0;
        _thisMonthFailed =
            int.tryParse((st['this_month_failed'] ?? '0').toString()) ?? 0;
      }

      if (data['recent_logs'] is List) {
        _recentLogs = List.from(data['recent_logs']);
      }
    });
    _saveLocalFallback();
  }

  Future _saveGatewaySettings() async {
    final emailUser = _hostUserCtrl.text.trim();
    final emailPass = _hostPasswordCtrl.text.trim().replaceAll(' ', '');

    if (emailUser.isEmpty) {
      _showToast('আপনার SMTP ইমেইল অ্যাড্রেস দিন।', isError: true);
      return;
    }
    if (!_isConnected && emailPass.isEmpty) {
      _showToast(
        'Google 16-digit App Password অথবা SMTP Password দিন।',
        isError: true,
      );
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final payload = {
        'provider': _selectedProvider,
        'email_host_user': emailUser,
        if (emailPass.isNotEmpty) 'email_host_password': emailPass,
        'sender_name': _senderNameCtrl.text.trim().isEmpty
            ? 'Store Admin'
            : _senderNameCtrl.text.trim(),
        'email_host': _smtpHostCtrl.text.trim().isEmpty
            ? 'smtp.gmail.com'
            : _smtpHostCtrl.text.trim(),
        'email_port': int.tryParse(_smtpPortCtrl.text.trim()) ?? 587,
        'email_use_tls': _useTls,
        'email_use_ssl': _useSsl,
      };

      final res = await _requestEmailEndpoint(
        'gateway/',
        method: 'POST',
        bodyMap: payload,
      );

      if (res != null && (res.statusCode == 200 || res.statusCode == 201)) {
        final decoded = jsonDecode(res.body);
        _applyGatewayPayload(decoded);
        widget.onDataChanged?.call();
        _showToast('Email Gateway সফলভাবে সেভ ও কানেক্ট হয়েছে!');
      } else {
        _showToast('Email Gateway সেভ করা যায়নি।', isError: true);
      }
    } catch (_) {
      _showToast('Network error while saving Email Gateway.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  Future _disconnectGateway() async {
    setState(() => _isActionBusy = true);
    try {
      final res = await _requestEmailEndpoint(
        'gateway/',
        method: 'POST',
        bodyMap: {'action': 'disconnect'},
      );
      if (res != null && res.statusCode == 200) {
        setState(() {
          _isConnected = false;
          _hostUserCtrl.clear();
          _hostPasswordCtrl.clear();
          _statusMessage = 'Email Gateway Disconnected';
        });
        widget.onDataChanged?.call();
        _showToast('Email Gateway ডিসকানেক্ট করা হয়েছে।');
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  Future _sendTestOrCustomEmail({
    required String toEmail,
    String subject = '',
    String message = '',
    bool isCustomOrderEmail = false,
  }) async {
    final cleanTo = toEmail.trim();
    if (cleanTo.isEmpty) {
      _showToast('প্রাপকের ইমেইল অ্যাড্রেস দিন।', isError: true);
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final recipients = cleanTo
          .split(RegExp(r'[,\s;]+'))
          .map((e) => e.trim())
          .where((e) => e.contains('@'))
          .toList();

      if (recipients.isEmpty) {
        _showToast('সঠিক ইমেইল অ্যাড্রেস দিন।', isError: true);
        setState(() => _isActionBusy = false);
        return;
      }

      int sentCount = 0;
      String lastError = '';

      for (final target in recipients) {
        final res = await _requestEmailEndpoint(
          isCustomOrderEmail ? 'send-order/' : 'send-test/',
          method: 'POST',
          bodyMap: {
            'to_email': target,
            if (subject.trim().isNotEmpty) 'subject': subject.trim(),
            if (message.trim().isNotEmpty) 'message': message.trim(),
          },
        );

        if (res != null && res.statusCode == 200) {
          sentCount++;
        } else if (res != null) {
          try {
            final errData = jsonDecode(res.body);
            lastError =
                (errData['detail'] ?? errData['message'] ?? 'SMTP Error')
                    .toString();
          } catch (_) {
            lastError = 'HTTP ${res.statusCode}';
          }
        } else {
          lastError = 'Server unreachable';
        }
      }

      await _fetchEmailGatewayData();
      widget.onDataChanged?.call();

      if (sentCount > 0) {
        _showToast(
          recipients.length == 1
              ? '${recipients.first}-এ সফলভাবে ইমেইল পাঠানো হয়েছে!'
              : '$sentCount টি ইমেইল সফলভাবে পাঠানো হয়েছে!',
        );
        if (isCustomOrderEmail) {
          setState(() {
            _composeMessageCtrl.clear();
          });
        }
      } else {
        _showToast('ইমেইল পাঠানো যায়নি: $lastError', isError: true);
      }
    } catch (_) {
      _showToast('Error dispatching email.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : _theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(color: t.primaryColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroBanner(t),
        const SizedBox(height: 16),
        _buildSubTabNavigation(t),
        const SizedBox(height: 16),
        if (_activeTab == 'email_gateway') _buildGatewaySetupSection(t),
        if (_activeTab == 'email_compose') _buildComposeEmailSection(t),
        if (_activeTab == 'email_logs') _buildEmailLogsSection(t),
      ],
    );
  }

  // ===========================================================================
  // HERO BANNER & KPI PILLS
  // ===========================================================================
  Widget _buildHeroBanner(CatalogThemeConfig t) {
    final remainingQuota = (_dailyLimit - _todaysSend).clamp(0, 999999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: t.useGradient
            ? t.brandGradient
            : LinearGradient(
                colors: [t.primaryColor, t.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: t.primaryColor.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Enterprise SMTP & Email Service',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                                : Colors.redAccent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _isConnected ? 'SMTP LIVE' : 'NOT CONNECTED',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: t.primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isActionBusy ? null : _fetchEmailGatewayData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Refresh',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroStatPill(
                Icons.speed_rounded,
                'Daily Quota Left: $remainingQuota / $_dailyLimit',
              ),
              _buildHeroStatPill(
                Icons.today_rounded,
                'Sent Today: $_todaysSend',
              ),
              _buildHeroStatPill(
                Icons.done_all_rounded,
                'This Month Sent: $_thisMonthSend',
              ),
              _buildHeroStatPill(
                Icons.error_outline_rounded,
                'Month Failed: $_thisMonthFailed',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabNavigation(CatalogThemeConfig t) {
    final tabs = [
      {
        'key': 'email_gateway',
        'label': 'Email Gateway',
        'icon': Icons.dns_rounded,
        'badge': 'SMTP',
      },
      {
        'key': 'email_compose',
        'label': 'Compose & Order Email',
        'icon': Icons.forward_to_inbox_rounded,
        'badge': 'HTML',
      },
      {
        'key': 'email_logs',
        'label': 'Email Logs',
        'icon': Icons.history_edu_rounded,
        'badge': '${_recentLogs.length}',
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _activeTab = tab['key'] as String);
              },
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient:
                      isSelected && t.useGradient ? t.brandGradient : null,
                  color: isSelected
                      ? (t.useGradient ? null : t.primaryColor)
                      : t.cardBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isSelected ? t.primaryColor : t.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : t.secondaryText,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : t.primaryText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.22)
                            : t.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tab['badge'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : t.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: EMAIL GATEWAY & SMTP CONFIGURATION
  // ===========================================================================
  Widget _buildGatewaySetupSection(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dns_rounded, color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select SMTP Provider',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  if (_isConnected)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      onPressed: _isActionBusy ? null : _disconnectGateway,
                      icon: const Icon(Icons.link_off_rounded, size: 15),
                      label: const Text(
                        'Disconnect',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _smtpProviders.map((prov) {
                  final id = prov['id'] as String;
                  final isSelected = _selectedProvider == id;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedProvider = id;
                        _smtpHostCtrl.text = prov['host'] as String;
                        _smtpPortCtrl.text = (prov['port'] as int).toString();
                        _useTls = prov['tls'] as bool;
                        _useSsl = prov['ssl'] as bool;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? t.primaryColor.withValues(alpha: 0.12)
                            : t.inputBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? t.primaryColor : t.cardBorder,
                          width: isSelected ? 1.6 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prov['name'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: t.primaryText,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: t.primaryColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: t.primaryColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              prov['badge'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: t.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            prov['hint'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Helpful Notice for Gmail 16-digit App Password
              if (_selectedProvider == 'gmail')
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.primaryColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: t.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: t.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Gmail SMTP গাইড: আপনার Google Account -> Security -> 2-Step Verification অন করে "App Passwords" থেকে ১৬-সংখ্যার App Password তৈরি করে নিচে বসান।',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.primaryText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  Expanded(
                    child: _buildLabeledInput(
                      t,
                      label: 'Sender Store Name (sender_name) *',
                      controller: _senderNameCtrl,
                      hint: 'e.g. Buynarabd Official',
                      icon: Icons.storefront_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLabeledInput(
                      t,
                      label: 'SMTP Email Address (email_host_user) *',
                      controller: _hostUserCtrl,
                      hint: 'store@gmail.com',
                      icon: Icons.alternate_email_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildLabeledInput(
                t,
                label: _isConnected
                    ? 'App Password / SMTP Password (পরিবর্তন করতে চাইলে নতুন করে দিন)'
                    : 'Google 16-Digit App Password / SMTP Password *',
                controller: _hostPasswordCtrl,
                hint: 'xxxx xxxx xxxx xxxx',
                icon: Icons.key_rounded,
                obscureText: _obscurePassword,
                suffix: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: t.secondaryText,
                  ),
                ),
              ),

              if (_selectedProvider == 'custom') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildLabeledInput(
                        t,
                        label: 'SMTP Host (email_host)',
                        controller: _smtpHostCtrl,
                        hint: 'smtp.yourdomain.com',
                        icon: Icons.language_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildLabeledInput(
                        t,
                        label: 'SMTP Port',
                        controller: _smtpPortCtrl,
                        hint: '587',
                        icon: Icons.numbers_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactSwitchBox(
                        t,
                        label: 'Use STARTTLS (Port 587)',
                        value: _useTls,
                        onChanged: (v) {
                          setState(() {
                            _useTls = v;
                            if (v) _useSsl = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCompactSwitchBox(
                        t,
                        label: 'Use SSL/TLS (Port 465)',
                        value: _useSsl,
                        onChanged: (v) {
                          setState(() {
                            _useSsl = v;
                            if (v) _useTls = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isActionBusy ? null : _saveGatewaySettings,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _isActionBusy
                        ? 'Connecting SMTP...'
                        : 'Save & Activate Email Gateway',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Test Connection Card (/api/v1/emails/send-test/)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_outlined,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Test Live Email Delivery',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Send an instant test email via your configured SMTP server to verify inbox delivery.',
                style: TextStyle(fontSize: 12, color: t.secondaryText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildLabeledInput(
                      t,
                      label: 'Test Recipient Email Address',
                      controller: _testEmailCtrl,
                      hint: 'customer@example.com',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isActionBusy
                          ? null
                          : () => _sendTestOrCustomEmail(
                                toEmail: _testEmailCtrl.text,
                              ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text(
                        'Send Test',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSwitchBox(
    CatalogThemeConfig t, {
    required String label,
    required bool value,
    required ValueChanged onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.primaryText,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: t.primaryColor,
            onChanged: (v) => onChanged(v),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: COMPOSE & ORDER NOTIFICATION EMAIL
  // ===========================================================================
  Widget _buildComposeEmailSection(CatalogThemeConfig t) {
    final senderDisplay = _senderNameCtrl.text.trim().isEmpty
        ? 'STORE ADMIN'
        : _senderNameCtrl.text.trim().toUpperCase();
    final subjectPreview = _composeSubjectCtrl.text.trim().isEmpty
        ? 'Order Notification / Update'
        : _composeSubjectCtrl.text.trim();
    final bodyPreview = _composeMessageCtrl.text.trim().isEmpty
        ? 'Your email message content will be automatically styled inside a clean branded HTML card.'
        : _composeMessageCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.forward_to_inbox_rounded,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Compose Customer / Order HTML Email',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _showHtmlPreview = !_showHtmlPreview);
                    },
                    icon: Icon(
                      _showHtmlPreview
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                      color: t.primaryColor,
                    ),
                    label: Text(
                      _showHtmlPreview ? 'Hide Preview' : 'HTML Preview',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: t.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Quick Load Preset Email Template:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: t.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickEmailTemplates.map((tpl) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: t.inputBg,
                        side: BorderSide(color: t.cardBorder),
                        label: Text(
                          tpl['title'] as String,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: t.primaryText,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _composeSubjectCtrl.text =
                                tpl['subject'] as String;
                            _composeMessageCtrl.text = tpl['body'] as String;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _buildLabeledInput(
                t,
                label:
                    'Recipient Email(s) (Comma separated for multiple customers) *',
                controller: _composeToCtrl,
                hint: 'customer1@gmail.com, customer2@gmail.com',
                icon: Icons.people_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildLabeledInput(
                t,
                label: 'Email Subject *',
                controller: _composeSubjectCtrl,
                hint: 'Order Confirmation - #ORD-1042',
                icon: Icons.subject_rounded,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _composeMessageCtrl,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Write your email message here... Our backend automatically wraps it in a responsive HTML template.',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12.5),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isActionBusy
                      ? null
                      : () => _sendTestOrCustomEmail(
                            toEmail: _composeToCtrl.text,
                            subject: _composeSubjectCtrl.text,
                            message: _composeMessageCtrl.text,
                            isCustomOrderEmail: true,
                          ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isActionBusy
                        ? 'Sending Branded HTML Email...'
                        : 'Send Branded HTML Email Now',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_showHtmlPreview) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE HTML EMAIL PREVIEW',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: t.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: t.isDarkMode
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderDisplay,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: t.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subjectPreview,
                        style: TextStyle(
                          fontSize: 12,
                          color: t.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Divider(color: t.cardBorder, height: 22),
                      Text(
                        bodyPreview,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: t.primaryText,
                        ),
                      ),
                      Divider(color: t.cardBorder, height: 26),
                      Center(
                        child: Text(
                          'Sent by $senderDisplay (${_hostUserCtrl.text.isEmpty ? "not-configured" : _hostUserCtrl.text})',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // TAB 3: EMAIL LOGS & DELIVERY TRACKER
  // ===========================================================================
  Widget _buildEmailLogsSection(CatalogThemeConfig t) {
    final filteredLogs = _recentLogs.where((lg) {
      if (lg is! Map) return false;
      final st = (lg['status'] ?? 'sent').toString().toUpperCase();
      if (_logStatusFilter != 'ALL' && st != _logStatusFilter) {
        return false;
      }
      final q = _logSearchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final rec = (lg['recipient_email'] ?? '').toString().toLowerCase();
        final sub = (lg['subject'] ?? '').toString().toLowerCase();
        final msg = (lg['message'] ?? '').toString().toLowerCase();
        return rec.contains(q) || sub.contains(q) || msg.contains(q);
      }
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu_rounded,
                  color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Email Delivery Logs (${filteredLogs.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _fetchEmailGatewayData,
                icon: Icon(Icons.refresh_rounded,
                    size: 16, color: t.primaryColor),
                label: Text(
                  'Refresh Logs',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: t.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _logSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: t.primaryText, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Search recipient email, subject or body...',
                    hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: t.secondaryText),
                    isDense: true,
                    filled: true,
                    fillColor: t.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: t.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: t.cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ...['ALL', 'SENT', 'FAILED'].map((st) {
                final active = _logStatusFilter == st;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: InkWell(
                    onTap: () => setState(() => _logStatusFilter = st),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active ? t.primaryColor : t.inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active ? t.primaryColor : t.cardBorder,
                        ),
                      ),
                      child: Text(
                        st,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : t.secondaryText,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          if (filteredLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No email delivery logs found.',
                  style: TextStyle(color: t.secondaryText, fontSize: 12.5),
                ),
              ),
            )
          else
            ...filteredLogs.map((lg) {
              final st = (lg['status'] ?? 'sent').toString().toUpperCase();
              final isSent = st == 'SENT';
              final recEmail = (lg['recipient_email'] ?? '').toString();
              final subj = (lg['subject'] ?? '').toString();
              final msg = (lg['message'] ?? '').toString();
              final err = (lg['error_message'] ?? '').toString();
              final createdRaw = (lg['created_at'] ?? '').toString();
              final formattedDate = createdRaw.length > 16
                  ? createdRaw.substring(0, 16).replaceAll('T', ' ')
                  : createdRaw;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSent
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 16,
                          color: isSent
                              ? const Color(0xFF16A34A)
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            recEmail,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSent
                                ? const Color(0xFF16A34A).withValues(alpha: 0.14)
                                : Colors.redAccent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            st,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isSent
                                  ? const Color(0xFF16A34A)
                                  : Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subj,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: t.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: t.secondaryText,
                        height: 1.35,
                      ),
                    ),
                    if (err.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'SMTP Error: $err',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: t.secondaryText,
                          ),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: recEmail));
                                _showToast('Email copied to clipboard');
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'Copy Email',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: t.secondaryText,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _isActionBusy
                                  ? null
                                  : () => _sendTestOrCustomEmail(
                                        toEmail: recEmail,
                                        subject: subj,
                                        message: msg,
                                        isCustomOrderEmail: true,
                                      ),
                              child: Text(
                                'Resend Email',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLabeledInput(
    CatalogThemeConfig t, {
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    ValueChanged? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: TextStyle(color: t.primaryText, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
            prefixIcon: Icon(icon, size: 17, color: t.secondaryText),
            suffixIcon: suffix,
            isDense: true,
            filled: true,
            fillColor: t.inputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: t.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: t.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: t.primaryColor, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}