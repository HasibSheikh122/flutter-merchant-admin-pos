// lib/widgets/catalog/category_list_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'catalog_theme_scope.dart';
import 'category_form_modal.dart';
import 'product_log_modal.dart';

class CategoryListView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onOpenProductList;
  final VoidCallback? onCatalogChanged;

  const CategoryListView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.onOpenProductList,
    this.onCatalogChanged,
  });

  @override
  State<CategoryListView> createState() => _CategoryListViewState();
}

class _CategoryListViewState extends State<CategoryListView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;
  List<dynamic> _categories = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant CategoryListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initAndFetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initAndFetch() async {
    final loadedTheme = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() {
      _theme = loadedTheme;
      _isLoading = true;
    });

    try {
      final res = await http.get(
        Uri.parse(
            '${_theme.apiBase}/api/v1/products/categories/?subdomain=${_theme.subdomain}&all_shops=true'),
        headers: _theme.headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          _categories = data;
        } else if (data is Map && data['results'] is List) {
          _categories = data['results'];
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : _theme.primaryColor,
        content: Text(
          msg,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final dynamic confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _theme.cardBg,
        title: Text('Delete Category?',
            style: TextStyle(
                color: _theme.primaryText, fontWeight: FontWeight.w900)),
        content: Text(
          '"${cat['name']}" category delete korben? (Pore Log theke Restore kora jabe)',
          style: TextStyle(color: _theme.secondaryText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final id = cat['id'];
      final res = await http.delete(
        Uri.parse(
            '${_theme.apiBase}/api/v1/products/categories/$id/?subdomain=${_theme.subdomain}'),
        headers: _theme.headers,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _showSnack('Category delete hoyeche.');
        widget.onCatalogChanged?.call();
        await _initAndFetch();
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _openAddOrEditCategory({Map<String, dynamic>? category}) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormModal(
        theme: _theme,
        existingCategory: category,
        onSaved: () {
          widget.onCatalogChanged?.call();
          _initAndFetch();
        },
      ),
    );
  }

  void _openCatalogLogs() {
    showDialog(
      context: context,
      builder: (_) => ProductLogModal(
        theme: _theme,
        onChanged: () {
          widget.onCatalogChanged?.call();
          _initAndFetch();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final filtered = _categories.where((c) {
      if (c is! Map) return false;
      final String name = (c['name'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.useGradient
                          ? null
                          : t.primaryColor.withValues(alpha: 0.15),
                      gradient: t.useGradient ? t.brandGradient : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.category_rounded,
                      color: t.useGradient ? Colors.white : t.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categories Management (${_categories.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          'Create, Edit, AI Auto Icon, SEO & Restore',
                          style:
                              TextStyle(fontSize: 11, color: t.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _initAndFetch,
                    icon: Icon(Icons.refresh_rounded, color: t.primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: () => _openAddOrEditCategory(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: t.useGradient ? null : t.primaryColor,
                        gradient: t.useGradient ? t.brandGradient : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            '+ Add Category (AI)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _openCatalogLogs,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: t.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 16, color: t.primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            'Category Logs & Restore',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.onOpenProductList != null)
                    InkWell(
                      onTap: widget.onOpenProductList,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: t.inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 16, color: t.primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Products List',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Field
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: t.primaryColor, size: 18),
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_isLoading)
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
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.cardBorder),
            ),
            child: Center(
              child: Text(
                'Kono Category paoa jayni.',
                style: TextStyle(color: t.secondaryText, fontSize: 13),
              ),
            ),
          )
        else
          ...filtered.map((rawCat) {
            final Map<String, dynamic> c =
                Map<String, dynamic>.from(rawCat as Map);
            final String name = (c['name'] ?? 'Category').toString();
            final String rawIcon = (c['icon'] ?? '').toString().trim();
            final String iconStr = (rawIcon.isEmpty || rawIcon == '🛍️')
                ? CatalogThemeConfig.guessCategoryIcon(name)
                : rawIcon;
            final String shopName =
                (c['shop_name'] ?? 'Main Store').toString();
            final int prodCount =
                int.tryParse((c['product_count'] ?? 0).toString()) ?? 0;
            final bool showHome = c['show_on_homepage'] ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.useGradient
                          ? null
                          : t.primaryColor.withValues(alpha: 0.14),
                      gradient: t.useGradient ? t.brandGradient : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      iconStr,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
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
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.primaryColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$prodCount Products',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.inputBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: t.cardBorder),
                              ),
                              child: Text(
                                shopName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: t.secondaryText,
                                ),
                              ),
                            ),
                            if (showHome)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Homepage',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit Category',
                    onPressed: () => _openAddOrEditCategory(category: c),
                    icon: Icon(Icons.edit_outlined,
                        color: t.primaryColor, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Delete Category',
                    onPressed: () => _deleteCategory(c),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}