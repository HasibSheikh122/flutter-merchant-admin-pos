// lib/widgets/marketing/banners_promos_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';
import 'marketing_promos_view.dart';

class BannersPromosView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onDataChanged;

  const BannersPromosView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.onDataChanged,
  });

  @override
  State createState() => _BannersPromosViewState();
}

class _BannersPromosViewState extends State {
  static String _cachedSubdomain = '';
  static List _cachedList = [];

  static const List _fontChoices = [
    {'id': 'Inter, sans-serif', 'name': 'Inter (Modern Clean)'},
    {'id': 'Poppins, sans-serif', 'name': 'Poppins (Friendly Rounded)'},
    {'id': 'Montserrat, sans-serif', 'name': 'Montserrat (Luxury Brand)'},
    {'id': '"Plus Jakarta Sans", sans-serif', 'name': 'Plus Jakarta Sans'},
    {'id': '"Playfair Display", serif', 'name': 'Playfair Display (Serif)'},
    {'id': 'Cinzel, serif', 'name': 'Cinzel (Royal Serif)'},
    {'id': 'Oswald, sans-serif', 'name': 'Oswald (Tall Bold)'},
    {'id': '"Bebas Neue", sans-serif', 'name': 'Bebas Neue (Poster)'},
    {'id': 'Syne, sans-serif', 'name': 'Syne (Avant-Garde)'},
    {'id': '"Hind Siliguri", sans-serif', 'name': 'Hind Siliguri (Bangla)'},
    {'id': '"Noto Sans Bengali", sans-serif', 'name': 'Noto Sans Bengali'},
    {'id': '"Anek Bangla", sans-serif', 'name': 'Anek Bangla (Modern)'},
  ];

