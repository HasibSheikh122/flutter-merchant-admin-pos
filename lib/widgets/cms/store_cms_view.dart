// lib/widgets/cms/store_cms_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';

class StoreCmsView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final VoidCallback? onDataChanged;

  const StoreCmsView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.initialTab = 'testimonials',
    this.onDataChanged,
  });

  @override
  State<StoreCmsView> createState() => _StoreCmsViewState();
}

class _StoreCmsViewState extends State<StoreCmsView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _loading = true;
  String _activeTab = 'testimonials';

  List _testimonials = [];
  List _blogs = [];
  List _faqs = [];
  List _gallery = [];

  @override
  void initState() {
    super.initState();
    _syncTab(widget.initialTab);
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant StoreCmsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _syncTab(widget.initialTab);
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
    }
  }

  void _syncTab(String raw) {
    final String clean = raw.trim().toLowerCase();
    if (clean == 'blogs') {
      _activeTab = 'blogs';
    } else if (clean == 'faqs') {
      _activeTab = 'faqs';
    } else if (clean == 'store_gallery') {
      _activeTab = 'store_gallery';
    } else {
      _activeTab = 'testimonials';
    }
  }

  Future<void> _reloadTheme() async {
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() => _theme = t);
  }

  Future<void> _initAndFetch() async {
    setState(() => _loading = true);
    final t = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (!mounted) return;
    setState(() => _theme = t);
    await _fetchAllCmsData();
  }

  Future<void> _fetchAllCmsData() async {
    setState(() => _loading = true);
    final String sub = Uri.encodeComponent(_theme.subdomain);
    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse(
                '${_theme.apiBase}/api/v1/stores/testimonials/?subdomain=$sub',
              ),
              headers: _theme.headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                '${_theme.apiBase}/api/v1/stores/blogs/?subdomain=$sub',
              ),
              headers: _theme.headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                '${_theme.apiBase}/api/v1/stores/faqs/?subdomain=$sub',
              ),
              headers: _theme.headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                '${_theme.apiBase}/api/v1/stores/gallery/?subdomain=$sub',
              ),
              headers: _theme.headers,
            )
            .catchError((_) => http.Response('[]', 500)),
      ]);

      if (!mounted) return;
      setState(() {
        _testimonials = _extractList(results[0].bodyBytes);
        _blogs = _extractList(results[1].bodyBytes);
        _faqs = _extractList(results[2].bodyBytes);
        _gallery = _extractList(results[3].bodyBytes);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List _extractList(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['results'] is List) {
        return decoded['results'];
      }
    } catch (_) {}
    return [];
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : _theme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: t.useGradient ? t.brandGradient : null,
                          color: t.useGradient ? null : t.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.article_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Store Content Management (CMS)',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: t.primaryText,
                            ),
                          ),
                          Text(
                            'Customer Testimonials, News & Blogs, Store FAQs & Lookbook Gallery',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _fetchAllCmsData,
                    icon: Icon(Icons.refresh_rounded, color: t.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    {
                      'id': 'testimonials',
                      'label': 'Testimonials (${_testimonials.length})',
                      'icon': Icons.format_quote_rounded
                    },
                    {
                      'id': 'blogs',
                      'label': 'News & Blogs (${_blogs.length})',
                      'icon': Icons.newspaper_rounded
                    },
                    {
                      'id': 'faqs',
                      'label': 'Store FAQs (${_faqs.length})',
                      'icon': Icons.help_outline_rounded
                    },
                    {
                      'id': 'store_gallery',
                      'label': 'Store Gallery (${_gallery.length})',
                      'icon': Icons.add_photo_alternate_outlined
                    },
                  ].map((tab) {
                    final String id = tab['id'].toString();
                    final bool sel = _activeTab == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _activeTab = id),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            gradient:
                                (sel && t.useGradient) ? t.brandGradient : null,
                            color: sel
                                ? (t.useGradient ? null : t.primaryColor)
                                : t.inputBg,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: sel ? t.primaryColor : t.cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                tab['icon'] as IconData,
                                size: 15,
                                color: sel ? Colors.white : t.secondaryText,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                tab['label'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: sel ? Colors.white : t.primaryText,
                                ),
                              ),
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
        const SizedBox(height: 14),
        if (_loading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 50),
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: t.primaryColor),
          )
        else ...[
          if (_activeTab == 'testimonials') _buildTestimonialsSection(t),
          if (_activeTab == 'blogs') _buildBlogsSection(t),
          if (_activeTab == 'faqs') _buildFaqsSection(t),
          if (_activeTab == 'store_gallery') _buildStoreGallerySection(t),
        ],
      ],
    );
  }

  // 1. Testimonials
  Widget _buildTestimonialsSection(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Testimonials (${_testimonials.length})',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddTestimonialDialog(t),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Testimonial'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_testimonials.isEmpty)
            Text(
              'কোনো কাস্টমার টেস্টিমোনিয়াল নেই।',
              style: TextStyle(color: t.secondaryText),
            )
          else
            ..._testimonials.map((raw) {
              final Map item = raw is Map ? raw : {};
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['customer_name'] ?? 'Customer'} (${item['rating'] ?? 5}★) • ${item['designation'] ?? 'Verified Buyer'}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (item['comment'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final String sub =
                            Uri.encodeComponent(_theme.subdomain);
                        await http.delete(
                          Uri.parse(
                            '${_theme.apiBase}/api/v1/stores/testimonials/${item['id']}/?subdomain=$sub',
                          ),
                          headers: _theme.headers,
                        );
                        _fetchAllCmsData();
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openAddTestimonialDialog(CatalogThemeConfig t) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController desigCtrl =
        TextEditingController(text: 'Verified Buyer');
    final TextEditingController commentCtrl = TextEditingController();
    int rating = 5;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              title: Text(
                'Add Customer Testimonial',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Customer Name',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: desigCtrl,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Designation (e.g. Verified Buyer)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField(
                      value: rating,
                      dropdownColor: t.cardBg,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Rating (1 - 5)',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                      items: [5, 4, 3, 2, 1]
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text('$r Stars (★)'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => rating = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 3,
                      style: TextStyle(color: t.primaryText),
                      decoration: InputDecoration(
                        labelText: 'Review / Feedback',
                        filled: true,
                        fillColor: t.inputBg,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final String sub = Uri.encodeComponent(_theme.subdomain);
                    await http.post(
                      Uri.parse(
                        '${_theme.apiBase}/api/v1/stores/testimonials/?subdomain=$sub',
                      ),
                      headers: _theme.headers,
                      body: jsonEncode({
                        'customer_name': nameCtrl.text.trim(),
                        'designation': desigCtrl.text.trim(),
                        'comment': commentCtrl.text.trim(),
                        'rating': rating,
                        'is_featured': true,
                      }),
                    );
                    _showToast('টেস্টিমোনিয়াল যুক্ত হয়েছে!');
                    _fetchAllCmsData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 2. Blogs
  Widget _buildBlogsSection(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Store News & Blog Posts (${_blogs.length})',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddBlogDialog(t),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Write Blog Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_blogs.isEmpty)
            Text(
              'কোনো ব্লগ পোস্ট প্রকাশিত হয়নি।',
              style: TextStyle(color: t.secondaryText),
            )
          else
            ..._blogs.map((raw) {
              final Map b = raw is Map ? raw : {};
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (b['title'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (b['summary'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final String sub =
                            Uri.encodeComponent(_theme.subdomain);
                        await http.delete(
                          Uri.parse(
                            '${_theme.apiBase}/api/v1/stores/blogs/${b['id']}/?subdomain=$sub',
                          ),
                          headers: _theme.headers,
                        );
                        _fetchAllCmsData();
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openAddBlogDialog(CatalogThemeConfig t) {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController tagCtrl =
        TextEditingController(text: 'Shopping Tips');
    final TextEditingController sumCtrl = TextEditingController();
    final TextEditingController contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: t.cardBg,
          title: Text(
            'Publish Blog Post',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: t.primaryText),
                  decoration: InputDecoration(
                    labelText: 'Blog Title',
                    filled: true,
                    fillColor: t.inputBg,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tagCtrl,
                  style: TextStyle(color: t.primaryText),
                  decoration: InputDecoration(
                    labelText: 'Category Tag',
                    filled: true,
                    fillColor: t.inputBg,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sumCtrl,
                  maxLines: 2,
                  style: TextStyle(color: t.primaryText),
                  decoration: InputDecoration(
                    labelText: 'Short Summary',
                    filled: true,
                    fillColor: t.inputBg,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  style: TextStyle(color: t.primaryText),
                  decoration: InputDecoration(
                    labelText: 'Full Content',
                    filled: true,
                    fillColor: t.inputBg,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final String sub = Uri.encodeComponent(_theme.subdomain);
                await http.post(
                  Uri.parse(
                    '${_theme.apiBase}/api/v1/stores/blogs/?subdomain=$sub',
                  ),
                  headers: _theme.headers,
                  body: jsonEncode({
                    'title': titleCtrl.text.trim(),
                    'category_tag': tagCtrl.text.trim(),
                    'summary': sumCtrl.text.trim(),
                    'content': contentCtrl.text.trim(),
                    'is_published': true,
                  }),
                );
                _showToast('ব্লগ পোস্ট প্রকাশিত হয়েছে!');
                _fetchAllCmsData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Publish'),
            ),
          ],
        );
      },
    );
  }

  // 3. FAQs
  Widget _buildFaqsSection(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Store Frequently Asked Questions (${_faqs.length})',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddFaqDialog(t),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add FAQ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_faqs.isEmpty)
            Text(
              'কোনো FAQ যুক্ত করা হয়নি।',
              style: TextStyle(color: t.secondaryText),
            )
          else
            ..._faqs.map((raw) {
              final Map f = raw is Map ? raw : {};
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q: ${f['question'] ?? ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'A: ${f['answer'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final String sub =
                            Uri.encodeComponent(_theme.subdomain);
                        await http.delete(
                          Uri.parse(
                            '${_theme.apiBase}/api/v1/stores/faqs/${f['id']}/?subdomain=$sub',
                          ),
                          headers: _theme.headers,
                        );
                        _fetchAllCmsData();
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openAddFaqDialog(CatalogThemeConfig t) {
    final TextEditingController qCtrl = TextEditingController();
    final TextEditingController aCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: t.cardBg,
          title: Text(
            'Add Store FAQ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qCtrl,
                style: TextStyle(color: t.primaryText),
                decoration: InputDecoration(
                  labelText: 'Question',
                  filled: true,
                  fillColor: t.inputBg,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: aCtrl,
                maxLines: 3,
                style: TextStyle(color: t.primaryText),
                decoration: InputDecoration(
                  labelText: 'Answer',
                  filled: true,
                  fillColor: t.inputBg,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final String sub = Uri.encodeComponent(_theme.subdomain);
                await http.post(
                  Uri.parse(
                    '${_theme.apiBase}/api/v1/stores/faqs/?subdomain=$sub',
                  ),
                  headers: _theme.headers,
                  body: jsonEncode({
                    'question': qCtrl.text.trim(),
                    'answer': aCtrl.text.trim(),
                  }),
                );
                _showToast('FAQ যুক্ত হয়েছে!');
                _fetchAllCmsData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save FAQ'),
            ),
          ],
        );
      },
    );
  }

  // 4. Store Gallery (Zero external package dependency)
  Widget _buildStoreGallerySection(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storefront Lookbook & Gallery (${_gallery.length})',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: t.primaryText,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddGalleryPhotoDialog(t),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: const Text('Add Photo by URL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_gallery.isEmpty)
            Text(
              'স্টোর গ্যালারিতে কোনো ছবি নেই।',
              style: TextStyle(color: t.secondaryText),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _gallery.map((raw) {
                final Map g = raw is Map ? raw : {};
                final String imgUrl = (g['image'] ?? '').toString();
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imgUrl,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 140,
                          height: 140,
                          color: t.inputBg,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () async {
                          final String sub =
                              Uri.encodeComponent(_theme.subdomain);
                          await http.delete(
                            Uri.parse(
                              '${_theme.apiBase}/api/v1/stores/gallery/${g['id']}/?subdomain=$sub',
                            ),
                            headers: _theme.headers,
                          );
                          _fetchAllCmsData();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _openAddGalleryPhotoDialog(CatalogThemeConfig t) {
    final TextEditingController imgUrlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: t.cardBg,
          title: Text(
            'Add Gallery Image',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          content: TextField(
            controller: imgUrlCtrl,
            style: TextStyle(color: t.primaryText),
            decoration: InputDecoration(
              labelText: 'Direct Image URL (https://...)',
              filled: true,
              fillColor: t.inputBg,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String rawUrl = imgUrlCtrl.text.trim();
                if (rawUrl.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  final imgRes = await http.get(Uri.parse(rawUrl));
                  if (imgRes.statusCode == 200) {
                    final String sub = Uri.encodeComponent(_theme.subdomain);
                    final req = http.MultipartRequest(
                      'POST',
                      Uri.parse(
                        '${_theme.apiBase}/api/v1/stores/gallery/?subdomain=$sub',
                      ),
                    );
                    _theme.headers.forEach((k, v) {
                      if (k.toLowerCase() != 'content-type') req.headers[k] = v;
                    });
                    req.files.add(
                      http.MultipartFile.fromBytes(
                        'image',
                        imgRes.bodyBytes,
                        filename: 'gallery_photo.jpg',
                      ),
                    );
                    await req.send();
                    _showToast('গ্যালারি ছবি যুক্ত হয়েছে!');
                    _fetchAllCmsData();
                  }
                } catch (e) {
                  _showToast('ছবি লোড করা যায়নি: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }
}