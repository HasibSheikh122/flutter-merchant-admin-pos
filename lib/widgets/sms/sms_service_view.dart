import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class SmsServiceView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final String? initialSubTab;
  final VoidCallback? onDataChanged;

  const SmsServiceView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'sms_gateway',
    this.initialSubTab,
    this.onDataChanged,
  });

  @override
  State<SmsServiceView> createState() => _SmsServiceViewState();
}

class _SmsServiceViewState extends State<SmsServiceView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  late String _activeTab;
  bool _isLoading = true;
  bool _isActionBusy = false;

  // Gateway & Live Stats (from /api/v1/sms/gateway/)
  bool _isConnected = false;
  String _gatewayStatusNote = 'Not Connected';
  String _selectedProvider = 'bulksmsbd';
  final TextEditingController _smsUsernameCtrl = TextEditingController();
  final TextEditingController _smsPasswordCtrl = TextEditingController();
  final TextEditingController _smsSenderCtrl =
      TextEditingController(text: '1234');
  final TextEditingController _apiUrlCtrl = TextEditingController(
    text: 'http://bulksmsbd.net/api/smsapi',
  );
  final TextEditingController _manualBalanceCtrl =
      TextEditingController(text: '0');
  bool _obscurePassword = true;

  double _smsBalance = 0.0;
  double _costPerSms = 1.0;
  int _todaysSend = 0;
  int _thisMonthSend = 0;
  int _thisMonthFailed = 0;
  List _recentLogs = [];

  // Tab 2: Individual SMS (/api/v1/sms/send-individual/)
  final TextEditingController _singleNumbersCtrl = TextEditingController();
  final TextEditingController _singleMessageCtrl = TextEditingController();

  // Tab 3: Templates (/api/v1/sms/templates/)
  List _templates = [];
  int? _editingTemplateId;
  final TextEditingController _tplNameCtrl = TextEditingController();
  final TextEditingController _tplTriggerCtrl =
      TextEditingController(text: 'order_placed');
  final TextEditingController _tplContentCtrl = TextEditingController();
  String _tplType = 'Custom';
  bool _tplIsActive = true;

  // Tab 4: Contact Groups (/api/v1/sms/groups/)
  List _groups = [];
  int? _editingGroupId;
  final TextEditingController _groupNameCtrl = TextEditingController();
  String _groupStatus = 'Active';
  String _groupMemberType = 'customer';
  final TextEditingController _groupCustomMembersCtrl = TextEditingController();

  // Tab 5: Bulk SMS & Transfer Users (/api/v1/sms/transfer-users/ & /api/v1/sms/send-bulk/)
  final Set _selectedSegments = {'all_customers'};
  List _transferredRecipients = [];
  final TextEditingController _manualBulkPhoneCtrl = TextEditingController();
  final TextEditingController _manualBulkNameCtrl = TextEditingController();
  final TextEditingController _bulkMessageCtrl = TextEditingController();
  final TextEditingController _logSearchCtrl = TextEditingController();
  String _logStatusFilter = 'ALL';

  static const List _providerPresets = [
    {
      'id': 'bulksmsbd',
      'name': 'BulkSMSBD',
      'tag': 'Popular BD',
      'url': 'http://bulksmsbd.net/api/smsapi',
      'sender': '8809617611000',
    },
    {
      'id': 'custom',
      'name': 'Bulk SMS Dhaka / Custom HTTP',
      'tag': 'HTTP GET/POST',
      'url': 'https://bulksmsdhaka.com/api/sendtext',
      'sender': '1234',
    },
    {
      'id': 'digitalsquare',
      'name': 'DigitalSquare Bulk SMS',
      'tag': 'Corporate BD',
      'url': 'http://api.greenweb.com.bd/api.php',
      'sender': '1234',
    },
    {
      'id': 'sslwireless',
      'name': 'SSL Wireless',
      'tag': 'Enterprise Masking',
      'url': 'https://smsplus.sslwireless.com/api/v3/send-sms',
      'sender': 'XYLO',
    },
    {
      'id': 'mimsms',
      'name': 'MimSMS',
      'tag': 'Transactional',
      'url': 'https://api.sms.net.bd/sendsms',
      'sender': '1234',
    },
    {
      'id': 'xylo_sms',
      'name': 'XYLO SMS Gateway',
      'tag': 'Cloud Managed',
      'url': 'http://bulksmsbd.net/api/smsapi',
      'sender': '1234',
    },
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = _normalizeTab(widget.initialSubTab ?? widget.initialTab);
    _initModule();
  }

  @override
  void didUpdateWidget(covariant SmsServiceView oldWidget) {
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
    if (lower.contains('single') || lower.contains('individual')) {
      return 'sms_single';
    }
    if (lower.contains('template')) {
      return 'sms_templates';
    }
    if (lower.contains('group') || lower.contains('contact')) {
      return 'sms_groups';
    }
    if (lower.contains('bulk') || lower.contains('log')) {
      return 'sms_bulk';
    }
    return 'sms_gateway';
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

  Future _initModule() async {
    setState(() => _isLoading = true);
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = loaded);
    }

    await _loadCachedFallback();
    await Future.wait([
      _fetchGatewayStatus(),
      _fetchTemplates(),
      _fetchGroups(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future _loadCachedFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _theme.subdomain;
      final cachedUser = prefs.getString('xylo_sms_user_$sub');
      final cachedSender = prefs.getString('xylo_sms_sender_$sub');
      final cachedUrl = prefs.getString('xylo_sms_url_$sub');
      final cachedProv = prefs.getString('xylo_sms_prov_$sub');
      if (cachedUser != null && cachedUser.isNotEmpty) {
        _smsUsernameCtrl.text = cachedUser;
      }
      if (cachedSender != null && cachedSender.isNotEmpty) {
        _smsSenderCtrl.text = cachedSender;
      }
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        _apiUrlCtrl.text = cachedUrl;
      }
      if (cachedProv != null && cachedProv.isNotEmpty) {
        _selectedProvider = cachedProv;
      }
    } catch (_) {}
  }

  Future _saveCachedFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _theme.subdomain;
      await prefs.setString('xylo_sms_user_$sub', _smsUsernameCtrl.text.trim());
      await prefs.setString(
          'xylo_sms_sender_$sub', _smsSenderCtrl.text.trim());
      await prefs.setString('xylo_sms_url_$sub', _apiUrlCtrl.text.trim());
      await prefs.setString('xylo_sms_prov_$sub', _selectedProvider);
    } catch (_) {}
  }

  // ===========================================================================
  // 1. GATEWAY API CALLS (/api/v1/sms/gateway/)
  // ===========================================================================
  Future _fetchGatewayStatus() async {
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/gateway/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .get(uri, headers: _theme.headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _applyGatewayResponse(jsonDecode(res.body));
      }
    } catch (_) {}
  }

  void _applyGatewayResponse(dynamic data) {
    if (data is! Map) return;
    setState(() {
      _isConnected = data['is_connected'] == true;
      _gatewayStatusNote =
          (data['gateway_note'] ?? data['message'] ?? 'Connected').toString();

      final cfg = data['config'];
      if (cfg is Map) {
        _selectedProvider =
            (cfg['provider'] ?? _selectedProvider).toString();
        final u = (cfg['sms_username'] ?? '').toString();
        final p = (cfg['sms_password'] ?? '').toString();
        final s = (cfg['sms_sender'] ?? '').toString();
        final url = (cfg['api_url'] ?? '').toString();
        if (u.isNotEmpty) _smsUsernameCtrl.text = u;
        if (p.isNotEmpty) _smsPasswordCtrl.text = p;
        if (s.isNotEmpty) _smsSenderCtrl.text = s;
        if (url.isNotEmpty) _apiUrlCtrl.text = url;

        _smsBalance =
            double.tryParse((cfg['sms_balance'] ?? '0').toString()) ?? 0.0;
        _costPerSms =
            double.tryParse((cfg['cost_per_sms'] ?? '1').toString()) ?? 1.0;
        _manualBalanceCtrl.text = _smsBalance.toStringAsFixed(0);
      }

      final st = data['stats'];
      if (st is Map) {
        _smsBalance =
            double.tryParse((st['sms_balance'] ?? _smsBalance).toString()) ??
                _smsBalance;
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
    _saveCachedFallback();
  }

  Future _saveGatewayConfig() async {
    final apiKey = _smsUsernameCtrl.text.trim();
    final apiUrl = _apiUrlCtrl.text.trim();
    if (apiKey.isEmpty || apiUrl.isEmpty) {
      _showToast('API Key এবং API URL অবশ্যই দিতে হবে।', isError: true);
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/gateway/?subdomain=${_theme.subdomain}',
      );
      final payload = {
        'provider': _selectedProvider,
        'sms_username': apiKey,
        'sms_password': _smsPasswordCtrl.text.trim().isEmpty
            ? '1234'
            : _smsPasswordCtrl.text.trim(),
        'sms_sender': _smsSenderCtrl.text.trim().isEmpty
            ? '1234'
            : _smsSenderCtrl.text.trim(),
        'api_url': apiUrl,
        'sms_balance': _manualBalanceCtrl.text.trim(),
      };

      final res = await http
          .post(
            uri,
            headers: _theme.headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        _applyGatewayResponse(decoded);
        widget.onDataChanged?.call();
        _showToast(
          (decoded['message'] ?? 'SMS Gateway সফলভাবে কানেক্ট হয়েছে!')
              .toString(),
        );
      } else {
        _showToast('Gateway save failed (${res.statusCode})', isError: true);
      }
    } catch (e) {
      _showToast('Network error while connecting gateway.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  Future _syncLiveBalance() async {
    setState(() => _isActionBusy = true);
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/gateway/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .post(
            uri,
            headers: _theme.headers,
            body: jsonEncode({'action': 'sync_balance'}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        _applyGatewayResponse(decoded);
        widget.onDataChanged?.call();
        _showToast(
          (decoded['gateway_note'] ?? 'Live balance synced!').toString(),
        );
      }
    } catch (_) {
      _showToast('Could not reach gateway balance endpoint.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  Future _disconnectGateway() async {
    setState(() => _isActionBusy = true);
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/gateway/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .post(
            uri,
            headers: _theme.headers,
            body: jsonEncode({'action': 'disconnect'}),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _applyGatewayResponse(jsonDecode(res.body));
        widget.onDataChanged?.call();
        _showToast('SMS Gateway disconnected.');
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  // ===========================================================================
  // 2. TEMPLATES API CALLS (/api/v1/sms/templates/)
  // ===========================================================================
  Future _fetchTemplates() async {
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/templates/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .get(uri, headers: _theme.headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && mounted) {
          setState(() => _templates = List.from(decoded));
        }
      }
    } catch (_) {}
  }

  Future _saveTemplate() async {
    final name = _tplNameCtrl.text.trim();
    final content = _tplContentCtrl.text.trim();
    if (name.isEmpty || content.isEmpty) {
      _showToast('Template Name এবং Content দেওয়া আবশ্যক।', isError: true);
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final payload = {
        'name': name,
        'template_type': _tplType,
        'trigger_event': _tplTriggerCtrl.text.trim(),
        'content': content,
        'is_active': _tplIsActive,
      };

      http.Response res;
      if (_editingTemplateId != null) {
        final uri = Uri.parse(
          '${_theme.apiBase}/api/v1/sms/templates/$_editingTemplateId/?subdomain=${_theme.subdomain}',
        );
        res = await http
            .patch(uri, headers: _theme.headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      } else {
        final uri = Uri.parse(
          '${_theme.apiBase}/api/v1/sms/templates/?subdomain=${_theme.subdomain}',
        );
        res = await http
            .post(uri, headers: _theme.headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _tplNameCtrl.clear();
        _tplContentCtrl.clear();
        _editingTemplateId = null;
        await _fetchTemplates();
        _showToast('SMS Template সংরক্ষিত হয়েছে!');
      } else {
        _showToast('Could not save template.', isError: true);
      }
    } catch (_) {
      _showToast('Error saving template.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  Future _deleteTemplate(Map tpl) async {
    if ((tpl['template_type'] ?? '') == 'Default') {
      _showToast(
        'Default template ডিলিট করা যাবে না, শুধু Edit করতে পারবেন।',
        isError: true,
      );
      return;
    }
    final id = tpl['id'];
    if (id == null) return;
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/templates/$id/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .delete(uri, headers: _theme.headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchTemplates();
        _showToast('Template deleted.');
      } else {
        final body = jsonDecode(res.body);
        _showToast(
          (body['detail'] ?? 'Cannot delete template').toString(),
          isError: true,
        );
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 3. GROUPS API CALLS (/api/v1/sms/groups/)
  // ===========================================================================
  Future _fetchGroups() async {
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/groups/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .get(uri, headers: _theme.headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && mounted) {
          setState(() => _groups = List.from(decoded));
        }
      }
    } catch (_) {}
  }

  Future _saveGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast('Group Name লিখুন।', isError: true);
      return;
    }

    final rawLines = _groupCustomMembersCtrl.text
        .split(RegExp(r'[\n,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final customMembersList = [];
    for (final entry in rawLines) {
      if (entry.contains(':')) {
        final parts = entry.split(':');
        customMembersList.add({
          'name': parts.first.trim(),
          'mobile': parts.sublist(1).join(':').trim(),
        });
      } else {
        customMembersList.add({
          'name': name,
          'mobile': entry,
        });
      }
    }

    setState(() => _isActionBusy = true);
    try {
      final payload = {
        'name': name,
        'status': _groupStatus,
        'member_type': _groupMemberType,
        'custom_Members': customMembersList,
      };

      http.Response res;
      if (_editingGroupId != null) {
        final uri = Uri.parse(
          '${_theme.apiBase}/api/v1/sms/groups/$_editingGroupId/?subdomain=${_theme.subdomain}',
        );
        res = await http
            .patch(uri, headers: _theme.headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      } else {
        final uri = Uri.parse(
          '${_theme.apiBase}/api/v1/sms/groups/?subdomain=${_theme.subdomain}',
        );
        res = await http
            .post(uri, headers: _theme.headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _groupNameCtrl.clear();
        _groupCustomMembersCtrl.clear();
        _editingGroupId = null;
        await _fetchGroups();
        _showToast('Contact Group সংরক্ষিত হয়েছে!');
      } else {
        _showToast('Group save failed.', isError: true);
      }
    } catch (_) {
      _showToast('Error saving group.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  Future _deleteGroup(int id) async {
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/groups/$id/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .delete(uri, headers: _theme.headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchGroups();
        _showToast('Group deleted.');
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 4. SEND INDIVIDUAL SMS (/api/v1/sms/send-individual/)
  // ===========================================================================
  Future _sendIndividualSms() async {
    final numbers = _singleNumbersCtrl.text.trim();
    final msg = _singleMessageCtrl.text.trim();
    if (numbers.isEmpty || msg.isEmpty) {
      _showToast('মোবাইল নম্বর এবং মেসেজ উভয়ই দিন।', isError: true);
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/send-individual/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .post(
            uri,
            headers: _theme.headers,
            body: jsonEncode({
              'numbers': numbers,
              'message': msg,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _singleMessageCtrl.clear();
        await _fetchGatewayStatus();
        widget.onDataChanged?.call();
        _showToast(
          (decoded['message'] ?? 'SMS সফলভাবে পাঠানো হয়েছে!').toString(),
        );
      } else {
        _showToast(
          (decoded['detail'] ?? 'SMS পাঠানো যায়নি।').toString(),
          isError: true,
        );
      }
    } catch (_) {
      _showToast('Connection error while sending SMS.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  // ===========================================================================
  // 5. TRANSFER USERS & SEND BULK (/api/v1/sms/transfer-users/ & /send-bulk/)
  // ===========================================================================
  Future _transferSelectedAudience() async {
    if (_selectedSegments.isEmpty) {
      _showToast('অন্তত একটি সেগমেন্ট বা গ্রুপ সিলেক্ট করুন।', isError: true);
      return;
    }
    setState(() => _isActionBusy = true);
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/transfer-users/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .post(
            uri,
            headers: _theme.headers,
            body: jsonEncode({
              'segments': _selectedSegments.toList(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          setState(() {
            _transferredRecipients = List.from(decoded);
          });
          _showToast(
            '${_transferredRecipients.length} জন গ্রাহকের নম্বর লোড হয়েছে!',
          );
        }
      }
    } catch (_) {
      _showToast('Could not load recipients from backend.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  Future _sendBulkSms() async {
    final msg = _bulkMessageCtrl.text.trim();
    if (_transferredRecipients.isEmpty) {
      _showToast(
        'আগে "Load Audience Contacts" বাটনে ক্লিক করে গ্রাহক তালিকা আনুন বা ম্যানুয়ালি যোগ করুন।',
        isError: true,
      );
      return;
    }
    if (msg.isEmpty) {
      _showToast('Bulk SMS মেসেজ লিখুন।', isError: true);
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final uri = Uri.parse(
        '${_theme.apiBase}/api/v1/sms/send-bulk/?subdomain=${_theme.subdomain}',
      );
      final res = await http
          .post(
            uri,
            headers: _theme.headers,
            body: jsonEncode({
              'recipients': _transferredRecipients,
              'message': msg,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _bulkMessageCtrl.clear();
        await _fetchGatewayStatus();
        widget.onDataChanged?.call();
        _showToast(
          (decoded['message'] ?? 'Bulk SMS সফলভাবে পাঠানো হয়েছে!').toString(),
        );
      } else {
        _showToast(
          (decoded['detail'] ?? 'Bulk SMS পাঠানো যায়নি।').toString(),
          isError: true,
        );
      }
    } catch (_) {
      _showToast('Error dispatching bulk SMS.', isError: true);
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  // ===========================================================================
  // SMS COUNTER HELPERS (matching backend calculate_sms_parts_and_cost)
  // ===========================================================================
  bool _isUnicode(String text) {
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 127) return true;
    }
    return false;
  }

  Map _computeSmsStats(String message) {
    final cleanSender =
        _smsSenderCtrl.text.trim().replaceAll('[', '').replaceAll(']', '');
    final branded =
        cleanSender.isNotEmpty ? '[$cleanSender]: $message' : message;
    final len = branded.length;
    if (len == 0) {
      return {'len': 0, 'parts': 0, 'isUnicode': false};
    }
    final isUni = _isUnicode(branded);
    int parts = 1;
    if (isUni) {
      parts = len <= 70 ? 1 : (len / 67).ceil();
    } else {
      parts = len <= 160 ? 1 : (len / 153).ceil();
    }
    return {'len': len, 'parts': parts, 'isUnicode': isUni};
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
        _buildTopHeroHeader(t),
        const SizedBox(height: 16),
        _buildSubTabsBar(t),
        const SizedBox(height: 16),
        if (_activeTab == 'sms_gateway') _buildGatewayTab(t),
        if (_activeTab == 'sms_single') _buildSingleSmsTab(t),
        if (_activeTab == 'sms_templates') _buildTemplatesTab(t),
        if (_activeTab == 'sms_groups') _buildGroupsTab(t),
        if (_activeTab == 'sms_bulk') _buildBulkAndLogsTab(t),
      ],
    );
  }

  Widget _buildTopHeroHeader(CatalogThemeConfig t) {
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
                  Icons.sms_rounded,
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
                            'SMS Gateway & Campaign Center',
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
                            _isConnected ? 'CONNECTED' : 'NOT CONNECTED',
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
                      _gatewayStatusNote,
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
                onPressed: _isActionBusy ? null : _syncLiveBalance,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text(
                  'Sync Balance',
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
                Icons.account_balance_wallet_rounded,
                'Live Balance: $_smsBalance',
              ),
              _buildHeroStatPill(
                Icons.today_rounded,
                'Today Sent: $_todaysSend',
              ),
              _buildHeroStatPill(
                Icons.mark_chat_read_rounded,
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

  Widget _buildSubTabsBar(CatalogThemeConfig t) {
    final tabs = [
      {
        'key': 'sms_gateway',
        'label': 'SMS Gateway',
        'icon': Icons.settings_input_antenna_rounded,
        'badge': _isConnected ? 'LIVE' : 'Setup',
      },
      {
        'key': 'sms_single',
        'label': 'Individual SMS',
        'icon': Icons.send_to_mobile_rounded,
        'badge': 'Instant',
      },
      {
        'key': 'sms_templates',
        'label': 'Templates',
        'icon': Icons.description_outlined,
        'badge': '${_templates.length}',
      },
      {
        'key': 'sms_groups',
        'label': 'Contact Groups',
        'icon': Icons.groups_2_outlined,
        'badge': '${_groups.length}',
      },
      {
        'key': 'sms_bulk',
        'label': 'Bulk SMS & Logs',
        'icon': Icons.campaign_outlined,
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
  // TAB 1: GATEWAY SETUP
  // ===========================================================================
  Widget _buildGatewayTab(CatalogThemeConfig t) {
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
              Icon(Icons.router_rounded, color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SMS Gateway Configuration',
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
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text(
                    'Disconnect',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _providerPresets.map((p) {
              final id = p['id'] as String;
              final isSelected = _selectedProvider == id;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedProvider = id;
                    _apiUrlCtrl.text = p['url'] as String;
                    if (_smsSenderCtrl.text.trim().isEmpty) {
                      _smsSenderCtrl.text = p['sender'] as String;
                    }
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
                              p['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
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
                      Text(
                        p['tag'] as String,
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
          _buildLabeledInput(
            t,
            label: 'API Key / SMS Username (sms_username) *',
            controller: _smsUsernameCtrl,
            hint: 'Paste your Gateway API Key or full URL with ?apikey=...',
            icon: Icons.vpn_key_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLabeledInput(
                  t,
                  label: 'Sender ID / Caller ID (sms_sender)',
                  controller: _smsSenderCtrl,
                  hint: '1234 or 8809617611000',
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLabeledInput(
                  t,
                  label: 'API Secret / Password (Optional)',
                  controller: _smsPasswordCtrl,
                  hint: '1234',
                  icon: Icons.lock_outline_rounded,
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
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLabeledInput(
            t,
            label: 'Gateway HTTP API Endpoint (api_url) *',
            controller: _apiUrlCtrl,
            hint: 'https://bulksmsdhaka.com/api/sendtext',
            icon: Icons.link_rounded,
          ),
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
              onPressed: _isActionBusy ? null : _saveGatewayConfig,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(
                _isActionBusy
                    ? 'Connecting Gateway...'
                    : 'Connect & Save SMS Gateway',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: INDIVIDUAL SMS
  // ===========================================================================
  Widget _buildSingleSmsTab(CatalogThemeConfig t) {
    final stats = _computeSmsStats(_singleMessageCtrl.text);
    final isUni = stats['isUnicode'] == true;
    final len = stats['len'] as int;
    final parts = stats['parts'] as int;

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
              Icon(Icons.send_to_mobile_rounded,
                  color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Send Individual / Quick Multi-Number SMS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: t.primaryText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sender: ${_smsSenderCtrl.text}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: t.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildLabeledInput(
            t,
            label: 'Mobile Number(s) (Comma separated) *',
            controller: _singleNumbersCtrl,
            hint: '017XXXXXXXX, 018XXXXXXXX',
            icon: Icons.phone_android_rounded,
          ),
          const SizedBox(height: 12),
          if (_templates.isNotEmpty) ...[
            Text(
              'Quick Insert Template:',
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
                children: _templates.map((tpl) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: t.inputBg,
                      side: BorderSide(color: t.cardBorder),
                      label: Text(
                        (tpl['name'] ?? 'Template').toString(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: t.primaryText,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _singleMessageCtrl.text =
                              (tpl['content'] ?? '').toString();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _singleMessageCtrl,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: t.primaryText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'এখানে আপনার বাংলা বা ইংরেজি মেসেজ লিখুন...',
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Encoding: ${isUni ? "Unicode (বাংলা 70/67 chars)" : "GSM-7 (English 160/153 chars)"}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: t.secondaryText,
                ),
              ),
              Text(
                'Length: $len chars  |  SMS Parts: $parts',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: t.primaryColor,
                ),
              ),
            ],
          ),
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
              onPressed: _isActionBusy ? null : _sendIndividualSms,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isActionBusy ? 'Sending SMS...' : 'Send Instant SMS Now',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: TEMPLATES
  // ===========================================================================
  Widget _buildTemplatesTab(CatalogThemeConfig t) {
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
              Text(
                _editingTemplateId == null
                    ? 'Create Custom SMS Template'
                    : 'Edit SMS Template (#$_editingTemplateId)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildLabeledInput(
                      t,
                      label: 'Template Name *',
                      controller: _tplNameCtrl,
                      hint: 'e.g. Order Placed Alert',
                      icon: Icons.title_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLabeledInput(
                      t,
                      label: 'Trigger Event',
                      controller: _tplTriggerCtrl,
                      hint: 'order_placed',
                      icon: Icons.bolt_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tplContentCtrl,
                maxLines: 3,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Use {CustomerName}, {CompanyName}, {OrderId}, {Amount}...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_editingTemplateId != null) ...[
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _editingTemplateId = null;
                          _tplNameCtrl.clear();
                          _tplContentCtrl.clear();
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isActionBusy ? null : _saveTemplate,
                      icon: const Icon(Icons.add_task_rounded, size: 17),
                      label: Text(
                        _editingTemplateId == null
                            ? 'Save Template'
                            : 'Update Template',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._templates.map((tpl) {
          if (tpl is! Map) return const SizedBox.shrink();
          final content = (tpl['content'] ?? '').toString();
          final tplType = (tpl['template_type'] ?? 'Custom').toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: t.primaryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        tplType,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: t.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (tpl['name'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                    ),
                    if ((tpl['trigger_event'] ?? '').toString().isNotEmpty)
                      Text(
                        (tpl['trigger_event'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: t.secondaryText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: t.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _singleMessageCtrl.text = content;
                          _activeTab = 'sms_single';
                        });
                      },
                      icon: Icon(Icons.send_outlined,
                          size: 15, color: t.primaryColor),
                      label: Text(
                        'Use in Single SMS',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: t.primaryColor,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _editingTemplateId =
                              int.tryParse(tpl['id'].toString());
                          _tplNameCtrl.text = (tpl['name'] ?? '').toString();
                          _tplTriggerCtrl.text =
                              (tpl['trigger_event'] ?? '').toString();
                          _tplContentCtrl.text = content;
                          _tplType = tplType;
                        });
                      },
                      icon: Icon(Icons.edit_outlined,
                          size: 15, color: t.secondaryText),
                      label: Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: t.secondaryText,
                        ),
                      ),
                    ),
                    if (tplType != 'Default')
                      IconButton(
                        onPressed: () => _deleteTemplate(tpl),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                          color: Colors.redAccent,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: CONTACT GROUPS
  // ===========================================================================
  Widget _buildGroupsTab(CatalogThemeConfig t) {
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
              Text(
                _editingGroupId == null
                    ? 'Create SMS Contact Group'
                    : 'Update SMS Group (#$_editingGroupId)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildLabeledInput(
                      t,
                      label: 'Group Name *',
                      controller: _groupNameCtrl,
                      hint: 'e.g. VIP Repeat Customers',
                      icon: Icons.groups_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Member Type',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: t.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          children: ['customer', 'vip_customer', 'employee']
                              .map((mt) {
                            final active = _groupMemberType == mt;
                            return ChoiceChip(
                              label: Text(mt),
                              selected: active,
                              selectedColor:
                                  t.primaryColor.withValues(alpha: 0.2),
                              onSelected: (_) {
                                setState(() => _groupMemberType = mt);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildLabeledInput(
                t,
                label:
                    'Custom Members (Optional: Name:017XXXXXXXX or comma-separated phones)',
                controller: _groupCustomMembersCtrl,
                hint: 'Rahim:01711223344, Karim:01819283746',
                icon: Icons.contact_phone_outlined,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isActionBusy ? null : _saveGroup,
                  icon: const Icon(Icons.save_outlined, size: 17),
                  label: Text(
                    _editingGroupId == null
                        ? 'Save Contact Group'
                        : 'Update Contact Group',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._groups.map((grp) {
          if (grp is! Map) return const SizedBox.shrink();
          final grpId = int.tryParse(grp['id'].toString()) ?? 0;
          final memberCount = grp['member_count'] ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: t.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.groups_2_rounded,
                    color: t.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (grp['name'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$memberCount Members • Type: ${grp['member_type']} • Status: ${grp['status']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: t.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedSegments.add('group_$grpId');
                      _activeTab = 'sms_bulk';
                    });
                    _transferSelectedAudience();
                  },
                  icon: const Icon(Icons.campaign_rounded, size: 15),
                  label: const Text(
                    'Send Bulk',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _deleteGroup(grpId),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: BULK SMS & RECENT LOGS
  // ===========================================================================
  Widget _buildBulkAndLogsTab(CatalogThemeConfig t) {
    final stats = _computeSmsStats(_bulkMessageCtrl.text);
    final parts = stats['parts'] as int;

    final filteredLogs = _recentLogs.where((lg) {
      if (lg is! Map) return false;
      final st = (lg['status'] ?? '').toString().toUpperCase();
      if (_logStatusFilter != 'ALL' && st != _logStatusFilter) {
        return false;
      }
      final q = _logSearchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final mob = (lg['mobile_number'] ?? '').toString().toLowerCase();
        final msg = (lg['message'] ?? '').toString().toLowerCase();
        return mob.contains(q) || msg.contains(q);
      }
      return true;
    }).toList();

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
                  Icon(Icons.campaign_rounded,
                      color: t.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bulk SMS Audience & Campaign Dispatcher',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Loaded: ${_transferredRecipients.length} Contacts',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: t.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '1. Select Audience Segments & Groups:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...[
                    {'id': 'all_customers', 'label': 'All Store Customers'},
                    {'id': 'active_clients', 'label': 'Active Clients'},
                    {'id': 'unpaid_clients', 'label': 'Unpaid / Due Clients'},
                  ].map((seg) {
                    final id = seg['id'] as String;
                    final selected = _selectedSegments.contains(id);
                    return FilterChip(
                      label: Text(seg['label'] as String),
                      selected: selected,
                      selectedColor: t.primaryColor.withValues(alpha: 0.2),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSegments.add(id);
                          } else {
                            _selectedSegments.remove(id);
                          }
                        });
                      },
                    );
                  }),
                  ..._groups.map((grp) {
                    final segKey = 'group_${grp['id']}';
                    final selected = _selectedSegments.contains(segKey);
                    return FilterChip(
                      label: Text(
                          '${grp['name']} (${grp['member_count'] ?? 0})'),
                      selected: selected,
                      selectedColor: t.primaryColor.withValues(alpha: 0.2),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSegments.add(segKey);
                          } else {
                            _selectedSegments.remove(segKey);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed:
                        _isActionBusy ? null : _transferSelectedAudience,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text(
                      'Load Audience Contacts',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_transferredRecipients.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() => _transferredRecipients.clear());
                      },
                      child: const Text(
                        'Clear List',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildLabeledInput(
                      t,
                      label: 'Add Manual Recipient Name',
                      controller: _manualBulkNameCtrl,
                      hint: 'Customer Name',
                      icon: Icons.person_add_alt_1_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLabeledInput(
                      t,
                      label: 'Add Manual Phone',
                      controller: _manualBulkPhoneCtrl,
                      hint: '017XXXXXXXX',
                      icon: Icons.dialpad_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: OutlinedButton(
                      onPressed: () {
                        final ph = _manualBulkPhoneCtrl.text.trim();
                        if (ph.isEmpty) return;
                        setState(() {
                          _transferredRecipients.add({
                            'id':
                                'man_${DateTime.now().millisecondsSinceEpoch}',
                            'name': _manualBulkNameCtrl.text.trim().isEmpty
                                ? 'Customer'
                                : _manualBulkNameCtrl.text.trim(),
                            'mobile': ph,
                          });
                          _manualBulkNameCtrl.clear();
                          _manualBulkPhoneCtrl.clear();
                        });
                      },
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bulkMessageCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Write campaign message... Use {CustomerName} and {CompanyName} for dynamic personalization.',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SMS Parts per Recipient: $parts',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: t.secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Total Recipients: ${_transferredRecipients.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: t.primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                  onPressed: _isActionBusy ? null : _sendBulkSms,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 17),
                  label: Text(
                    _isActionBusy
                        ? 'Dispatching Bulk SMS...'
                        : 'Send Bulk SMS to ${_transferredRecipients.length} Recipients',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recent Logs Card
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
                  Icon(Icons.history_edu_rounded,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recent Gateway Logs (${filteredLogs.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _fetchGatewayStatus,
                    icon: Icon(Icons.refresh_rounded,
                        size: 16, color: t.primaryColor),
                    label: Text(
                      'Refresh',
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
                        hintText: 'Search mobile number or message...',
                        hintStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
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
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No SMS logs found.',
                      style: TextStyle(color: t.secondaryText, fontSize: 12.5),
                    ),
                  ),
                )
              else
                ...filteredLogs.map((lg) {
                  final st = (lg['status'] ?? 'sent').toString().toUpperCase();
                  final isSent = st == 'SENT';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(12),
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
                              size: 15,
                              color: isSent
                                  ? const Color(0xFF16A34A)
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                (lg['mobile_number'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                              ),
                            ),
                            Text(
                              (lg['created_at'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          (lg['message'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: t.secondaryText,
                          ),
                        ),
                        if ((lg['provider_response'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Gateway: ${lg['provider_response']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
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