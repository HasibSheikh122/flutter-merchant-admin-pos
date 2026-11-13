// lib/widgets/marketing/newsletter_leads_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';
import 'marketing_promos_view.dart';

class NewsletterLeadsView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onDataChanged;

  const NewsletterLeadsView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.onDataChanged,
  });

  @override
  State createState() => _NewsletterLeadsViewState();
}

class _NewsletterLeadsViewState extends State {
  static String _cachedSubdomain = '';
  static List _cachedList = [];

  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _loading = true;
  List _subscribers = [];
  final TextEditingController _searchCtrl = TextEditingController();

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
        _subscribers = List.from(_cachedList);
        _loading = false;
      });
      return;
    }

    setState(() {
      _theme = t;
      _loading = true;
    });
    await _fetchSubscribers();
  }

  Future _fetchSubscribers() async {
    setState(() => _loading = true);
    final String sub = Uri.encodeComponent(_theme.subdomain);
    try {
      final res = await http.get(
        Uri.parse('${_theme.apiBase}/api/v1/stores/subscribers/?subdomain=$sub'),
        headers: _theme.headers,
      );
      if (!mounted) return;
      final List list = MarketingUi.extractList(res.bodyBytes);
      _cachedSubdomain = _theme.subdomain;
      _cachedList = List.from(list);
      setState(() {
        _subscribers = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future _deleteSubscriber(dynamic id) async {
    final String sub = Uri.encodeComponent(_theme.subdomain);
    try {
      await http.delete(
        Uri.parse(
          '${_theme.apiBase}/api/v1/stores/subscribers/$id/?subdomain=$sub',
        ),
        headers: _theme.headers,
      );
      if (!mounted) return;
      MarketingUi.showToast(context, _theme, 'ইমেইল রিমুভ করা হয়েছে।');
      await _fetchSubscribers();
    } catch (_) {}
  }

  void _copyCsv(List list) {
    final List rows = ['ID,Subscriber Email,Subscribed Date'];
    for (int i = 0; list.length > i; i++) {
      final Map s = list[i] is Map ? list[i] : {};
      rows.add(
        '${i + 1},"${s['email'] ?? ''}","${s['created_at'] ?? 'Recent'}"',
      );
    }
    Clipboard.setData(ClipboardData(text: rows.join('\n')));
    MarketingUi.showToast(
      context,
      _theme,
      'সব সাবস্ক্রাইবার ইমেইল CSV ফরম্যাটে কপি হয়েছে!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final String q = _searchCtrl.text.trim().toLowerCase();
    final List filtered = _subscribers.where((raw) {
      if (raw is! Map) return false;
      return q.isEmpty ||
          (raw['email'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final bool isWide = maxW >= 650;

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
                          Icons.mark_email_unread_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Newsletter Subscribers (${_subscribers.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: MarketingUi.textColor(t),
                            ),
                          ),
                          Text(
                            'Customer email leads collected from the storefront newsletter',
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
                      OutlinedButton.icon(
                        onPressed: () => _copyCsv(filtered),
                        icon: Icon(
                          Icons.table_view_rounded,
                          size: 16,
                          color: t.primaryColor,
                        ),
                        label: Text(
                          'Export CSV',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: t.primaryColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: t.primaryColor),
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

            if (isWide)
              Row(
                children: [
                  Expanded(
                    child: MarketingUi.kpiCard(
                      t: t,
                      label: 'Total Subscribers',
                      value: '${_subscribers.length}',
                      subtext: 'Collected Leads',
                      icon: Icons.people_alt_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MarketingUi.kpiCard(
                      t: t,
                      label: 'Audience Ready',
                      value: '100% Verified',
                      subtext: 'Opt-in Storefront Leads',
                      icon: Icons.verified_rounded,
                      accentColor: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MarketingUi.kpiCard(
                      t: t,
                      label: 'Campaign Ready',
                      value: 'Mail Export',
                      subtext: 'One-Click CSV Copy',
                      icon: Icons.send_rounded,
                      accentColor: const Color(0xFFA855F7),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: MarketingUi.kpiCard(
                      t: t,
                      label: 'Total Subscribers',
                      value: '${_subscribers.length}',
                      subtext: 'Collected Leads',
                      icon: Icons.people_alt_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MarketingUi.kpiCard(
                      t: t,
                      label: 'Audience Ready',
                      value: '100% Verified',
                      subtext: 'Opt-in Leads',
                      icon: Icons.verified_rounded,
                      accentColor: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
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
                  MarketingUi.textField(
                    t: t,
                    label: '',
                    controller: _searchCtrl,
                    hint: 'Search by customer email address...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: t.secondaryText,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
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
                          'কোনো সাবস্ক্রাইবার ইমেইল পাওয়া যায়নি।',
                          style: TextStyle(color: t.secondaryText),
                        ),
                      ),
                    )
                  else
                    MarketingUi.buildResponsiveGrid(
                      maxWidth: maxW - 28,
                      items: filtered,
                      itemBuilder: (raw) {
                        final Map s = raw is Map ? raw : {};
                        final String email = (s['email'] ?? '').toString();
                        final String dateStr =
                            (s['created_at'] ?? 'Recent').toString();
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MarketingUi.sectionBg(t),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: MarketingUi.fieldBorder(t),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      t.primaryColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.mail_outline_rounded,
                                  color: t.primaryColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: MarketingUi.textColor(t),
                                      ),
                                    ),
                                    Text(
                                      dateStr.length > 10
                                          ? dateStr.substring(0, 10)
                                          : dateStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: t.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy Email',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: email),
                                  );
                                  MarketingUi.showToast(
                                    context,
                                    t,
                                    'ইমেইল কপি হয়েছে!',
                                  );
                                },
                                icon: Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: t.primaryColor,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove Subscriber',
                                onPressed: () => _deleteSubscriber(s['id']),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFEF4444),
                                ),
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