  static const List _stagePresets = [
    {
      'id': 'stage_1',
      'name': 'Cyber Black Golden Showroom',
      'skyTop': 0xFF070B14,
      'skyBottom': 0xFF141E30,
      'floorTop': 0xFF0F172A,
      'floorBottom': 0xFF050811,
      'pedestalColor': 0xFF111827,
      'rimColor': 0xFFF59E0B,
      'archColor': 0xFF1E293B,
      'isLightStage': false,
    },
    {
      'id': 'stage_2',
      'name': 'Botanical Nature Showroom',
      'skyTop': 0xFF38BDF8,
      'skyBottom': 0xFFE0F2FE,
      'floorTop': 0xFF94A3B8,
      'floorBottom': 0xFF334155,
      'pedestalColor': 0xFFF8FAFC,
      'rimColor': 0xFF38BDF8,
      'archColor': 0xFFE2E8F0,
      'isLightStage': true,
    },
    {
      'id': 'stage_3',
      'name': 'Original White Showroom',
      'skyTop': 0xFF60A5FA,
      'skyBottom': 0xFFDBEAFE,
      'floorTop': 0xFFCBD5E1,
      'floorBottom': 0xFF475569,
      'pedestalColor': 0xFFFFFFFF,
      'rimColor': 0xFF60A5FA,
      'archColor': 0xFFF1F5F9,
      'isLightStage': true,
    },
    {
      'id': 'stage_4',
      'name': 'Emerald Royal Podium',
      'skyTop': 0xFF022C22,
      'skyBottom': 0xFF064E3B,
      'floorTop': 0xFF065F46,
      'floorBottom': 0xFF022C22,
      'pedestalColor': 0xFF047857,
      'rimColor': 0xFF34D399,
      'archColor': 0xFF064E3B,
      'isLightStage': false,
    },
    {
      'id': 'stage_5',
      'name': 'Neon Cyber Studio',
      'skyTop': 0xFF090D16,
      'skyBottom': 0xFF1E1B4B,
      'floorTop': 0xFF1E1B4B,
      'floorBottom': 0xFF090D16,
      'pedestalColor': 0xFF0F172A,
      'rimColor': 0xFFA855F7,
      'archColor': 0xFF312E81,
      'isLightStage': false,
    },
    {
      'id': 'stage_6',
      'name': 'Sunset Gold Atrium',
      'skyTop': 0xFF451A03,
      'skyBottom': 0xFF78350F,
      'floorTop': 0xFF451A03,
      'floorBottom': 0xFF1C1917,
      'pedestalColor': 0xFF292524,
      'rimColor': 0xFFFBBF24,
      'archColor': 0xFF78350F,
      'isLightStage': false,
    },
    {
      'id': 'stage_7',
      'name': 'Minimalist Slate Studio',
      'skyTop': 0xFF1E293B,
      'skyBottom': 0xFF334155,
      'floorTop': 0xFF1E293B,
      'floorBottom': 0xFF0F172A,
      'pedestalColor': 0xFF334155,
      'rimColor': 0xFF22D3EE,
      'archColor': 0xFF475569,
      'isLightStage': false,
    },
  ];

  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _loading = true;
  List _banners = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _typeFilter = 'all';

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
        _banners = List.from(_cachedList);
        _loading = false;
      });
      return;
    }

    setState(() {
      _theme = t;
      _loading = true;
    });
    await _fetchBanners();
  }

  Future _fetchBanners() async {
    setState(() => _loading = true);
    final String sub = Uri.encodeComponent(_theme.subdomain);
    try {
      final res = await http.get(
        Uri.parse(
          '${_theme.apiBase}/api/v1/stores/banners/?subdomain=$sub&admin=true',
        ),
        headers: _theme.headers,
      );
      if (!mounted) return;
      final List list = MarketingUi.extractList(res.bodyBytes);
      _cachedSubdomain = _theme.subdomain;
      _cachedList = List.from(list);
      setState(() {
        _banners = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future _removeBackgroundViaApi(Uint8List rawBytes, String fileName) async {
    final String sub = Uri.encodeComponent(_theme.subdomain);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${_theme.apiBase}/api/v1/stores/tools/remove-bg/?subdomain=$sub',
        ),
      );
      _theme.headers.forEach((k, v) {
        if (k.toLowerCase() != 'content-type') req.headers[k] = v;
      });
      req.files.add(
        http.MultipartFile.fromBytes('image', rawBytes, filename: fileName),
      );
      final streamed = await req.send().timeout(const Duration(seconds: 25));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final String cType = (res.headers['content-type'] ?? '').toLowerCase();
        if (cType.contains('image/')) return res.bodyBytes;
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map) {
          final String b64 = (decoded['image_base64'] ??
                  decoded['image'] ??
                  decoded['data'] ??
                  '')
              .toString();
          if (b64.isNotEmpty) {
            final String cleanB64 =
                b64.contains(',') ? b64.split(',').last : b64;
            return base64Decode(cleanB64);
          }
          final String imgUrl = MarketingUi.resolveImg(
            _theme,
            decoded['url'] ?? decoded['image_url'],
          );
          if (imgUrl.isNotEmpty) {
            final dl = await http.get(Uri.parse(imgUrl));
            if (dl.statusCode == 200) return dl.bodyBytes;
          }
        }
      }
    } catch (_) {}
    return rawBytes;
  }

  Future _uploadMultipartOrJson({
    required String method,
    required String url,
    required Map fields,
    Uint8List? primaryBytes,
    Uint8List? secondaryBytes,
    Uint8List? bgBytes,
  }) async {
    final bool hasFiles =
        primaryBytes != null || secondaryBytes != null || bgBytes != null;
    if (!hasFiles) {
      if (method == 'POST') {
        return http.post(
          Uri.parse(url),
          headers: _theme.headers,
          body: jsonEncode(fields),
        );
      } else {
        return http.patch(
          Uri.parse(url),
          headers: _theme.headers,
          body: jsonEncode(fields),
        );
      }
    }

    final req = http.MultipartRequest(method, Uri.parse(url));
    _theme.headers.forEach((k, v) {
      if (k.toLowerCase() != 'content-type') req.headers[k] = v;
    });
    fields.forEach((k, v) {
      if (v != null) {
        req.fields[k.toString()] =
            (v is Map || v is List) ? jsonEncode(v) : v.toString();
      }
    });
    if (primaryBytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'image',
          primaryBytes,
          filename: 'banner_primary.png',
        ),
      );
    }
    if (secondaryBytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'secondary_image',
          secondaryBytes,
          filename: 'banner_secondary.png',
        ),
      );
    }
    if (bgBytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'background_image',
          bgBytes,
          filename: 'banner_stage_bg.png',
        ),
      );
    }
    final streamed = await req.send();
    return http.Response.fromStream(streamed);
  }

  Future _toggleBannerActive(Map banner) async {
    final String sub = Uri.encodeComponent(_theme.subdomain);
    final res = await http.post(
      Uri.parse(
        '${_theme.apiBase}/api/v1/stores/banners/${banner['id']}/toggle-active/?subdomain=$sub',
      ),
      headers: _theme.headers,
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      await http.patch(
        Uri.parse(
          '${_theme.apiBase}/api/v1/stores/banners/${banner['id']}/?subdomain=$sub',
        ),
        headers: _theme.headers,
        body: jsonEncode({'is_active': !(banner['is_active'] == true)}),
      );
    }
    if (!mounted) return;
    MarketingUi.showToast(context, _theme, 'ব্যানার স্ট্যাটাস আপডেট হয়েছে!');
    await _fetchBanners();
  }

  Future _deleteBanner(dynamic id) async {
    final String sub = Uri.encodeComponent(_theme.subdomain);
    await http.delete(
      Uri.parse('${_theme.apiBase}/api/v1/stores/banners/$id/?subdomain=$sub'),
      headers: _theme.headers,
    );
    if (!mounted) return;
    MarketingUi.showToast(context, _theme, 'ব্যানার মুছে ফেলা হয়েছে।');
    await _fetchBanners();
  }

  double _normScalePct(dynamic raw) {
    final double val = double.tryParse((raw ?? 100).toString()) ?? 100.0;
    if (val > 0 && 5.0 >= val) return val * 100.0;
    return val.clamp(30.0, 250.0);
  }

  Widget _build3DStageCanvas({
    required String stagePreset,
    Uint8List? customBgBytes,
    String customBgUrl = '',
    Uint8List? leftBytes,
    String leftImgUrl = '',
    Uint8List? rightBytes,
    String rightImgUrl = '',
    required double leftOx,
    required double leftOy,
    required double leftScalePct,
    required double rightOx,
    required double rightOy,
    required double rightScalePct,
    required double textOx,
    required double textOy,
    required double textScalePct,
    required double timerOx,
    required double timerOy,
    required double timerScalePct,
    required double timerGap,
    required double timerPadX,
    required double timerPadY,
    required bool timerBoxBg,
    required String badgeText,
    required String headlineText,
    required String subtitleText,
    required String buttonText,
    required List customTexts,
    VoidCallback? onPrevStage,
    VoidCallback? onNextStage,
    bool showTopStatusOverlay = true,
    double canvasHeight = 230,
  }) {
    int stageIdx = _stagePresets.indexWhere((s) => s['id'] == stagePreset);
    if (0 > stageIdx) stageIdx = 0;
    final Map stage = _stagePresets[stageIdx] as Map;
    final Color skyTop = Color(stage['skyTop'] as int);
    final Color skyBottom = Color(stage['skyBottom'] as int);
    final Color floorTop = Color(stage['floorTop'] as int);
    final Color floorBottom = Color(stage['floorBottom'] as int);
    final Color pedestalCol = Color(stage['pedestalColor'] as int);
    final Color rimCol = Color(stage['rimColor'] as int);
    final Color archCol = Color(stage['archColor'] as int);
    final bool isLightStage = stage['isLightStage'] == true;
    const double pxFactor = 0.42;

    return Container(
      height: canvasHeight,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rimCol.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [skyTop, skyBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: -30,
            left: 55,
            right: 55,
            bottom: 55,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(180),
                ),
                border: Border.all(
                  color: rimCol.withValues(alpha: 0.35),
                  width: 3,
                ),
                gradient: LinearGradient(
                  colors: [
                    archCol.withValues(alpha: 0.25),
                    skyBottom.withValues(alpha: 0.65),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: canvasHeight * 0.34,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [floorTop, floorBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  top: BorderSide(
                    color: rimCol.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (customBgBytes != null)
            Positioned.fill(
              child: Image.memory(
                customBgBytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            )
          else if (customBgUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                customBgUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // Left & Right 3D Pedestals
          Positioned(
            left: 14,
            bottom: 14,
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 48,
                  decoration: BoxDecoration(
                    color: pedestalCol.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: rimCol, width: 1.5),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 84,
                  height: 18,
                  decoration: BoxDecoration(
                    color: pedestalCol,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: rimCol, width: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 48,
                  decoration: BoxDecoration(
                    color: pedestalCol.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: rimCol, width: 1.5),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 84,
                  height: 18,
                  decoration: BoxDecoration(
                    color: pedestalCol,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: rimCol, width: 1.4),
                  ),
                ),
              ],
            ),
          ),

          if (leftBytes != null || leftImgUrl.isNotEmpty)
            Positioned(
              left: 18 + (leftOx * pxFactor),
              bottom: 26 - (leftOy * pxFactor),
              child: Transform.scale(
                scale: (leftScalePct / 100.0).clamp(0.3, 2.5),
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 80,
                  height: 98,
                  child: leftBytes != null
                      ? Image.memory(
                          leftBytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        )
                      : Image.network(
                          leftImgUrl,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                ),
              ),
            ),

          if (rightBytes != null || rightImgUrl.isNotEmpty)
            Positioned(
              right: 18 - (rightOx * pxFactor),
              bottom: 26 - (rightOy * pxFactor),
              child: Transform.scale(
                scale: (rightScalePct / 100.0).clamp(0.3, 2.5),
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 80,
                  height: 98,
                  child: rightBytes != null
                      ? Image.memory(
                          rightBytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        )
                      : Image.network(
                          rightImgUrl,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                ),
              ),
            ),

          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(textOx * pxFactor, (textOy * pxFactor) - 32),
                child: Transform.scale(
                  scale: (textScalePct / 100.0).clamp(0.5, 2.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 62),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (badgeText.isNotEmpty)
                          Text(
                            badgeText.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: isLightStage
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFFBBF24),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          headlineText.isEmpty
                              ? "Up to 50% off today's best deals!"
                              : headlineText,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isLightStage
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                          ),
                        ),
                        if (subtitleText.isNotEmpty)
                          Text(
                            subtitleText,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isLightStage
                                  ? const Color(0xFF334155)
                                  : Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(timerOx * pxFactor, (timerOy * pxFactor) + 8),
                child: Transform.scale(
                  scale: (timerScalePct / 100.0).clamp(0.5, 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      {'val': '01', 'lbl': 'DAYS'},
                      {'val': '12', 'lbl': 'HRS'},
                      {'val': '45', 'lbl': 'MIN'},
                      {'val': '30', 'lbl': 'SEC'},
                    ].map((tBox) {
                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: (timerGap * 0.25).clamp(1.5, 10.0),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: (timerPadX * 0.45).clamp(5.0, 16.0),
                          vertical: (timerPadY * 0.4).clamp(3.0, 12.0),
                        ),
                        decoration: BoxDecoration(
                          color: timerBoxBg
                              ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                              : Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tBox['val'].toString(),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              tBox['lbl'].toString(),
                              style: const TextStyle(
                                fontSize: 6.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    buttonText.isEmpty
                        ? 'CLAIM DEAL NOW  →'
                        : '${buttonText.toUpperCase()}  →',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          ...customTexts.map((rawLayer) {
            if (rawLayer is! Map) return const SizedBox.shrink();
            final String txt = (rawLayer['text'] ?? '').toString();
            if (txt.isEmpty) return const SizedBox.shrink();
            final double lx =
                double.tryParse((rawLayer['x'] ?? 0).toString()) ?? 0;
            final double ly =
                double.tryParse((rawLayer['y'] ?? 0).toString()) ?? 0;
            final double lScale =
                (double.tryParse((rawLayer['scale'] ?? 100).toString()) ??
                        100) /
                    100.0;
            return Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(lx * pxFactor, ly * pxFactor),
                  child: Transform.scale(
                    scale: lScale.clamp(0.3, 3.0),
                    child: Text(
                      txt,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: MarketingUi.parseHex(
                          rawLayer['color']?.toString(),
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          if (showTopStatusOverlay)
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '🟢 Live 3D Stage Preview',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Stage ${stageIdx + 1}/${_stagePresets.length}: ${stage['name']}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFBBF24),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (onPrevStage != null)
            Positioned(
              left: 6,
              top: (canvasHeight / 2) - 15,
              child: InkWell(
                onTap: onPrevStage,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          if (onNextStage != null)
            Positioned(
              right: 6,
              top: (canvasHeight / 2) - 15,
              child: InkWell(
                onTap: onNextStage,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openStandardBannerModal(CatalogThemeConfig t, {Map? existing}) {
    String bannerType = (existing?['banner_type'] ?? 'hero').toString();
    if (bannerType == 'countdown') bannerType = 'hero';

    final TextEditingController badgeCtrl = TextEditingController(
      text: (existing?['badge_title'] ?? 'NEW COLLECTION').toString(),
    );
    final TextEditingController titleCtrl = TextEditingController(
      text: (existing?['title'] ?? '').toString(),
    );
    final TextEditingController subCtrl = TextEditingController(
      text: (existing?['subtitle'] ?? '').toString(),
    );
    final TextEditingController btnCtrl = TextEditingController(
      text: (existing?['button_text'] ?? 'Shop Collection').toString(),
    );
    final TextEditingController urlCtrl = TextEditingController(
      text: (existing?['target_url'] ?? '/products').toString(),
    );
    String fontFamily =
        (existing?['font_family'] ?? 'Inter, sans-serif').toString();
    if (!_fontChoices.any((f) => f['id'] == fontFamily)) {
      fontFamily = 'Inter, sans-serif';
    }
    String bgColorHex = (existing?['bg_color'] ?? '#0f172a').toString();
    Uint8List? pickedHeroBytes;
    final String existingImgUrl = MarketingUi.resolveImg(
      t,
      existing?['image_url'] ?? existing?['image'],
    );
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double screenW = MediaQuery.of(ctx).size.width;
            final double modalW = screenW > 760
                ? 640
                : (screenW > 520 ? screenW * 0.92 : screenW - 24);
            final bool twoCol = modalW >= 500;

            return Dialog(
              backgroundColor: MarketingUi.modalBg(t),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
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
                            child: Text(
                              existing != null
                                  ? 'Edit Standard Hero / Weekly Banner'
                                  : 'Add Standard Hero / Weekly Banner',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: MarketingUi.textColor(t),
                              ),
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

                      if (twoCol)
                        Row(
                          children: [
                            Expanded(
                              child: MarketingUi.dropdownField(
                                t: t,
                                label: 'Banner Slot Type',
                                value: bannerType,
                                items: const [
                                  {
                                    'id': 'hero',
                                    'name': 'Hero Slider Banner (Max 3)'
                                  },
                                  {
                                    'id': 'weekly',
                                    'name': 'Weekly Specials Promo'
                                  },
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(
                                      () => bannerType = v.toString(),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MarketingUi.textField(
                                t: t,
                                label: 'Badge Title',
                                controller: badgeCtrl,
                                hint: 'NEW COLLECTION',
                              ),
                            ),
                          ],
                        )
                      else ...[
                        MarketingUi.dropdownField(
                          t: t,
                          label: 'Banner Slot Type',
                          value: bannerType,
                          items: const [
                            {
                              'id': 'hero',
                              'name': 'Hero Slider Banner (Max 3)'
                            },
                            {'id': 'weekly', 'name': 'Weekly Specials Promo'},
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => bannerType = v.toString());
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        MarketingUi.textField(
                          t: t,
                          label: 'Badge Title',
                          controller: badgeCtrl,
                          hint: 'NEW COLLECTION',
                        ),
                      ],
                      const SizedBox(height: 12),

                      MarketingUi.textField(
                        t: t,
                        label: 'Headline Title *',
                        controller: titleCtrl,
                        hint: 'e.g. Curated Products for Modern Living',
                      ),
                      const SizedBox(height: 12),

                      MarketingUi.textField(
                        t: t,
                        label: 'Subtitle / Tagline',
                        controller: subCtrl,
                        maxLines: 2,
                        hint: 'Short offer description or subtitle...',
                      ),
                      const SizedBox(height: 12),

                      if (twoCol)
                        Row(
                          children: [
                            Expanded(
                              child: MarketingUi.dropdownField(
                                t: t,
                                label: 'Font Family',
                                value: fontFamily,
                                items: _fontChoices,
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(
                                      () => fontFamily = v.toString(),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MarketingUi.textField(
                                t: t,
                                label: 'CTA Button Text',
                                controller: btnCtrl,
                                hint: 'Shop Collection',
                              ),
                            ),
                          ],
                        )
                      else ...[
                        MarketingUi.dropdownField(
                          t: t,
                          label: 'Font Family',
                          value: fontFamily,
                          items: _fontChoices,
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => fontFamily = v.toString());
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        MarketingUi.textField(
                          t: t,
                          label: 'CTA Button Text',
                          controller: btnCtrl,
                          hint: 'Shop Collection',
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

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MarketingUi.sectionBg(t),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MarketingUi.fieldBorder(t)),
                        ),
                        child: Column(
                          children: [
                            if (pickedHeroBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  pickedHeroBytes!,
                                  height: 100,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else if (existingImgUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  existingImgUrl,
                                  height: 100,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked =
                                      await MarketingUi.pickOrDownloadImageBytes(
                                    ctx,
                                    t,
                                  );
                                  if (picked != null &&
                                      picked['bytes'] is Uint8List) {
                                    setModalState(() {
                                      pickedHeroBytes =
                                          picked['bytes'] as Uint8List;
                                    });
                                  }
                                },
                                icon: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 18,
                                  color: t.primaryColor,
                                ),
                                label: Text(
                                  pickedHeroBytes != null
                                      ? '✅ Banner Image Selected'
                                      : 'Select Banner Image (Phone / URL)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: t.primaryColor,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: t.primaryColor),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
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
                                      if (titleCtrl.text.trim().isEmpty) {
                                        MarketingUi.showToast(
                                          context,
                                          t,
                                          'Headline Title লিখুন!',
                                          isError: true,
                                        );
                                        return;
                                      }
                                      setModalState(() => saving = true);
                                      final String sub =
                                          Uri.encodeComponent(_theme.subdomain);
                                      final Map fields = {
                                        'banner_type': bannerType,
                                        'badge_title': badgeCtrl.text.trim(),
                                        'title': titleCtrl.text.trim(),
                                        'subtitle': subCtrl.text.trim(),
                                        'font_family': fontFamily,
                                        'bg_color': bgColorHex,
                                        'button_text': btnCtrl.text.trim(),
                                        'target_url': urlCtrl.text.trim(),
                                        'is_active': true,
                                      };
                                      final String endpoint = existing != null
                                          ? '${_theme.apiBase}/api/v1/stores/banners/${existing['id']}/?subdomain=$sub'
                                          : '${_theme.apiBase}/api/v1/stores/banners/?subdomain=$sub';

                                      await _uploadMultipartOrJson(
                                        method:
                                            existing != null ? 'PATCH' : 'POST',
                                        url: endpoint,
                                        fields: fields,
                                        primaryBytes: pickedHeroBytes,
                                      );
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      if (mounted) {
                                        MarketingUi.showToast(
                                          context,
                                          t,
                                          'Standard Banner সেভ হয়েছে!',
                                        );
                                      }
                                      await _fetchBanners();
                                    },
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                saving ? 'Saving...' : 'Save Banner',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
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

  void _openCountdown3DStudioModal(CatalogThemeConfig t, {Map? existing}) {
    String stagePreset = (existing?['stage_preset'] ?? 'stage_1').toString();
    if (!_stagePresets.any((s) => s['id'] == stagePreset)) {
      stagePreset = 'stage_1';
    }

    Uint8List? leftBytes;
    Uint8List? rightBytes;
    Uint8List? customBgBytes;

    final String existingLeftUrl = MarketingUi.resolveImg(
      t,
      existing?['image_url'] ?? existing?['image'],
    );
    final String existingRightUrl = MarketingUi.resolveImg(
      t,
      existing?['secondary_image_url'] ?? existing?['secondary_image'],
    );
    final String existingBgUrl = MarketingUi.resolveImg(
      t,
      existing?['background_image_url'] ?? existing?['background_image'],
    );

    double leftOx =
        double.tryParse((existing?['left_ox'] ?? 0).toString()) ?? 0;
    double leftOy =
        double.tryParse((existing?['left_oy'] ?? 0).toString()) ?? 0;
    double leftScalePct = _normScalePct(existing?['left_scale']);

    double rightOx =
        double.tryParse((existing?['right_ox'] ?? 0).toString()) ?? 0;
    double rightOy =
        double.tryParse((existing?['right_oy'] ?? 0).toString()) ?? 0;
    double rightScalePct = _normScalePct(existing?['right_scale']);

    double textOx =
        double.tryParse((existing?['text_ox'] ?? 0).toString()) ?? 0;
    double textOy =
        double.tryParse((existing?['text_oy'] ?? 0).toString()) ?? 0;
    double textScalePct = _normScalePct(existing?['text_scale']);

    double timerOx =
        double.tryParse((existing?['timer_ox'] ?? 0).toString()) ?? 0;
    double timerOy =
        double.tryParse((existing?['timer_oy'] ?? 0).toString()) ?? 0;
    double timerScalePct = _normScalePct(existing?['timer_scale']);
    double timerGap =
        double.tryParse((existing?['timer_gap'] ?? 12).toString()) ?? 12;
    double timerPadX =
        double.tryParse((existing?['timer_pad_x'] ?? 16).toString()) ?? 16;
    double timerPadY =
        double.tryParse((existing?['timer_pad_y'] ?? 8).toString()) ?? 8;
    bool timerBoxBg = existing?['timer_box_bg'] == true;

    List customTexts = [];
    if (existing?['custom_texts'] is List) {
      customTexts = List.from(existing!['custom_texts']);
    }

    final TextEditingController badgeCtrl = TextEditingController(
      text: (existing?['badge_title'] ?? '48-HOUR COUNTDOWN').toString(),
    );
    final TextEditingController titleCtrl = TextEditingController(
      text: (existing?['title'] ?? "Up to 50% off today's best deals!")
          .toString(),
    );
    final TextEditingController subCtrl = TextEditingController(
      text: (existing?['subtitle'] ?? '').toString(),
    );
    final TextEditingController endCtrl = TextEditingController(
      text: (existing?['countdown_end'] ??
              DateTime.now()
                  .add(const Duration(hours: 48))
                  .toIso8601String()
                  .substring(0, 16))
          .toString(),
    );
    final TextEditingController btnCtrl = TextEditingController(
      text: (existing?['button_text'] ?? 'CLAIM DEAL NOW').toString(),
    );
    final TextEditingController urlCtrl = TextEditingController(
      text: (existing?['target_url'] ?? '/products').toString(),
    );

    bool removingLeftBg = false;
    bool removingRightBg = false;
    bool savingBanner = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStudioState) {
            final double screenW = MediaQuery.of(ctx).size.width;
            final double modalW = screenW > 960
                ? 880
                : (screenW > 600 ? screenW * 0.94 : screenW - 16);
            final bool twoCol = modalW >= 540;

            void cycleStage(int delta) {
              int idx = _stagePresets.indexWhere((s) => s['id'] == stagePreset);
              if (0 > idx) idx = 0;
              idx = (idx + delta) % _stagePresets.length;
              if (0 > idx) idx += _stagePresets.length;
              setStudioState(() {
                stagePreset = _stagePresets[idx]['id'].toString();
              });
            }

            Widget buildSlider({
              required String label,
              required String valTxt,
              required double val,
              required double min,
              required double max,
              required Color col,
              required ValueChanged onChanged,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: t.secondaryText,
                        ),
                      ),
                      Text(
                        valTxt,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: col,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 24,
                    child: Slider(
                      value: val.clamp(min, max),
                      min: min,
                      max: max,
                      activeColor: col,
                      onChanged: (v) => onChanged(v),
                    ),
                  ),
                ],
              );
            }

            return Dialog(
              backgroundColor: MarketingUi.modalBg(t),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: MarketingUi.fieldBorder(t), width: 1.5),
              ),
              child: Container(
                width: modalW,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Create 3D Panoramic Countdown Banner',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: MarketingUi.textColor(t),
                            ),
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
                    Divider(color: MarketingUi.fieldBorder(t), height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _build3DStageCanvas(
                              stagePreset: stagePreset,
                              customBgBytes: customBgBytes,
                              customBgUrl: existingBgUrl,
                              leftBytes: leftBytes,
                              leftImgUrl: existingLeftUrl,
                              rightBytes: rightBytes,
                              rightImgUrl: existingRightUrl,
                              leftOx: leftOx,
                              leftOy: leftOy,
                              leftScalePct: leftScalePct,
                              rightOx: rightOx,
                              rightOy: rightOy,
                              rightScalePct: rightScalePct,
                              textOx: textOx,
                              textOy: textOy,
                              textScalePct: textScalePct,
                              timerOx: timerOx,
                              timerOy: timerOy,
                              timerScalePct: timerScalePct,
                              timerGap: timerGap,
                              timerPadX: timerPadX,
                              timerPadY: timerPadY,
                              timerBoxBg: timerBoxBg,
                              badgeText: badgeCtrl.text,
                              headlineText: titleCtrl.text,
                              subtitleText: subCtrl.text,
                              buttonText: btnCtrl.text,
                              customTexts: customTexts,
                              onPrevStage: () => cycleStage(-1),
                              onNextStage: () => cycleStage(1),
                              canvasHeight: twoCol ? 240 : 215,
                            ),
                            const SizedBox(height: 12),

                            MarketingUi.dropdownField(
                              t: t,
                              label: '1. Select 3D Stage Background Preset',
                              value: stagePreset,
                              items: _stagePresets,
                              onChanged: (v) {
                                if (v != null) {
                                  setStudioState(
                                    () => stagePreset = v.toString(),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: removingLeftBg
                                        ? null
                                        : () async {
                                            final picked = await MarketingUi
                                                .pickOrDownloadImageBytes(
                                              ctx,
                                              t,
                                            );
                                            if (picked == null) return;
                                            setStudioState(
                                              () => removingLeftBg = true,
                                            );
                                            final Uint8List cutout =
                                                await _removeBackgroundViaApi(
                                              picked['bytes'] as Uint8List,
                                              picked['name'].toString(),
                                            );
                                            setStudioState(() {
                                              leftBytes = cutout;
                                              removingLeftBg = false;
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.auto_fix_high_rounded,
                                      size: 15,
                                    ),
                                    label: Text(
                                      removingLeftBg
                                          ? 'Removing BG...'
                                          : (leftBytes != null
                                              ? '✅ Left Ready'
                                              : 'Left Product (Auto BG)'),
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: removingRightBg
                                        ? null
                                        : () async {
                                            final picked = await MarketingUi
                                                .pickOrDownloadImageBytes(
                                              ctx,
                                              t,
                                            );
                                            if (picked == null) return;
                                            setStudioState(
                                              () => removingRightBg = true,
                                            );
                                            final Uint8List cutout =
                                                await _removeBackgroundViaApi(
                                              picked['bytes'] as Uint8List,
                                              picked['name'].toString(),
                                            );
                                            setStudioState(() {
                                              rightBytes = cutout;
                                              removingRightBg = false;
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.auto_fix_high_rounded,
                                      size: 15,
                                    ),
                                    label: Text(
                                      removingRightBg
                                          ? 'Removing BG...'
                                          : (rightBytes != null
                                              ? '✅ Right Ready'
                                              : 'Right Model (Auto BG)'),
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Horizontal Sliders
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Container(
                                    width: 205,
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: MarketingUi.sectionBg(t),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: MarketingUi.fieldBorder(t),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '📦 Left Product',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'X Offset',
                                          valTxt: '${leftOx.round()}px',
                                          val: leftOx,
                                          min: -220,
                                          max: 220,
                                          col: const Color(0xFF059669),
                                          onChanged: (v) => setStudioState(
                                            () => leftOx = v as double,
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'Y Offset',
                                          valTxt: '${leftOy.round()}px',
                                          val: leftOy,
                                          min: -160,
                                          max: 160,
                                          col: const Color(0xFF059669),
                                          onChanged: (v) => setStudioState(
                                            () => leftOy = v as double,
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'Scale %',
                                          valTxt: '${leftScalePct.round()}%',
                                          val: leftScalePct,
                                          min: 40,
                                          max: 220,
                                          col: const Color(0xFF059669),
                                          onChanged: (v) => setStudioState(
                                            () => leftScalePct = v as double,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 205,
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: MarketingUi.sectionBg(t),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: MarketingUi.fieldBorder(t),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '📝 Text Content',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF9333EA),
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'X Offset',
                                          valTxt: '${textOx.round()}px',
                                          val: textOx,
                                          min: -220,
                                          max: 220,
                                          col: const Color(0xFF9333EA),
                                          onChanged: (v) => setStudioState(
                                            () => textOx = v as double,
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'Y Offset',
                                          valTxt: '${textOy.round()}px',
                                          val: textOy,
                                          min: -160,
                                          max: 160,
                                          col: const Color(0xFF9333EA),
                                          onChanged: (v) => setStudioState(
                                            () => textOy = v as double,
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'Scale %',
                                          valTxt: '${textScalePct.round()}%',
                                          val: textScalePct,
                                          min: 50,
                                          max: 200,
                                          col: const Color(0xFF9333EA),
                                          onChanged: (v) => setStudioState(
                                            () => textScalePct = v as double,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 205,
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: MarketingUi.sectionBg(t),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: MarketingUi.fieldBorder(t),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '⏱️ Timer Styling',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'X Offset',
                                          valTxt: '${timerOx.round()}px',
                                          val: timerOx,
                                          min: -220,
                                          max: 220,
                                          col: const Color(0xFFD97706),
                                          onChanged: (v) => setStudioState(
                                            () => timerOx = v as double,
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'Y Offset',
                                          valTxt: '${timerOy.round()}px',
                                          val: timerOy,
                                          min: -160,
                                          max: 160,
                                          col: const Color(0xFFD97706),
                                          onChanged: (v) => setStudioState(
                                            () => timerOy = v as double,
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'Scale %',
                                          valTxt: '${timerScalePct.round()}%',
                                          val: timerScalePct,
                                          min: 50,
                                          max: 200,
                                          col: const Color(0xFFD97706),
                                          onChanged: (v) => setStudioState(
                                            () => timerScalePct = v as double,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 205,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: MarketingUi.sectionBg(t),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: MarketingUi.fieldBorder(t),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '🧍 Right Model',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'X Offset',
                                          valTxt: '${rightOx.round()}px',
                                          val: rightOx,
                                          min: -220,
                                          max: 220,
                                          col: const Color(0xFF2563EB),
                                          onChanged: (v) => setStudioState(
                                            () => rightOx = v as double,
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'Y Offset',
                                          valTxt: '${rightOy.round()}px',
                                          val: rightOy,
                                          min: -160,
                                          max: 160,
                                          col: const Color(0xFF2563EB),
                                          onChanged: (v) => setStudioState(
                                            () => rightOy = v as double,
                                          ),
                                        ),
                                        buildSlider(
                                          label: 'Scale %',
                                          valTxt: '${rightScalePct.round()}%',
                                          val: rightScalePct,
                                          min: 40,
                                          max: 220,
                                          col: const Color(0xFF2563EB),
                                          onChanged: (v) => setStudioState(
                                            () => rightScalePct = v as double,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            MarketingUi.textField(
                              t: t,
                              label: 'Headline Title *',
                              controller: titleCtrl,
                              hint: "Up to 50% off today's best deals!",
                              onChanged: (_) => setStudioState(() {}),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: MarketingUi.textField(
                                    t: t,
                                    label: 'Badge Title',
                                    controller: badgeCtrl,
                                    onChanged: (_) => setStudioState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: MarketingUi.textField(
                                    t: t,
                                    label: 'Countdown End',
                                    controller: endCtrl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: MarketingUi.textField(
                                    t: t,
                                    label: 'CTA Button Text',
                                    controller: btnCtrl,
                                    onChanged: (_) => setStudioState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: MarketingUi.textField(
                                    t: t,
                                    label: 'Target URL',
                                    controller: urlCtrl,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: savingBanner
                                ? null
                                : () async {
                                    setStudioState(() => savingBanner = true);
                                    final String sub =
                                        Uri.encodeComponent(_theme.subdomain);
                                    final Map fields = {
                                      'banner_type': 'countdown',
                                      'stage_preset': stagePreset,
                                      'badge_title': badgeCtrl.text.trim(),
                                      'title': titleCtrl.text.trim(),
                                      'subtitle': subCtrl.text.trim(),
                                      'countdown_end': endCtrl.text.trim(),
                                      'button_text': btnCtrl.text.trim(),
                                      'target_url': urlCtrl.text.trim(),
                                      'left_ox': leftOx.round(),
                                      'left_oy': leftOy.round(),
                                      'left_scale': leftScalePct.round(),
                                      'right_ox': rightOx.round(),
                                      'right_oy': rightOy.round(),
                                      'right_scale': rightScalePct.round(),
                                      'text_ox': textOx.round(),
                                      'text_oy': textOy.round(),
                                      'text_scale': textScalePct.round(),
                                      'timer_ox': timerOx.round(),
                                      'timer_oy': timerOy.round(),
                                      'timer_scale': timerScalePct.round(),
                                      'timer_gap': timerGap.round(),
                                      'timer_pad_x': timerPadX.round(),
                                      'timer_pad_y': timerPadY.round(),
                                      'timer_box_bg': timerBoxBg,
                                      'custom_texts': customTexts,
                                      'is_active': true,
                                    };
                                    final String endpoint = existing != null
                                        ? '${_theme.apiBase}/api/v1/stores/banners/${existing['id']}/?subdomain=$sub'
                                        : '${_theme.apiBase}/api/v1/stores/banners/?subdomain=$sub';

                                    await _uploadMultipartOrJson(
                                      method:
                                          existing != null ? 'PATCH' : 'POST',
                                      url: endpoint,
                                      fields: fields,
                                      primaryBytes: leftBytes,
                                      secondaryBytes: rightBytes,
                                      bgBytes: customBgBytes,
                                    );
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                    if (mounted) {
                                      MarketingUi.showToast(
                                        context,
                                        t,
                                        '3D Countdown Banner সেভ হয়েছে!',
                                      );
                                    }
                                    await _fetchBanners();
                                  },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              savingBanner ? 'Saving...' : 'Save 3D Banner',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
    final int total = _banners.length;
    final int active =
        _banners.where((b) => b is Map && b['is_active'] == true).length;
    final int heroCount = _banners
        .where(
          (b) =>
              b is Map &&
              b['banner_type'] == 'hero' &&
              b['is_active'] == true,
        )
        .length;
    final int countdownCount = _banners
        .where((b) => b is Map && b['banner_type'] == 'countdown')
        .length;

    final String q = _searchCtrl.text.trim().toLowerCase();
    final List filtered = _banners.where((raw) {
      if (raw is! Map) return false;
      final bool matchQ = q.isEmpty ||
          (raw['title'] ?? '').toString().toLowerCase().contains(q) ||
          (raw['subtitle'] ?? '').toString().toLowerCase().contains(q);
      final bool matchType = _typeFilter == 'all' ||
          (raw['banner_type'] ?? 'hero').toString() == _typeFilter;
      return matchQ && matchType;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
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
                          Icons.photo_size_select_actual_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Storefront Banners & 3D Countdown Studio',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: MarketingUi.textColor(t),
                            ),
                          ),
                          Text(
                            'Control 3D Showroom countdown, hero carousels & weekly promos',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openCountdown3DStudioModal(t),
                        icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                        label: const Text('+ Add 3D Banner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openStandardBannerModal(t),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('+ Add Standard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
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
                label: 'Total Banners',
                value: '$total',
                subtext: 'All Storefront Slots',
                icon: Icons.layers_rounded,
                accentColor: const Color(0xFF10B981),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: 'Active Live',
                value: '$active',
                subtext: 'Visible on Shop',
                icon: Icons.check_circle_outline_rounded,
                accentColor: const Color(0xFF3B82F6),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: 'Hero Carousel',
                value: '$heroCount / 3',
                subtext: 'Top Slider Capacity',
                icon: Icons.photo_library_rounded,
                accentColor: const Color(0xFFF59E0B),
              ),
              MarketingUi.kpiCard(
                t: t,
                label: '3D Countdown',
                value: '$countdownCount',
                subtext: 'Interactive Stage',
                icon: Icons.timer_rounded,
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
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: MarketingUi.textField(
                          t: t,
                          label: '',
                          controller: _searchCtrl,
                          hint: 'Search banners...',
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
                          value: _typeFilter,
                          items: const [
                            {'id': 'all', 'name': 'All Types'},
                            {'id': 'hero', 'name': 'Hero Slider'},
                            {'id': 'countdown', 'name': '3D Countdown'},
                            {'id': 'weekly', 'name': 'Weekly Promo'},
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _typeFilter = v.toString());
                            }
                          },
                        ),
                      ),
                    ],
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
                          'কোনো ব্যানার পাওয়া যায়নি।',
                          style: TextStyle(color: t.secondaryText),
                        ),
                      ),
                    )
                  else
                    MarketingUi.buildResponsiveGrid(
                      maxWidth: maxW - 28,
                      items: filtered,
                      itemBuilder: (raw) {
                        final Map b = raw is Map ? raw : {};
                        final bool isActive = b['is_active'] == true;
                        final String bType =
                            (b['banner_type'] ?? 'hero').toString();
                        final String leftUrl = MarketingUi.resolveImg(
                          t,
                          b['image_url'] ?? b['image'],
                        );
                        final String rightUrl = MarketingUi.resolveImg(
                          t,
                          b['secondary_image_url'] ?? b['secondary_image'],
                        );
                        final String bgUrl = MarketingUi.resolveImg(
                          t,
                          b['background_image_url'] ?? b['background_image'],
                        );

                        return Container(
                          padding: const EdgeInsets.all(12),
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
                              if (bType == 'countdown')
                                _build3DStageCanvas(
                                  stagePreset:
                                      (b['stage_preset'] ?? 'stage_1').toString(),
                                  customBgUrl: bgUrl,
                                  leftImgUrl: leftUrl,
                                  rightImgUrl: rightUrl,
                                  leftOx: double.tryParse(
                                          (b['left_ox'] ?? 0).toString()) ??
                                      0,
                                  leftOy: double.tryParse(
                                          (b['left_oy'] ?? 0).toString()) ??
                                      0,
                                  leftScalePct: _normScalePct(b['left_scale']),
                                  rightOx: double.tryParse(
                                          (b['right_ox'] ?? 0).toString()) ??
                                      0,
                                  rightOy: double.tryParse(
                                          (b['right_oy'] ?? 0).toString()) ??
                                      0,
                                  rightScalePct:
                                      _normScalePct(b['right_scale']),
                                  textOx: double.tryParse(
                                          (b['text_ox'] ?? 0).toString()) ??
                                      0,
                                  textOy: double.tryParse(
                                          (b['text_oy'] ?? 0).toString()) ??
                                      0,
                                  textScalePct: _normScalePct(b['text_scale']),
                                  timerOx: double.tryParse(
                                          (b['timer_ox'] ?? 0).toString()) ??
                                      0,
                                  timerOy: double.tryParse(
                                          (b['timer_oy'] ?? 0).toString()) ??
                                      0,
                                  timerScalePct:
                                      _normScalePct(b['timer_scale']),
                                  timerGap: double.tryParse(
                                          (b['timer_gap'] ?? 12).toString()) ??
                                      12,
                                  timerPadX: double.tryParse(
                                          (b['timer_pad_x'] ?? 16)
                                              .toString()) ??
                                      16,
                                  timerPadY: double.tryParse(
                                          (b['timer_pad_y'] ?? 8).toString()) ??
                                      8,
                                  timerBoxBg: b['timer_box_bg'] == true,
                                  badgeText:
                                      (b['badge_title'] ?? '48-HOUR COUNTDOWN')
                                          .toString(),
                                  headlineText: (b['title'] ?? '').toString(),
                                  subtitleText:
                                      (b['subtitle'] ?? '').toString(),
                                  buttonText:
                                      (b['button_text'] ?? 'CLAIM DEAL NOW')
                                          .toString(),
                                  customTexts: b['custom_texts'] is List
                                      ? b['custom_texts']
                                      : [],
                                  showTopStatusOverlay: false,
                                  canvasHeight: 170,
                                )
                              else
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: MarketingUi.parseHex(
                                      b['bg_color']?.toString(),
                                      const Color(0xFF0F172A),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: leftUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            leftUrl,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.image_outlined,
                                            color: Colors.white54,
                                            size: 36,
                                          ),
                                        ),
                                ),
                              const SizedBox(height: 10),
                              Text(
                                (b['title'] ?? 'Untitled Banner').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: MarketingUi.textColor(t),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () => _toggleBannerActive(b),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFF10B981)
                                                .withValues(alpha: 0.16)
                                            : t.cardBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isActive ? 'Live' : 'Paused',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isActive
                                              ? const Color(0xFF10B981)
                                              : t.secondaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          if (bType == 'countdown') {
                                            _openCountdown3DStudioModal(
                                              t,
                                              existing: b,
                                            );
                                          } else {
                                            _openStandardBannerModal(
                                              t,
                                              existing: b,
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: MarketingUi.textColor(t),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteBanner(b['id']),
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