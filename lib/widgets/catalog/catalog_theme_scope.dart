// lib/widgets/catalog/catalog_theme_scope.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CatalogThemeConfig {
  final Color primaryColor;
  final Color secondaryColor;
  final bool useGradient;
  final bool isDarkMode;
  final String apiBase;
  final String subdomain;
  final String token;

  static const String _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  const CatalogThemeConfig({
    this.primaryColor = const Color(0xFF5B9A42),
    this.secondaryColor = const Color(0xFF1E3A1A),
    this.useGradient = true,
    this.isDarkMode = false,
    this.apiBase = 'https://shop.xylotechsolution.com',
    this.subdomain = 'nextlook',
    this.token = '',
  });

  LinearGradient get brandGradient => LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color get cardBg => isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBorder =>
      isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2EBE0);
  Color get primaryText =>
      isDarkMode ? Colors.white : const Color(0xFF1E3A1A);
  Color get secondaryText =>
      isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get inputBg =>
      isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  Map<String, String> get headers {
    final Map<String, String> h = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': _browserUserAgent,
      'X-Tenant-Subdomain': subdomain,
      'x-subdomain': subdomain,
      'X-Tenant-Domain': '$subdomain.shop.xylotechsolution.com',
    };
    if (token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Color parseHex(String? hexStr, Color fallback) {
    if (hexStr == null || hexStr.trim().isEmpty) return fallback;
    String clean = hexStr.trim().replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  static Future load({
    required bool isDarkMode,
    required Color fallbackBrandGreen,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? pHex = prefs.getString('mobile_app_primary_color');
    final String? sHex = prefs.getString('mobile_app_secondary_color');
    final bool useGrad = prefs.getBool('mobile_app_use_gradient') ?? true;
    final String token = prefs.getString('merchant_token') ?? '';

    const String envSub = String.fromEnvironment(
      'TENANT_SUBDOMAIN',
      defaultValue: '',
    );
    const String envDom = String.fromEnvironment(
      'STORE_DOMAIN',
      defaultValue: '',
    );

    String sub = prefs.getString('active_subdomain') ?? envSub;
    if (sub.isEmpty && envDom.isNotEmpty) {
      sub = envDom
          .replaceAll('https://', '')
          .replaceAll('http://', '')
          .split('.')
          .first;
    }
    if (sub.isEmpty) sub = 'nextlook';

    String api = prefs.getString('api_base_url') ?? '';
    if (api.isEmpty) {
      api = envDom.isNotEmpty
          ? (envDom.startsWith('http') ? envDom : 'https://$envDom')
          : 'https://$sub.shop.xylotechsolution.com';
    }
    while (api.endsWith('/')) {
      api = api.substring(0, api.length - 1);
    }

    return CatalogThemeConfig(
      primaryColor: parseHex(pHex, fallbackBrandGreen),
      secondaryColor: parseHex(sHex, const Color(0xFF1E3A1A)),
      useGradient: useGrad,
      isDarkMode: isDarkMode,
      apiBase: api,
      subdomain: sub,
      token: token,
    );
  }

  static String guessCategoryIcon(String rawText) {
    final String t = rawText.toLowerCase().trim();
    if (t.isEmpty) return '🛍️';
    const iconRules = {
      'মধু': '🍯', 'honey': '🍯',
      'ঘি': '🧈', 'ghee': '🧈', 'butter': '🧈',
      'তেল': '🫗', 'oil': '🫗',
      'চাল': '🍚', 'rice': '🍚',
      'মসলা': '🌶️', 'spice': '🌶️', 'masala': '🌶️', 'আচার': '🥒', 'pickle': '🥒',
      'বাদাম': '🥜', 'nut': '🥜', 'খেজুর': '🌴', 'date': '🌴',
      'ফল': '🍎', 'fruit': '🍎', 'আম': '🥭', 'mango': '🥭',
      'সবজি': '🥦', 'vegetable': '🥦',
      'মাছ': '🐟', 'fish': '🐟', 'ইলিশ': '🐟', 'শুঁটকি': '🐟', 'চিংড়ি': '🦐',
      'মাংস': '🥩', 'meat': '🥩', 'beef': '🥩', 'chicken': '🍗', 'মুরগি': '🍗',
      'ডিম': '🥚', 'egg': '🥚',
      'কেক': '🍰', 'cake': '🍰', 'বিস্কুট': '🍪', 'biscuit': '🍪', 'মিষ্টি': '🍮',
      'চা': '🍵', 'tea': '🍵', 'কফি': '☕', 'coffee': '☕', 'জুস': '🧃', 'juice': '🧃',
      'শার্ট': '👕', 'shirt': '👕', 'টি-শার্ট': '👕', 'tshirt': '👕',
      'প্যান্ট': '👖', 'pant': '👖', 'jeans': '👖',
      'পাঞ্জাবি': '🥻', 'panjabi': '🥻', 'শাড়ি': '🥻', 'saree': '🥻',
      'থ্রি পিস': '👗', 'dress': '👗', 'kurti': '👚', 'কুর্তি': '👚',
      'বোরকা': '🧕', 'হিজাব': '🧕', 'abaya': '🧕', 'hijab': '🧕', 'আতর': '🌸',
      'জুতা': '👟', 'shoe': '👟', 'sneaker': '👟', 'স্যান্ডেল': '🩴', 'sandal': '🩴',
      'ব্যাগ': '👜', 'bag': '👜', 'wallet': '👛', 'মানিব্যাগ': '👛',
      'ঘড়ি': '⌚', 'watch': '⌚', 'গয়না': '💎', 'jewelry': '💎', 'চশমা': '👓',
      'স্কিনকেয়ার': '🧴', 'skincare': '🧴', 'cream': '🧴', 'ক্রিম': '🧴', 'সাবান': '🧼',
      'মেকআপ': '💄', 'makeup': '💄', 'lipstick': '💄', 'লিপস্টিক': '💄',
      'শ্যাম্পু': '🧴', 'shampoo': '🧴', 'পারফিউম': '🌸', 'perfume': '🌸',
      'মোবাইল': '📱', 'mobile': '📱', 'phone': '📱', 'চার্জার': '🔌', 'charger': '🔌',
      'ল্যাপটপ': '💻', 'laptop': '💻', 'কম্পিউটার': '🖥️', 'computer': '🖥️',
      'হেডফোন': '🎧', 'headphone': '🎧', 'earbud': '🎧', 'স্পিকার': '🔊', 'speaker': '🔊',
      'ক্যামেরা': '📷', 'camera': '📷', 'রাউটার': '📡', 'router': '📡',
      'টিভি': '📺', 'tv': '📺', 'ফ্রিজ': '🧊', 'fridge': '🧊', 'এসি': '❄️', 'ফ্যান': '🌀',
      'ব্লেন্ডার': '🥤', 'blender': '🥤', 'রাইস কুকার': '🍚', 'রান্নাঘর': '🍳', 'kitchen': '🍳',
      'ফার্নিচার': '🛋️', 'furniture': '🛋️', 'বেডশিট': '🛏️', 'পর্দা': '🪟',
      'বাচ্চা': '👶', 'শিশু': '🧒', 'baby': '👶', 'ডায়াপার': '🧷', 'diaper': '🧷',
      'খেলনা': '🧸', 'toy': '🧸',
      'ওষুধ': '💊', 'medicine': '💊', 'হেলথ': '🩺', 'health': '🩺',
      'খেলাধুলা': '🏅', 'sport': '🏅', 'ক্রিকেট': '🏏', 'ফুটবল': '⚽', 'জিম': '🏋️',
      'বাইক': '🏍️', 'bike': '🏍️', 'হেলমেট': '⛑️', 'helmet': '⛑️', 'গাড়ি': '🚗',
      'বই': '📚', 'book': '📚', 'খাতা': '📓', 'কলম': '🖊️', 'stationery': '✏️',
      'গিফট': '🎁', 'gift': '🎁', 'ফুল': '💐', 'flower': '💐',
      'বিড়াল': '🐱', 'cat': '🐱', 'কুকুর': '🐶', 'dog': '🐶', 'পাখি': '🦜', 'গাছ': '🪴', 'বীজ': '🌱',
    };
    for (final entry in iconRules.entries) {
      if (t.contains(entry.key)) return entry.value;
    }
    return '🛍️';
  }
}