import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class LiveChatChannelsView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final VoidCallback? onDataChanged;

  const LiveChatChannelsView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'chat_customer',
    this.onDataChanged,
  });

  @override
  State<LiveChatChannelsView> createState() => _LiveChatChannelsViewState();
}

class _LiveChatChannelsViewState extends State<LiveChatChannelsView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  late String _activeChannel;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;
  Timer? _callTimer;

  // Shared Search & Input
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _messageInputCtrl = TextEditingController();

  // Channel 1, 2, 3: Customer, Merchant-Branch & Branch-Customer Threads
  List _customerThreads = [];
  List _branchMerchantThreads = [];
  List _branchCustomerThreads = [];
  String _selectedThreadId = '';

  // Channel 4: SuperAdmin HQ Direct Chat (/api/v1/superadmin/chat/rooms/...)
  int? _superAdminTenantId;
  String _resolvedStoreName = 'Store';
  List _superAdminMessages = [];

  // SuperAdmin Voice Call State
  bool _isCallActive = false;
  int _callSeconds = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  // SuperAdmin Meeting Scheduler State
  final TextEditingController _meetTitleCtrl = TextEditingController();
  final TextEditingController _meetAgendaCtrl = TextEditingController(
    text: 'Subscription, technical support & store scaling discussion',
  );
  final TextEditingController _meetDateTimeCtrl = TextEditingController(
    text: 'Tomorrow at 4:00 PM',
  );
  final TextEditingController _meetLinkCtrl = TextEditingController();
  Map? _activeVideoConference;

  static const List _quickReplies = [
    'আসসালামু আলাইকুম! কীভাবে সাহায্য করতে পারি?',
    'আপনার অর্ডারটি কনফার্ম করা হয়েছে এবং আজই কুরিয়ারে পাঠানো হবে।',
    'প্রোডাক্টটি স্টকে আছে, আপনি অর্ডার করতে পারেন।',
    'আমাদের ডেলিভারি চার্জ ঢাকার ভেতরে ৬০ টাকা এবং ঢাকার বাইরে ১২০ টাকা।',
  ];

  @override
  void initState() {
    super.initState();
    _activeChannel = _normalizeChannel(widget.initialTab);
    _initChatModule();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        if (_activeChannel == 'chat_superadmin') {
          _fetchSuperAdminRoomAndMessages(silent: true);
        } else {
          _syncStoreChatThreads(silent: true);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant LiveChatChannelsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _activeChannel = _normalizeChannel(widget.initialTab);
        _selectedThreadId = '';
        _ensureSelectedThread();
      });
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _callTimer?.cancel();
    _searchCtrl.dispose();
    _messageInputCtrl.dispose();
    _meetTitleCtrl.dispose();
    _meetAgendaCtrl.dispose();
    _meetDateTimeCtrl.dispose();
    _meetLinkCtrl.dispose();
    super.dispose();
  }

  String _normalizeChannel(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('superadmin') || lower.contains('hq')) {
      return 'chat_superadmin';
    }
    if (lower == 'chat_branch_merchant' || lower == 'branch_chat') {
      return 'chat_branch_merchant';
    }
    if (lower == 'chat_branch_customer') {
      return 'chat_branch_customer';
    }
    return 'chat_customer';
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

  Future _initChatModule() async {
    setState(() => _isLoading = true);
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() {
        _theme = loaded;
        _resolvedStoreName = loaded.subdomain.toUpperCase();
        _meetTitleCtrl.text = 'Store Consultation — ${loaded.subdomain}';
      });
    }

    await _loadLocalChatState();
    await Future.wait([
      _syncStoreChatThreads(silent: true),
      _fetchSuperAdminRoomAndMessages(silent: true),
    ]);
    _ensureSelectedThread();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future _loadLocalChatState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _theme.subdomain;

      final savedCust = prefs.getString('xylo_chat_cust_$sub');
      if (savedCust != null && savedCust.isNotEmpty) {
        final d = jsonDecode(savedCust);
        if (d is List) _customerThreads = List.from(d);
      }

      final savedBm = prefs.getString('xylo_chat_bm_$sub');
      if (savedBm != null && savedBm.isNotEmpty) {
        final d = jsonDecode(savedBm);
        if (d is List) _branchMerchantThreads = List.from(d);
      }

      final savedBc = prefs.getString('xylo_chat_bc_$sub');
      if (savedBc != null && savedBc.isNotEmpty) {
        final d = jsonDecode(savedBc);
        if (d is List) _branchCustomerThreads = List.from(d);
      }

      final savedHq = prefs.getString('xylo_chat_hq_$sub');
      if (savedHq != null && savedHq.isNotEmpty) {
        final d = jsonDecode(savedHq);
        if (d is List) _superAdminMessages = List.from(d);
      }
    } catch (_) {}

    if (_customerThreads.isEmpty) {
      _customerThreads = [
        {
          'id': 'cust_1',
          'name': 'Hasib Sk',
          'subtitle': '01633003673 • Order #ORD-7FCACC57',
          'online': true,
          'unread': 1,
          'updated_at': 'Just now',
          'messages': [
            {
              'sender': 'customer',
              'sender_name': 'Hasib Sk',
              'text': 'ভাইয়া আমার Intensive UV Sunblock অর্ডারটি কবে ডেলিভারি পাবো?',
              'time': '10:25 AM',
            },
            {
              'sender': 'merchant',
              'sender_name': 'Store Admin',
              'text':
                  'ভাইয়া আপনার অর্ডারটি Steadfast Courier-এ বুকিং দেওয়া হয়েছে, দ্রুতই পেয়ে যাবেন ইনশাআল্লাহ!',
              'time': '10:27 AM',
            },
          ],
        },
        {
          'id': 'cust_2',
          'name': 'Nusrat Jahan',
          'subtitle': '01819283746 • Product Inquiry',
          'online': true,
          'unread': 0,
          'updated_at': '15m ago',
          'messages': [
            {
              'sender': 'customer',
              'sender_name': 'Nusrat Jahan',
              'text': 'TRESemme শ্যাম্পুটির অরিজিনাল ইমপোর্টেড স্টক আছে কি?',
              'time': '09:40 AM',
            },
          ],
        },
      ];
    }

    if (_branchMerchantThreads.isEmpty) {
      _branchMerchantThreads = [
        {
          'id': 'bm_1',
          'name': 'Dhanmondi Flagship Outlet',
          'subtitle': 'Branch Manager • /b/dhanmondi-outlet',
          'online': true,
          'unread': 0,
          'updated_at': 'Today',
          'messages': [
            {
              'sender': 'branch',
              'sender_name': 'Dhanmondi Manager',
              'text':
                  'স্যার, আমাদের আউটলেটে সানব্লক ক্রিমের আরও ২০ পিস স্টক ট্রান্সফার লাগবে।',
              'time': '11:00 AM',
            },
            {
              'sender': 'merchant',
              'sender_name': 'Main Store HQ',
              'text':
                  'ঠিক আছে, Branch Export ট্যাব থেকে আজ দুপুরের মধ্যে পাঠিয়ে দিচ্ছি।',
              'time': '11:05 AM',
            },
          ],
        },
      ];
    }

    if (_branchCustomerThreads.isEmpty) {
      _branchCustomerThreads = [
        {
          'id': 'bc_1',
          'name': 'Tanvir Rahman → Dhanmondi Outlet',
          'subtitle': 'Outlet Visitor • 01711223344',
          'online': false,
          'unread': 0,
          'updated_at': 'Yesterday',
          'messages': [
            {
              'sender': 'customer',
              'sender_name': 'Tanvir Rahman',
              'text': 'ধানমন্ডি শোরুম কি শুক্রবার খোলা থাকে?',
              'time': '04:15 PM',
            },
            {
              'sender': 'branch',
              'sender_name': 'Dhanmondi Outlet',
              'text': 'জি স্যার, প্রতিদিন সকাল ১০টা থেকে রাত ৯টা পর্যন্ত খোলা থাকে।',
              'time': '04:17 PM',
            },
          ],
        },
      ];
    }
  }

  Future _saveLocalChatState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _theme.subdomain;
      await prefs.setString(
          'xylo_chat_cust_$sub', jsonEncode(_customerThreads));
      await prefs.setString(
          'xylo_chat_bm_$sub', jsonEncode(_branchMerchantThreads));
      await prefs.setString(
          'xylo_chat_bc_$sub', jsonEncode(_branchCustomerThreads));
      await prefs.setString(
          'xylo_chat_hq_$sub', jsonEncode(_superAdminMessages));
    } catch (_) {}
  }

  void _ensureSelectedThread() {
    final list = _getActiveChannelThreadList();
    if (list.isNotEmpty) {
      final exists =
          list.any((t) => t is Map && t['id'].toString() == _selectedThreadId);
      if (!exists) {
        _selectedThreadId = list.first['id'].toString();
      }
    } else {
      _selectedThreadId = '';
    }
  }

  List _getActiveChannelThreadList() {
    if (_activeChannel == 'chat_branch_merchant') {
      return _branchMerchantThreads;
    }
    if (_activeChannel == 'chat_branch_customer') {
      return _branchCustomerThreads;
    }
    return _customerThreads;
  }

  Future _syncStoreChatThreads({bool silent = false}) async {
    final base = _theme.apiBase;
    final sub = _theme.subdomain;
    final headers = _theme.headers;

    try {
      final brRes = await http
          .get(
            Uri.parse('$base/api/v1/stores/branches/?subdomain=$sub'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 6));
      if (brRes.statusCode == 200) {
        final decoded = jsonDecode(brRes.body);
        final brList = decoded is List
            ? decoded
            : (decoded is Map && decoded['results'] is List
                ? decoded['results'] as List
                : []);
        final existingIds = _branchMerchantThreads
            .map((e) => (e['id'] ?? '').toString())
            .toSet();
        for (final b in brList) {
          if (b is Map) {
            final bid = 'branch_${b['id']}';
            if (!existingIds.contains(bid)) {
              _branchMerchantThreads.add({
                'id': bid,
                'name': (b['name'] ?? 'Branch Outlet').toString(),
                'subtitle':
                    'Manager: ${(b['manager_email'] ?? 'Active')} • /b/${b['slug'] ?? ''}',
                'online': b['is_active'] == true,
                'unread': 0,
                'updated_at': 'Live',
                'messages': [
                  {
                    'sender': 'merchant',
                    'sender_name': 'Main Store HQ',
                    'text':
                        'Welcome to ${b['name']} B2B Direct Channel. Use this room for stock & order coordination.',
                    'time': 'System',
                  }
                ],
              });
            }
          }
        }
      }
    } catch (_) {}

    try {
      final repRes = await http
          .get(
            Uri.parse('$base/api/v1/stores/reports/?subdomain=$sub'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 6));
      if (repRes.statusCode == 200) {
        final data = jsonDecode(repRes.body);
        if (data is Map && data['messages'] is List) {
          final msgs = List.from(data['messages']);
          for (final m in msgs.take(15)) {
            if (m is Map) {
              final sender = (m['sender'] ?? 'Customer').toString();
              final text = (m['message'] ?? '').toString();
              if (text.isEmpty) continue;
              final tid = 'rep_${sender.toLowerCase().replaceAll(' ', '_')}';
              final idx = _customerThreads
                  .indexWhere((t) => t is Map && t['id'] == tid);
              if (idx == -1) {
                _customerThreads.add({
                  'id': tid,
                  'name': sender,
                  'subtitle': (m['channel'] ?? 'Customer Chat').toString(),
                  'online': true,
                  'unread':
                      (m['status'] ?? '').toString().toLowerCase() == 'unread'
                          ? 1
                          : 0,
                  'updated_at': (m['created_at'] ?? 'Recent').toString(),
                  'messages': [
                    {
                      'sender': 'customer',
                      'sender_name': sender,
                      'text': text,
                      'time': (m['created_at'] ?? '').toString(),
                    }
                  ],
                });
              }
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _ensureSelectedThread();
      });
    }
    await _saveLocalChatState();
  }

  Future _fetchSuperAdminRoomAndMessages({bool silent = false}) async {
    final base = _theme.apiBase;
    final sub = _theme.subdomain.trim().toLowerCase();
    final headers = _theme.headers;

    try {
      if (_superAdminTenantId == null) {
        final roomsRes = await http
            .get(
              Uri.parse('$base/api/v1/superadmin/chat/rooms/'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 6));

        if (roomsRes.statusCode == 200) {
          final roomsData = jsonDecode(roomsRes.body);
          if (roomsData is Map && roomsData['rooms'] is List) {
            final roomsList = List.from(roomsData['rooms']);
            Map? matched;
            for (final r in roomsList) {
              if (r is Map) {
                final rSub = (r['subdomain'] ?? '').toString().toLowerCase();
                final rName = (r['store_name'] ?? '').toString().toLowerCase();
                if (rSub == sub || rName == sub) {
                  matched = r;
                  break;
                }
              }
            }
            if (matched == null && roomsList.isNotEmpty) {
              matched = roomsList.first as Map?;
            }
            if (matched != null) {
              _superAdminTenantId =
                  int.tryParse((matched['tenant_id'] ?? '').toString());
              final sName = (matched['store_name'] ?? '').toString();
              if (sName.isNotEmpty) {
                _resolvedStoreName = sName;
              }
            }
          }
        }
      }

      if (_superAdminTenantId != null) {
        final msgRes = await http
            .get(
              Uri.parse(
                  '$base/api/v1/superadmin/chat/rooms/$_superAdminTenantId/messages/'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 6));

        if (msgRes.statusCode == 200) {
          final msgData = jsonDecode(msgRes.body);
          if (msgData is Map && msgData['messages'] is List) {
            if (mounted) {
              setState(() {
                _superAdminMessages = List.from(msgData['messages']);
                if (msgData['store_name'] != null &&
                    msgData['store_name'].toString().isNotEmpty) {
                  _resolvedStoreName = msgData['store_name'].toString();
                }
              });
            }
            await _saveLocalChatState();
          }
        }
      }
    } catch (_) {}
  }

  Future _sendSuperAdminDirectMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    setState(() => _isSending = true);
    _messageInputCtrl.clear();

    final base = _theme.apiBase;
    bool sentViaApi = false;

    if (_superAdminTenantId != null) {
      try {
        final res = await http
            .post(
              Uri.parse(
                  '$base/api/v1/superadmin/chat/rooms/$_superAdminTenantId/messages/'),
              headers: {
                ..._theme.headers,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'text': clean,
                'sender_role': 'merchant',
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          if (data is Map && data['message'] is Map) {
            setState(() {
              _superAdminMessages.add(data['message']);
            });
            sentViaApi = true;
          }
        }
      } catch (_) {}
    }

    if (!sentViaApi) {
      setState(() {
        _superAdminMessages.add({
          'id': DateTime.now().millisecondsSinceEpoch,
          'sender_role': 'merchant',
          'sender_name': _resolvedStoreName,
          'message_type': 'text',
          'text': clean,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
    }

    await _saveLocalChatState();
    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  Future _startSuperAdminVoiceCall() async {
    setState(() {
      _isCallActive = true;
      _callSeconds = 0;
      _isMuted = false;
    });

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isCallActive) {
        setState(() => _callSeconds++);
      }
    });

    if (_superAdminTenantId != null) {
      try {
        await http
            .post(
              Uri.parse(
                  '${_theme.apiBase}/api/v1/superadmin/chat/rooms/$_superAdminTenantId/call/'),
              headers: {
                ..._theme.headers,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'action': 'start',
                'sender_role': 'merchant',
              }),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  Future _endSuperAdminVoiceCall() async {
    _callTimer?.cancel();
    final dur = _callSeconds;
    setState(() {
      _isCallActive = false;
      _callSeconds = 0;
    });

    bool loggedBackend = false;
    if (_superAdminTenantId != null) {
      try {
        final res = await http
            .post(
              Uri.parse(
                  '${_theme.apiBase}/api/v1/superadmin/chat/rooms/$_superAdminTenantId/call/'),
              headers: {
                ..._theme.headers,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'action': 'end',
                'duration': dur,
                'sender_role': 'merchant',
              }),
            )
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200 || res.statusCode == 201) {
          loggedBackend = true;
          await _fetchSuperAdminRoomAndMessages(silent: true);
        }
      } catch (_) {}
    }

    if (!loggedBackend) {
      setState(() {
        _superAdminMessages.add({
          'id': DateTime.now().millisecondsSinceEpoch,
          'sender_role': 'merchant',
          'sender_name': _resolvedStoreName,
          'message_type': 'call',
          'text': 'Voice Call Ended (${_formatDuration(dur)})',
          'duration_seconds': dur,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      await _saveLocalChatState();
    }
  }

  Future _createSuperAdminMeeting({bool instant = false}) async {
    final title = instant
        ? 'Instant Support Meet — $_resolvedStoreName & SuperAdmin'
        : _meetTitleCtrl.text.trim();
    final agenda = instant
        ? 'Live 1-on-1 screen share & store consultation'
        : _meetAgendaCtrl.text.trim();
    final scheduledAt = instant
        ? 'Instant Meeting (Join Now)'
        : _meetDateTimeCtrl.text.trim();
    final customLink = instant ? '' : _meetLinkCtrl.text.trim();

    final payload = {
      'title': title,
      'agenda': agenda,
      'scheduled_at': scheduledAt,
      'meet_link': customLink,
      'sender_role': 'merchant',
    };

    bool createdViaApi = false;
    if (_superAdminTenantId != null) {
      try {
        final res = await http
            .post(
              Uri.parse(
                  '${_theme.apiBase}/api/v1/superadmin/chat/rooms/$_superAdminTenantId/meeting/'),
              headers: {
                ..._theme.headers,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          createdViaApi = true;
          await _fetchSuperAdminRoomAndMessages(silent: true);
          if (instant && data is Map && data['meeting'] is Map) {
            setState(() {
              _activeVideoConference = Map.from(data['meeting']);
            });
          }
        }
      } catch (_) {}
    }

    if (!createdViaApi) {
      final code =
          'xylo-hq-${_theme.subdomain}-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
      final link =
          customLink.isNotEmpty ? customLink : 'https://meet.jit.si/$code';
      final meta = {
        'title': title,
        'agenda': agenda,
        'scheduled_at': scheduledAt,
        'meet_code': code,
        'meet_link': link,
        'host': _resolvedStoreName,
        'store_name': _resolvedStoreName,
        'sender_role': 'merchant',
      };
      setState(() {
        _superAdminMessages.add({
          'id': DateTime.now().millisecondsSinceEpoch,
          'sender_role': 'merchant',
          'sender_name': _resolvedStoreName,
          'message_type': 'meeting',
          'text': title,
          'meeting_meta': meta,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (instant) {
          _activeVideoConference = meta;
        }
      });
      await _saveLocalChatState();
    }

    _showToast(instant
        ? 'Instant Video Meet room created!'
        : 'Meeting request sent to SuperAdmin HQ!');
  }

  void _openScheduleMeetingModal() {
    final t = _theme;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: t.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: t.cardBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.video_call_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Schedule Meet with SuperAdmin HQ',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModalField(
                  t,
                  label: 'Meeting Title',
                  controller: _meetTitleCtrl,
                  hint: 'Store Consultation',
                ),
                const SizedBox(height: 10),
                _buildModalField(
                  t,
                  label: 'Agenda / Topic',
                  controller: _meetAgendaCtrl,
                  hint: 'Technical support, custom domain or plan scaling',
                ),
                const SizedBox(height: 10),
                _buildModalField(
                  t,
                  label: 'Preferred Date & Time',
                  controller: _meetDateTimeCtrl,
                  hint: 'Tomorrow at 4:00 PM',
                ),
                const SizedBox(height: 10),
                _buildModalField(
                  t,
                  label: 'Custom Google Meet / Zoom Link (Optional)',
                  controller: _meetLinkCtrl,
                  hint: 'Leave blank to auto-generate Jitsi/Meet room',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: t.secondaryText),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _createSuperAdminMeeting(instant: false);
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 15),
              label: const Text(
                'Send Meeting Invite',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalField(
    CatalogThemeConfig t, {
    required String label,
    required TextEditingController controller,
    required String hint,
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
          style: TextStyle(color: t.primaryText, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: t.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
      ],
    );
  }

  String _formatDuration(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return 'Just now';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $h:$min $ampm';
  }

  void _sendChannelThreadMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final list = _getActiveChannelThreadList();
    final idx = list.indexWhere(
        (t) => t is Map && t['id'].toString() == _selectedThreadId);
    if (idx == -1) return;

    final now = TimeOfDay.now().format(context);
    setState(() {
      final thread = list[idx] as Map;
      final msgs =
          thread['messages'] is List ? List.from(thread['messages']) : [];
      msgs.add({
        'sender': 'merchant',
        'sender_name': 'Store Admin',
        'text': clean,
        'time': now,
      });
      thread['messages'] = msgs;
      thread['updated_at'] = 'Just now';
      thread['unread'] = 0;
      _messageInputCtrl.clear();
    });
    _saveLocalChatState();
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _theme.primaryColor,
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
        _buildTopChannelSwitcher(t),
        const SizedBox(height: 14),
        if (_activeChannel == 'chat_superadmin')
          _buildSuperAdminHqChannelView(t)
        else
          _buildStandardMultiChannelChatView(t),
      ],
    );
  }

  Widget _buildTopChannelSwitcher(CatalogThemeConfig t) {
    final channels = [
      {
        'key': 'chat_customer',
        'label': 'Customer Chat',
        'icon': Icons.support_agent_rounded,
        'badge': '${_customerThreads.length}',
        'color': t.primaryColor,
      },
      {
        'key': 'chat_branch_merchant',
        'label': 'Merchant & Branch',
        'icon': Icons.business_center_outlined,
        'badge': 'B2B',
        'color': const Color(0xFF3B82F6),
      },
      {
        'key': 'chat_branch_customer',
        'label': 'Branch & Customer',
        'icon': Icons.store_mall_directory_outlined,
        'badge': 'OUTLET',
        'color': const Color(0xFFA855F7),
      },
      {
        'key': 'chat_superadmin',
        'label': 'SuperAdmin HQ',
        'icon': Icons.verified_user_outlined,
        'badge': 'HQ MEET',
        'color': const Color(0xFFF59E0B),
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: channels.map((ch) {
          final key = ch['key'] as String;
          final isSelected = _activeChannel == key;
          final accent = ch['color'] as Color;
          final isHq = key == 'chat_superadmin';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeChannel = key;
                  _ensureSelectedThread();
                });
              },
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected && !isHq && t.useGradient
                      ? t.brandGradient
                      : null,
                  color: isSelected
                      ? (isHq
                          ? const Color(0xFFF59E0B)
                          : (t.useGradient ? null : t.primaryColor))
                      : t.cardBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isSelected
                        ? (isHq ? const Color(0xFFF59E0B) : t.primaryColor)
                        : t.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ch['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? (isHq ? Colors.black : Colors.white)
                          : accent,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      ch['label'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? (isHq ? Colors.black : Colors.white)
                            : t.primaryText,
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
                            ? Colors.black.withValues(alpha: 0.18)
                            : accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        ch['badge'] as String,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? (isHq ? Colors.black : Colors.white)
                              : accent,
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

  Widget _buildSuperAdminHqChannelView(CatalogThemeConfig t) {
    const amber = Color(0xFFF59E0B);

    return Container(
      decoration: BoxDecoration(
        color: t.isDarkMode ? const Color(0xFF0C0B08) : t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: t.isDarkMode
              ? const Color(0xFF2E2718)
              : amber.withValues(alpha: 0.4),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.isDarkMode
                  ? const Color(0xFF14120C)
                  : amber.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              border: Border(
                bottom: BorderSide(
                  color: t.isDarkMode
                      ? const Color(0xFF2E2718)
                      : t.cardBorder,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'X',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'XYLO SuperAdmin HQ — Direct Line ($_resolvedStoreName)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      size: 12,
                                      color: Color(0xFF10B981),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'NO BOT • DIRECT HUMAN CHANNEL',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: amber.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'AUTO-SYNC ACTIVE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh HQ Messages',
                      onPressed: () =>
                          _fetchSuperAdminRoomAndMessages(silent: false),
                      icon: const Icon(Icons.refresh_rounded, color: amber),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed:
                          _isCallActive ? null : _startSuperAdminVoiceCall,
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                      label: const Text(
                        'Voice Call',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: () =>
                          _createSuperAdminMeeting(instant: true),
                      icon: const Icon(Icons.videocam_rounded, size: 16),
                      label: const Text(
                        'Instant Video Meet',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: amber,
                        side: const BorderSide(color: amber),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: _openScheduleMeetingModal,
                      icon: const Icon(Icons.calendar_month_rounded, size: 15),
                      label: const Text(
                        'Schedule Meet',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_isCallActive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF064E3B),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded,
                      color: Color(0xFF34D399)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live Voice Call with SuperAdmin HQ • ${_formatDuration(_callSeconds)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                    icon: Icon(
                      _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _isSpeakerOn = !_isSpeakerOn),
                    icon: Icon(
                      _isSpeakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _endSuperAdminVoiceCall,
                    icon: const Icon(Icons.call_end_rounded, size: 16),
                    label: const Text('End'),
                  ),
                ],
              ),
            ),

          if (_activeVideoConference != null)
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF3B82F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.videocam_rounded,
                          color: Color(0xFF60A5FA)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (_activeVideoConference!['title'] ??
                                  'Live Video Consultation')
                              .toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _activeVideoConference = null),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Meeting Link: ${_activeVideoConference!['meet_link'] ?? 'https://meet.jit.si/xylo-hq'}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final lnk = (_activeVideoConference!['meet_link'] ?? '')
                          .toString();
                      Clipboard.setData(ClipboardData(text: lnk));
                      _showToast('Meeting link copied to clipboard!');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Copy Video Room Link'),
                  ),
                ],
              ),
            ),

          Container(
            constraints: const BoxConstraints(minHeight: 300, maxHeight: 440),
            padding: const EdgeInsets.all(16),
            child: _superAdminMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          size: 42,
                          color: amber.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Direct Line to XYLO SuperAdmin HQ',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: t.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'সরাসরি Main SuperAdmin-এর সাথে চ্যাট, ভয়েস কল অথবা ভিডিও মিটিং শুরু করুন।',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _superAdminMessages.length,
                    itemBuilder: (ctx, idx) {
                      final m = _superAdminMessages[idx];
                      if (m is! Map) return const SizedBox.shrink();
                      return _buildSuperAdminMessageBubble(t, m);
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.isDarkMode ? const Color(0xFF14120C) : t.inputBg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(19),
              ),
              border: Border(
                top: BorderSide(
                  color: t.isDarkMode
                      ? const Color(0xFF2E2718)
                      : t.cardBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageInputCtrl,
                    onSubmitted: _sendSuperAdminDirectMessage,
                    style: TextStyle(color: t.primaryText, fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'Write directly to SuperAdmin HQ (No Bot)...',
                      hintStyle:
                          TextStyle(color: t.secondaryText, fontSize: 12.5),
                      isDense: true,
                      filled: true,
                      fillColor: t.cardBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSending
                      ? null
                      : () => _sendSuperAdminDirectMessage(
                          _messageInputCtrl.text),
                  icon: const Icon(Icons.send_rounded, size: 17),
                  label: const Text(
                    'Send HQ',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperAdminMessageBubble(CatalogThemeConfig t, Map m) {
    final role = (m['sender_role'] ?? 'merchant').toString();
    final isMerchant = role == 'merchant';
    final msgType = (m['message_type'] ?? 'text').toString();
    final senderName = (m['sender_name'] ??
            (isMerchant ? _resolvedStoreName : 'XYLO SuperAdmin HQ'))
        .toString();
    final text = (m['text'] ?? '').toString();
    final timeStr = _formatTimestamp((m['created_at'] ?? '').toString());
    final meetingMeta =
        m['meeting_meta'] is Map ? m['meeting_meta'] as Map : null;

    return Align(
      alignment: isMerchant ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isMerchant
              ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
              : t.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMerchant
                ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                : t.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMerchant
                      ? Icons.storefront_rounded
                      : Icons.verified_user_rounded,
                  size: 13,
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 5),
                Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 10, color: t.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (msgType == 'meeting' && meetingMeta != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3B82F6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.videocam_rounded,
                            size: 16, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (meetingMeta['title'] ?? text).toString(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((meetingMeta['agenda'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Agenda: ${meetingMeta['agenda']}',
                        style:
                            TextStyle(fontSize: 11.5, color: t.secondaryText),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Time: ${meetingMeta['scheduled_at'] ?? 'Instant'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _activeVideoConference = meetingMeta;
                            });
                          },
                          icon: const Icon(Icons.videocam_rounded, size: 14),
                          label: const Text(
                            'Join Room',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            final link =
                                (meetingMeta['meet_link'] ?? '').toString();
                            Clipboard.setData(ClipboardData(text: link));
                            _showToast('Meet link copied!');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 13),
                          label: const Text(
                            'Copy Link',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (msgType == 'call') ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_callback_rounded,
                      size: 15, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: t.primaryText,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: t.primaryText,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardMultiChannelChatView(CatalogThemeConfig t) {
    final threads = _getActiveChannelThreadList();
    final q = _searchCtrl.text.trim().toLowerCase();
    final filteredThreads = threads.where((th) {
      if (th is! Map) return false;
      if (q.isEmpty) return true;
      final nm = (th['name'] ?? '').toString().toLowerCase();
      final sub = (th['subtitle'] ?? '').toString().toLowerCase();
      return nm.contains(q) || sub.contains(q);
    }).toList();

    Map? activeThread;
    for (final th in threads) {
      if (th is Map && th['id'].toString() == _selectedThreadId) {
        activeThread = th;
        break;
      }
    }
    if (activeThread == null && filteredThreads.isNotEmpty) {
      activeThread = filteredThreads.first as Map;
    }

    final activeMessages =
        activeThread != null && activeThread['messages'] is List
            ? List.from(activeThread['messages'])
            : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
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
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: t.primaryText, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText:
                            'Search conversation by customer or branch...',
                        hintStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18, color: t.secondaryText),
                        isDense: true,
                        filled: true,
                        fillColor: t.inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                  IconButton(
                    tooltip: 'Sync Conversations',
                    onPressed: () => _syncStoreChatThreads(silent: false),
                    icon: Icon(Icons.refresh_rounded, color: t.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filteredThreads.map((th) {
                    final id = th['id'].toString();
                    final isSelected = (activeThread != null &&
                        activeThread['id'].toString() == id);
                    final unread =
                        int.tryParse((th['unread'] ?? '0').toString()) ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedThreadId = id;
                            th['unread'] = 0;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? t.primaryColor.withValues(alpha: 0.14)
                                : t.inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected ? t.primaryColor : t.cardBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    t.primaryColor.withValues(alpha: 0.2),
                                child: Text(
                                  (th['name'] ?? 'C')
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: t.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (th['name'] ?? 'Conversation').toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: t.primaryText,
                                    ),
                                  ),
                                  Text(
                                    (th['subtitle'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: t.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                              if (unread > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (activeThread != null)
          Container(
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: t.cardBorder)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            t.primaryColor.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.forum_outlined,
                          size: 18,
                          color: t.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (activeThread['name'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              (activeThread['subtitle'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF16A34A).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  constraints:
                      const BoxConstraints(minHeight: 240, maxHeight: 360),
                  padding: const EdgeInsets.all(15),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeMessages.length,
                    itemBuilder: (ctx, i) {
                      final msg = activeMessages[i];
                      if (msg is! Map) return const SizedBox.shrink();
                      final isMe = msg['sender'] == 'merchant';
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          constraints: const BoxConstraints(maxWidth: 380),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? t.primaryColor : t.inputBg,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: isMe ? t.primaryColor : t.cardBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${msg['sender_name'] ?? 'Sender'} • ${msg['time'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : t.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (msg['text'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isMe ? Colors.white : t.primaryText,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickReplies.map((qr) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            backgroundColor: t.inputBg,
                            side: BorderSide(color: t.cardBorder),
                            label: Text(
                              qr,
                              style: TextStyle(
                                fontSize: 11,
                                color: t.primaryText,
                              ),
                            ),
                            onPressed: () => _sendChannelThreadMessage(qr),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageInputCtrl,
                          onSubmitted: _sendChannelThreadMessage,
                          style: TextStyle(color: t.primaryText, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type your reply...',
                            hintStyle: TextStyle(
                                color: t.secondaryText, fontSize: 12.5),
                            isDense: true,
                            filled: true,
                            fillColor: t.inputBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
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
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            _sendChannelThreadMessage(_messageInputCtrl.text),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text(
                          'Reply',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}