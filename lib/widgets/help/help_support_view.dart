import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class HelpSupportView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;

  const HelpSupportView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'help_support',
  });

  @override
  State<HelpSupportView> createState() => _HelpSupportViewState();
}

class _HelpSupportViewState extends State<HelpSupportView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _isLoading = true;
  List _dropdowns = [];
  int _selectedDropdownIndex = 0;
  int _selectedSubDropdownIndex = -1;
  int _selectedPageIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initHelpModule();
  }

  @override
  void didUpdateWidget(covariant HelpSupportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
    }
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

  Future _initHelpModule() async {
    setState(() => _isLoading = true);
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) {
      setState(() => _theme = loaded);
    }

    await _loadCachedHelpTree();
    await _fetchHelpTreeFromBackend();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future _loadCachedHelpTree() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('xylo_help_tree_cache');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['dropdowns'] is List) {
          _dropdowns = List.from(decoded['dropdowns']);
        }
      }
    } catch (_) {}

    if (_dropdowns.isEmpty) {
      _dropdowns = _defaultSeededHelpTree();
    }
  }

  Future _fetchHelpTreeFromBackend() async {
    final base = _theme.apiBase;
    final headers = _theme.headers;

    final urls = [
      '$base/api/v1/help/tree/',
      '$base/api/v1/help/',
    ];

    for (final url in urls) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map &&
              decoded['dropdowns'] is List &&
              (decoded['dropdowns'] as List).isNotEmpty) {
            if (mounted) {
              setState(() {
                _dropdowns = List.from(decoded['dropdowns']);
                _selectedDropdownIndex = 0;
                _selectedSubDropdownIndex = -1;
                _selectedPageIndex = 0;
              });
            }
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('xylo_help_tree_cache', jsonEncode(decoded));
            break;
          }
        }
      } catch (_) {}
    }
  }

  List _defaultSeededHelpTree() {
    return [
      {
        'id': 1,
        'title': '🚀 Store Setup & Onboarding',
        'slug': 'store-setup-onboarding',
        'icon': 'rocket',
        'badge': 'START HERE',
        'sub_dropdowns': [],
        'pages': [
          {
            'id': 1,
            'title': '১. নতুন স্টোর ও প্রোডাক্ট সেটআপ গাইড',
            'subtitle':
                'স্টোর কাস্টমাইজেশন, প্রোডাক্ট আপলোড ও কুরিয়ার কানেকশন ভিডিও টিউটোরিয়াল',
            'canvas_bg_color': '#090805',
            'elements': [
              {
                'id': 1,
                'element_type': 'shape',
                'shape_kind': 'rounded_rect',
                'title': '✨ XYLO SaaS ই-কমার্স মাস্টার গাইডে স্বাগতম!',
                'text':
                    'নিচের ভিডিও টিউটোরিয়াল এবং স্টেপ-বাই-স্টেপ নির্দেশিকা অনুসরণ করে মাত্র ১০ মিনিটে আপনার অনলাইন স্টোর লাইভ করুন।',
                'font_size': 20.0,
                'text_color': '#FFFFFF',
                'gradient_colors': ['#F5B800', '#EA580C', '#18140B'],
                'border_color': '#F5B800',
                'border_radius': 20.0,
                'choto_boxes': [
                  '⚡ 10 Min Setup',
                  '🎬 Video Guide',
                  '🌐 Live Store'
                ],
                'badge_text': 'OFFICIAL GUIDE',
                'website_url': 'https://xylotechsolution.com',
                'button_label': '🌐 Visit Official Portal',
                'indicator_type': 'none',
              },
              {
                'id': 2,
                'element_type': 'indicator',
                'shape_kind': 'pill',
                'title': 'STEP 01 • নিচের ভিডিওটি দেখুন ⬇',
                'text': 'প্রোডাক্ট আপলোড করার সম্পূর্ণ নিয়ম',
                'font_size': 15.0,
                'text_color': '#090805',
                'gradient_colors': ['#10B981', '#34D399', '#059669'],
                'border_color': '#A7F3D0',
                'border_radius': 30.0,
                'badge_text': 'STEP POINTER',
                'indicator_type': 'arrow_down',
              },
              {
                'id': 3,
                'element_type': 'video',
                'shape_kind': 'rounded_rect',
                'title': '🎬 YouTube Tutorial: কীভাবে প্রোডাক্ট ও স্টক যোগ করবেন',
                'text':
                    'এই ভিডিওতে বারকোড, ভ্যারিয়েন্ট এবং ডিসকাউন্ট প্রাইস সেটআপ দেখানো হয়েছে।',
                'font_size': 16.0,
                'text_color': '#FFFFFF',
                'gradient_colors': ['#1E293B', '#0F172A', '#090805'],
                'border_color': '#38BDF8',
                'border_radius': 18.0,
                'choto_boxes': ['▶️ YouTube HD', '📦 Stock Setup'],
                'badge_text': 'YOUTUBE VIDEO',
                'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
                'video_source': 'youtube',
                'thumbnail_url':
                    'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800&q=80',
                'website_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
                'button_label': '▶️ Watch on YouTube',
                'indicator_type': 'none',
              },
              {
                'id': 4,
                'element_type': 'video',
                'shape_kind': 'rounded_rect',
                'title': '📘 Facebook Video & Website Guide',
                'text':
                    'ফেসবুক পিক্সেল, কুরিয়ার বুকিং ও অটো-ইনভয়েস সেটআপ গাইড।',
                'font_size': 16.0,
                'text_color': '#FFFFFF',
                'gradient_colors': ['#311042', '#1E1B4B', '#090D16'],
                'border_color': '#A855F7',
                'border_radius': 18.0,
                'choto_boxes': ['📘 Facebook Live', '🚚 Courier API'],
                'badge_text': 'FACEBOOK VIDEO',
                'video_url':
                    'https://www.facebook.com/facebook/videos/10153231379946729/',
                'video_source': 'facebook',
                'thumbnail_url':
                    'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=800&q=80',
                'website_url': 'https://xylotechsolution.com',
                'button_label': '🌐 Read Docs',
                'indicator_type': 'step_beacon',
              },
            ],
          },
        ],
      },
    ];
  }

  Color _parseHex(String? raw, Color fallback) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final clean = raw.trim().replaceAll('#', '');
    if (clean.length == 6) {
      final v = int.tryParse('FF$clean', radix: 16);
      if (v != null) return Color(v);
    } else if (clean.length == 8) {
      final v = int.tryParse(clean, radix: 16);
      if (v != null) return Color(v);
    }
    return fallback;
  }

  void _copyOrOpenLink(String url, String label) {
    if (url.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: url.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label লিংক ক্লিপবোর্ডে কপি হয়েছে: $url',
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

    final activeDropdown = (_dropdowns.isNotEmpty &&
            _selectedDropdownIndex < _dropdowns.length)
        ? _dropdowns[_selectedDropdownIndex] as Map
        : null;

    final subDropdowns =
        (activeDropdown != null && activeDropdown['sub_dropdowns'] is List)
            ? List.from(activeDropdown['sub_dropdowns'])
            : [];

    Map? targetDropdown = activeDropdown;
    if (_selectedSubDropdownIndex >= 0 &&
        _selectedSubDropdownIndex < subDropdowns.length) {
      targetDropdown = subDropdowns[_selectedSubDropdownIndex] as Map;
    }

    final pages = (targetDropdown != null && targetDropdown['pages'] is List)
        ? List.from(targetDropdown['pages'])
        : (targetDropdown != null && targetDropdown['sub_pages'] is List
            ? List.from(targetDropdown['sub_pages'])
            : []);

    final activePage = (pages.isNotEmpty && _selectedPageIndex < pages.length)
        ? pages[_selectedPageIndex] as Map
        : (pages.isNotEmpty ? pages.first as Map : null);

    final rawElements = (activePage != null && activePage['elements'] is List)
        ? List.from(activePage['elements'])
        : [];

    final q = _searchCtrl.text.trim().toLowerCase();
    final filteredElements = rawElements.where((el) {
      if (el is! Map) return false;
      if (q.isEmpty) return true;
      final title = (el['title'] ?? '').toString().toLowerCase();
      final txt = (el['text'] ?? '').toString().toLowerCase();
      return title.contains(q) || txt.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopHeroHeader(t),
        const SizedBox(height: 14),
        _buildDropdownSelectorBar(t),
        if (subDropdowns.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildSubDropdownBar(t, subDropdowns),
        ],
        if (pages.length > 1) ...[
          const SizedBox(height: 10),
          _buildPageTabsBar(t, pages),
        ],
        const SizedBox(height: 14),
        if (activePage != null)
          _buildVisualCanvasPage(t, activePage, filteredElements),
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
                  Icons.menu_book_rounded,
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
                      'Help & Support Visual Guide Center',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Step-by-step Video Tutorials, Visual Canvas Guides & Store Setup Documentation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
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
                onPressed: _fetchHelpTreeFromBackend,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text(
                  'Sync Live Guide',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search tutorials, videos or setup steps...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 18),
              isDense: true,
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.2),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSelectorBar(CatalogThemeConfig t) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _dropdowns.asMap().entries.map((entry) {
          final idx = entry.key;
          final dd = entry.value;
          if (dd is! Map) return const SizedBox.shrink();
          final isSelected = _selectedDropdownIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDropdownIndex = idx;
                  _selectedSubDropdownIndex = -1;
                  _selectedPageIndex = 0;
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
                      Icons.folder_special_outlined,
                      size: 16,
                      color: isSelected ? Colors.white : t.primaryColor,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      (dd['title'] ?? 'Guide').toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : t.primaryText,
                      ),
                    ),
                    if ((dd['badge'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.22)
                              : t.primaryColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          (dd['badge'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : t.primaryColor,
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
    );
  }

  Widget _buildSubDropdownBar(CatalogThemeConfig t, List subDropdowns) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Main Guide'),
            selected: _selectedSubDropdownIndex == -1,
            onSelected: (_) {
              setState(() {
                _selectedSubDropdownIndex = -1;
                _selectedPageIndex = 0;
              });
            },
          ),
          const SizedBox(width: 8),
          ...subDropdowns.asMap().entries.map((entry) {
            final idx = entry.key;
            final sub = entry.value;
            if (sub is! Map) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text((sub['title'] ?? 'Sub-Guide').toString()),
                selected: _selectedSubDropdownIndex == idx,
                onSelected: (_) {
                  setState(() {
                    _selectedSubDropdownIndex = idx;
                    _selectedPageIndex = 0;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPageTabsBar(CatalogThemeConfig t, List pages) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: pages.asMap().entries.map((entry) {
          final idx = entry.key;
          final pg = entry.value;
          if (pg is! Map) return const SizedBox.shrink();
          final active = _selectedPageIndex == idx;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedPageIndex = idx),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? t.primaryColor.withValues(alpha: 0.16)
                      : t.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? t.primaryColor : t.cardBorder,
                  ),
                ),
                child: Text(
                  (pg['title'] ?? 'Page ${idx + 1}').toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active ? t.primaryColor : t.primaryText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVisualCanvasPage(
    CatalogThemeConfig t,
    Map page,
    List elements,
  ) {
    final bgHex = (page['canvas_bg_color'] ?? '#090805').toString();
    final canvasBg = t.isDarkMode ? _parseHex(bgHex, t.cardBg) : t.cardBg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: canvasBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (page['title'] ?? 'Visual Guide').toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: t.primaryText,
            ),
          ),
          if ((page['subtitle'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              (page['subtitle'] ?? '').toString(),
              style: TextStyle(
                fontSize: 12.5,
                color: t.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...elements.map((el) {
            if (el is! Map) return const SizedBox.shrink();
            return _buildCanvasElementCard(t, el);
          }),
        ],
      ),
    );
  }

  Widget _buildCanvasElementCard(CatalogThemeConfig t, Map el) {
    final elType =
        (el['element_type'] ?? el['type'] ?? 'shape').toString().toLowerCase();
    final title = (el['title'] ?? '').toString();
    final text = (el['text'] ?? '').toString();
    final badgeText = (el['badge_text'] ?? '').toString();
    final borderColor = _parseHex(
        (el['border_color'] ?? '#F5B800').toString(), t.primaryColor);
    final borderRadius =
        (double.tryParse((el['border_radius'] ?? '18').toString()) ?? 18.0)
            .clamp(8.0, 32.0);

    final rawGrad = el['gradient_colors'] is List
        ? List.from(el['gradient_colors'])
        : ['#F5B800', '#EA580C', '#18140B'];
    final gradColors = rawGrad
        .map((c) => _parseHex(c.toString(), const Color(0xFF1E293B)))
        .toList();
    if (gradColors.length < 2) {
      gradColors.add(const Color(0xFF0F172A));
    }

    final chotoBoxes =
        el['choto_boxes'] is List ? List.from(el['choto_boxes']) : [];
    final imageUrl = (el['image_url'] ?? '').toString();
    final gifUrl = (el['gif_url'] ?? '').toString();
    final videoUrl = (el['video_url'] ?? '').toString();
    final thumbUrl = (el['thumbnail_url'] ?? '').toString();
    final websiteUrl = (el['website_url'] ?? '').toString();
    final buttonLabel = (el['button_label'] ?? 'Open Link').toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badgeText.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.45,
              ),
            ),
          ],
          if (elType == 'video' ||
              thumbUrl.isNotEmpty ||
              imageUrl.isNotEmpty ||
              gifUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    thumbUrl.isNotEmpty
                        ? thumbUrl
                        : (imageUrl.isNotEmpty ? imageUrl : gifUrl),
                    height: 175,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      width: double.infinity,
                      color: Colors.black26,
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  if (elType == 'video' || videoUrl.isNotEmpty)
                    InkWell(
                      onTap: () => _copyOrOpenLink(
                        videoUrl.isNotEmpty ? videoUrl : websiteUrl,
                        'Video Tutorial',
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (chotoBoxes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chotoBoxes.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    tag.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (websiteUrl.isNotEmpty || videoUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _copyOrOpenLink(
                websiteUrl.isNotEmpty ? websiteUrl : videoUrl,
                buttonLabel,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}