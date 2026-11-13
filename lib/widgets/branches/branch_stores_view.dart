// lib/widgets/branches/branch_stores_view.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../catalog/catalog_theme_scope.dart';

class BranchStoresView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab; // 'list', 'add', 'export', 'notice', 'chat'
  final VoidCallback? onDataChanged;

  const BranchStoresView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'list',
    this.onDataChanged,
  });

  @override
  State<BranchStoresView> createState() => _BranchStoresViewState();
}

class _BranchStoresViewState extends State<BranchStoresView> {
  String _activeTab = 'list';
  bool _isLoading = true;
  bool _isSaving = false;

  CatalogThemeConfig _theme = const CatalogThemeConfig();

  String _apiBase = 'https://nextlook.shop.xylotechsolution.com';
  String _subdomain = 'buynarabd';
  String _token = '';

  // 1. Branches & Subscription Quota
  List _branches = [];
  int _maxBranchesQuota = 5;
  String _planName = 'Pro Merchant Plan';
  String _branchSearchQuery = '';
  String _branchStatusFilter = 'all'; // 'all', 'active', 'inactive'
  final Set _visiblePasswordBranchIds = {};

  // 2. Add / Edit Branch Form State
  int? _editingBranchId;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _slugCtrl = TextEditingController();
  final TextEditingController _categoryLabelCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _managerNameCtrl = TextEditingController();
  final TextEditingController _managerEmailCtrl = TextEditingController();
  final TextEditingController _managerPasswordCtrl = TextEditingController();
  bool _branchIsActive = true;
  bool _obscureManagerPassword = false;

  // 3. Export Product / Stock Transfer State
  List _mainStoreProducts = [];
  List _transferHistory = [];
  Map _transferSummary = {
    'total_transfers': 0,
    'total_pieces_sent': 0,
    'total_stock_value': 0.0,
  };
  int? _selectedExportBranchId;
  int? _historyFilterBranchId;
  String _exportProductSearch = '';
  final Map _selectedTransferQuantities = {};
  final TextEditingController _transferNoteCtrl = TextEditingController();
  bool _isTransferring = false;

  // 4. Branch Notices State
  List _branchNotices = [];
  final TextEditingController _noticeTitleCtrl = TextEditingController();
  final TextEditingController _noticeMessageCtrl = TextEditingController();
  String _noticePriority = 'high';
  String _noticeTargetBranch = 'all';
  bool _isPostingNotice = false;

  // 5. Branch Chat State
  int? _selectedChatBranchId;
  String _chatChannelMode = 'branch_merchant';
  List _chatMessages = [];
  final TextEditingController _chatInputCtrl = TextEditingController();
  bool _isSendingChat = false;
  Timer? _chatPollTimer;

  @override
  void initState() {
    super.initState();
    _activeTab = _normalizeTab(widget.initialTab);
    _nameCtrl.addListener(_autoGenerateSlug);
    _initData();
  }

  @override
  void didUpdateWidget(covariant BranchStoresView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTab = _normalizeTab(widget.initialTab);
    if (oldWidget.initialTab != widget.initialTab && nextTab != _activeTab) {
      setState(() {
        _activeTab = nextTab;
        if (_activeTab == 'add' && _editingBranchId == null) {
          _resetBranchForm();
        }
      });
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _loadTheme();
    }
  }

  @override
  void dispose() {
    _chatPollTimer?.cancel();
    _nameCtrl.removeListener(_autoGenerateSlug);
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _categoryLabelCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _managerNameCtrl.dispose();
    _managerEmailCtrl.dispose();
    _managerPasswordCtrl.dispose();
    _transferNoteCtrl.dispose();
    _noticeTitleCtrl.dispose();
    _noticeMessageCtrl.dispose();
    _chatInputCtrl.dispose();
    super.dispose();
  }

