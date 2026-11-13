// lib/widgets/order/orders_list_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class OrdersListView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onOrdersChanged;

  const OrdersListView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.onOrdersChanged,
  });

  @override
  State<OrdersListView> createState() => _OrdersListViewState();
}

class _OrdersListViewState extends State<OrdersListView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isSyncingQueue = false;

  List _orders = [];
  List _cachedProducts = [];

  // Offline queues
  List _pendingStatusQueue = [];
  List _pendingNewOrdersQueue = [];

  // Realtime watcher
  Timer? _realtimeTimer;
  final Set _knownOrderNumbers = {};
  Map? _latestRealtimeOrderBanner;
  DateTime? _lastSyncedAt;

  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _sortBy = 'newest';

  final TextEditingController _searchCtrl = TextEditingController();

  String get _cacheOrdersKey => 'offline_cached_orders_${_theme.subdomain}';
  String get _cacheProductsKey => 'offline_cached_products_${_theme.subdomain}';
  String get _queueStatusKey => 'offline_status_queue_${_theme.subdomain}';
  String get _queueNewOrdersKey => 'offline_new_orders_queue_${_theme.subdomain}';

  // =========================================================================
  // 🌟 BUILT-IN ORDER HELPER METHODS (NO EXTERNAL OrderUtils NEEDED)
  // =========================================================================
  BoxDecoration _primaryDecoration(CatalogThemeConfig t, {double radius = 14}) {
    return BoxDecoration(
      color: t.useGradient ? null : t.primaryColor,
      gradient: t.useGradient ? t.brandGradient : null,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  String _extractCustomerName(Map ord) {
    final direct = (ord['customer_name'] ?? '').toString().trim();
    if (direct.isNotEmpty && direct.toLowerCase() != 'null') return direct;

    final ship = ord['shipping_address'];
    if (ship is Map) {
      final sName =
          (ship['name'] ?? ship['full_name'] ?? ship['customer_name'] ?? '')
              .toString()
              .trim();
      if (sName.isNotEmpty) return sName;
    }

    final cData = ord['customer_data'];
    if (cData is Map) {
      final cName = (cData['full_name'] ?? cData['first_name'] ?? '')
          .toString()
          .trim();
      if (cName.isNotEmpty) return cName;
    }

    return 'Walk-in Customer';
  }

  String _extractCustomerPhone(Map ord) {
    final direct =
        (ord['customer_phone'] ?? ord['phone'] ?? '').toString().trim();
    if (direct.isNotEmpty && direct.toLowerCase() != 'null') return direct;

    final ship = ord['shipping_address'];
    if (ship is Map) {
      final sPhone =
          (ship['phone'] ?? ship['phoneNumber'] ?? ship['customer_phone'] ?? '')
              .toString()
              .trim();
      if (sPhone.isNotEmpty) return sPhone;
    }

    final cData = ord['customer_data'];
    if (cData is Map) {
      final cPhone = (cData['phone'] ?? '').toString().trim();
      if (cPhone.isNotEmpty) return cPhone;
    }

    return 'N/A';
  }

  String _extractCustomerEmail(Map ord) {
    final direct =
        (ord['customer_email'] ?? ord['email'] ?? '').toString().trim();
    if (direct.isNotEmpty && direct.toLowerCase() != 'null') return direct;

    final ship = ord['shipping_address'];
    if (ship is Map) {
      final sEmail =
          (ship['email'] ?? ship['customer_email'] ?? '').toString().trim();
      if (sEmail.isNotEmpty) return sEmail;
    }

    final cData = ord['customer_data'];
    if (cData is Map) {
      final cEmail = (cData['email'] ?? '').toString().trim();
      if (cEmail.isNotEmpty) return cEmail;
    }

    return '';
  }

  String _extractAddress(Map ord) {
    final fullAddr = (ord['full_address'] ?? '').toString().trim();
    if (fullAddr.isNotEmpty && fullAddr.toLowerCase() != 'null') {
      return fullAddr;
    }

    final ship = ord['shipping_address'];
    if (ship is Map) {
      final addr = (ship['address'] ??
              ship['street_address'] ??
              ship['full_address'] ??
              '')
          .toString()
          .trim();
      final city = (ship['city'] ?? '').toString().trim();
      if (addr.isNotEmpty && city.isNotEmpty && !addr.contains(city)) {
        return '$addr, $city';
      }
      if (addr.isNotEmpty) return addr;
    } else if (ship is String && ship.trim().isNotEmpty) {
      return ship.trim();
    }

    return 'Fulbarigate, Khulna';
  }

  double _extractAmount(Map ord) {
    final raw = ord['total'] ??
        ord['total_amount'] ??
        ord['grand_total'] ??
        ord['amount'] ??
        ord['subtotal'] ??
        0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().replaceAll(',', '')) ?? 0.0;
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return 'Recent';
    final str = rawDate.toString().trim();
    if (str.isEmpty) return 'Recent';
    final parsed = DateTime.tryParse(str);
    if (parsed == null) return str;
    final local = parsed.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = local.day.toString().padLeft(2, '0');
    final mon = months[local.month - 1];
    final hr = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $mon ${local.year}, $hr:$min $ampm';
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered' || s == 'completed') return const Color(0xFF10B981);
    if (s == 'shipped' || s == 'in_transit') return const Color(0xFF3B82F6);
    if (s == 'processing') return const Color(0xFF8B5CF6);
    if (s == 'cancelled' || s == 'refunded') return Colors.redAccent;
    return const Color(0xFFF59E0B);
  }

  IconData _statusIcon(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered' || s == 'completed') return Icons.check_circle_rounded;
    if (s == 'shipped' || s == 'in_transit') return Icons.local_shipping_rounded;
    if (s == 'processing') return Icons.sync_rounded;
    if (s == 'cancelled' || s == 'refunded') return Icons.cancel_rounded;
    return Icons.schedule_rounded;
  }

  @override
  void initState() {
    super.initState();
    _initializeRealtimeAndOfflineEngine();
  }

  @override
  void didUpdateWidget(covariant OrdersListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadThemeOnly();
    }
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadThemeOnly() async {
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = loaded);
    }
  }

  Future<void> _initializeRealtimeAndOfflineEngine() async {
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() {
      _theme = loaded;
      _isLoading = true;
    });

    await _loadLocalCacheAndQueues();
    await _fetchOrdersFromBackend(isInitial: true);
    await _fetchProductsForOfflineCreator();

    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollRealtimeOrdersAndSync();
    });
  }

  Future<void> _loadLocalCacheAndQueues() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rawStatusQ = prefs.getString(_queueStatusKey);
      if (rawStatusQ != null && rawStatusQ.isNotEmpty) {
        final decoded = jsonDecode(rawStatusQ);
        if (decoded is List) _pendingStatusQueue = decoded;
      }

      final rawNewOrdQ = prefs.getString(_queueNewOrdersKey);
      if (rawNewOrdQ != null && rawNewOrdQ.isNotEmpty) {
        final decoded = jsonDecode(rawNewOrdQ);
        if (decoded is List) _pendingNewOrdersQueue = decoded;
      }

      final rawCachedOrders = prefs.getString(_cacheOrdersKey);
      if (rawCachedOrders != null && rawCachedOrders.isNotEmpty) {
        final decoded = jsonDecode(rawCachedOrders);
        if (decoded is List && decoded.isNotEmpty) {
          final merged = _mergeOrdersWithOfflineQueues(decoded);
          for (final o in merged) {
            if (o is Map && o['order_number'] != null) {
              _knownOrderNumbers.add(o['order_number'].toString());
            }
          }
          if (mounted) {
            setState(() {
              _orders = merged;
              _isLoading = false;
            });
          }
        }
      }

      final rawCachedProds = prefs.getString(_cacheProductsKey);
      if (rawCachedProds != null && rawCachedProds.isNotEmpty) {
        final decoded = jsonDecode(rawCachedProds);
        if (decoded is List) {
          _cachedProducts = decoded;
        }
      }
    } catch (_) {}
  }

  Future<void> _saveQueuesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueStatusKey, jsonEncode(_pendingStatusQueue));
      await prefs.setString(
          _queueNewOrdersKey, jsonEncode(_pendingNewOrdersQueue));
    } catch (_) {}
  }

  Future<void> _saveOrdersCacheToStorage(List serverOrders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheOrdersKey, jsonEncode(serverOrders));
    } catch (_) {}
  }

  List _mergeOrdersWithOfflineQueues(List baseOrders) {
    final List result = [];

    for (final qItem in _pendingNewOrdersQueue) {
      if (qItem is Map && qItem['display_order'] is Map) {
        final disp = Map<String, dynamic>.from(qItem['display_order'] as Map);
        disp['is_offline_created'] = true;
        disp['pending_sync'] = true;
        result.add(disp);
      }
    }

    final Map statusOverrides = {};
    for (final sq in _pendingStatusQueue) {
      if (sq is Map && sq['order_number'] != null) {
        statusOverrides[sq['order_number'].toString()] =
            sq['status'].toString();
      }
    }

    for (final raw in baseOrders) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final ordNo = (item['order_number'] ?? '').toString();
      if (statusOverrides.containsKey(ordNo)) {
        item['status'] = statusOverrides[ordNo];
        item['pending_sync'] = true;
      }
      result.add(item);
    }

    return result;
  }

  Future<void> _pollRealtimeOrdersAndSync() async {
    if (!mounted || _isSyncingQueue) return;

    if (_pendingStatusQueue.isNotEmpty || _pendingNewOrdersQueue.isNotEmpty) {
      await _syncOfflineQueuesWithBackend(silent: true);
    }

    await _fetchOrdersFromBackend(isInitial: false, silent: true);
  }

  Future<void> _fetchProductsForOfflineCreator() async {
    final t = _theme;
    try {
      final res = await http
          .get(
            Uri.parse(
                '${t.apiBase}/api/v1/products/?subdomain=${t.subdomain}&all_branches=true'),
            headers: t.headers,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        List list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          list = decoded['results'] as List;
        }
        if (list.isNotEmpty) {
          _cachedProducts = list;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheProductsKey, jsonEncode(list));
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchOrdersFromBackend({
    bool isInitial = false,
    bool silent = false,
  }) async {
    if (!mounted) return;
    if (!silent && _orders.isEmpty) {
      setState(() => _isLoading = true);
    }

    final t = _theme;
    try {
      final res = await http
          .get(
            Uri.parse(
                '${t.apiBase}/api/v1/orders/?subdomain=${t.subdomain}&admin=true'),
            headers: t.headers,
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        List serverList = [];
        if (decoded is List) {
          serverList = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          serverList = decoded['results'] as List;
        }

        Map? newlyArrivedOrder;
        final bool hadPreviousOrders = _knownOrderNumbers.isNotEmpty;

        for (final raw in serverList) {
          if (raw is Map) {
            final ordNo = (raw['order_number'] ?? '').toString();
            if (ordNo.isNotEmpty && !_knownOrderNumbers.contains(ordNo)) {
              _knownOrderNumbers.add(ordNo);
              if (hadPreviousOrders && !isInitial) {
                newlyArrivedOrder ??= Map<String, dynamic>.from(raw);
              }
            }
          }
        }

        await _saveOrdersCacheToStorage(serverList);
        final mergedList = _mergeOrdersWithOfflineQueues(serverList);

        if (mounted) {
          setState(() {
            _orders = mergedList;
            _isOffline = false;
            _isLoading = false;
            _lastSyncedAt = DateTime.now();
            if (newlyArrivedOrder != null) {
              _latestRealtimeOrderBanner = newlyArrivedOrder;
            }
          });
        }

        if (newlyArrivedOrder != null && mounted) {
          HapticFeedback.heavyImpact();
          final cName = _extractCustomerName(newlyArrivedOrder);
          final amt = _extractAmount(newlyArrivedOrder);
          final oNum = newlyArrivedOrder['order_number'] ?? '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: t.primaryColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'নতুন অর্ডার এসেছে! #$oNum • $cName (৳${amt.toStringAsFixed(0)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          widget.onOrdersChanged?.call();
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncOfflineQueuesWithBackend({bool silent = false}) async {
    if (_isSyncingQueue) return;
    if (_pendingStatusQueue.isEmpty && _pendingNewOrdersQueue.isEmpty) return;

    setState(() => _isSyncingQueue = true);
    final t = _theme;
    int syncedCount = 0;

    try {
      final List remainingNewOrders = [];
      for (final item in _pendingNewOrdersQueue) {
        if (item is! Map) continue;
        final payload = item['payload'];
        try {
          final res = await http
              .post(
                Uri.parse(
                    '${t.apiBase}/api/v1/orders/?subdomain=${t.subdomain}'),
                headers: {
                  ...t.headers,
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 8));

          if (res.statusCode == 200 || res.statusCode == 201) {
            syncedCount++;
          } else {
            remainingNewOrders.add(item);
          }
        } catch (_) {
          remainingNewOrders.add(item);
        }
      }
      _pendingNewOrdersQueue = remainingNewOrders;

      final List remainingStatusUpdates = [];
      for (final item in _pendingStatusQueue) {
        if (item is! Map) continue;
        final ordNo = (item['order_number'] ?? '').toString();
        final newStatus = (item['status'] ?? '').toString();
        try {
          final cleanNo = Uri.encodeComponent(ordNo.replaceFirst('#', ''));
          final res = await http
              .patch(
                Uri.parse(
                    '${t.apiBase}/api/v1/orders/$cleanNo/update-status/?subdomain=${t.subdomain}'),
                headers: {
                  ...t.headers,
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'status': newStatus}),
              )
              .timeout(const Duration(seconds: 8));

          if (res.statusCode == 200) {
            syncedCount++;
          } else {
            remainingStatusUpdates.add(item);
          }
        } catch (_) {
          remainingStatusUpdates.add(item);
        }
      }
      _pendingStatusQueue = remainingStatusUpdates;

      await _saveQueuesToStorage();

      if (syncedCount > 0) {
        await _fetchOrdersFromBackend(silent: true);
        widget.onOrdersChanged?.call();
        if (mounted && !silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: t.primaryColor,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'সফলভাবে $syncedCountটি অফলাইন কাজ সার্ভারে সিঙ্ক হয়েছে!',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingQueue = false);
      }
    }
  }

  Future<void> _updateOrderStatus(Map order, String newStatus) async {
    final t = _theme;
    final ordNo = (order['order_number'] ?? order['id'] ?? '').toString();
    if (ordNo.isEmpty) return;

    setState(() {
      for (int i = 0; i < _orders.length; i++) {
        final o = _orders[i];
        if (o is Map && (o['order_number'] ?? '').toString() == ordNo) {
          final updated = Map<String, dynamic>.from(o);
          updated['status'] = newStatus;
          if (_isOffline) {
            updated['pending_sync'] = true;
          }
          _orders[i] = updated;
          break;
        }
      }
    });

    if (order['is_offline_created'] == true) {
      for (int i = 0; i < _pendingNewOrdersQueue.length; i++) {
        final q = _pendingNewOrdersQueue[i];
        if (q is Map &&
            q['display_order'] is Map &&
            q['display_order']['order_number'] == ordNo) {
          q['display_order']['status'] = newStatus;
          break;
        }
      }
      await _saveQueuesToStorage();
      return;
    }

    try {
      final cleanNo = Uri.encodeComponent(ordNo.replaceFirst('#', ''));
      final res = await http
          .patch(
            Uri.parse(
                '${t.apiBase}/api/v1/orders/$cleanNo/update-status/?subdomain=${t.subdomain}'),
            headers: {
              ...t.headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        await _saveOrdersCacheToStorage(_orders);
        widget.onOrdersChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: t.primaryColor,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Order #$ordNo status updated to ${newStatus.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }
        return;
      }
      throw Exception('Server status ${res.statusCode}');
    } catch (_) {
      _pendingStatusQueue.removeWhere(
          (item) => item is Map && item['order_number'] == ordNo);
      _pendingStatusQueue.add({
        'order_number': ordNo,
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await _saveQueuesToStorage();

      setState(() {
        _isOffline = true;
        for (int i = 0; i < _orders.length; i++) {
          final o = _orders[i];
          if (o is Map && (o['order_number'] ?? '').toString() == ordNo) {
            final updated = Map<String, dynamic>.from(o);
            updated['status'] = newStatus;
            updated['pending_sync'] = true;
            _orders[i] = updated;
            break;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'অফলাইন মোডে স্ট্যাটাস সেভ হয়েছে! অনলাইনে এলেই অটো-সিঙ্ক হবে।',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      }
    }
  }

  void _openOrderDetailAndCourierModal(
    Map<String, dynamic> ord, {
    String initialTab = 'invoice',
  }) {
    final t = _theme;
    final String ordNo = (ord['order_number'] ?? ord['id'] ?? '').toString();
    final String custName = _extractCustomerName(ord);
    final String custPhone = _extractCustomerPhone(ord);
    final String address = _extractAddress(ord);
    final double amount = _extractAmount(ord);
    final String status = (ord['status'] ?? 'pending').toString().toLowerCase();
    final List items = (ord['items'] is List) ? (ord['items'] as List) : [];

    String activeSection = initialTab;
    String selectedCourier = 'steadfast';
    bool isBookingCourier = false;
    final noteCtrl = TextEditingController(
      text: (ord['notes'] ?? 'Handle with care').toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                border: Border.all(color: t.cardBorder),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: t.secondaryText.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: _primaryDecoration(t, radius: 12),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #$ordNo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: t.primaryText,
                                  ),
                                ),
                                Text(
                                  'Status: ${status.toUpperCase()} • Total: ৳${amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: t.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded,
                              color: t.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(
                                () => activeSection = 'invoice'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: activeSection == 'invoice'
                                  ? _primaryDecoration(t, radius: 10)
                                  : BoxDecoration(
                                      color: t.inputBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: t.cardBorder),
                                    ),
                              alignment: Alignment.center,
                              child: Text(
                                'Invoice & Items',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: activeSection == 'invoice'
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
                            onTap: () => setModalState(
                                () => activeSection = 'courier'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: activeSection == 'courier'
                                  ? _primaryDecoration(t, radius: 10)
                                  : BoxDecoration(
                                      color: t.inputBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: t.cardBorder),
                                    ),
                              alignment: Alignment.center,
                              child: Text(
                                'Courier Dispatch',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: activeSection == 'courier'
                                      ? Colors.white
                                      : t.primaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (activeSection == 'invoice') ...[
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
                            Text(
                              'CUSTOMER DETAILS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: t.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              custName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Phone: $custPhone',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: t.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Address: $address',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ORDER ITEMS (${items.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: t.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: t.inputBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order Package (#$ordNo)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryText,
                                ),
                              ),
                              Text(
                                '৳${amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...items.map((rawIt) {
                          final it = rawIt as Map;
                          final pName =
                              (it['product_name'] ?? it['name'] ?? 'Product')
                                  .toString();
                          final qty = it['quantity'] ?? 1;
                          final price =
                              it['unit_price'] ?? it['price'] ?? amount;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: t.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: t.cardBorder),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$pName  ×$qty',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: t.primaryText,
                                    ),
                                  ),
                                ),
                                Text(
                                  '৳$price',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: t.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
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
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text:
                                  'Invoice #$ordNo\nCustomer: $custName ($custPhone)\nAddress: $address\nTotal: ৳${amount.toStringAsFixed(0)}',
                            ));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: t.primaryColor,
                                content: Text(
                                    'Invoice #$ordNo copied & sent to print!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text(
                            'Print / Copy Invoice',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'SELECT COURIER PROVIDER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: t.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in [
                            'steadfast',
                            'pathao',
                            'redx',
                            'paperfly'
                          ])
                            InkWell(
                              onTap: () =>
                                  setModalState(() => selectedCourier = c),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: selectedCourier == c
                                    ? _primaryDecoration(t, radius: 10)
                                    : BoxDecoration(
                                        color: t.inputBg,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border:
                                            Border.all(color: t.cardBorder),
                                      ),
                                child: Text(
                                  c.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: selectedCourier == c
                                        ? Colors.white
                                        : t.primaryText,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildModalInput(
                        t,
                        controller: noteCtrl,
                        label: 'Courier Note / Instruction',
                        hint: 'Handle with care',
                        icon: Icons.note_alt_outlined,
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
                          onPressed: isBookingCourier
                              ? null
                              : () async {
                                  setModalState(
                                      () => isBookingCourier = true);
                                  try {
                                    await http
                                        .post(
                                          Uri.parse(
                                              '${t.apiBase}/api/v1/stores/courier/book/?subdomain=${t.subdomain}'),
                                          headers: {
                                            ...t.headers,
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode({
                                            'provider': selectedCourier,
                                            'order_number': ordNo,
                                            'customer_name': custName,
                                            'customer_phone': custPhone,
                                            'delivery_address': address,
                                            'cod_amount': amount,
                                            'note': noteCtrl.text.trim(),
                                          }),
                                        )
                                        .timeout(const Duration(seconds: 8));
                                  } catch (_) {}

                                  await _updateOrderStatus(ord, 'shipped');
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                          icon: const Icon(Icons.local_shipping_rounded,
                              size: 18),
                          label: Text(
                            isBookingCourier
                                ? 'Dispatching...'
                                : 'Book ${selectedCourier.toUpperCase()} & Mark Shipped',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openOrderNotifyModal(
    Map<String, dynamic> ord, {
    required String channel,
  }) {
    final t = _theme;
    final bool isSms = channel == 'sms';
    final String ordNo = (ord['order_number'] ?? ord['id'] ?? '').toString();
    final String custName = _extractCustomerName(ord);
    final String custPhone = _extractCustomerPhone(ord);
    final String custEmail = _extractCustomerEmail(ord);
    final double amount = _extractAmount(ord);

    final recipientCtrl = TextEditingController(
      text: isSms ? custPhone : custEmail,
    );
    final msgCtrl = TextEditingController(
      text:
          'Dear $custName, your order #$ordNo (Total: ৳${amount.toStringAsFixed(0)}) at ${t.subdomain.toUpperCase()} is being processed. Thank you!',
    );
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: t.cardBorder),
              ),
              title: Row(
                children: [
                  Icon(
                    isSms ? Icons.sms_rounded : Icons.email_rounded,
                    color: t.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSms
                          ? 'Send Order SMS (#$ordNo)'
                          : 'Send Order Email (#$ordNo)',
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
                  children: [
                    _buildModalInput(
                      t,
                      controller: recipientCtrl,
                      label: isSms ? 'Recipient Phone' : 'Recipient Email',
                      hint: isSms ? '017XXXXXXXX' : 'customer@gmail.com',
                      icon: isSms ? Icons.phone_rounded : Icons.alternate_email,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: msgCtrl,
                      maxLines: 4,
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Message Content',
                        labelStyle: TextStyle(color: t.secondaryText),
                        filled: true,
                        fillColor: t.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.cardBorder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: t.secondaryText)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          setDialogState(() => isSending = true);
                          try {
                            final endpoint = isSms
                                ? '/api/v1/sms/send/?subdomain=${t.subdomain}'
                                : '/api/v1/emails/send/?subdomain=${t.subdomain}';
                            await http
                                .post(
                                  Uri.parse('${t.apiBase}$endpoint'),
                                  headers: {
                                    ...t.headers,
                                    'Content-Type': 'application/json',
                                  },
                                  body: jsonEncode({
                                    'recipient': recipientCtrl.text.trim(),
                                    'mobile_number': recipientCtrl.text.trim(),
                                    'email': recipientCtrl.text.trim(),
                                    'message': msgCtrl.text.trim(),
                                    'order_number': ordNo,
                                  }),
                                )
                                .timeout(const Duration(seconds: 7));
                          } catch (_) {}

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: t.primaryColor,
                                content: Text(
                                  isSms
                                      ? 'SMS queued for ${recipientCtrl.text}!'
                                      : 'Email queued for ${recipientCtrl.text}!',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(isSending ? 'Sending...' : 'Send Now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openCreateOrderModal() {
    final t = _theme;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController(text: 'Fulbarigate, Khulna');
    final customProdCtrl = TextEditingController();
    final customPriceCtrl = TextEditingController(text: '500');
    final shippingCtrl = TextEditingController(text: '60');

    Map? selectedProduct =
        _cachedProducts.isNotEmpty && _cachedProducts.first is Map
            ? Map<String, dynamic>.from(_cachedProducts.first as Map)
            : null;
    int quantity = 1;
    String paymentMethod = 'cod';
    bool useCustomItem = _cachedProducts.isEmpty;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double unitPrice = useCustomItem
                ? (double.tryParse(customPriceCtrl.text) ?? 0.0)
                : (double.tryParse(
                        (selectedProduct?['price'] ?? '0').toString()) ??
                    0.0);
            final double shipCost =
                double.tryParse(shippingCtrl.text) ?? 60.0;
            final double subtotal = unitPrice * quantity;
            final double grandTotal = subtotal + shipCost;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  border: Border.all(color: t.cardBorder),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: t.secondaryText.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: _primaryDecoration(t, radius: 12),
                                child: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Instant / Offline Order',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: t.primaryText,
                                    ),
                                  ),
                                  Text(
                                    _isOffline
                                        ? 'Offline Mode Active — Will auto-sync when online'
                                        : 'Live Online Mode — Direct sync to store',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: _isOffline
                                          ? const Color(0xFFD97706)
                                          : t.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close_rounded,
                                color: t.secondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildModalInput(
                        t,
                        controller: nameCtrl,
                        label: 'Customer Name *',
                        hint: 'e.g. Rahim Uddin',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 10),
                      _buildModalInput(
                        t,
                        controller: phoneCtrl,
                        label: 'Phone Number *',
                        hint: 'e.g. 01700000000',
                        icon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 10),
                      _buildModalInput(
                        t,
                        controller: addressCtrl,
                        label: 'Delivery Address',
                        hint: 'Street, Area, City',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SELECT PRODUCT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: t.secondaryText,
                            ),
                          ),
                          if (_cachedProducts.isNotEmpty)
                            InkWell(
                              onTap: () => setModalState(
                                  () => useCustomItem = !useCustomItem),
                              child: Text(
                                useCustomItem
                                    ? 'Choose from Catalog'
                                    : '+ Custom Item',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (!useCustomItem && _cachedProducts.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: t.inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              isExpanded: true,
                              dropdownColor: t.cardBg,
                              value: selectedProduct?['id'],
                              items: _cachedProducts.map((rawP) {
                                final pm = rawP as Map;
                                return DropdownMenuItem(
                                  value: pm['id'],
                                  child: Text(
                                    '${pm['name']} (৳${pm['price']} • Stock: ${pm['stock_quantity'] ?? 0})',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: t.primaryText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                final found = _cachedProducts.firstWhere(
                                  (e) => (e as Map)['id'] == val,
                                  orElse: () => _cachedProducts.first,
                                );
                                setModalState(() {
                                  selectedProduct =
                                      Map<String, dynamic>.from(found as Map);
                                });
                              },
                            ),
                          ),
                        )
                      else ...[
                        _buildModalInput(
                          t,
                          controller: customProdCtrl,
                          label: 'Product Name',
                          hint: 'Enter item name',
                          icon: Icons.shopping_bag_outlined,
                        ),
                        const SizedBox(height: 8),
                        _buildModalInput(
                          t,
                          controller: customPriceCtrl,
                          label: 'Unit Price (৳)',
                          hint: '500',
                          icon: Icons.payments_outlined,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QUANTITY',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: t.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: t.inputBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: t.cardBorder),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          if (quantity > 1) {
                                            setModalState(() => quantity--);
                                          }
                                        },
                                        icon: Icon(Icons.remove_rounded,
                                            color: t.primaryText, size: 18),
                                      ),
                                      Text(
                                        '$quantity',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: t.primaryText,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            setModalState(() => quantity++),
                                        icon: Icon(Icons.add_rounded,
                                            color: t.primaryColor, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildModalInput(
                              t,
                              controller: shippingCtrl,
                              label: 'Shipping Charge (৳)',
                              hint: '60',
                              icon: Icons.local_shipping_outlined,
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final pm in [
                            {'k': 'cod', 'l': 'Cash on Delivery (COD)'},
                            {'k': 'cash', 'l': 'Counter Cash (POS)'},
                          ])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => setModalState(
                                      () => paymentMethod = pm['k'].toString()),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                    decoration: paymentMethod == pm['k']
                                        ? _primaryDecoration(t, radius: 10)
                                        : BoxDecoration(
                                            color: t.inputBg,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border:
                                                Border.all(color: t.cardBorder),
                                          ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      pm['l'].toString(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: paymentMethod == pm['k']
                                            ? Colors.white
                                            : t.primaryText,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: t.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grand Total (incl. ৳${shipCost.toStringAsFixed(0)} shipping):',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              '৳${grandTotal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: t.primaryColor,
                              ),
                            ),
                          ],
                        ),
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
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final cName = nameCtrl.text.trim().isEmpty
                                      ? 'Walk-in Customer'
                                      : nameCtrl.text.trim();
                                  final cPhone = phoneCtrl.text.trim().isEmpty
                                      ? '01700000000'
                                      : phoneCtrl.text.trim();
                                  final cAddr = addressCtrl.text.trim().isEmpty
                                      ? 'Fulbarigate, Khulna'
                                      : addressCtrl.text.trim();

                                  final prodName = useCustomItem
                                      ? (customProdCtrl.text.trim().isEmpty
                                          ? 'Custom Order Item'
                                          : customProdCtrl.text.trim())
                                      : (selectedProduct?['name'] ?? 'Product')
                                          .toString();
                                  final prodId = useCustomItem
                                      ? (_cachedProducts.isNotEmpty
                                          ? (_cachedProducts.first as Map)['id']
                                          : 1)
                                      : selectedProduct?['id'];

                                  setModalState(() => isSubmitting = true);

                                  final payload = {
                                    'customer_name': cName,
                                    'customer_phone': cPhone,
                                    'shipping_address': cAddr,
                                    'payment_method': paymentMethod,
                                    'shipping_cost': shipCost,
                                    'items': [
                                      {
                                        'product_id': prodId,
                                        'quantity': quantity,
                                        'unit_price': unitPrice,
                                      }
                                    ],
                                  };

                                  await _submitNewOrderOnlineOrOffline(
                                    payload: payload,
                                    productName: prodName,
                                    unitPrice: unitPrice,
                                    quantity: quantity,
                                    shippingCost: shipCost,
                                    grandTotal: grandTotal,
                                  );

                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                          label: Text(
                            isSubmitting
                                ? 'Saving Order...'
                                : (_isOffline
                                    ? 'Save Order Offline (Auto-Sync Later)'
                                    : 'Place Order Now'),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalInput(
    CatalogThemeConfig t, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(
              color: t.primaryText, fontSize: 13, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
            prefixIcon: Icon(icon, color: t.primaryColor, size: 18),
            filled: true,
            fillColor: t.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Future<void> _submitNewOrderOnlineOrOffline({
    required Map payload,
    required String productName,
    required double unitPrice,
    required int quantity,
    required double shippingCost,
    required double grandTotal,
  }) async {
    final t = _theme;

    try {
      final res = await http
          .post(
            Uri.parse('${t.apiBase}/api/v1/orders/?subdomain=${t.subdomain}'),
            headers: {
              ...t.headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchOrdersFromBackend(silent: true);
        widget.onOrdersChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: t.primaryColor,
              behavior: SnackBarBehavior.floating,
              content: const Text(
                'নতুন অর্ডার সফলভাবে তৈরি হয়েছে!',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          );
        }
        return;
      }
      throw Exception('Failed status ${res.statusCode}');
    } catch (_) {
      final tempId =
          'OFFLINE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final displayOrder = {
        'id': tempId,
        'order_number': tempId,
        'status': 'pending',
        'customer_name': payload['customer_name'],
        'customer_phone': payload['customer_phone'],
        'full_address': payload['shipping_address'],
        'shipping_address': {
          'name': payload['customer_name'],
          'phone': payload['customer_phone'],
          'address': payload['shipping_address'],
        },
        'payment_method': payload['payment_method'],
        'shipping_cost': shippingCost,
        'subtotal': unitPrice * quantity,
        'total': grandTotal,
        'total_amount': grandTotal,
        'created_at': DateTime.now().toIso8601String(),
        'is_offline_created': true,
        'pending_sync': true,
        'items': [
          {
            'product_name': productName,
            'quantity': quantity,
            'unit_price': unitPrice,
            'total_price': unitPrice * quantity,
          }
        ],
      };

      _pendingNewOrdersQueue.insert(0, {
        'temp_id': tempId,
        'payload': payload,
        'display_order': displayOrder,
      });
      await _saveQueuesToStorage();

      if (mounted) {
        setState(() {
          _isOffline = true;
          _orders = [displayOrder, ..._orders];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'অফলাইন মোডে অর্ডার তৈরি হয়েছে! ইন্টারনেট এলেই সার্ভারে অটো-সিঙ্ক হবে।',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        );
      }
    }
  }

  List get _filteredOrders {
    final q = _searchQuery.trim().toLowerCase();

    final list = _orders.where((raw) {
      if (raw is! Map) return false;
      final status = (raw['status'] ?? 'pending').toString().toLowerCase();
      if (_selectedStatus != 'all' && status != _selectedStatus) {
        return false;
      }

      if (q.isNotEmpty) {
        final ordNo = (raw['order_number'] ?? '').toString().toLowerCase();
        final cName = _extractCustomerName(raw).toLowerCase();
        final cPhone = _extractCustomerPhone(raw).toLowerCase();
        final addr = _extractAddress(raw).toLowerCase();
        if (!ordNo.contains(q) &&
            !cName.contains(q) &&
            !cPhone.contains(q) &&
            !addr.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) {
      final ma = a as Map;
      final mb = b as Map;
      if (_sortBy == 'amount_high') {
        return _extractAmount(mb).compareTo(_extractAmount(ma));
      } else if (_sortBy == 'amount_low') {
        return _extractAmount(ma).compareTo(_extractAmount(mb));
      }
      return 0;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final filtered = _filteredOrders;

    int pendingCount = 0;
    int processingCount = 0;
    int shippedCount = 0;
    int deliveredCount = 0;
    double grossValue = 0.0;

    for (final raw in _orders) {
      if (raw is! Map) continue;
      final st = (raw['status'] ?? 'pending').toString().toLowerCase();
      final amt = _extractAmount(raw);
      if (st != 'cancelled') grossValue += amt;
      if (st == 'pending') pendingCount++;
      if (st == 'processing') processingCount++;
      if (st == 'shipped') shippedCount++;
      if (st == 'delivered' || st == 'completed') deliveredCount++;
    }

    final int totalPendingSync =
        _pendingStatusQueue.length + _pendingNewOrdersQueue.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_latestRealtimeOrderBanner != null)
          _buildRealtimeNewOrderBanner(t, _latestRealtimeOrderBanner!),

        if (_isOffline || totalPendingSync > 0)
          _buildOfflineAndSyncBanner(t, totalPendingSync),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: _primaryDecoration(t, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 22,
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
                                'Orders & Courier Dispatch',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _isOffline
                                    ? Colors.amber.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _isOffline
                                          ? Colors.amberAccent
                                          : const Color(0xFF4ADE80),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _isOffline ? 'OFFLINE READY' : 'LIVE REALTIME',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_orders.length} Total Orders • ৳${grossValue.toStringAsFixed(0)} Gross Value',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _syncOfflineQueuesWithBackend();
                      _fetchOrdersFromBackend();
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildHeaderStatBox('Pending', pendingCount),
                  const SizedBox(width: 8),
                  _buildHeaderStatBox('Processing', processingCount),
                  const SizedBox(width: 8),
                  _buildHeaderStatBox('Shipped', shippedCount),
                  const SizedBox(width: 8),
                  _buildHeaderStatBox('Delivered', deliveredCount),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _lastSyncedAt != null
                        ? 'Auto-syncs every 5s • Works offline'
                        : 'Offline cache enabled',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: _openCreateOrderModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_rounded,
                              color: t.primaryColor, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            '+ New Order (Online/Offline)',
                            style: TextStyle(
                              color: t.primaryColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search Order #, Customer, Phone, Address...',
                        hintStyle:
                            TextStyle(color: t.secondaryText, fontSize: 12),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: t.primaryColor, size: 19),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: t.inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    tooltip: 'Sort Orders',
                    color: t.cardBg,
                    surfaceTintColor: Colors.transparent,
                    onSelected: (val) =>
                        setState(() => _sortBy = val.toString()),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'newest',
                        child: Text(
                          'Newest First',
                          style: TextStyle(
                              color: t.primaryText,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'amount_high',
                        child: Text(
                          'Highest Amount (৳)',
                          style: TextStyle(
                              color: t.primaryText,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'amount_low',
                        child: Text(
                          'Lowest Amount (৳)',
                          style: TextStyle(
                              color: t.primaryText,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: t.inputBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: t.primaryColor, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final st in [
                      {'k': 'all', 'l': 'All Orders'},
                      {'k': 'pending', 'l': 'Pending'},
                      {'k': 'processing', 'l': 'Processing'},
                      {'k': 'shipped', 'l': 'Shipped'},
                      {'k': 'delivered', 'l': 'Delivered'},
                      {'k': 'cancelled', 'l': 'Cancelled'},
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(
                              () => _selectedStatus = st['k'].toString()),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: _selectedStatus == st['k']
                                ? _primaryDecoration(t, radius: 10)
                                : BoxDecoration(
                                    color: t.inputBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: t.cardBorder),
                                  ),
                            child: Text(
                              st['l'].toString(),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _selectedStatus == st['k']
                                    ? Colors.white
                                    : t.primaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_isLoading && _orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: t.primaryColor),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 42, color: t.primaryColor),
                const SizedBox(height: 10),
                Text(
                  'No Orders Found',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ],
            ),
          )
        else
          ...filtered.map((raw) {
            final ord = Map<String, dynamic>.from(raw as Map);
            return _buildOrderCard(t, ord);
          }),
      ],
    );
  }

  Widget _buildRealtimeNewOrderBanner(CatalogThemeConfig t, Map newOrd) {
    final ordNo = (newOrd['order_number'] ?? '').toString();
    final cName = _extractCustomerName(newOrd);
    final amt = _extractAmount(newOrd);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: Color(0xFF10B981), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'নতুন রিয়েলটাইম অর্ডার এসেছে! (#$ordNo)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                Text(
                  '$cName • Bill: ৳${amt.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: t.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _latestRealtimeOrderBanner = null),
            icon: Icon(Icons.close_rounded, color: t.secondaryText, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineAndSyncBanner(CatalogThemeConfig t, int pendingCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.3),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOffline
                      ? 'Offline Mode Active (Working from Local Cache)'
                      : 'Pending Offline Actions Ready to Sync',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                Text(
                  pendingCount > 0
                      ? '$pendingCount offline change(s) queued — will sync automatically when online'
                      : 'You can view orders, change status & create new orders offline.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          if (pendingCount > 0)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isSyncingQueue
                  ? null
                  : () => _syncOfflineQueuesWithBackend(silent: false),
              icon: const Icon(Icons.sync_rounded, size: 15),
              label: Text(
                _isSyncingQueue ? 'Syncing...' : 'Sync ($pendingCount)',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatBox(String label, int count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(CatalogThemeConfig t, Map<String, dynamic> ord) {
    final String ordNo = (ord['order_number'] ?? ord['id'] ?? '').toString();
    final String status = (ord['status'] ?? 'pending').toString().toLowerCase();
    final String custName = _extractCustomerName(ord);
    final String custPhone = _extractCustomerPhone(ord);
    final String address = _extractAddress(ord);
    final double amount = _extractAmount(ord);
    final String payMethod =
        (ord['payment_method'] ?? 'cod').toString().toUpperCase();
    final String dateStr = _formatDate(ord['created_at']);
    final List items = (ord['items'] is List) ? (ord['items'] as List) : [];
    final bool pendingSync = ord['pending_sync'] == true;
    final Color statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pendingSync ? const Color(0xFFF59E0B) : t.cardBorder,
          width: pendingSync ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: _primaryDecoration(t, radius: 10),
                      child: Text(
                        ordNo.startsWith('#') ? ordNo : '#$ordNo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (pendingSync) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'OFFLINE QUEUED',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton(
                tooltip: 'Change Order Status (Online & Offline)',
                color: t.cardBg,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: t.cardBorder),
                ),
                onSelected: (val) =>
                    _updateOrderStatus(ord, val.toString()),
                itemBuilder: (_) => [
                  for (final s in [
                    'pending',
                    'processing',
                    'shipped',
                    'delivered',
                    'cancelled',
                  ])
                    PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: _statusColor(s),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.toUpperCase(),
                            style: TextStyle(
                              color: t.primaryText,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), color: statusColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_drop_down_rounded,
                          color: statusColor, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      custName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$custPhone • $address',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: t.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$dateStr • ${items.isNotEmpty ? items.length : 1} item(s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '৳${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: t.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Text(
                      payMethod,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: t.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: t.cardBorder, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionChip(
                  t,
                  icon: Icons.receipt_long_rounded,
                  label: 'Invoice',
                  onTap: () => _openOrderDetailAndCourierModal(
                    ord,
                    initialTab: 'invoice',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildActionChip(
                  t,
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  onTap: () => _openOrderNotifyModal(ord, channel: 'sms'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildActionChip(
                  t,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  onTap: () => _openOrderNotifyModal(ord, channel: 'email'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _openOrderDetailAndCourierModal(
                    ord,
                    initialTab: 'courier',
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: _primaryDecoration(t, radius: 10),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'SEND STEADFAST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(
    CatalogThemeConfig t, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: t.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: t.primaryText),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}