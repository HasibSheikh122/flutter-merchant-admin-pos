// lib/widgets/catalog/product_list_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'catalog_theme_scope.dart';
import 'product_form_modal.dart';
import 'product_log_modal.dart';
import '../inventory/barcode_scanner_view.dart';

class ProductListView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onOpenCategoryList;
  final VoidCallback? onCatalogChanged;

  const ProductListView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.onOpenCategoryList,
    this.onCatalogChanged,
  });

  @override
  State createState() => _ProductListViewState();
}

class _ProductListViewState extends State {
  @override
  ProductListView get widget => super.widget as ProductListView;

  // Static In-Memory Cache so switching tabs or background notification timers never re-fetch products
  static List _cachedProducts = [];
  static List _cachedCategories = [];
  static String _cachedSubdomain = '';

  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;
  bool _isRefreshing = false;

  List _products = [];
  List _categories = [];
  String _searchQuery = '';
  int? _selectedCategoryId;

  // Pagination State (20 products per page so phone never lags)
  static const int _pageSize = 20;
  int _currentPage = 1;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCatalog(forceNetwork: false);
  }

  @override
  void didUpdateWidget(covariant ProductListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update theme colors if dark mode or brand color changed — NEVER re-fetch products!
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _updateThemeOnly();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future _updateThemeOnly() async {
    final loadedTheme = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() {
      _theme = loadedTheme;
    });
  }

  Future _initCatalog({bool forceNetwork = true}) async {
    final loadedTheme = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;

    // If we already have cached products for this store and forceNetwork is false, show immediately without loading!
    if (!forceNetwork &&
        _cachedProducts.isNotEmpty &&
        _cachedSubdomain == loadedTheme.subdomain) {
      setState(() {
        _theme = loadedTheme;
        _products = _cachedProducts;
        _categories = _cachedCategories;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _theme = loadedTheme;
      if (_products.isEmpty) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
    });

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse(
                  '${_theme.apiBase}/api/v1/products/?subdomain=${_theme.subdomain}&admin=true&include_inactive=true'),
              headers: _theme.headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '${_theme.apiBase}/api/v1/products/categories/?subdomain=${_theme.subdomain}&all_shops=true'),
              headers: _theme.headers,
            )
            .catchError((_) => http.Response('[]', 500)),
      ]);

      if (results[0].statusCode == 200) {
        final pData = jsonDecode(results[0].body);
        if (pData is List) {
          _products = pData;
        } else if (pData is Map && pData['results'] is List) {
          _products = pData['results'] as List;
        }
        _cachedProducts = _products;
        _cachedSubdomain = _theme.subdomain;
      }

      if (results[1].statusCode == 200) {
        final cData = jsonDecode(results[1].body);
        if (cData is List) {
          _categories = cData;
        } else if (cData is Map && cData['results'] is List) {
          _categories = cData['results'] as List;
        }
        _cachedCategories = _categories;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
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

  Future _deleteProduct(Map product) async {
    final dynamic confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _theme.cardBg,
        title: Text('Delete Product?',
            style: TextStyle(
                color: _theme.primaryText, fontWeight: FontWeight.w900)),
        content: Text(
          '"${product['name']}" delete korben? (Chayle pore Product Log theke Restore korte parben)',
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
      final id = product['id'];
      final res = await http.delete(
        Uri.parse(
            '${_theme.apiBase}/api/v1/products/$id/?subdomain=${_theme.subdomain}'),
        headers: _theme.headers,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _showSnack('Product delete kora hoyeche (Log theke Restore kora jabe).');
        setState(() {
          _products.removeWhere((item) => item is Map && item['id'] == id);
          _cachedProducts = _products;
        });
      }
    } catch (e) {
      _showSnack('Delete error: $e', isError: true);
    }
  }

  void _openAddOrEditProduct({Map? product}) {
    showDialog(
      context: context,
      builder: (_) => ProductFormModal(
        theme: _theme,
        existingProduct:
            product != null ? Map<String, dynamic>.from(product) : null,
        categories: _categories,
        onSaved: () {
          _initCatalog(forceNetwork: true);
        },
      ),
    );
  }

  void _openProductLogModal({Map? product, String initialTab = 'activity'}) {
    showDialog(
      context: context,
      builder: (_) => ProductLogModal(
        theme: _theme,
        product: product != null ? Map<String, dynamic>.from(product) : null,
        initialTab: initialTab,
        onChanged: () {
          _initCatalog(forceNetwork: true);
        },
      ),
    );
  }

  List get _filteredProducts {
    return _products.where((p) {
      if (p is! Map) return false;
      final String name = (p['name'] ?? '').toString().toLowerCase();
      final String sku = (p['sku'] ?? '').toString().toLowerCase();
      if (_searchQuery.isNotEmpty &&
          !name.contains(_searchQuery.toLowerCase()) &&
          !sku.contains(_searchQuery.toLowerCase())) {
        return false;
      }

      if (_selectedCategoryId != null) {
        final List cIds =
            (p['category_ids'] is List) ? (p['category_ids'] as List) : [];
        final int? primaryCat =
            int.tryParse((p['category_id'] ?? '').toString());
        if (!cIds.contains(_selectedCategoryId) &&
            primaryCat != _selectedCategoryId) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final List filtered = _filteredProducts;

    final int totalItems = filtered.length;
    final int totalPages =
        totalItems == 0 ? 1 : ((totalItems + _pageSize - 1) ~/ _pageSize);
    final int safePage = _currentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : (startIndex + _pageSize);
    final List paginatedItems = totalItems == 0
        ? []
        : filtered.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header & Action Buttons Bar
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
                      Icons.inventory_2_rounded,
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
                          'Products Catalog (${_products.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          'Add, Edit, AI Copywriter, SKU Barcode/QR Print & Logs',
                          style:
                              TextStyle(fontSize: 11, color: t.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  if (_isRefreshing)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.primaryColor,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Refresh Products',
                    onPressed: () => _initCatalog(forceNetwork: true),
                    icon: Icon(Icons.refresh_rounded, color: t.primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Main Action Buttons Row inside Product List
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTopActionButton(
                    label: '+ Add Product (AI)',
                    icon: Icons.add_circle_outline_rounded,
                    isPrimaryGradient: true,
                    onTap: () => _openAddOrEditProduct(),
                  ),
                  _buildTopActionButton(
                    label: 'Product Logs & Restore',
                    icon: Icons.history_rounded,
                    isPrimaryGradient: false,
                    onTap: () => _openProductLogModal(),
                  ),
                  if (widget.onOpenCategoryList != null)
                    _buildTopActionButton(
                      label: 'Categories (${_categories.length})',
                      icon: Icons.category_outlined,
                      isPrimaryGradient: false,
                      onTap: widget.onOpenCategoryList!,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Input
              TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  setState(() {
                    _searchQuery = v.trim();
                    _currentPage = 1;
                  });
                },
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search product by name or SKU...',
                  hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: t.primaryColor, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _searchQuery = '';
                              _currentPage = 1;
                            });
                          },
                        )
                      : null,
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
              const SizedBox(height: 10),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill('All', _selectedCategoryId == null, () {
                      setState(() {
                        _selectedCategoryId = null;
                        _currentPage = 1;
                      });
                    }),
                    ..._categories.map((c) {
                      final int cId =
                          int.tryParse((c['id'] ?? 0).toString()) ?? 0;
                      return _buildFilterPill(
                        (c['name'] ?? 'Category').toString(),
                        _selectedCategoryId == cId,
                        () {
                          setState(() {
                            _selectedCategoryId = cId;
                            _currentPage = 1;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Product Cards List
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
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 42, color: t.primaryColor),
                const SizedBox(height: 10),
                Text(
                  'Kono Product paoa jayni',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText),
                ),
                const SizedBox(height: 12),
                _buildTopActionButton(
                  label: '+ Add First Product',
                  icon: Icons.add,
                  isPrimaryGradient: true,
                  onTap: () => _openAddOrEditProduct(),
                ),
              ],
            ),
          )
        else ...[
          ...paginatedItems.map((rawProd) {
            final Map p = Map.from(rawProd as Map);
            return _buildProductCard(p);
          }),
          if (totalPages > 1)
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: safePage > 1
                        ? () => setState(() => _currentPage = safePage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text(
                      'Prev',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'Page $safePage of $totalPages (${startIndex + 1}-$endIndex of $totalItems)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: totalPages > safePage
                        ? () => setState(() => _currentPage = safePage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text(
                      'Next',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildTopActionButton({
    required String label,
    required IconData icon,
    required bool isPrimaryGradient,
    required VoidCallback onTap,
  }) {
    final t = _theme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isPrimaryGradient
              ? (t.useGradient ? null : t.primaryColor)
              : t.inputBg,
          gradient:
              (isPrimaryGradient && t.useGradient) ? t.brandGradient : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimaryGradient ? t.primaryColor : t.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimaryGradient ? Colors.white : t.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isPrimaryGradient ? Colors.white : t.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, bool selected, VoidCallback onTap) {
    final t = _theme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                selected ? (t.useGradient ? null : t.primaryColor) : t.inputBg,
            gradient: (selected && t.useGradient) ? t.brandGradient : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? t.primaryColor : t.cardBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : t.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map p) {
    final t = _theme;
    final String name = (p['name'] ?? 'Product').toString();
    final String sku = (p['sku'] ?? '').toString().trim().isNotEmpty
        ? (p['sku']).toString().trim()
        : 'SKU-${p['id'] ?? 1001}';
    final String unit = (p['unit'] ?? '1 pc').toString();
    final String price = (p['price'] ?? '0').toString();
    final String? comparePrice = p['compare_price']?.toString();
    final String? tpPrice = (p['trade_price'] ?? p['cost_price'])?.toString();
    final int stock = int.tryParse((p['stock_quantity'] ?? 0).toString()) ?? 0;
    final int notesCount =
        int.tryParse((p['notes_count'] ?? 0).toString()) ?? 0;
    final String catName = (p['category_name'] ?? 'General').toString();
    final String? imgUrl = p['primary_image']?.toString();
    final bool isActive = p['is_active'] ?? true;
    final String emojiIcon =
        CatalogThemeConfig.guessCategoryIcon('$catName $name');

    return Container(
      key: ValueKey('prod_card_${p['id'] ?? sku}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? t.cardBorder
              : Colors.redAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Thumbnail with Memory Cache (140px) & Gapless Playback
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.cardBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: (imgUrl != null && imgUrl.isNotEmpty)
                      ? Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          width: 56,
                          height: 56,
                          cacheWidth: 140,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => Text(emojiIcon,
                              style: const TextStyle(fontSize: 24)),
                        )
                      : Text(emojiIcon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: stock > 0
                                ? t.primaryColor.withValues(alpha: 0.14)
                                : Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            stock > 0 ? 'Stock: $stock' : 'Out of Stock',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color:
                                  stock > 0 ? t.primaryColor : Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'SKU: $sku  •  Unit: $unit  •  $catName',
                      style: TextStyle(fontSize: 11, color: t.secondaryText),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '৳$price',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: t.primaryColor,
                          ),
                        ),
                        if (comparePrice != null && comparePrice.isNotEmpty)
                          Text(
                            '৳$comparePrice',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.secondaryText,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'TP: ৳${(tpPrice != null && tpPrice.isNotEmpty) ? tpPrice : "N/A"}',
                            style: TextStyle(
                              fontSize: 10.5,
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
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: t.cardBorder, height: 1),
          const SizedBox(height: 10),

          // Action Buttons Row on every Product Card (Includes QR / Barcode Print)
          Row(
            children: [
              Expanded(
                child: _buildCardActionBtn(
                  label: 'Edit / AI',
                  icon: Icons.auto_awesome_outlined,
                  color: t.primaryColor,
                  onTap: () => _openAddOrEditProduct(product: p),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCardActionBtn(
                  label: 'QR / Barcode',
                  icon: Icons.qr_code_2_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    SkuBarcodeQrPrintModal.show(
                      context,
                      product: Map<String, dynamic>.from(p),
                      theme: t,
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCardActionBtn(
                  label: 'TP / Log',
                  icon: Icons.price_change_outlined,
                  color: Colors.amber.shade700,
                  onTap: () =>
                      _openProductLogModal(product: p, initialTab: 'tp'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCardActionBtn(
                  label: notesCount > 0 ? 'Notes ($notesCount)' : 'Notes',
                  icon: Icons.sticky_note_2_outlined,
                  color: Colors.blueAccent,
                  onTap: () =>
                      _openProductLogModal(product: p, initialTab: 'notes'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Delete Product',
                onPressed: () => _deleteProduct(p),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}