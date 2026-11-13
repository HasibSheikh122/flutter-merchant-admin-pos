// lib/widgets/catalog/product_log_modal.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'catalog_theme_scope.dart';

class ProductLogModal extends StatefulWidget {
  final CatalogThemeConfig theme;
  final Map<String, dynamic>? product;
  final String initialTab; // 'activity' | 'tp' | 'notes'
  final VoidCallback? onChanged;

  const ProductLogModal({
    super.key,
    required this.theme,
    this.product,
    this.initialTab = 'activity',
    this.onChanged,
  });

  @override
  State<ProductLogModal> createState() => _ProductLogModalState();
}

class _ProductLogModalState extends State<ProductLogModal> {
  late String _activeTab;
  bool _isLoading = true;
  bool _isActionLoading = false;

  List<dynamic> _activityLogs = [];
  String _actionFilter = 'all';

  List<dynamic> _tpLogs = [];
  String? _currentTp;
  String? _sellingPrice;
  int _tpPage = 1;
  int _tpTotalPages = 1;
  final TextEditingController _newTpCtrl = TextEditingController();
  final TextEditingController _tpRemarkCtrl = TextEditingController();

  List<dynamic> _notes = [];
  final TextEditingController _noteTitleCtrl = TextEditingController();
  final TextEditingController _noteBodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    if (widget.product != null) {
      _currentTp =
          (widget.product!['trade_price'] ?? widget.product!['cost_price'] ?? '')
              .toString();
      _sellingPrice = (widget.product!['price'] ?? '').toString();
      _newTpCtrl.text = _currentTp ?? '';
    }
    _fetchCurrentTabData();
  }

  @override
  void dispose() {
    _newTpCtrl.dispose();
    _tpRemarkCtrl.dispose();
    _noteTitleCtrl.dispose();
    _noteBodyCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : widget.theme.primaryColor,
        content: Text(
          msg,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _fetchCurrentTabData() async {
    setState(() => _isLoading = true);
    try {
      if (_activeTab == 'tp' && widget.product != null) {
        final id = widget.product!['id'];
        final res = await http.get(
          Uri.parse(
              '${widget.theme.apiBase}/api/v1/products/$id/tp-logs/?subdomain=${widget.theme.subdomain}&page=$_tpPage'),
          headers: widget.theme.headers,
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map) {
            _currentTp = data['current_tp']?.toString();
            _sellingPrice = data['selling_price']?.toString();
            _tpTotalPages =
                int.tryParse((data['total_pages'] ?? 1).toString()) ?? 1;
            _tpLogs = (data['results'] is List) ? data['results'] : [];
          }
        }
      } else if (_activeTab == 'notes' && widget.product != null) {
        final id = widget.product!['id'];
        final res = await http.get(
          Uri.parse(
              '${widget.theme.apiBase}/api/v1/products/$id/notes/?subdomain=${widget.theme.subdomain}'),
          headers: widget.theme.headers,
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) _notes = data;
        }
      } else {
        String url =
            '${widget.theme.apiBase}/api/v1/products/logs/?subdomain=${widget.theme.subdomain}';
        if (widget.product != null) {
          url += '&entity_type=product&entity_id=${widget.product!['id']}';
        }
        if (_actionFilter != 'all') {
          url += '&action_type=$_actionFilter';
        }
        final res =
            await http.get(Uri.parse(url), headers: widget.theme.headers);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) _activityLogs = data;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTpQuick() async {
    if (widget.product == null) return;
    final String rawTp = _newTpCtrl.text.trim();
    if (rawTp.isEmpty || double.tryParse(rawTp) == null) {
      _showSnack('Sothik TP (Trade Price) likhun!', isError: true);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final id = widget.product!['id'];
      final res = await http.post(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/products/$id/tp-logs/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
        body: jsonEncode({
          'trade_price': rawTp,
          'remark': _tpRemarkCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 200) {
        _tpRemarkCtrl.clear();
        _showSnack('TP (Trade Price) update o log record hoyeche!');
        widget.onChanged?.call();
        await _fetchCurrentTabData();
      } else {
        _showSnack('TP update korte somossha hoyeche', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _addProductNote() async {
    if (widget.product == null) return;
    if (_noteTitleCtrl.text.trim().isEmpty &&
        _noteBodyCtrl.text.trim().isEmpty) {
      _showSnack('Note-er title ba biboron likhun!', isError: true);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final id = widget.product!['id'];
      final res = await http.post(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/products/$id/notes/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
        body: jsonEncode({
          'title': _noteTitleCtrl.text.trim(),
          'note': _noteBodyCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        _noteTitleCtrl.clear();
        _noteBodyCtrl.clear();
        _showSnack('Product Note add kora hoyeche!');
        widget.onChanged?.call();
        await _fetchCurrentTabData();
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteNote(int noteId) async {
    if (widget.product == null) return;
    final id = widget.product!['id'];
    try {
      final res = await http.delete(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/products/$id/notes/$noteId/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
      );
      if (res.statusCode == 200) {
        _showSnack('Note delete kora hoyeche.');
        widget.onChanged?.call();
        await _fetchCurrentTabData();
      }
    } catch (_) {}
  }

  Future<void> _restoreDeletedItem(int logId) async {
    setState(() => _isActionLoading = true);
    try {
      final res = await http.post(
        Uri.parse(
            '${widget.theme.apiBase}/api/v1/products/logs/$logId/restore/?subdomain=${widget.theme.subdomain}'),
        headers: widget.theme.headers,
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _showSnack(data['message'] ?? 'Item shofolbhabe Restore hoyeche!');
        widget.onChanged?.call();
        await _fetchCurrentTabData();
      } else {
        _showSnack(data['error'] ?? 'Restore kora jayni', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final String prodName = widget.product != null
        ? (widget.product!['name'] ?? 'Product').toString()
        : 'Catalog Activity & Audit Logs';

    return Dialog(
      backgroundColor: t.cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.cardBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: t.useGradient ? null : t.primaryColor,
                gradient: t.useGradient ? t.brandGradient : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prodName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.product != null
                              ? 'Product Logs, TP History & Notes'
                              : 'All Product & Category Changes + Restore',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            if (widget.product != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.cardBorder)),
                ),
                child: Row(
                  children: [
                    _buildTabBtn('activity', 'Activity Log', Icons.history),
                    const SizedBox(width: 8),
                    _buildTabBtn(
                        'tp', 'TP (কেনা দাম) Log', Icons.price_change_outlined),
                    const SizedBox(width: 8),
                    _buildTabBtn(
                        'notes', 'Product Notes', Icons.sticky_note_2_outlined),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All Logs'),
                    _buildFilterChip('create', 'Created'),
                    _buildFilterChip('update', 'Updated'),
                    _buildFilterChip('tp_update', 'TP Logs'),
                    _buildFilterChip('stock_update', 'Stock'),
                    _buildFilterChip('delete', 'Deleted / Restore'),
                  ],
                ),
              ),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: t.primaryColor),
                    )
                  : _activeTab == 'tp' && widget.product != null
                      ? _buildTpLogSection()
                      : _activeTab == 'notes' && widget.product != null
                          ? _buildNotesSection()
                          : _buildActivityListSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBtn(String id, String label, IconData icon) {
    final t = widget.theme;
    final bool selected = _activeTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTab = id);
          _fetchCurrentTabData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? (t.useGradient ? null : t.primaryColor) : t.inputBg,
            gradient: (selected && t.useGradient) ? t.brandGradient : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? t.primaryColor : t.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14, color: selected ? Colors.white : t.primaryText),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : t.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String actionKey, String label) {
    final t = widget.theme;
    final bool selected = _actionFilter == actionKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: selected,
        selectedColor: t.primaryColor,
        backgroundColor: t.inputBg,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : t.primaryText,
          ),
        ),
        onSelected: (_) {
          setState(() => _actionFilter = actionKey);
          _fetchCurrentTabData();
        },
      ),
    );
  }

  Widget _buildTpLogSection() {
    final t = widget.theme;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current TP: ৳${_currentTp ?? "Not Set"}  •  Selling Price: ৳${_sellingPrice ?? "0"}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTpCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'New TP (৳)',
                        labelStyle:
                            TextStyle(color: t.secondaryText, fontSize: 11),
                        filled: true,
                        fillColor: t.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _tpRemarkCtrl,
                      style: TextStyle(color: t.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Remark (Optional)',
                        labelStyle:
                            TextStyle(color: t.secondaryText, fontSize: 11),
                        filled: true,
                        fillColor: t.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading ? null : _updateTpQuick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text(
                    'Update TP & Record Log',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'TP Change History (Page $_tpPage of $_tpTotalPages)',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900, color: t.primaryText),
        ),
        const SizedBox(height: 8),
        if (_tpLogs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Kono TP history paoa jayni.',
                  style: TextStyle(color: t.secondaryText, fontSize: 12)),
            ),
          )
        else
          ..._tpLogs.map((log) => _buildLogItemCard(log)),
      ],
    );
  }

  Widget _buildNotesSection() {
    final t = widget.theme;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Product Note',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteTitleCtrl,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Note Title',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 11),
                  filled: true,
                  fillColor: t.cardBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteBodyCtrl,
                maxLines: 2,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Note Details...',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 11),
                  filled: true,
                  fillColor: t.cardBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading ? null : _addProductNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.note_add_outlined, size: 16),
                  label: const Text(
                    'Save Product Note',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_notes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Ei product-e kono note nei.',
                  style: TextStyle(color: t.secondaryText, fontSize: 12)),
            ),
          )
        else
          ..._notes.map((n) {
            final int noteId = int.tryParse((n['id'] ?? 0).toString()) ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_rounded,
                      color: t.primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (n['title'] ?? 'Note').toString(),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: t.primaryText),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (n['note'] ?? '').toString(),
                          style:
                              TextStyle(fontSize: 12, color: t.secondaryText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By ${(n['actor_name'] ?? 'Admin')} • ${(n['created_at'] ?? '').toString().split('T').first}',
                          style:
                              TextStyle(fontSize: 10, color: t.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 18),
                    onPressed: () => _deleteNote(noteId),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildActivityListSection() {
    final t = widget.theme;
    if (_activityLogs.isEmpty) {
      return Center(
        child: Text(
          'Kono activity log paoa jayni.',
          style: TextStyle(color: t.secondaryText, fontSize: 12.5),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _activityLogs.length,
      itemBuilder: (ctx, i) => _buildLogItemCard(_activityLogs[i]),
    );
  }

  Widget _buildLogItemCard(dynamic log) {
    final t = widget.theme;
    final int logId = int.tryParse((log['id'] ?? 0).toString()) ?? 0;
    final String entityName = (log['entity_name'] ?? 'Item').toString();
    final String actionType = (log['action_type'] ?? 'update').toString();
    final String summary = (log['summary'] ?? '').toString();
    final String actor = (log['actor_name'] ?? 'Merchant Admin').toString();
    final String createdAt = (log['created_at'] ?? '')
        .toString()
        .replaceFirst('T', ' ')
        .split('.')
        .first;
    final bool isRestorable = log['is_restorable'] == true;
    final bool isRestored = log['is_restored'] == true;
    final List<dynamic> changes =
        (log['changes'] is List) ? log['changes'] : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: actionType == 'delete'
              ? Colors.redAccent.withValues(alpha: 0.4)
              : t.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actionType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: t.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
              ),
              if (isRestorable && !isRestored)
                ElevatedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () => _restoreDeletedItem(logId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.restore_rounded, size: 14),
                  label: const Text('Restore',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(fontSize: 11.5, color: t.primaryText),
          ),
          if (changes.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...changes.take(4).map((c) {
              if (c is! Map) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${c['field']}: ${c['old']} ➔ ${c['new']}',
                  style: TextStyle(fontSize: 10.5, color: t.secondaryText),
                ),
              );
            }),
          ],
          const SizedBox(height: 4),
          Text(
            '$actor • $createdAt',
            style: TextStyle(fontSize: 9.5, color: t.secondaryText),
          ),
        ],
      ),
    );
  }
}