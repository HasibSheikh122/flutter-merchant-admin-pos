// lib/widgets/marketing/store_announcements_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';
import 'marketing_promos_view.dart';

class StoreAnnouncementsView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onDataChanged;

  const StoreAnnouncementsView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.onDataChanged,
  });

  @override
  State createState() => _StoreAnnouncementsViewState();
}

class _StoreAnnouncementsViewState extends State {
  static String _cachedSubdomain = '';
  static List _cachedList = [];

  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _loading = true;
  List _announcements = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _styleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _initAndFetch(forceRefresh: false);
  }

  @override
  void didUpdateWidget(covariant StatefulWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dynamic oldW = oldWidget;
    final dynamic curW = widget;
    if (oldW.isDarkMode != curW.isDarkMode ||
        oldW.brandGreen != curW.brandGreen) {
      _reloadThemeOnly();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future _reloadThemeOnly() async {
    final dynamic curW = widget;
    final t = await CatalogThemeConfig.load(
      isDarkMode: curW.isDarkMode == true,
      fallbackBrandGreen: curW.brandGreen as Color,
    );
    if (!mounted) return;
    setState(() => _theme = t);
  }

  Future _initAndFetch({bool forceRefresh = false}) async {
    final dynamic curW = widget;
    final t = await CatalogThemeConfig.load(
      isDarkMode: curW.isDarkMode == true,
      fallbackBrandGreen: curW.brandGreen as Color,
    );
    if (!mounted) return;

    if (!forceRefresh &&
        _cachedSubdomain == t.subdomain &&
        _cachedList.isNotEmpty) {
      setState(() {
        _theme = t;
        _announcements = List.from(_cachedList);
        _loading = false;
      });
      return;
    }

    setState(() {
      _theme = t;
      _loading = true;
    });
    await _fetchAnnouncements();
  }

  Future _fetchAnnouncements() async {
    setState(() => _loading = true);
    final String sub = Uri.encodeComponent(_theme.subdomain);
    try {
      final res = await http.get(
        Uri.parse(
          '${_theme.apiBase}/api/v1/stores/store-announcements/?subdomain=$sub&admin=true',
        ),
        headers: _theme.headers,
      );
      if (!mounted) return;
      final List list = MarketingUi.extractList(res.bodyBytes);
      _cachedSubdomain = _theme.subdomain;
      _cachedList = List.from(list);
      setState(() {
        _announcements = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future _toggleActive(Map item) async {
    final String sub = Uri.encodeComponent(_theme.subdomain);
    final bool nextState = !(item['is_active'] == true);
    try {
      await http.patch(
        Uri.parse(
          '${_theme.apiBase}/api/v1/stores/store-announcements/${item['id']}/?subdomain=$sub',
        ),
        headers: _theme.headers,
        body: jsonEncode({'is_active': nextState}),
      );
      if (!mounted) return;
      MarketingUi.showToast(
        context,
        _theme,
        nextState
            ? 'অ্যানাউন্সমেন্ট লাইভ করা হয়েছে!'
            : 'অ্যানাউন্সমেন্ট পজ করা হয়েছে।',
      );
      await _fetchAnnouncements();
    } catch (_) {}
  }

  Future _deleteAnnouncement(dynamic id) async {
    final String sub = Uri.encodeComponent(_theme.subdomain);
    try {
      await http.delete(
        Uri.parse(
          '${_theme.apiBase}/api/v1/stores/store-announcements/$id/?subdomain=$sub',
        ),
        headers: _theme.headers,
      );
      if (!mounted) return;
      MarketingUi.showToast(context, _theme, 'অ্যানাউন্সমেন্ট মুছে ফেলা হয়েছে।');
      await _fetchAnnouncements();
    } catch (_) {}
  }

  void _openAnnouncementModal(CatalogThemeConfig t, {Map? existing}) {
    final TextEditingController titleCtrl = TextEditingController(
      text: (existing?['title'] ?? 'SPECIAL OFFER').toString(),
    );
    final TextEditingController msgCtrl = TextEditingController(
      text: (existing?['message'] ?? '').toString(),
    );
    final TextEditingController phoneCtrl = TextEditingController(
      text: (existing?['phone'] ?? '+880 1700-000000').toString(),
    );
    final TextEditingController btnCtrl = TextEditingController(
      text: (existing?['button_text'] ?? 'Shop Now').toString(),
    );
    final TextEditingController urlCtrl = TextEditingController(
      text: (existing?['target_url'] ?? '/products').toString(),
    );
    String displayStyle =
        (existing?['display_style'] ?? 'top_bar').toString();
    if (!['top_bar', 'banner_strip', 'popup'].contains(displayStyle)) {
      displayStyle = 'top_bar';
    }
    String bgColorHex = (existing?['bg_color'] ?? '#047857').toString();
    String textColorHex = (existing?['text_color'] ?? '#ffffff').toString();
    bool syncHeader = existing != null
        ? (existing['sync_to_header_bar'] == true)
        : true;
    bool isActive = existing != null ? (existing['is_active'] == true) : true;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double screenW = MediaQuery.of(ctx).size.width;
            final double modalW = screenW > 700
                ? 620
                : (screenW > 500 ? screenW * 0.92 : screenW - 24);
            final bool twoCol = modalW >= 500;

            return Dialog(
              backgroundColor: MarketingUi.modalBg(t),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: MarketingUi.fieldBorder(t), width: 1.5),
              ),
              child: Container(
                width: modalW,
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color:
                                        t.primaryColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.campaign_rounded,
                                    color: t.primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        existing != null
                                            ? 'Edit Storefront Announcement'
                                            : 'Create Storefront Announcement',
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                          color: MarketingUi.textColor(t),
                                        ),
                                      ),
                                      Text(
                                        'Top Marquee Bar, Promo Strip or Storefront Welcome Popup',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: t.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: MarketingUi.textColor(t),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Live Preview Strip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: MarketingUi.parseHex(
                            bgColorHex,
                            const Color(0xFF047857),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                titleCtrl.text.isEmpty
                                    ? 'SPECIAL OFFER'
                                    : titleCtrl.text.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: MarketingUi.parseHex(
                                    textColorHex,
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                msgCtrl.text.isEmpty
                                    ? 'প্রথম অর্ডারে ২০% ছাড় এবং ফ্রি হোম ডেলিভারি!'
                                    : msgCtrl.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: MarketingUi.parseHex(
                                    textColorHex,
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (twoCol)
                        Row(
                          children: [
                            Expanded(
                              child: MarketingUi.textField(
                                t: t,
                                label: 'Badge Title *',
                                controller: titleCtrl,
                                hint: 'e.g. EID SALE / FREE DELIVERY',
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MarketingUi.dropdownField(
                                t: t,
                                label: 'Display Style',
                                value: displayStyle,
                                items: const [
                                  {
                                    'id': 'top_bar',
                                    'name': 'Top Marquee / Header Bar'
                                  },
                                  {
                                    'id': 'banner_strip',
                                    'name': 'Highlighted Promo Strip'
                                  },
                                  {
                                    'id': 'popup',
                                    'name': 'Storefront Welcome Popup'
                                  },
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(
                                      () => displayStyle = v.toString(),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        )
                      else ...[
                        MarketingUi.textField(
                          t: t,
                          label: 'Badge Title *',
                          controller: titleCtrl,
                          hint: 'e.g. EID SALE / FREE DELIVERY',
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 12),
                        MarketingUi.dropdownField(
                          t: t,
                          label: 'Display Style',
                          value: displayStyle,
                          items: const [
                            {
                              'id': 'top_bar',
                              'name': 'Top Marquee / Header Bar'
                            },
                            {
                              'id': 'banner_strip',
                              'name': 'Highlighted Promo Strip'
                            },
                            {
                              'id': 'popup',
                              'name': 'Storefront Welcome Popup'
                            },
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => displayStyle = v.toString());
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 12),

                      MarketingUi.textField(
                        t: t,
                        label: 'Announcement Message *',
                        controller: msgCtrl,
                        maxLines: 2,
                        hint: 'প্রথম অর্ডারে ২০% ছাড়! আজই অর্ডার করুন...',
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),

                      if (twoCol)
                        Row(
                          children: [
                            Expanded(
                              child: MarketingUi.textField(
                                t: t,
                                label: 'Helpline Phone Number',
                                controller: phoneCtrl,
                                hint: '+880 1700-000000',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MarketingUi.textField(
                                t: t,
                                label: 'CTA Button Text',
                                controller: btnCtrl,
                                hint: 'Shop Now',
                              ),
                            ),
                          ],
                        )
                      else ...[
                        MarketingUi.textField(
                          t: t,
                          label: 'Helpline Phone Number',
                          controller: phoneCtrl,
                          hint: '+880 1700-000000',
                        ),
                        const SizedBox(height: 12),
                        MarketingUi.textField(
                          t: t,
                          label: 'CTA Button Text',
                          controller: btnCtrl,
                          hint: 'Shop Now',
                        ),
                      ],
                      const SizedBox(height: 12),

                      MarketingUi.textField(
                        t: t,
                        label: 'Target URL',
                        controller: urlCtrl,
                        hint: '/products',
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'Bar Background Color',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MarketingUi.labelColor(t),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          '#047857',
                          '#0f172a',
                          '#1d4ed8',
                          '#7e22ce',
                          '#be123c',
                          '#b45309',
                        ].map((hex) {
                          final bool sel = bgColorHex.toLowerCase() == hex;
                          return InkWell(
                            onTap: () => setModalState(() => bgColorHex = hex),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: MarketingUi.parseHex(hex, Colors.green),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sel
                                      ? MarketingUi.textColor(t)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: sel
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: MarketingUi.sectionBg(t),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MarketingUi.fieldBorder(t)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Sync to Top Storefront Header Bar',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: MarketingUi.textColor(t),
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: syncHeader,
                                  activeColor: Colors.white,
                                  activeTrackColor: t.primaryColor,
                                  onChanged: (v) =>
                                      setModalState(() => syncHeader = v),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Publish Active Immediately',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: MarketingUi.textColor(t),
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  activeColor: Colors.white,
                                  activeTrackColor: t.primaryColor,
                                  onChanged: (v) =>
                                      setModalState(() => isActive = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MarketingUi.textColor(t),
                                side: BorderSide(
                                  color: MarketingUi.fieldBorder(t),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (msgCtrl.text.trim().isEmpty) {
                                        MarketingUi.showToast(
                                          context,
                                          t,
                                          'অ্যানাউন্সমেন্ট মেসেজ লিখুন!',
                                          isError: true,
                                        );
                                        return;
                                      }
                                      setModalState(() => saving = true);
                                      final String sub =
                                          Uri.encodeComponent(_theme.subdomain);
                                      final Map body = {
                                        'title': titleCtrl.text.trim(),
                                        'message': msgCtrl.text.trim(),
                                        'phone': phoneCtrl.text.trim(),
                                        'display_style': displayStyle,
                                        'bg_color': bgColorHex,
                                        'text_color': textColorHex,
                                        'button_text': btnCtrl.text.trim(),
                                        'target_url': urlCtrl.text.trim(),
                                        'sync_to_header_bar': syncHeader,
                                        'is_active': isActive,
                                      };
                                      if (existing != null) {
                                        await http.patch(
                                          Uri.parse(
                                            '${_theme.apiBase}/api/v1/stores/store-announcements/${existing['id']}/?subdomain=$sub',
                                          ),
                                          headers: _theme.headers,
                                          body: jsonEncode(body),
                                        );
                                      } else {
                                        await http.post(
                                          Uri.parse(
                                            '${_theme.apiBase}/api/v1/stores/store-announcements/?subdomain=$sub',
                                          ),
                                          headers: _theme.headers,
                                          body: jsonEncode(body),
                                        );
                                      }
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      if (mounted) {
                                        MarketingUi.showToast(
                                          context,
                                          t,
                                          'স্টোর অ্যানাউন্সমেন্ট সেভ হয়েছে!',
                                        );
                                      }
                                      await _fetchAnnouncements();
                                    },
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                saving ? 'Saving...' : 'Publish Announcement',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final int total = _announcements.length;
    final int active =
        _announcements.where((a) => a is Map && a['is_active'] == true).length;
    final int topBarCount = _announcements
        .where((a) => a is Map && (a['display_style'] ?? 'top_bar') == 'top_bar')
        .length;
    final int popupCount = _announcements
        .where((a) => a is Map && (a['display_style'] ?? '') != 'top_bar')
        .length;

    final String q = _searchCtrl.text.trim().toLowerCase();
    final List filtered = _announcements.where((raw) {
      if (raw is! Map) return false;
      final bool matchQ = q.isEmpty ||
          (raw['title'] ?? '').toString().toLowerCase().contains(q) ||
          (raw['message'] ?? '').toString().toLowerCase().contains(q);
      final bool matchStyle = _styleFilter == 'all' ||
          (raw['display_style'] ?? 'top_bar').toString() == _styleFilter;
      return matchQ && matchStyle;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
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
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: t.useGradient ? t.brandGradient : null,
                          color: t.useGradient ? null : t.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Storefront Announcements & Marquee',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: MarketingUi.textColor(t),
                            ),
                          ),
                          Text(
                            'Manage top scrolling marquee notices, promo strips & welcome popups',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _initAndFetch(forceRefresh: true),
                        icon: Icon(Icons.refresh_rounded, color: t.primaryColor),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openAnnouncementModal(t),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('+ New Announcement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            MarketingUi.buildKpiGrid4(
              maxW,
              MarketingUi.kpiCard(
                t: t,
                label: 'Total Notices',
                value: '$total',
                subtext: 'All Storefront Bars',
                icon: Icons.campaign_rounded,
                accentColor: const Color(0xFF10B981),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: 'Active Live',
                value: '$active',
                subtext: 'Showing on Shop',
                icon: Icons.check_circle_outline_rounded,
                accentColor: const Color(0xFF3B82F6),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: 'Top Marquee',
                value: '$topBarCount',
                subtext: 'Header Scroll Bars',
                icon: Icons.view_headline_rounded,
                accentColor: const Color(0xFFF59E0B),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: 'Strips & Popups',
                value: '$popupCount',
                subtext: 'Special Alerts',
                icon: Icons.auto_awesome_rounded,
                accentColor: const Color(0xFFA855F7),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                children: [
                  if (maxW >= 560)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: MarketingUi.textField(
                            t: t,
                            label: '',
                            controller: _searchCtrl,
                            hint: 'Search announcements by badge or message...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: t.secondaryText,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: MarketingUi.dropdownField(
                            t: t,
                            label: '',
                            value: _styleFilter,
                            items: const [
                              {'id': 'all', 'name': 'All Display Styles'},
                              {'id': 'top_bar', 'name': 'Top Marquee Bar'},
                              {'id': 'banner_strip', 'name': 'Promo Strip'},
                              {'id': 'popup', 'name': 'Welcome Popup'},
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _styleFilter = v.toString());
                              }
                            },
                          ),
                        ),
                      ],
                    )
                  else ...[
                    MarketingUi.textField(
                      t: t,
                      label: '',
                      controller: _searchCtrl,
                      hint: 'Search announcements...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: t.secondaryText,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    MarketingUi.dropdownField(
                      t: t,
                      label: '',
                      value: _styleFilter,
                      items: const [
                        {'id': 'all', 'name': 'All Display Styles'},
                        {'id': 'top_bar', 'name': 'Top Marquee Bar'},
                        {'id': 'banner_strip', 'name': 'Promo Strip'},
                        {'id': 'popup', 'name': 'Welcome Popup'},
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _styleFilter = v.toString());
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 14),

                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: t.primaryColor),
                      ),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          'কোনো স্টোর অ্যানাউন্সমেন্ট পাওয়া যায়নি।',
                          style: TextStyle(color: t.secondaryText),
                        ),
                      ),
                    )
                  else
                    MarketingUi.buildResponsiveGrid(
                      maxWidth: maxW - 28,
                      items: filtered,
                      itemBuilder: (raw) {
                        final Map a = raw is Map ? raw : {};
                        final bool isActive = a['is_active'] == true;
                        final Color barBg = MarketingUi.parseHex(
                          a['bg_color']?.toString(),
                          const Color(0xFF047857),
                        );
                        final Color barTxt = MarketingUi.parseHex(
                          a['text_color']?.toString(),
                          Colors.white,
                        );
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: MarketingUi.sectionBg(t),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? t.primaryColor
                                  : MarketingUi.fieldBorder(t),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: barBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${a['title'] ?? 'OFFER'} • ${a['message'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: barTxt,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '📞 ${a['phone'] ?? 'N/A'} • ${(a['display_style'] ?? 'top_bar').toString().toUpperCase()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: t.secondaryText,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _toggleActive(a),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? const Color(0xFF10B981)
                                                    .withValues(alpha: 0.16)
                                                : t.cardBg,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isActive ? 'Live' : 'Paused',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: isActive
                                                  ? const Color(0xFF10B981)
                                                  : t.secondaryText,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _openAnnouncementModal(
                                          t,
                                          existing: a,
                                        ),
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: MarketingUi.textColor(t),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _deleteAnnouncement(a['id']),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}