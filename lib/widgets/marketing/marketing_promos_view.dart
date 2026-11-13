// lib/widgets/marketing/marketing_promos_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';

import 'store_announcements_view.dart';
import 'coupons_promos_view.dart';
import 'banners_promos_view.dart';
import 'newsletter_leads_view.dart';

export 'store_announcements_view.dart';
export 'coupons_promos_view.dart';
export 'banners_promos_view.dart';
export 'newsletter_leads_view.dart';

class MarketingPromosView extends StatelessWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final VoidCallback? onDataChanged;

  const MarketingPromosView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.initialTab = 'announcements',
    this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    final String clean = initialTab.trim().toLowerCase();
    if (clean == 'coupons') {
      return CouponsPromosView(
        isDarkMode: isDarkMode,
        brandGreen: brandGreen,
        onDataChanged: onDataChanged,
      );
    }
    if (clean == 'banners') {
      return BannersPromosView(
        isDarkMode: isDarkMode,
        brandGreen: brandGreen,
        onDataChanged: onDataChanged,
      );
    }
    if (clean == 'newsletter') {
      return NewsletterLeadsView(
        isDarkMode: isDarkMode,
        brandGreen: brandGreen,
        onDataChanged: onDataChanged,
      );
    }
    return StoreAnnouncementsView(
      isDarkMode: isDarkMode,
      brandGreen: brandGreen,
      onDataChanged: onDataChanged,
    );
  }
}

class MarketingUi {
  static const MethodChannel nativeChannel =
      MethodChannel('com.xylosaas.xylo_merchant_admin/alerts');

  static Color modalBg(CatalogThemeConfig t) =>
      t.isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  static Color sectionBg(CatalogThemeConfig t) =>
      t.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

  static Color fieldFill(CatalogThemeConfig t) =>
      t.isDarkMode ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);

  static Color fieldBorder(CatalogThemeConfig t) =>
      t.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

  static Color labelColor(CatalogThemeConfig t) =>
      t.isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

  static Color textColor(CatalogThemeConfig t) =>
      t.isDarkMode ? Colors.white : const Color(0xFF0F172A);

  static Color hintColor(CatalogThemeConfig t) =>
      t.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static Color parseHex(String? hexStr, Color fallback) {
    if (hexStr == null || hexStr.trim().isEmpty) return fallback;
    String clean = hexStr.trim().replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  static String resolveImg(CatalogThemeConfig t, dynamic raw) {
    if (raw == null) return '';
    final String s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    if (s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('data:')) {
      return s;
    }
    return '${t.apiBase}${s.startsWith('/') ? '' : '/'}$s';
  }

  static List extractList(List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes.cast()));
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['results'] is List) {
        return decoded['results'];
      }
    } catch (_) {}
    return [];
  }

  static void showToast(
    BuildContext context,
    CatalogThemeConfig t,
    String msg, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : t.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static Widget textField({
    required CatalogThemeConfig t,
    required String label,
    required TextEditingController controller,
    String hint = '',
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged? onChanged,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: labelColor(t),
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged != null ? (v) => onChanged(v) : null,
          style: TextStyle(
            color: textColor(t),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: t.primaryColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: hintColor(t),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: fieldFill(t),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fieldBorder(t), width: 1.4),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fieldBorder(t), width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.primaryColor, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  static Widget dropdownField({
    required CatalogThemeConfig t,
    required String label,
    required String value,
    required List items,
    required ValueChanged onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: labelColor(t),
            ),
          ),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField(
          initialValue: value,
          dropdownColor: modalBg(t),
          isExpanded: true,
          iconEnabledColor: textColor(t),
          style: TextStyle(
            color: textColor(t),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldFill(t),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fieldBorder(t), width: 1.4),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fieldBorder(t), width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.primaryColor, width: 1.8),
            ),
          ),
          items: items.map((item) {
            final Map m = item is Map ? item : {'id': item, 'name': item};
            return DropdownMenuItem(
              value: m['id'].toString(),
              child: Text(
                m['name'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor(t),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: (v) => onChanged(v),
        ),
      ],
    );
  }

  static Widget kpiCard({
    required CatalogThemeConfig t,
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: t.secondaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor(t),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildKpiGrid4(
    double maxWidth,
    Widget c1,
    Widget c2,
    Widget c3,
    Widget c4,
  ) {
    if (maxWidth >= 700) {
      return Row(
        children: [
          Expanded(child: c1),
          const SizedBox(width: 10),
          Expanded(child: c2),
          const SizedBox(width: 10),
          Expanded(child: c3),
          const SizedBox(width: 10),
          Expanded(child: c4),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: c1),
            const SizedBox(width: 10),
            Expanded(child: c2),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: c3),
            const SizedBox(width: 10),
            Expanded(child: c4),
          ],
        ),
      ],
    );
  }

  static Widget buildResponsiveGrid({
    required double maxWidth,
    required List items,
    required Function itemBuilder,
  }) {
    int cols = 1;
    if (maxWidth >= 1020) {
      cols = 3;
    } else if (maxWidth >= 600) {
      cols = 2;
    }
    if (cols == 1) {
      return Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: itemBuilder(item) as Widget,
              ),
            )
            .toList(),
      );
    }

    final List rows = [];
    for (int i = 0; items.length > i; i += cols) {
      final List rowChildren = [];
      for (int c = 0; cols > c; c++) {
        if (c > 0) rowChildren.add(const SizedBox(width: 12));
        final int idx = i + c;
        if (items.length > idx) {
          rowChildren.add(Expanded(child: itemBuilder(items[idx]) as Widget));
        } else {
          rowChildren.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowChildren.cast(),
          ),
        ),
      );
    }
    return Column(children: rows.cast());
  }

  static Future pickOrDownloadImageBytes(
    BuildContext ctx,
    CatalogThemeConfig t,
  ) async {
    try {
      final dynamic res = await nativeChannel.invokeMethod('pickImage');
      if (res is Map && res['base64'] != null) {
        final Uint8List bytes = base64Decode(res['base64'].toString());
        final String name = (res['name'] ?? 'picked_image.png').toString();
        return {'bytes': bytes, 'name': name};
      }
    } catch (_) {}

    if (!ctx.mounted) return null;
    final TextEditingController urlCtrl = TextEditingController();
    final String? enteredUrl = await showDialog(
      context: ctx,
      builder: (dCtx) {
        return AlertDialog(
          backgroundColor: modalBg(t),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: fieldBorder(t)),
          ),
          title: Text(
            'Select Image from URL',
            style: TextStyle(
              color: textColor(t),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: textField(
            t: t,
            label: 'Direct Image Link (https://...)',
            controller: urlCtrl,
            hint: 'https://example.com/banner.png',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: t.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dCtx).pop(urlCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Load Image'),
            ),
          ],
        );
      },
    );
    if (enteredUrl != null && enteredUrl.isNotEmpty) {
      try {
        final r = await http.get(Uri.parse(enteredUrl));
        if (r.statusCode == 200) {
          return {'bytes': r.bodyBytes, 'name': 'remote_image.png'};
        }
      } catch (_) {}
    }
    return null;
  }
}