  String _normalizeTab(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('add')) return 'add';
    if (lower.contains('export') || lower.contains('transfer')) return 'export';
    if (lower.contains('notice') || lower.contains('alert')) return 'notice';
    if (lower.contains('chat')) return 'chat';
    return 'list';
  }

  void _autoGenerateSlug() {
    if (_editingBranchId != null) return;
    final raw = _nameCtrl.text.trim().toLowerCase();
    final slug = raw
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    _slugCtrl.text = slug;
  }

  Future _loadTheme() async {
    final cfg = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = cfg);
    }
  }

  Map<String, String> _headers({bool jsonContent = false}) {
    final map = <String, String>{
      'Accept': 'application/json',
      'X-Tenant-Subdomain': _subdomain,
      'x-subdomain': _subdomain,
      'X-Tenant-Domain': _subdomain,
    };
    if (jsonContent) {
      map['Content-Type'] = 'application/json';
    }
    if (_token.isNotEmpty) {
      map['Authorization'] = 'Bearer $_token';
    }
    return map;
  }

  Future _initData() async {
    await _loadTheme();
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('merchant_token') ?? '';
    _subdomain = prefs.getString('active_subdomain') ?? 'buynarabd';
    String base = prefs.getString('api_base_url') ?? 'https://nextlook.shop.xylotechsolution.com';
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    _apiBase = base;

    await _fetchAllBranchData();

    _chatPollTimer?.cancel();
    _chatPollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _activeTab == 'chat') {
        _fetchBranchChatMessages(silent: true);
      }
    });
  }

  Future _fetchAllBranchData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    final prefs = await SharedPreferences.getInstance();

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/branches/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/branch-product-transfers/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/merchant/subscription/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 6))
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/announcements/?subdomain=$_subdomain'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 6))
            .catchError((_) => http.Response('[]', 500)),
      ]);

      // 1. Parse Branches
      if (results[0].statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(results[0].bodyBytes));
        List parsedBranches = [];
        if (decoded is List) {
          parsedBranches = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          parsedBranches = decoded['results'];
        }
        _branches = parsedBranches;
        await prefs.setString(
            'cached_branches_$_subdomain', jsonEncode(_branches));
      } else {
        final cached = prefs.getString('cached_branches_$_subdomain');
        if (cached != null && cached.isNotEmpty) {
          final dec = jsonDecode(cached);
          if (dec is List) _branches = dec;
        }
      }

      if (_branches.isNotEmpty) {
        final firstId = int.tryParse((_branches.first['id'] ?? '').toString());
        _selectedExportBranchId ??= firstId;
        _selectedChatBranchId ??= firstId;
      }

      // 2. Parse Export / Transfer Data
      if (results[1].statusCode == 200) {
        final tData = jsonDecode(utf8.decode(results[1].bodyBytes));
        if (tData is Map) {
          if (tData['main_products'] is List) {
            _mainStoreProducts = tData['main_products'];
          }
          if (tData['history'] is List) {
            _transferHistory = tData['history'];
          }
          if (tData['summary'] is Map) {
            _transferSummary = Map.from(tData['summary']);
          }
        }
      }

      // 3. Parse Subscription Quota
      if (results[2].statusCode == 200) {
        final subData = jsonDecode(utf8.decode(results[2].bodyBytes));
        if (subData is Map) {
          _planName = (subData['plan_name'] ?? _planName).toString();
          if (subData['branch_quota'] is Map) {
            final bq = subData['branch_quota'];
            _maxBranchesQuota =
                int.tryParse((bq['max_branches'] ?? 5).toString()) ?? 5;
          }
        }
      }

      // 4. Parse Notices
      List combinedNotices = [];
      final localNoticesRaw =
          prefs.getString('branch_notices_$_subdomain') ?? '[]';
      try {
        final localDec = jsonDecode(localNoticesRaw);
        if (localDec is List) combinedNotices.addAll(localDec);
      } catch (_) {}

      if (results[3].statusCode == 200) {
        final nDec = jsonDecode(utf8.decode(results[3].bodyBytes));
        List remoteList = [];
        if (nDec is List) {
          remoteList = nDec;
        } else if (nDec is Map && nDec['results'] is List) {
          remoteList = nDec['results'];
        }
        for (var item in remoteList) {
          if (item is Map) {
            final existingIdx = combinedNotices.indexWhere(
                (e) => e['id'].toString() == item['id'].toString());
            if (existingIdx == -1) {
              combinedNotices.add({
                'id': item['id'],
                'title': item['title'] ?? 'Branch Notice',
                'message': item['message'] ?? '',
                'priority': 'high',
                'target_branch': 'All Branches',
                'is_active': item['is_active'] ?? true,
                'created_at': item['created_at_formatted'] ??
                    item['created_at'] ??
                    'Just now',
              });
            }
          }
        }
      }
      _branchNotices = combinedNotices;

      await _fetchBranchChatMessages(silent: true);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _generateRandomPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789@#';
    final rnd = Random();
    final pass =
        List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
    setState(() {
      _managerPasswordCtrl.text = pass;
      _obscureManagerPassword = false;
    });
  }

  void _resetBranchForm() {
    _editingBranchId = null;
    _nameCtrl.clear();
    _slugCtrl.clear();
    _categoryLabelCtrl.text = 'Regional Branch';
    _phoneCtrl.text = '+880 1700-000000';
    _addressCtrl.clear();
    _descCtrl.clear();
    _managerNameCtrl.clear();
    _managerEmailCtrl.clear();
    _managerPasswordCtrl.clear();
    _branchIsActive = true;
    _generateRandomPassword();
  }

  void _startEditBranch(Map branch) {
    setState(() {
      _editingBranchId = int.tryParse((branch['id'] ?? '').toString());
      _nameCtrl.text = (branch['name'] ?? '').toString();
      _slugCtrl.text = (branch['slug'] ?? '').toString();
      _categoryLabelCtrl.text =
          (branch['category_label'] ?? 'Regional Branch').toString();
      _phoneCtrl.text =
          (branch['contact_phone'] ?? '+880 1700-000000').toString();
      _addressCtrl.text = (branch['address'] ?? '').toString();
      _descCtrl.text = (branch['description'] ?? '').toString();
      _managerNameCtrl.text = (branch['manager_name'] ?? '').toString();
      _managerEmailCtrl.text = (branch['manager_email'] ?? '').toString();
      _managerPasswordCtrl.text =
          (branch['manager_password_display'] ?? '123456').toString();
      _branchIsActive = branch['is_active'] != false;
      _activeTab = 'add';
    });
  }

  Future _saveBranch() async {
    final name = _nameCtrl.text.trim();
    final email = _managerEmailCtrl.text.trim();
    final password = _managerPasswordCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('অনুগ্রহ করে ব্রাঞ্চের নাম লিখুন।', isError: true);
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('বৈধ ম্যানেজার লগইন ইমেইল প্রদান করুন।', isError: true);
      return;
    }
    if (_editingBranchId == null && password.length < 6) {
      _showSnack('ম্যানেজার পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।',
          isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      'name': name,
      'slug': _slugCtrl.text.trim().isNotEmpty
          ? _slugCtrl.text.trim()
          : name.toLowerCase().replaceAll(' ', '-'),
      'category_label': _categoryLabelCtrl.text.trim(),
      'contact_phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'manager_name': _managerNameCtrl.text.trim().isNotEmpty
          ? _managerNameCtrl.text.trim()
          : '$name Manager',
      'manager_email': email,
      if (password.isNotEmpty) 'manager_password': password,
      'is_active': _branchIsActive,
    };

    try {
      http.Response res;
      if (_editingBranchId != null) {
        res = await http.patch(
          Uri.parse(
              '$_apiBase/api/v1/stores/branches/$_editingBranchId/?subdomain=$_subdomain'),
          headers: _headers(jsonContent: true),
          body: jsonEncode(payload),
        );
      } else {
        res = await http.post(
          Uri.parse('$_apiBase/api/v1/stores/branches/?subdomain=$_subdomain'),
          headers: _headers(jsonContent: true),
          body: jsonEncode(payload),
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _showSnack(_editingBranchId != null
            ? 'ব্রাঞ্চ সফলভাবে আপডেট হয়েছে!'
            : 'নতুন ব্রাঞ্চ ও ম্যানেজার পোর্টাল তৈরি হয়েছে!');
        _resetBranchForm();
        setState(() => _activeTab = 'list');
        await _fetchAllBranchData();
        widget.onDataChanged?.call();
      } else {
        String errMsg = 'ব্রাঞ্চ সেভ করতে সমস্যা হয়েছে (${res.statusCode})';
        try {
          final errJson = jsonDecode(utf8.decode(res.bodyBytes));
          if (errJson is Map) {
            errMsg = errJson.values.first.toString();
          }
        } catch (_) {}
        _showSnack(errMsg, isError: true);
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future _toggleBranchActive(Map branch, bool nextVal) async {
    final id = branch['id'];
    setState(() {
      branch['is_active'] = nextVal;
    });

    try {
      final res = await http.patch(
        Uri.parse('$_apiBase/api/v1/stores/branches/$id/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({'is_active': nextVal}),
      );
      if (res.statusCode == 200) {
        _showSnack(nextVal
            ? '${branch['name']} সক্রিয় (Active) করা হয়েছে!'
            : '${branch['name']} নিষ্ক্রিয় (Inactive) করা হয়েছে।');
        widget.onDataChanged?.call();
      } else {
        setState(() => branch['is_active'] = !nextVal);
        _showSnack('স্ট্যাটাস আপডেট ব্যর্থ হয়েছে।', isError: true);
      }
    } catch (_) {
      setState(() => branch['is_active'] = !nextVal);
    }
  }

  Future _deleteBranch(Map branch) async {
    final dynamic confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ব্রাঞ্চ ডিলিট করবেন?'),
        content: Text(
            'আপনি কি নিশ্চিতভাবে "${branch['name']}" ব্রাঞ্চটি ডিলিট করতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ডিলিট করুন'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(
        Uri.parse(
            '$_apiBase/api/v1/stores/branches/${branch['id']}/?subdomain=$_subdomain'),
        headers: _headers(),
      );
      if (res.statusCode == 204 || res.statusCode == 200) {
        _showSnack('"${branch['name']}" ডিলিট করা হয়েছে।');
        await _fetchAllBranchData();
        widget.onDataChanged?.call();
      } else {
        _showSnack('ডিলিট করা যায়নি (${res.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('ত্রুটি: $e', isError: true);
    }
  }

  // =======================================================================
  // 3. EXPORT PRODUCT / STOCK TRANSFER EXECUTION
  // =======================================================================
  Future _submitStockTransfer() async {
    if (_selectedExportBranchId == null) {
      _showSnack('প্রোডাক্ট পাঠানোর জন্য একটি টার্গেট ব্রাঞ্চ সিলেক্ট করুন।',
          isError: true);
      return;
    }

    final List itemsPayload = [];
    _selectedTransferQuantities.forEach((prodId, qty) {
      final int qVal = int.tryParse(qty.toString()) ?? 0;
      if (qVal > 0) {
        itemsPayload.add({
          'product_id': prodId,
          'quantity': qVal,
        });
      }
    });

    if (itemsPayload.isEmpty) {
      _showSnack('অন্তত ১টি প্রোডাক্ট এবং পরিমাণ (Quantity) সিলেক্ট করুন।',
          isError: true);
      return;
    }

    setState(() => _isTransferring = true);

    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/branch-product-transfers/?subdomain=$_subdomain'),
        headers: _headers(jsonContent: true),
        body: jsonEncode({
          'target_branch_id': _selectedExportBranchId,
          'items': itemsPayload,
          'note': _transferNoteCtrl.text.trim(),
        }),
      );

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201 || res.statusCode == 200) {
        final msg = (decoded is Map && decoded['message'] != null)
            ? decoded['message'].toString()
            : 'প্রোডাক্ট সফলভাবে ব্রাঞ্চে ট্রান্সফার হয়েছে!';
        _showSnack(msg);
        setState(() {
          _selectedTransferQuantities.clear();
          _transferNoteCtrl.clear();
        });
        await _fetchAllBranchData();
        widget.onDataChanged?.call();
      } else {
        final err = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'প্রোডাক্ট ট্রান্সফার ব্যর্থ হয়েছে।';
        _showSnack(err, isError: true);
      }
    } catch (e) {
      _showSnack('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  // =======================================================================
  // 4. BRANCH NOTICES & ALERTS
  // =======================================================================
  Future _postBranchNotice() async {
    final title = _noticeTitleCtrl.text.trim();
    final message = _noticeMessageCtrl.text.trim();
    if (title.isEmpty || message.isEmpty) {
      _showSnack('নোটিশের শিরোনাম এবং বিস্তারিত মেসেজ লিখুন।', isError: true);
      return;
    }

    setState(() => _isPostingNotice = true);

    final prefs = await SharedPreferences.getInstance();
    final nowStr =
        '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${TimeOfDay.now().format(context)}';

    final newNotice = {
      'id': 'BN-${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'message': message,
      'priority': _noticePriority,
      'target_branch': _noticeTargetBranch == 'all'
          ? 'All Branches'
          : _noticeTargetBranch,
      'is_active': true,
      'created_at': nowStr,
    };

    try {
      await http
          .post(
            Uri.parse(
                '$_apiBase/api/v1/stores/announcements/?subdomain=$_subdomain'),
            headers: _headers(jsonContent: true),
            body: jsonEncode({
              'title': '[$_noticeTargetBranch] $title',
              'message': message,
              'display_style': 'banner_strip',
              'is_active': true,
              'sync_to_header_bar': false,
            }),
          )
          .catchError((_) => http.Response('{}', 500));

      final localRaw = prefs.getString('branch_notices_$_subdomain') ?? '[]';
      List localList = [];
      try {
        final dec = jsonDecode(localRaw);
        if (dec is List) localList = dec;
      } catch (_) {}

      localList.insert(0, newNotice);
      await prefs.setString(
          'branch_notices_$_subdomain', jsonEncode(localList));

      _noticeTitleCtrl.clear();
      _noticeMessageCtrl.clear();
      _showSnack('ব্রাঞ্চ নোটিশ সফলভাবে প্রকাশ করা হয়েছে!');
      await _fetchAllBranchData(silent: true);
    } finally {
      if (mounted) {
        setState(() => _isPostingNotice = false);
      }
    }
  }

  Future _deleteBranchNotice(dynamic id) async {
    final prefs = await SharedPreferences.getInstance();
    final idStr = id.toString();

    if (!idStr.startsWith('BN-')) {
      await http
          .delete(
            Uri.parse(
                '$_apiBase/api/v1/stores/announcements/$idStr/?subdomain=$_subdomain'),
            headers: _headers(),
          )
          .catchError((_) => http.Response('', 500));
    }

    final localRaw = prefs.getString('branch_notices_$_subdomain') ?? '[]';
    try {
      final dec = jsonDecode(localRaw);
      if (dec is List) {
        dec.removeWhere((e) => e['id'].toString() == idStr);
        await prefs.setString('branch_notices_$_subdomain', jsonEncode(dec));
      }
    } catch (_) {}

    setState(() {
      _branchNotices.removeWhere((e) => e['id'].toString() == idStr);
    });
    _showSnack('নোটিশ ডিলিট করা হয়েছে।');
  }

  // =======================================================================
  // 5. BRANCH CHAT
  // =======================================================================
  Future _fetchBranchChatMessages({bool silent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final branchId = _selectedChatBranchId ?? 0;
    final key = 'branch_chat_${_subdomain}_${branchId}_$_chatChannelMode';

    List loaded = [];
    final cachedRaw = prefs.getString(key);
    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      try {
        final dec = jsonDecode(cachedRaw);
        if (dec is List) loaded = dec;
      } catch (_) {}
    }

    try {
      final res = await http
          .get(
            Uri.parse(
                '$_apiBase/api/v1/chat/messages/?subdomain=$_subdomain&branch_id=$branchId&channel=$_chatChannelMode'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final dec = jsonDecode(utf8.decode(res.bodyBytes));
        List remoteMsgs = [];
        if (dec is List) {
          remoteMsgs = dec;
        } else if (dec is Map && dec['results'] is List) {
          remoteMsgs = dec['results'];
        }
        if (remoteMsgs.isNotEmpty) {
          loaded = remoteMsgs;
          await prefs.setString(key, jsonEncode(loaded));
        }
      }
    } catch (_) {}

    if (loaded.isEmpty && _branches.isNotEmpty) {
      final matchedBranch = _branches.firstWhere(
        (b) => int.tryParse((b['id'] ?? '').toString()) == branchId,
        orElse: () => _branches.first,
      );
      loaded = [
        {
          'id': 'welcome-1',
          'sender': 'branch_manager',
          'sender_name': '${matchedBranch['name']} Manager',
          'text':
              'আসসালামু আলাইকুম! ${matchedBranch['name']} আউটলেট থেকে যুক্ত হয়েছি। স্টক বা অর্ডার সংক্রান্ত কোনো নির্দেশনা থাকলে এখানে জানাতে পারেন।',
          'time': 'Today',
        }
      ];
    }

    if (mounted) {
      setState(() {
        _chatMessages = loaded;
      });
    }
  }

  Future _sendBranchChatMessage([String? presetText]) async {
    final text = (presetText ?? _chatInputCtrl.text).trim();
    if (text.isEmpty) return;

    if (presetText == null) {
      _chatInputCtrl.clear();
    }

    setState(() => _isSendingChat = true);

    final prefs = await SharedPreferences.getInstance();
    final branchId = _selectedChatBranchId ?? 0;
    final key = 'branch_chat_${_subdomain}_${branchId}_$_chatChannelMode';

    final msgObj = {
      'id': 'msg-${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'merchant_owner',
      'sender_name': 'Main Store Admin',
      'text': text,
      'time': TimeOfDay.now().format(context),
    };

    setState(() {
      _chatMessages.add(msgObj);
    });

    await prefs.setString(key, jsonEncode(_chatMessages));

    try {
      await http
          .post(
            Uri.parse('$_apiBase/api/v1/chat/messages/?subdomain=$_subdomain'),
            headers: _headers(jsonContent: true),
            body: jsonEncode({
              'branch_id': branchId,
              'channel_type': _chatChannelMode,
              'content': text,
              'message': text,
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (mounted) {
      setState(() => _isSendingChat = false);
    }
  }

  // =======================================================================
  // 6. BRANCH AUDIT HISTORY MODAL
  // =======================================================================
  Future _openBranchAuditModal(Map branch, CatalogThemeConfig t) async {
    final branchId = branch['id'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder(
          future: http
              .get(
                Uri.parse(
                    '$_apiBase/api/v1/stores/branches/$branchId/audit-history/?subdomain=$_subdomain'),
                headers: _headers(),
              )
              .catchError((_) => http.Response('{}', 500)),
          builder: (context, snapshot) {
            Map auditData = {};
            bool loading = snapshot.connectionState == ConnectionState.waiting;
            if (snapshot.hasData) {
              final resp = snapshot.data as http.Response;
              if (resp.statusCode == 200) {
                try {
                  final dec = jsonDecode(utf8.decode(resp.bodyBytes));
                  if (dec is Map) auditData = dec;
                } catch (_) {}
              }
            }

            final overview = (auditData['overview'] is Map)
                ? auditData['overview'] as Map
                : {};
            final invLogs = (auditData['inventory_history'] is List)
                ? auditData['inventory_history'] as List
                : [];
            final ordLogs = (auditData['order_history'] is List)
                ? auditData['order_history'] as List
                : [];
            final catLogs = (auditData['category_history'] is List)
                ? auditData['category_history'] as List
                : [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.86,
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                    decoration: BoxDecoration(
                      gradient: t.useGradient ? t.brandGradient : null,
                      color: t.useGradient ? null : t.primaryColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.analytics_rounded,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${branch['name']} — Audit & History',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Manager: ${branch['manager_email'] ?? 'N/A'} | /b/${branch['slug'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildMiniStatTile(
                                  t,
                                  'Total Products',
                                  '${overview['total_products'] ?? branch['total_products'] ?? 0}',
                                  Icons.inventory_2_rounded,
                                  const Color(0xFF059669),
                                ),
                                _buildMiniStatTile(
                                  t,
                                  'Stock Value',
                                  '৳${overview['total_stock_value'] ?? 0}',
                                  Icons.account_balance_wallet_rounded,
                                  const Color(0xFF2563EB),
                                ),
                                _buildMiniStatTile(
                                  t,
                                  'Branch Orders',
                                  '${overview['total_orders'] ?? 0}',
                                  Icons.shopping_bag_rounded,
                                  const Color(0xFF7C3AED),
                                ),
                                _buildMiniStatTile(
                                  t,
                                  'Branch Revenue',
                                  '৳${overview['total_revenue'] ?? 0}',
                                  Icons.payments_rounded,
                                  const Color(0xFFD97706),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Branch Inventory Stock (${invLogs.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: t.primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (invLogs.isEmpty)
                              _buildEmptyHint(
                                  t, 'এই ব্রাঞ্চে এখনো কোনো প্রোডাক্ট স্টক নেই।')
                            else
                              ...invLogs.take(15).map((item) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: t.inputBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: t.cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (item['product_name'] ??
                                                        'Product')
                                                    .toString(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: t.primaryText,
                                                ),
                                              ),
                                              Text(
                                                'SKU: ${item['sku'] ?? 'N/A'}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: t.secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (int.tryParse(
                                                            (item['stock_quantity'] ??
                                                                    0)
                                                                .toString()) ??
                                                        0) >
                                                    0
                                                ? const Color(0xFF059669)
                                                    .withOpacity(0.14)
                                                : const Color(0xFFDC2626)
                                                    .withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${item['stock_quantity'] ?? 0} ${item['unit'] ?? 'pc'}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: (int.tryParse(
                                                              (item['stock_quantity'] ??
                                                                      0)
                                                                  .toString()) ??
                                                          0) >
                                                      0
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            const SizedBox(height: 16),
                            Text(
                              'Recent Branch Orders (${ordLogs.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: t.primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (ordLogs.isEmpty)
                              _buildEmptyHint(
                                  t, 'এই ব্রাঞ্চে এখনো কোনো অর্ডার আসেনি।')
                            else
                              ...ordLogs.take(10).map((ord) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: t.inputBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: t.cardBorder),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '#${ord['order_number'] ?? ord['id']} • ${ord['customer_name'] ?? 'Customer'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12.5,
                                                color: t.primaryText,
                                              ),
                                            ),
                                            Text(
                                              'Phone: ${ord['customer_phone'] ?? 'N/A'} | Status: ${(ord['status'] ?? 'pending').toString().toUpperCase()}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: t.secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '৳${ord['total'] ?? 0}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13.5,
                                            color: t.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            if (catLogs.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Branch Categories (${catLogs.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: catLogs
                                    .map((c) => Chip(
                                          backgroundColor: t.inputBg,
                                          label: Text(
                                            '${c['icon'] ?? '📦'} ${c['name']} (${c['products_count'] ?? 0})',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: t.primaryText,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =======================================================================
  // 7. BRANCH THEME CONFIG MODAL
  // =======================================================================
  Future _openBranchThemeModal(Map branch, CatalogThemeConfig t) async {
    final branchId = branch['id'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder(
          future: http
              .get(
                Uri.parse(
                    '$_apiBase/api/v1/stores/branches/$branchId/themes/?subdomain=$_subdomain'),
                headers: _headers(),
              )
              .catchError((_) => http.Response('[]', 500)),
          builder: (context, snapshot) {
            List themes = [];
            bool loading = snapshot.connectionState == ConnectionState.waiting;
            if (snapshot.hasData) {
              final resp = snapshot.data as http.Response;
              if (resp.statusCode == 200) {
                try {
                  final dec = jsonDecode(utf8.decode(resp.bodyBytes));
                  if (dec is List) themes = dec;
                } catch (_) {}
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                    decoration: BoxDecoration(
                      gradient: t.useGradient ? t.brandGradient : null,
                      color: t.useGradient ? null : t.primaryColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.palette_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${branch['name']} — Branch Storefront Theme',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (themes.isEmpty)
                    Expanded(
                      child: Center(
                        child: _buildEmptyHint(
                            t, 'কোনো থিম টেমপ্লেট পাওয়া যায়নি।'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: themes.length,
                        itemBuilder: (context, index) {
                          final th = themes[index] as Map;
                          final bool isActive = th['is_active'] == true;
                          final bool isFree = th['is_free'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: t.inputBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isActive ? t.primaryColor : t.cardBorder,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: t.primaryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.storefront_rounded,
                                    color: t.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (th['name'] ?? 'Theme').toString(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: t.primaryText,
                                        ),
                                      ),
                                      Text(
                                        isFree
                                            ? 'FREE THEME'
                                            : 'Premium • ৳${th['price'] ?? 0}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isFree
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFD97706),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isActive
                                        ? const Color(0xFF059669)
                                        : t.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: isActive
                                      ? null
                                      : () async {
                                          final res = await http.post(
                                            Uri.parse(
                                                '$_apiBase/api/v1/stores/branches/$branchId/set-theme/?subdomain=$_subdomain'),
                                            headers:
                                                _headers(jsonContent: true),
                                            body: jsonEncode(
                                                {'theme_id': th['id']}),
                                          );
                                          if (res.statusCode == 200) {
                                            Navigator.pop(ctx);
                                            _showSnack(
                                                '"${th['name']}" থিমটি ব্রাঞ্চে অ্যাক্টিভ হয়েছে!');
                                            _fetchAllBranchData(silent: true);
                                          } else {
                                            _showSnack(
                                                'থিম অ্যাক্টিভ করতে সমস্যা হয়েছে।',
                                                isError: true);
                                          }
                                        },
                                  child: Text(isActive ? 'Active' : 'Activate'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =======================================================================
  // MAIN BUILD
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    final t = _theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopHeroHeader(t),
        const SizedBox(height: 14),
        _buildNavigationTabs(t),
        const SizedBox(height: 16),
        if (_isLoading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: t.primaryColor),
          )
        else ...[
          if (_activeTab == 'list') _buildBranchListTab(t),
          if (_activeTab == 'add') _buildAddEditBranchTab(t),
          if (_activeTab == 'export') _buildExportProductTab(t),
          if (_activeTab == 'notice') _buildBranchNoticesTab(t),
          if (_activeTab == 'chat') _buildBranchChatTab(t),
        ],
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildTopHeroHeader(CatalogThemeConfig t) {
    final int activeCount =
        _branches.where((b) => b is Map && b['is_active'] != false).length;
    final int totalBranchProducts = _branches.fold<int>(
      0,
      (sum, b) =>
          sum +
          (int.tryParse(
                  (b['total_products'] ?? b['products_count'] ?? 0).toString()) ??
              0),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: t.useGradient ? t.brandGradient : null,
        color: t.useGradient ? null : t.primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: t.primaryColor.withOpacity(0.26),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'External Branch Stores & Manager Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Plan: $_planName • Quota: ${_branches.length}/$_maxBranchesQuota Branches',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _fetchAllBranchData(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh Branches',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildHeaderBadge(Icons.store_mall_directory_rounded,
                  'Total Branches: ${_branches.length}'),
              _buildHeaderBadge(
                  Icons.check_circle_rounded, 'Active: $activeCount'),
              _buildHeaderBadge(Icons.inventory_2_rounded,
                  'Branch Products: $totalBranchProducts'),
              _buildHeaderBadge(Icons.local_shipping_rounded,
                  'Sent Stock: ${_transferSummary['total_pieces_sent'] ?? 0} pcs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs(CatalogThemeConfig t) {
    final List tabs = [
      {
        'id': 'list',
        'label': 'Branch List (${_branches.length})',
        'icon': Icons.storefront_rounded,
      },
      {
        'id': 'add',
        'label': _editingBranchId != null ? 'Edit Branch' : '+ Add Branch',
        'icon': Icons.add_business_rounded,
      },
      {
        'id': 'export',
        'label': 'Export Product',
        'icon': Icons.swap_horiz_rounded,
      },
      {
        'id': 'notice',
        'label': 'Branch Notice',
        'icon': Icons.campaign_rounded,
      },
      {
        'id': 'chat',
        'label': 'Branch Chat',
        'icon': Icons.forum_rounded,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final String id = tab['id'].toString();
          final bool selected = _activeTab == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (id == 'add' && _activeTab != 'add') {
                    _resetBranchForm();
                  }
                  _activeTab = id;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: (selected && t.useGradient) ? t.brandGradient : null,
                  color: selected
                      ? (t.useGradient ? null : t.primaryColor)
                      : t.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.transparent : t.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: selected ? Colors.white : t.secondaryText,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tab['label'].toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : t.primaryText,
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

  // =======================================================================
  // TAB 1: BRANCH LIST
  // =======================================================================
  Widget _buildBranchListTab(CatalogThemeConfig t) {
    final filtered = _branches.where((raw) {
      if (raw is! Map) return false;
      final isActive = raw['is_active'] != false;
      if (_branchStatusFilter == 'active' && !isActive) return false;
      if (_branchStatusFilter == 'inactive' && isActive) return false;

      if (_branchSearchQuery.trim().isNotEmpty) {
        final q = _branchSearchQuery.toLowerCase().trim();
        final name = (raw['name'] ?? '').toString().toLowerCase();
        final slug = (raw['slug'] ?? '').toString().toLowerCase();
        final email = (raw['manager_email'] ?? '').toString().toLowerCase();
        final addr = (raw['address'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            slug.contains(q) ||
            email.contains(q) ||
            addr.contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _branchSearchQuery = v),
                style: TextStyle(color: t.primaryText, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText:
                      'Search branch by name, slug, manager email or address...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12.5),
                  prefixIcon: Icon(Icons.search_rounded, color: t.primaryColor),
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                children: [
                  _buildFilterChip(t, 'All (${_branches.length})', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip(t, 'Active', 'active'),
                  const SizedBox(width: 8),
                  _buildFilterChip(t, 'Inactive', 'inactive'),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      _resetBranchForm();
                      setState(() => _activeTab = 'add');
                    },
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text(
                      'New Branch',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          _buildEmptyStateCard(
            t,
            icon: Icons.store_mall_directory_outlined,
            title: 'কোনো ব্রাঞ্চ স্টোর পাওয়া যায়নি',
            subtitle:
                'আপনার আউটলেট বা রিজিওনাল ব্রাঞ্চ তৈরি করতে "+ Add Branch" বাটনে ক্লিক করুন।',
            buttonLabel: '+ Create First Branch',
            onTap: () {
              _resetBranchForm();
              setState(() => _activeTab = 'add');
            },
          )
        else
          ...filtered.map((b) => _buildBranchCard(b as Map, t)),
      ],
    );
  }

  Widget _buildFilterChip(CatalogThemeConfig t, String label, String key) {
    final bool selected = _branchStatusFilter == key;
    return InkWell(
      onTap: () => setState(() => _branchStatusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.primaryColor.withOpacity(0.15) : t.inputBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? t.primaryColor : t.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? t.primaryColor : t.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildBranchCard(Map branch, CatalogThemeConfig t) {
    final int branchId = int.tryParse((branch['id'] ?? 0).toString()) ?? 0;
    final String name = (branch['name'] ?? 'Branch Outlet').toString();
    final String slug = (branch['slug'] ?? '').toString();
    final String categoryLabel =
        (branch['category_label'] ?? 'Regional Branch').toString();
    final String phone = (branch['contact_phone'] ?? 'N/A').toString();
    final String address =
        (branch['address'] ?? 'Dhaka, Bangladesh').toString();
    final String managerEmail =
        (branch['manager_email'] ?? 'Not assigned').toString();
    final String managerPassword =
        (branch['manager_password_display'] ?? '••••••').toString();
    final int productsCount = int.tryParse(
            (branch['total_products'] ?? branch['products_count'] ?? 0)
                .toString()) ??
        0;
    final bool isActive = branch['is_active'] != false;
    final bool showPass = _visiblePasswordBranchIds.contains(branchId);

    String activeThemeName = 'Modern Clean (Default)';
    if (branch['theme_config'] is Map) {
      final tc = branch['theme_config'] as Map;
      if (tc['active_theme_details'] is Map) {
        activeThemeName =
            (tc['active_theme_details']['name'] ?? activeThemeName).toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDarkMode ? 0.22 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: t.useGradient ? t.brandGradient : null,
                  color: t.useGradient ? null : t.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'B',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            categoryLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'URL: /b/$slug  •  Theme: $activeThemeName',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: t.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeColor: t.primaryColor,
                onChanged: (val) => _toggleBranchActive(branch, val),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_rounded, size: 14, color: t.secondaryText),
                  const SizedBox(width: 5),
                  Text(
                    phone,
                    style: TextStyle(fontSize: 12, color: t.primaryText),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 14, color: t.secondaryText),
                  const SizedBox(width: 5),
                  Text(
                    address.isEmpty ? 'No address set' : address,
                    style: TextStyle(fontSize: 12, color: t.primaryText),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_rounded,
                      size: 14, color: t.primaryColor),
                  const SizedBox(width: 5),
                  Text(
                    '$productsCount Products in Branch',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: t.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Manager Login Credentials Box
          Container(
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
                    Icon(Icons.admin_panel_settings_rounded,
                        size: 16, color: t.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Branch Manager Portal Credentials',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                          text:
                              'Branch: $name\nPortal: /b/$slug?view=portal\nEmail: $managerEmail\nPassword: $managerPassword',
                        ));
                        _showSnack(
                            'ম্যানেজার লগইন তথ্য ক্লিপবোর্ডে কপি করা হয়েছে!');
                      },
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 13, color: t.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Copy Login',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Email: $managerEmail',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.primaryText,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pass: ${showPass ? managerPassword : '••••••••'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.primaryText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (showPass) {
                                _visiblePasswordBranchIds.remove(branchId);
                              } else {
                                _visiblePasswordBranchIds.add(branchId);
                              }
                            });
                          },
                          child: Icon(
                            showPass
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 16,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action Buttons Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCardActionBtn(
                t,
                icon: Icons.analytics_outlined,
                label: 'Audit & History',
                color: const Color(0xFF2563EB),
                onTap: () => _openBranchAuditModal(branch, t),
              ),
              _buildCardActionBtn(
                t,
                icon: Icons.palette_outlined,
                label: 'Theme Setup',
                color: const Color(0xFF7C3AED),
                onTap: () => _openBranchThemeModal(branch, t),
              ),
              _buildCardActionBtn(
                t,
                icon: Icons.swap_horiz_rounded,
                label: 'Export Stock',
                color: const Color(0xFF059669),
                onTap: () {
                  setState(() {
                    _selectedExportBranchId = branchId;
                    _activeTab = 'export';
                  });
                },
              ),
              _buildCardActionBtn(
                t,
                icon: Icons.forum_outlined,
                label: 'Chat',
                color: const Color(0xFFD97706),
                onTap: () {
                  setState(() {
                    _selectedChatBranchId = branchId;
                    _activeTab = 'chat';
                  });
                  _fetchBranchChatMessages();
                },
              ),
              _buildCardActionBtn(
                t,
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: t.primaryColor,
                onTap: () => _startEditBranch(branch),
              ),
              _buildCardActionBtn(
                t,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: const Color(0xFFDC2626),
                onTap: () => _deleteBranch(branch),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardActionBtn(
    CatalogThemeConfig t, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.11),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.5, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // TAB 2: ADD / EDIT BRANCH
  // =======================================================================
  Widget _buildAddEditBranchTab(CatalogThemeConfig t) {
    final List presetLabels = [
      'Regional Branch',
      'Flagship Outlet',
      'City Center',
      'Express Counter',
      'Warehouse Hub',
    ];

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
              Icon(
                _editingBranchId != null
                    ? Icons.edit_location_alt_rounded
                    : Icons.add_business_rounded,
                color: t.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _editingBranchId != null
                      ? 'Edit Branch Store & Manager Credentials'
                      : 'Create New External Branch Store',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ),
              if (_editingBranchId != null)
                TextButton(
                  onPressed: () {
                    _resetBranchForm();
                    setState(() => _activeTab = 'list');
                  },
                  child: const Text('Cancel Edit'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'প্রতিটি ব্রাঞ্চের জন্য আলাদা স্টোরফ্রন্ট লিংক (/b/slug) এবং ব্রাঞ্চ ম্যানেজার লগইন পোর্টাল তৈরি হবে।',
            style: TextStyle(fontSize: 12, color: t.secondaryText),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            t,
            label: 'Branch Name *',
            hint: 'e.g., Dhanmondi Flagship Outlet',
            controller: _nameCtrl,
            icon: Icons.storefront_rounded,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            t,
            label: 'Branch URL Slug (/b/slug)',
            hint: 'dhanmondi-flagship-outlet',
            controller: _slugCtrl,
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            'Branch Type / Category Label',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: t.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presetLabels.map((lbl) {
              final isSelected = _categoryLabelCtrl.text.trim() == lbl;
              return InkWell(
                onTap: () =>
                    setState(() => _categoryLabelCtrl.text = lbl.toString()),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? t.primaryColor : t.inputBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? t.primaryColor : t.cardBorder,
                    ),
                  ),
                  child: Text(
                    lbl.toString(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : t.primaryText,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildInputField(
            t,
            label: 'Contact Phone',
            hint: '+880 1700-000000',
            controller: _phoneCtrl,
            icon: Icons.phone_rounded,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            t,
            label: 'Full Branch Address',
            hint: 'House 12, Road 5, Dhanmondi, Dhaka',
            controller: _addressCtrl,
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            t,
            label: 'Short Description (Optional)',
            hint: 'Branch timings & special services...',
            controller: _descCtrl,
            icon: Icons.notes_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security_rounded,
                        color: t.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Branch Manager Portal Login Setup',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  t,
                  label: 'Manager Full Name',
                  hint: 'e.g., Tanvir Ahmed',
                  controller: _managerNameCtrl,
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  t,
                  label: 'Manager Login Email *',
                  hint: 'dhanmondi.manager@buynarabd.com',
                  controller: _managerEmailCtrl,
                  icon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _buildInputField(
                        t,
                        label: 'Manager Login Password * (Min 6 chars)',
                        hint: 'Enter or generate password',
                        controller: _managerPasswordCtrl,
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureManagerPassword,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _generateRandomPassword,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                      label: const Text(
                        'Auto Gen',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Branch Active & Publicly Visible',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: t.primaryText,
              ),
            ),
            subtitle: Text(
              'Active থাকলে কাস্টমাররা এই ব্রাঞ্চে ভিজিট ও অর্ডার করতে পারবে।',
              style: TextStyle(fontSize: 11.5, color: t.secondaryText),
            ),
            value: _branchIsActive,
            activeColor: t.primaryColor,
            onChanged: (v) => setState(() => _branchIsActive = v),
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSaving ? null : _saveBranch,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _editingBranchId != null
                    ? 'Update Branch Store'
                    : 'Create Branch & Manager Portal',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // TAB 3: EXPORT PRODUCT / STOCK TRANSFER TO BRANCH
  // =======================================================================
  Widget _buildExportProductTab(CatalogThemeConfig t) {
    final filteredProducts = _mainStoreProducts.where((p) {
      if (p is! Map) return false;
      if (_exportProductSearch.trim().isEmpty) return true;
      final q = _exportProductSearch.toLowerCase().trim();
      final name = (p['name'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();

    final filteredHistory = _transferHistory.where((h) {
      if (h is! Map) return false;
      if (_historyFilterBranchId == null) return true;
      final bId = int.tryParse((h['target_branch'] ?? '').toString());
      return bId == _historyFilterBranchId;
    }).toList();

    int selectedItemsCount = 0;
    int totalSelectedPcs = 0;
    _selectedTransferQuantities.forEach((_, v) {
      final q = int.tryParse(v.toString()) ?? 0;
      if (q > 0) {
        selectedItemsCount++;
        totalSelectedPcs += q;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildMiniStatTile(
              t,
              'Total Transfers',
              '${_transferSummary['total_transfers'] ?? _transferHistory.length}',
              Icons.swap_horizontal_circle_rounded,
              const Color(0xFF059669),
            ),
            _buildMiniStatTile(
              t,
              'Pieces Transferred',
              '${_transferSummary['total_pieces_sent'] ?? 0} pcs',
              Icons.inventory_rounded,
              const Color(0xFF2563EB),
            ),
            _buildMiniStatTile(
              t,
              'Transferred Value',
              '৳${_transferSummary['total_stock_value'] ?? 0}',
              Icons.payments_rounded,
              const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Stock Transfer Builder Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Select Target Branch & Products to Export',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'মেইন স্টোরের স্টক থেকে নির্দিষ্ট ব্রাঞ্চে প্রোডাক্ট পাঠালে মেইন স্টক অটোমেটিক কমবে এবং ব্রাঞ্চ স্টকে যোগ হবে।',
                style: TextStyle(fontSize: 11.5, color: t.secondaryText),
              ),
              const SizedBox(height: 12),
              if (_branches.isEmpty)
                _buildEmptyHint(
                    t, 'প্রোডাক্ট ট্রান্সফার করার আগে অন্তত ১টি ব্রাঞ্চ তৈরি করুন।')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _branches.map((b) {
                    final int bId =
                        int.tryParse((b['id'] ?? 0).toString()) ?? 0;
                    final bool isSelected = _selectedExportBranchId == bId;
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedExportBranchId = bId),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: (isSelected && t.useGradient)
                              ? t.brandGradient
                              : null,
                          color: isSelected
                              ? (t.useGradient ? null : t.primaryColor)
                              : t.inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : t.cardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 15,
                              color: isSelected ? Colors.white : t.primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${b['name']} (${b['total_products'] ?? b['products_count'] ?? 0})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color:
                                    isSelected ? Colors.white : t.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (v) => setState(() => _exportProductSearch = v),
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search Main Store product by name or SKU...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, color: t.primaryColor),
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (filteredProducts.isEmpty)
                _buildEmptyHint(t, 'মেইন স্টোরে কোনো প্রোডাক্ট পাওয়া যায়নি।')
              else
                ...filteredProducts.take(25).map((prod) {
                  final int pId =
                      int.tryParse((prod['id'] ?? 0).toString()) ?? 0;
                  final int availStock =
                      int.tryParse((prod['stock_quantity'] ?? 0).toString()) ??
                          0;
                  final int chosenQty = int.tryParse(
                          (_selectedTransferQuantities[pId] ?? 0).toString()) ??
                      0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: chosenQty > 0
                          ? t.primaryColor.withOpacity(0.08)
                          : t.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: chosenQty > 0 ? t.primaryColor : t.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (prod['name'] ?? 'Product').toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: t.primaryText,
                                ),
                              ),
                              Text(
                                'SKU: ${prod['sku'] ?? 'N/A'} • Price: ৳${prod['price'] ?? 0} • Main Stock: $availStock',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: availStock > 0
                                      ? t.secondaryText
                                      : const Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: chosenQty <= 0
                                  ? null
                                  : () {
                                      setState(() {
                                        if (chosenQty - 1 <= 0) {
                                          _selectedTransferQuantities
                                              .remove(pId);
                                        } else {
                                          _selectedTransferQuantities[pId] =
                                              chosenQty - 1;
                                        }
                                      });
                                    },
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20),
                            ),
                            Text(
                              '$chosenQty',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            IconButton(
                              onPressed: chosenQty >= availStock
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedTransferQuantities[pId] =
                                            chosenQty + 1;
                                      });
                                    },
                              icon: Icon(Icons.add_circle_outline,
                                  size: 20, color: t.primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              _buildInputField(
                t,
                label: 'Transfer Reference / Note (Optional)',
                hint: 'e.g., Weekly restock for Eid campaign',
                controller: _transferNoteCtrl,
                icon: Icons.sticky_note_2_outlined,
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isTransferring ? null : _submitStockTransfer,
                  icon: _isTransferring
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    selectedItemsCount > 0
                        ? 'Transfer $selectedItemsCount Products ($totalSelectedPcs pcs) to Branch'
                        : 'Select Products Above to Transfer Stock',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Stock Transfer History List
        Container(
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.history_rounded, color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stock Transfer Audit History (${filteredHistory.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filteredHistory.isEmpty)
                _buildEmptyHint(
                    t, 'এখনো কোনো ব্রাঞ্চে প্রোডাক্ট ট্রান্সফার করা হয়নি।')
              else
                ...filteredHistory.take(30).map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                              Expanded(
                                child: Text(
                                  '${item['product_name'] ?? 'Product'} (${item['transfer_quantity'] ?? 0} pcs)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    color: t.primaryText,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: t.primaryColor.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '→ ${item['branch_name'] ?? 'Branch'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: t.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Main Stock: ${item['source_stock_before']} → ${item['source_stock_after']}  |  Branch Stock: ${item['branch_stock_before']} → ${item['branch_stock_after']}  |  Value: ৳${item['total_value'] ?? 0}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date: ${item['created_at_formatted'] ?? item['created_at'] ?? ''} • By: ${item['transferred_by'] ?? 'Admin'}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  // =======================================================================
  // TAB 4: BRANCH NOTICES & ALERTS
  // =======================================================================
  Widget _buildBranchNoticesTab(CatalogThemeConfig t) {
    final List priorities = [
      {'id': 'normal', 'label': 'Normal Info'},
      {'id': 'high', 'label': 'High Priority'},
      {'id': 'critical', 'label': 'Urgent Alert'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Publish Official Branch Notice / Alert',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'সকল ব্রাঞ্চ ম্যানেজার অথবা নির্দিষ্ট কোনো ব্রাঞ্চের পোর্টালে জরুরি নির্দেশনা ও নোটিশ পাঠান।',
                style: TextStyle(fontSize: 11.5, color: t.secondaryText),
              ),
              const SizedBox(height: 12),
              _buildInputField(
                t,
                label: 'Notice Title *',
                hint: 'e.g., ঈদ ক্যাম্পেইন স্টক অডিট ও ডেলিভারি নির্দেশনা',
                controller: _noticeTitleCtrl,
                icon: Icons.campaign_rounded,
              ),
              const SizedBox(height: 12),
              _buildInputField(
                t,
                label: 'Detailed Notice Message *',
                hint: 'আপনার নির্দেশনা বিস্তারিত লিখুন...',
                controller: _noticeMessageCtrl,
                icon: Icons.message_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Text(
                'Target Branch & Priority',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: () => setState(() => _noticeTargetBranch = 'all'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: _noticeTargetBranch == 'all'
                            ? t.primaryColor
                            : t.inputBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'All Branches',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _noticeTargetBranch == 'all'
                              ? Colors.white
                              : t.primaryText,
                        ),
                      ),
                    ),
                  ),
                  ..._branches.map((b) {
                    final bName = (b['name'] ?? 'Branch').toString();
                    final selected = _noticeTargetBranch == bName;
                    return InkWell(
                      onTap: () => setState(() => _noticeTargetBranch = bName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? t.primaryColor : t.inputBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          bName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : t.primaryText,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: priorities.map((p) {
                  final pid = p['id'].toString();
                  final selected = _noticePriority == pid;
                  return InkWell(
                    onTap: () => setState(() => _noticePriority = pid),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            selected ? const Color(0xFFD97706) : t.inputBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p['label'].toString(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : t.primaryText,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                  onPressed: _isPostingNotice ? null : _postBranchNotice,
                  icon: const Icon(Icons.send_rounded, size: 17),
                  label: const Text(
                    'Publish Branch Notice',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_branchNotices.isEmpty)
          _buildEmptyHint(t, 'এখনো কোনো ব্রাঞ্চ নোটিশ প্রকাশ করা হয়নি।')
        else
          ..._branchNotices.map((n) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: t.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.campaign_rounded,
                          color: t.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (n['title'] ?? 'Branch Notice').toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              color: t.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (n['message'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: t.primaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Target: ${n['target_branch'] ?? 'All Branches'} • ${n['created_at'] ?? ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteBranchNotice(n['id']),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFDC2626), size: 19),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  // =======================================================================
  // TAB 5: BRANCH LIVE CHAT
  // =======================================================================
  Widget _buildBranchChatTab(CatalogThemeConfig t) {
    final List quickPrompts = [
      'আজকের স্টক রিপোর্ট পাঠান',
      'পেন্ডিং অর্ডারগুলো দ্রুত ডিসপ্যাচ করুন',
      'নতুন প্রোডাক্ট ট্রান্সফার পাঠানো হয়েছে, রিসিভ করুন',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.forum_rounded, color: t.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Real-Time Branch Communication Hub',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '● LIVE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _chatChannelMode = 'branch_merchant');
                    _fetchBranchChatMessages();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _chatChannelMode == 'branch_merchant'
                          ? t.primaryColor
                          : t.inputBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Branch Manager Chat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _chatChannelMode == 'branch_merchant'
                            ? Colors.white
                            : t.primaryText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _chatChannelMode = 'branch_customer');
                    _fetchBranchChatMessages();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _chatChannelMode == 'branch_customer'
                          ? t.primaryColor
                          : t.inputBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Branch Customer Support',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _chatChannelMode == 'branch_customer'
                            ? Colors.white
                            : t.primaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_branches.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _branches.map((b) {
                  final int bId =
                      int.tryParse((b['id'] ?? 0).toString()) ?? 0;
                  final bool isSel = _selectedChatBranchId == bId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text((b['name'] ?? 'Branch').toString()),
                      selected: isSel,
                      selectedColor: t.primaryColor,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : t.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedChatBranchId = bId);
                        _fetchBranchChatMessages();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            height: 290,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.cardBorder),
            ),
            child: ListView.builder(
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final m = _chatMessages[index] as Map;
                final bool isMe = m['sender'] == 'merchant_owner' ||
                    m['is_merchant'] == true;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 9),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isMe ? t.primaryColor : t.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: isMe ? null : Border.all(color: t.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (m['sender_name'] ??
                                  (isMe ? 'Main Admin' : 'Branch Manager'))
                              .toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isMe ? Colors.white70 : t.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (m['text'] ?? m['content'] ?? m['message'] ?? '')
                              .toString(),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isMe ? Colors.white : t.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickPrompts
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          backgroundColor: t.inputBg,
                          label: Text(
                            p.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: t.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () =>
                              _sendBranchChatMessage(p.toString()),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputCtrl,
                  onSubmitted: (_) => _sendBranchChatMessage(),
                  style: TextStyle(color: t.primaryText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Write message to branch manager...',
                    hintStyle:
                        TextStyle(color: t.secondaryText, fontSize: 12),
                    filled: true,
                    fillColor: t.inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    _isSendingChat ? null : () => _sendBranchChatMessage(),
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // SHARED UI HELPERS
  // =======================================================================
  Widget _buildInputField(
    CatalogThemeConfig t, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: t.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          obscureText: obscureText,
          style: TextStyle(color: t.primaryText, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.secondaryText, fontSize: 12.5),
            prefixIcon: Icon(icon, color: t.primaryColor, size: 19),
            filled: true,
            fillColor: t.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
      ],
    );
  }

  Widget _buildMiniStatTile(
    CatalogThemeConfig t,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: t.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(CatalogThemeConfig t, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.cardBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          color: t.secondaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(
    CatalogThemeConfig t, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 46, color: t.primaryColor),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: t.secondaryText),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onTap,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}