// lib/widgets/general_settings_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeneralSettingsView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;
  final VoidCallback? onSettingsUpdated;

  const GeneralSettingsView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'theme_branding',
    this.onSettingsUpdated,
  });

  @override
  State<GeneralSettingsView> createState() => _GeneralSettingsViewState();
}

class _GeneralSettingsViewState extends State<GeneralSettingsView> {
  late String _activeSubTab;
  bool _isLoading = true;
  bool _isSaving = false;

  String _subdomain = 'bestbdbazar';
  String _apiBase = 'https://nextlook.shop.xylotechsolution.com';
  String _token = '';

  // Mobile App Only Theme Colors & Gradient Mode (Not sent to Website Backend)
  late Color _mobilePrimaryColor;
  late Color _mobileSecondaryColor;
  bool _useGradient = true;

  // 1. Theme & Branding Controllers
  final TextEditingController _storeNameCtrl = TextEditingController();
  final TextEditingController _taglineCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _primaryColorCtrl =
      TextEditingController(text: '#5B9A42');
  final TextEditingController _secondaryColorCtrl =
      TextEditingController(text: '#1E3A1A');
  final TextEditingController _contactEmailCtrl = TextEditingController();
  final TextEditingController _contactPhoneCtrl = TextEditingController();
  final TextEditingController _contactAddressCtrl = TextEditingController();
  String _selectedCurrency = 'BDT';
  String _currencySymbol = '৳';
  String _selectedThemeKey = 'grocery';
  List<dynamic> _marketplaceThemes = [];

  // 2. Subscription & Billing State
  Map<String, dynamic> _currentSubscription = {};
  List<dynamic> _allPlans = [];

  // 3. Payment Gateways State
  bool _enableCod = true;
  bool _enableOnlinePayment = true;
  Map<String, dynamic> _themeConfig = {};
  final TextEditingController _sslStoreIdCtrl = TextEditingController();
  final TextEditingController _sslStorePassCtrl = TextEditingController();
  final TextEditingController _bkashNumberCtrl = TextEditingController();
  final TextEditingController _nagadNumberCtrl = TextEditingController();
  bool _sslSandbox = true;

  // 4. Security & 2FA State
  bool _twoFactorEnabled = false;
  final TextEditingController _securityPhoneCtrl = TextEditingController();
  final TextEditingController _securityEmailCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  bool _obscurePass = true;

  // 5. Announcements & Alerts State
  bool _showAnnouncementBar = true;
  final TextEditingController _headerAnnouncementTextCtrl =
      TextEditingController();
  final TextEditingController _headerAnnouncementPhoneCtrl =
      TextEditingController();
  List<dynamic> _storeAnnouncements = [];
  List<dynamic> _adminNotifications = [];
  final TextEditingController _newAnnTitleCtrl =
      TextEditingController(text: 'Special Offer');
  final TextEditingController _newAnnMsgCtrl = TextEditingController();
  final TextEditingController _newAnnPhoneCtrl =
      TextEditingController(text: '+880 1700-000000');
  String _newAnnStyle = 'top_bar';

  // Active Brand Color & Gradient Getters
  Color get _activeBrandColor => _mobilePrimaryColor;
  LinearGradient get _activeGradient => LinearGradient(
        colors: [_mobilePrimaryColor, _mobileSecondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Theme Helpers
  Color get _cardBg =>
      widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get _cardBorder =>
      widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2EBE0);
  Color get _primaryText =>
      widget.isDarkMode ? Colors.white : const Color(0xFF1E3A1A);
  Color get _secondaryText =>
      widget.isDarkMode ? const Color(0xFF94A3B8) : Colors.grey.shade600;
  Color get _inputBg =>
      widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  // Preset Swatches for Individual Color Picker (No angle brackets to prevent copy-paste issues)
  static const _presetHexColors = [
    '#5B9A42', '#059669', '#16A34A', '#0D9488', '#0891B2', '#0284C7',
    '#2563EB', '#4F46E5', '#7C3AED', '#9333EA', '#C026D3', '#DB2777',
    '#E11D48', '#DC2626', '#EA580C', '#D97706', '#CA8A04', '#65A30D',
    '#1E3A1A', '#0F172A', '#1E293B', '#334155', '#50332A', '#7E22CE',
  ];

  // Ready-made Gradient Presets (Primary + Secondary pairs)
  static const _gradientPresets = [
    {'name': 'Xylo Forest', 'primary': '#5B9A42', 'secondary': '#1E3A1A'},
    {'name': 'Royal Purple', 'primary': '#9333EA', 'secondary': '#3B0764'},
    {'name': 'Emerald Glow', 'primary': '#10B981', 'secondary': '#064E3B'},
    {'name': 'Ocean Blue', 'primary': '#2563EB', 'secondary': '#0F172A'},
    {'name': 'Cyber Pink', 'primary': '#EC4899', 'secondary': '#4C1D95'},
    {'name': 'Sunset Flame', 'primary': '#F97316', 'secondary': '#7F1D1D'},
    {'name': 'Teal Breeze', 'primary': '#0D9488', 'secondary': '#134E4A'},
    {'name': 'Gold Luxury', 'primary': '#D97706', 'secondary': '#451A03'},
  ];

  @override
  void initState() {
    super.initState();
    _activeSubTab = widget.initialTab;
    _mobilePrimaryColor = widget.brandGreen;
    _mobileSecondaryColor = const Color(0xFF1E3A1A);
    _primaryColorCtrl.text = _colorToHex(_mobilePrimaryColor);
    _secondaryColorCtrl.text = _colorToHex(_mobileSecondaryColor);
    _loadAllSettingsData();
  }

  @override
  void didUpdateWidget(covariant GeneralSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _activeSubTab = widget.initialTab;
      });
    }
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _taglineCtrl.dispose();
    _descCtrl.dispose();
    _primaryColorCtrl.dispose();
    _secondaryColorCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactAddressCtrl.dispose();
    _sslStoreIdCtrl.dispose();
    _sslStorePassCtrl.dispose();
    _bkashNumberCtrl.dispose();
    _nagadNumberCtrl.dispose();
    _securityPhoneCtrl.dispose();
    _securityEmailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _headerAnnouncementTextCtrl.dispose();
    _headerAnnouncementPhoneCtrl.dispose();
    _newAnnTitleCtrl.dispose();
    _newAnnMsgCtrl.dispose();
    _newAnnPhoneCtrl.dispose();
    super.dispose();
  }

  Color _hexToColor(String hexString,
      {Color fallback = const Color(0xFF5B9A42)}) {
    String clean = hexString.trim().replaceAll('#', '');
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    final int? val = int.tryParse(clean, radix: 16);
    if (val != null) {
      return Color(val);
    }
    return fallback;
  }

  String _colorToHex(Color color) {
    final int r = (color.r * 255.0).round() & 0xff;
    final int g = (color.g * 255.0).round() & 0xff;
    final int b = (color.b * 255.0).round() & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Future<void> _persistMobileThemeAndNotify() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'mobile_app_primary_color', _colorToHex(_mobilePrimaryColor));
    await prefs.setString(
        'mobile_app_secondary_color', _colorToHex(_mobileSecondaryColor));
    await prefs.setBool('mobile_app_use_gradient', _useGradient);
    if (widget.onSettingsUpdated != null) {
      widget.onSettingsUpdated!();
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Tenant-Subdomain': _subdomain,
        'x-subdomain': _subdomain,
        'X-Tenant-Domain': _subdomain,
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Future<void> _loadAllSettingsData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('merchant_token') ?? '';
    _subdomain = prefs.getString('active_subdomain') ?? 'bestbdbazar';
    _apiBase = prefs.getString('api_base_url') ?? 'https://nextlook.shop.xylotechsolution.com';
    if (_apiBase.endsWith('/')) {
      _apiBase = _apiBase.substring(0, _apiBase.length - 1);
    }

    // Load Mobile-Only Colors & Gradient Mode from SharedPreferences
    final String savedMobPrimary =
        prefs.getString('mobile_app_primary_color') ??
            _colorToHex(widget.brandGreen);
    final String savedMobSecondary =
        prefs.getString('mobile_app_secondary_color') ?? '#1E3A1A';
    _useGradient = prefs.getBool('mobile_app_use_gradient') ?? true;

    _mobilePrimaryColor =
        _hexToColor(savedMobPrimary, fallback: widget.brandGreen);
    _mobileSecondaryColor =
        _hexToColor(savedMobSecondary, fallback: const Color(0xFF1E3A1A));
    _primaryColorCtrl.text = _colorToHex(_mobilePrimaryColor);
    _secondaryColorCtrl.text = _colorToHex(_mobileSecondaryColor);

    final userJson = prefs.getString('merchant_user');
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final u = jsonDecode(userJson);
        if (u is Map && u['email'] != null) {
          _securityEmailCtrl.text = u['email'].toString();
        }
      } catch (_) {}
    }

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/settings/?subdomain=$_subdomain'),
              headers: _headers,
            )
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/marketplace/themes/?subdomain=$_subdomain'),
              headers: _headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/subscriptions/current/?subdomain=$_subdomain'),
              headers: _headers,
            )
            .then((res) => res.statusCode == 404
                ? http.get(
                    Uri.parse(
                        '$_apiBase/api/v1/stores/merchant/subscription/?subdomain=$_subdomain'),
                    headers: _headers,
                  )
                : Future.value(res))
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/subscriptions/plans/?subdomain=$_subdomain'),
              headers: _headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/merchant/security/?subdomain=$_subdomain&email=${Uri.encodeComponent(_securityEmailCtrl.text)}'),
              headers: _headers,
            )
            .catchError((_) => http.Response('{}', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/store-announcements/?subdomain=$_subdomain'),
              headers: _headers,
            )
            .catchError((_) => http.Response('[]', 500)),
        http
            .get(
              Uri.parse(
                  '$_apiBase/api/v1/stores/merchant/admin-notifications/?subdomain=$_subdomain'),
              headers: _headers,
            )
            .catchError((_) => http.Response('[]', 500)),
      ]);

      if (results[0].statusCode == 200) {
        final s = jsonDecode(results[0].body);
        if (s is Map) {
          _storeNameCtrl.text = (s['store_name'] ?? '').toString();
          _taglineCtrl.text = (s['store_tagline'] ?? '').toString();
          _descCtrl.text = (s['store_description'] ?? '').toString();
          _contactEmailCtrl.text = (s['contact_email'] ?? '').toString();
          _contactPhoneCtrl.text = (s['contact_phone'] ?? '').toString();
          _contactAddressCtrl.text = (s['contact_address'] ?? '').toString();
          _selectedCurrency = (s['currency'] ?? 'BDT').toString();
          _currencySymbol = (s['currency_symbol'] ?? '৳').toString();
          _selectedThemeKey = (s['theme'] ?? 'grocery').toString();

          _enableCod = s['enable_cod'] ?? true;
          _enableOnlinePayment = s['enable_online_payment'] ?? true;

          _showAnnouncementBar = s['show_announcement_bar'] ?? true;
          _headerAnnouncementTextCtrl.text =
              (s['announcement_text'] ?? '').toString();
          _headerAnnouncementPhoneCtrl.text =
              (s['announcement_phone'] ?? '').toString();

          if (s['theme_config'] is Map) {
            _themeConfig = Map<String, dynamic>.from(s['theme_config']);
            final pg = _themeConfig['payment_gateways'];
            if (pg is Map) {
              _sslStoreIdCtrl.text = (pg['ssl_store_id'] ?? '').toString();
              _sslStorePassCtrl.text = (pg['ssl_store_pass'] ?? '').toString();
              _bkashNumberCtrl.text = (pg['bkash_number'] ?? '').toString();
              _nagadNumberCtrl.text = (pg['nagad_number'] ?? '').toString();
              _sslSandbox = pg['ssl_sandbox'] ?? true;
            }
          }
        }
      }

      if (results[1].statusCode == 200) {
        final tData = jsonDecode(results[1].body);
        if (tData is List) {
          _marketplaceThemes = tData;
        }
      }

      if (results[2].statusCode == 200) {
        final subData = jsonDecode(results[2].body);
        if (subData is Map) {
          _currentSubscription = Map<String, dynamic>.from(subData);
        }
      }

      if (results[3].statusCode == 200) {
        final pData = jsonDecode(results[3].body);
        if (pData is List) {
          _allPlans = pData;
        } else if (pData is Map && pData['results'] is List) {
          _allPlans = pData['results'];
        }
      }

      if (results[4].statusCode == 200) {
        final secData = jsonDecode(results[4].body);
        if (secData is Map) {
          _securityPhoneCtrl.text = (secData['phone'] ?? '').toString();
          _twoFactorEnabled = secData['two_factor_enabled'] == true;
        }
      }

      if (results[5].statusCode == 200) {
        final aData = jsonDecode(results[5].body);
        if (aData is List) {
          _storeAnnouncements = aData;
        } else if (aData is Map && aData['results'] is List) {
          _storeAnnouncements = aData['results'];
        }
      }

      if (results[6].statusCode == 200) {
        final nData = jsonDecode(results[6].body);
        if (nData is List) {
          _adminNotifications = nData;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : _activeBrandColor,
        content: Text(
          msg,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ===========================================================================
  // MOBILE APP COLOR PICKER DIALOG (DOES NOT AFFECT WEBSITE)
  // ===========================================================================

  Future<void> _openColorPickerDialog({required bool isPrimary}) async {
    Color tempColor = isPrimary ? _mobilePrimaryColor : _mobileSecondaryColor;
    HSVColor hsv = HSVColor.fromColor(tempColor);
    final TextEditingController hexInputCtrl =
        TextEditingController(text: _colorToHex(tempColor));

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateFromColor(Color c) {
              tempColor = c;
              hsv = HSVColor.fromColor(c);
              hexInputCtrl.text = _colorToHex(c);
            }

            final Color previewStart =
                isPrimary ? tempColor : _mobilePrimaryColor;
            final Color previewEnd =
                isPrimary ? _mobileSecondaryColor : tempColor;

            return AlertDialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: _cardBorder),
              ),
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tempColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: tempColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPrimary
                              ? 'Mobile App Primary Color'
                              : 'Mobile App Secondary Color',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _primaryText,
                          ),
                        ),
                        Text(
                          'Shudhu mobile app-er jonno (Website-e change hobe na)',
                          style: TextStyle(fontSize: 11, color: _secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live Solid + Gradient Preview Banner
                      Container(
                        height: 58,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _useGradient ? null : tempColor,
                          gradient: _useGradient
                              ? LinearGradient(
                                  colors: [previewStart, previewEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _cardBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _useGradient
                              ? '${_colorToHex(previewStart)}  ➔  ${_colorToHex(previewEnd)}'
                              : _colorToHex(tempColor),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.0,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Hue Slider
                      Text(
                        'Hue (Color Tone)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _primaryText,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor:
                              HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0)
                                  .toColor(),
                          thumbColor: tempColor,
                        ),
                        child: Slider(
                          value: hsv.hue,
                          min: 0,
                          max: 360,
                          onChanged: (val) {
                            setModalState(() {
                              hsv = hsv.withHue(val);
                              tempColor = hsv.toColor();
                              hexInputCtrl.text = _colorToHex(tempColor);
                            });
                          },
                        ),
                      ),

                      // Saturation Slider
                      Text(
                        'Saturation (Intensity)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _primaryText,
                        ),
                      ),
                      Slider(
                        value: hsv.saturation,
                        min: 0.0,
                        max: 1.0,
                        activeColor: tempColor,
                        onChanged: (val) {
                          setModalState(() {
                            hsv = hsv.withSaturation(val);
                            tempColor = hsv.toColor();
                            hexInputCtrl.text = _colorToHex(tempColor);
                          });
                        },
                      ),

                      // Brightness Slider
                      Text(
                        'Brightness (Dark / Light)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _primaryText,
                        ),
                      ),
                      Slider(
                        value: hsv.value,
                        min: 0.1,
                        max: 1.0,
                        activeColor: tempColor,
                        onChanged: (val) {
                          setModalState(() {
                            hsv = hsv.withValue(val);
                            tempColor = hsv.toColor();
                            hexInputCtrl.text = _colorToHex(tempColor);
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Preset Color Swatches
                      Text(
                        'Quick Preset Colors',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presetHexColors.map((hex) {
                          final Color swatchColor = _hexToColor(hex);
                          final bool isSelected =
                              _colorToHex(tempColor) == hex.toUpperCase();
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                updateFromColor(swatchColor);
                              });
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: swatchColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black26,
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Manual Hex Field
                      TextField(
                        controller: hexInputCtrl,
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Hex Code (e.g. #9333EA)',
                          labelStyle:
                              TextStyle(color: _secondaryText, fontSize: 12),
                          prefixIcon:
                              Icon(Icons.tag, color: tempColor, size: 18),
                          filled: true,
                          fillColor: _inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _cardBorder),
                          ),
                        ),
                        onChanged: (val) {
                          final cleaned = val.trim().replaceAll('#', '');
                          if (cleaned.length == 6 &&
                              int.tryParse(cleaned, radix: 16) != null) {
                            setModalState(() {
                              tempColor = _hexToColor('#$cleaned');
                              hsv = HSVColor.fromColor(tempColor);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: _secondaryText, fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final String pickedHex = _colorToHex(tempColor);
                    setState(() {
                      if (isPrimary) {
                        _mobilePrimaryColor = tempColor;
                        _primaryColorCtrl.text = pickedHex;
                      } else {
                        _mobileSecondaryColor = tempColor;
                        _secondaryColorCtrl.text = pickedHex;
                      }
                    });
                    await _persistMobileThemeAndNotify();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tempColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text(
                    'Apply to Mobile App',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // API SAVE ACTIONS
  // ===========================================================================

  Future<void> _saveStoreSettings(Map<String, dynamic> payload,
      {String successMsg = 'Settings shofolbhabe save hoyeche!'}) async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save Mobile App Colors & Gradient locally ONLY (Never sent to Website API)
      _mobilePrimaryColor = _hexToColor(
        _primaryColorCtrl.text,
        fallback: _mobilePrimaryColor,
      );
      _mobileSecondaryColor = _hexToColor(
        _secondaryColorCtrl.text,
        fallback: _mobileSecondaryColor,
      );
      await _persistMobileThemeAndNotify();

      final res = await http.patch(
        Uri.parse('$_apiBase/api/v1/stores/settings/?subdomain=$_subdomain'),
        headers: _headers,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        if (_storeNameCtrl.text.trim().isNotEmpty) {
          await prefs.setString('store_name', _storeNameCtrl.text.trim());
        }
        _showSnack(successMsg);
        if (widget.onSettingsUpdated != null) {
          widget.onSettingsUpdated!();
        }
      } else {
        _showSnack('Save korte somossha hoyeche (${res.statusCode})',
            isError: true);
      }
    } catch (e) {
      _showSnack('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _activateOrBuyTheme(String themeKey, bool isPurchased) async {
    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/marketplace/themes/action/?subdomain=$_subdomain'),
        headers: _headers,
        body: jsonEncode({
          'action': isPurchased ? 'activate' : 'buy',
          'theme_key': themeKey,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _showSnack(data['message'] ?? 'Theme active hoyeche!');
        await _loadAllSettingsData();
      } else {
        _showSnack(data['detail'] ?? 'Theme update ব্যর্থ হয়েছে',
            isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSecuritySettings() async {
    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/merchant/security/?subdomain=$_subdomain'),
        headers: _headers,
        body: jsonEncode({
          'email': _securityEmailCtrl.text.trim(),
          'phone': _securityPhoneCtrl.text.trim(),
          'enable_2fa': _twoFactorEnabled,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _showSnack(data['message'] ?? 'Security & 2FA update hoyeche!');
      } else {
        _showSnack(data['detail'] ?? 'Update ব্যর্থ হয়েছে', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeMerchantPassword() async {
    final newPass = _newPasswordCtrl.text.trim();
    final confirmPass = _confirmPasswordCtrl.text.trim();

    if (newPass.length < 6) {
      _showSnack('Notun password kompokkhe 6 okkhorer hote hobe!',
          isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('Password duiti milche na!', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/merchant/change-password/?subdomain=$_subdomain'),
        headers: _headers,
        body: jsonEncode({
          'email': _securityEmailCtrl.text.trim(),
          'new_password': newPass,
          'enable_2fa': _twoFactorEnabled,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
        _showSnack(data['message'] ?? 'Password poriborton hoyeche!');
      } else {
        _showSnack(data['detail'] ?? 'Password change ব্যর্থ হয়েছে',
            isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createStoreAnnouncement() async {
    if (_newAnnMsgCtrl.text.trim().isEmpty) {
      _showSnack('Announcement message likhun!', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/store-announcements/?subdomain=$_subdomain'),
        headers: _headers,
        body: jsonEncode({
          'title': _newAnnTitleCtrl.text.trim(),
          'message': _newAnnMsgCtrl.text.trim(),
          'phone': _newAnnPhoneCtrl.text.trim(),
          'display_style': _newAnnStyle,
          'is_active': true,
          'sync_to_header_bar': true,
        }),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        _newAnnMsgCtrl.clear();
        _showSnack('Storefront Announcement create o live kora hoyeche!');
        await _loadAllSettingsData();
      } else {
        _showSnack('Create korte somossha hoyeche', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _activateAnnouncementOnHeader(int id) async {
    try {
      final res = await http.post(
        Uri.parse(
            '$_apiBase/api/v1/stores/store-announcements/$id/activate/?subdomain=$_subdomain'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        _showSnack('Announcement-ti Storefront Top Bar-e live kora hoyeche!');
        await _loadAllSettingsData();
      }
    } catch (_) {}
  }

  Future<void> _deleteStoreAnnouncement(int id) async {
    try {
      final res = await http.delete(
        Uri.parse(
            '$_apiBase/api/v1/stores/store-announcements/$id/?subdomain=$_subdomain'),
        headers: _headers,
      );
      if (res.statusCode == 204 || res.statusCode == 200) {
        _showSnack('Announcement delete kora hoyeche.');
        await _loadAllSettingsData();
      }
    } catch (_) {}
  }

  // ===========================================================================
  // UI BUILDERS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _useGradient
                          ? null
                          : _activeBrandColor.withValues(alpha: 0.15),
                      gradient: _useGradient ? _activeGradient : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.settings_suggest_rounded,
                      color: _useGradient ? Colors.white : _activeBrandColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'General Settings & Store Control',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _primaryText,
                          ),
                        ),
                        Text(
                          'Theme, Subscription, Payment, 2FA Security & Announcements',
                          style: TextStyle(fontSize: 11, color: _secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadAllSettingsData,
                    icon: Icon(Icons.refresh_rounded, color: _primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 5 Sub-Tabs Navigation Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSubTabChip('theme_branding', 'Theme & Branding',
                        Icons.palette_outlined),
                    _buildSubTabChip('subscription_billing',
                        'Subscription & Billing', Icons.card_membership_rounded),
                    _buildSubTabChip('payment_gateways', 'Payment Gateways',
                        Icons.account_balance_wallet_outlined),
                    _buildSubTabChip('security_2fa', 'Security & 2FA',
                        Icons.security_rounded),
                    _buildSubTabChip('announcements_alerts',
                        'Announcements & Alerts', Icons.campaign_outlined),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: _activeBrandColor),
            ),
          )
        else
          _buildSelectedTabBody(),
      ],
    );
  }

  Widget _buildSubTabChip(String id, String label, IconData icon) {
    final bool isSelected = _activeSubTab == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _activeSubTab = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (_useGradient ? null : _activeBrandColor)
                : _inputBg,
            gradient: (isSelected && _useGradient) ? _activeGradient : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _activeBrandColor : _cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : _primaryText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : _primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabBody() {
    switch (_activeSubTab) {
      case 'subscription_billing':
        return _buildSubscriptionBillingTab();
      case 'payment_gateways':
        return _buildPaymentGatewaysTab();
      case 'security_2fa':
        return _buildSecurity2FATab();
      case 'announcements_alerts':
        return _buildAnnouncementsAlertsTab();
      case 'theme_branding':
      default:
        return _buildThemeBrandingTab();
    }
  }

  // ===========================================================================
  // TAB 1: THEME & BRANDING (WITH SOLID + GRADIENT COLOR SYSTEM)
  // ===========================================================================
  Widget _buildThemeBrandingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Store Identity & Mobile App Colors Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Store Identity & Brand Colors',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 14),
              _buildTextField('Store Name', _storeNameCtrl, Icons.storefront),
              const SizedBox(height: 12),
              _buildTextField(
                  'Store Tagline / Slogan', _taglineCtrl, Icons.short_text),
              const SizedBox(height: 12),
              _buildTextField('Store Description', _descCtrl, Icons.description,
                  maxLines: 2),
              const SizedBox(height: 14),

              // Mobile App Color & Gradient Control Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _activeBrandColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _activeBrandColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_iphone_rounded,
                            color: _activeBrandColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mobile App Theme & Gradient System (শুধুমাত্র মোবাইল অ্যাপের জন্য)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: _primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Live Gradient / Solid Preview Bar
                    Container(
                      height: 38,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _useGradient ? null : _mobilePrimaryColor,
                        gradient: _useGradient ? _activeGradient : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _useGradient
                            ? 'ACTIVE GRADIENT: ${_colorToHex(_mobilePrimaryColor)} ➔ ${_colorToHex(_mobileSecondaryColor)}'
                            : 'ACTIVE SOLID COLOR: ${_colorToHex(_mobilePrimaryColor)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Gradient Mode Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: _activeBrandColor,
                      title: Text(
                        'Enable Gradient Color Mode (Primary + Secondary)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _primaryText,
                        ),
                      ),
                      subtitle: Text(
                        'Top Bar, Bottom Bar, Drawer, Cards o Button-e gradient lagbe',
                        style: TextStyle(fontSize: 10.5, color: _secondaryText),
                      ),
                      value: _useGradient,
                      onChanged: (val) async {
                        setState(() => _useGradient = val);
                        await _persistMobileThemeAndNotify();
                      },
                    ),

                    // Quick Gradient Presets Row
                    Text(
                      '1-Click Gradient Presets:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _gradientPresets.map((preset) {
                          final Color c1 =
                              _hexToColor(preset['primary'] ?? '#5B9A42');
                          final Color c2 =
                              _hexToColor(preset['secondary'] ?? '#1E3A1A');
                          final String pName = preset['name'] ?? 'Preset';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () async {
                                setState(() {
                                  _mobilePrimaryColor = c1;
                                  _mobileSecondaryColor = c2;
                                  _primaryColorCtrl.text = _colorToHex(c1);
                                  _secondaryColorCtrl.text = _colorToHex(c2);
                                  _useGradient = true;
                                });
                                await _persistMobileThemeAndNotify();
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [c1, c2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.white30, width: 1),
                                ),
                                child: Text(
                                  pName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
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
              const SizedBox(height: 12),

              // Interactive Color Picker Fields (Primary & Secondary)
              Row(
                children: [
                  Expanded(
                    child: _buildColorPickerField(
                      label: 'Primary Hex (App)',
                      controller: _primaryColorCtrl,
                      currentColor: _mobilePrimaryColor,
                      onTapPicker: () => _openColorPickerDialog(isPrimary: true),
                      onHexSubmitted: (val) async {
                        final c =
                            _hexToColor(val, fallback: _mobilePrimaryColor);
                        setState(() {
                          _mobilePrimaryColor = c;
                          _primaryColorCtrl.text = _colorToHex(c);
                        });
                        await _persistMobileThemeAndNotify();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildColorPickerField(
                      label: 'Secondary Hex (App)',
                      controller: _secondaryColorCtrl,
                      currentColor: _mobileSecondaryColor,
                      onTapPicker: () =>
                          _openColorPickerDialog(isPrimary: false),
                      onHexSubmitted: (val) async {
                        final c =
                            _hexToColor(val, fallback: _mobileSecondaryColor);
                        setState(() {
                          _mobileSecondaryColor = c;
                          _secondaryColorCtrl.text = _colorToHex(c);
                        });
                        await _persistMobileThemeAndNotify();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        'Contact Phone', _contactPhoneCtrl, Icons.phone),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                        'Contact Email', _contactEmailCtrl, Icons.email),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                  'Store Address', _contactAddressCtrl, Icons.location_on),
              const SizedBox(height: 16),
              _buildGradientActionButton(
                label: 'Save Branding & Identity',
                icon: Icons.save_rounded,
                onPressed: _isSaving
                    ? null
                    : () {
                        _saveStoreSettings({
                          'store_name': _storeNameCtrl.text.trim(),
                          'store_tagline': _taglineCtrl.text.trim(),
                          'store_description': _descCtrl.text.trim(),
                          'contact_phone': _contactPhoneCtrl.text.trim(),
                          'contact_email': _contactEmailCtrl.text.trim(),
                          'contact_address': _contactAddressCtrl.text.trim(),
                          'currency': _selectedCurrency,
                          'currency_symbol': _currencySymbol,
                          'theme': _selectedThemeKey,
                        },
                            successMsg:
                                'Mobile App Color, Gradient o Store Identity save hoyeche!');
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Theme Marketplace Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2. Storefront Theme Marketplace',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Active storefront template select ba purchase korun',
                style: TextStyle(fontSize: 11, color: _secondaryText),
              ),
              const SizedBox(height: 14),
              ..._marketplaceThemes.map((t) {
                final String key = (t['key'] ?? 'default').toString();
                final String name = (t['name'] ?? 'Theme').toString();
                final String tagline = (t['tagline'] ?? '').toString();
                final double price =
                    double.tryParse((t['price'] ?? 0).toString()) ?? 0.0;
                final bool isFree = t['is_free'] == true || price <= 0;
                final bool isPurchased = t['is_purchased'] == true || isFree;
                final bool isActive =
                    t['is_active'] == true || _selectedThemeKey == key;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _inputBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? _activeBrandColor : _cardBorder,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _useGradient
                              ? null
                              : _activeBrandColor.withValues(alpha: 0.15),
                          gradient: _useGradient ? _activeGradient : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.web_rounded,
                          color:
                              _useGradient ? Colors.white : _activeBrandColor,
                          size: 22,
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
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: _primaryText,
                              ),
                            ),
                            Text(
                              tagline,
                              style: TextStyle(
                                  fontSize: 11, color: _secondaryText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isFree
                                  ? 'FREE THEME'
                                  : 'PREMIUM • ৳${price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isFree
                                    ? _activeBrandColor
                                    : Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isActive
                            ? null
                            : () => _activateOrBuyTheme(key, isPurchased),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive
                              ? Colors.grey
                              : (isPurchased
                                  ? _activeBrandColor
                                  : Colors.amber.shade700),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          isActive
                              ? 'Active'
                              : (isPurchased ? 'Activate' : 'Unlock'),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        color: _useGradient ? null : _activeBrandColor,
        gradient: _useGradient ? _activeGradient : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _activeBrandColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildColorPickerField({
    required String label,
    required TextEditingController controller,
    required Color currentColor,
    required VoidCallback onTapPicker,
    required ValueChanged<String> onHexSubmitted,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTapPicker,
      onSubmitted: onHexSubmitted,
      style: TextStyle(
        color: _primaryText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _secondaryText, fontSize: 12),
        prefixIcon: GestureDetector(
          onTap: onTapPicker,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: currentColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
        suffixIcon: IconButton(
          tooltip: 'Pick Color',
          icon: Icon(Icons.colorize_rounded, color: _activeBrandColor, size: 18),
          onPressed: onTapPicker,
        ),
        filled: true,
        fillColor: _inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _cardBorder),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SUBSCRIPTION & BILLING
  // ===========================================================================
  Widget _buildSubscriptionBillingTab() {
    final String planName =
        (_currentSubscription['plan_name'] ?? 'Growth Spark').toString();
    final String status =
        (_currentSubscription['status'] ?? 'Active').toString();
    final String priceStr =
        (_currentSubscription['price'] ?? '৳1,500 / মাস').toString();
    final int daysLeft =
        int.tryParse((_currentSubscription['days_left'] ?? 30).toString()) ??
            30;
    final String expiryDate =
        (_currentSubscription['expiry_date'] ?? 'N/A').toString();

    final Map<String, dynamic> branchQuota =
        (_currentSubscription['branch_quota'] is Map)
            ? Map<String, dynamic>.from(_currentSubscription['branch_quota'])
            : {};
    final int maxBranches =
        int.tryParse((branchQuota['max_branches'] ?? 1).toString()) ?? 1;
    final int branchesUsed =
        int.tryParse((branchQuota['branches_used'] ?? 0).toString()) ?? 0;
    final int maxProdPerBranch = int.tryParse(
            (branchQuota['max_products_per_branch'] ?? 100).toString()) ??
        100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Active Plan Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: _useGradient
                ? _activeGradient
                : const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: _activeBrandColor.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'CURRENT PLAN • ${status.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$daysLeft Days Left',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                planName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$priceStr • Expires: $expiryDate',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDarkQuotaBox(
                        'Branches Used', '$branchesUsed / $maxBranches'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDarkQuotaBox(
                        'Products / Branch', 'Max $maxProdPerBranch'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Available Plans List
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available SaaS Plans & Quotas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Database-er live subscription plans (/api/v1/subscriptions/plans/)',
                style: TextStyle(fontSize: 11, color: _secondaryText),
              ),
              const SizedBox(height: 14),
              if (_allPlans.isEmpty)
                Text(
                  'Kono additional plan paoa jayni.',
                  style: TextStyle(color: _secondaryText, fontSize: 12),
                )
              else
                ..._allPlans.map((pl) {
                  final String pDisplay =
                      (pl['display_name'] ?? pl['name'] ?? 'Plan').toString();
                  final String mPrice =
                      (pl['monthly_price'] ?? '0').toString();
                  final int maxProd =
                      int.tryParse((pl['max_products'] ?? 100).toString()) ??
                          100;
                  final int maxBr =
                      int.tryParse((pl['max_branches'] ?? 1).toString()) ?? 1;
                  final bool isCurrent =
                      pDisplay.toLowerCase() == planName.toLowerCase();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? _activeBrandColor : _cardBorder,
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pDisplay,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: _primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '৳$mPrice / month • Max $maxProd Products • $maxBr Branches',
                                style: TextStyle(
                                    fontSize: 11, color: _secondaryText),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (_useGradient ? null : _activeBrandColor)
                                : _activeBrandColor.withValues(alpha: 0.12),
                            gradient: (isCurrent && _useGradient)
                                ? _activeGradient
                                : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isCurrent ? 'Current' : 'Available',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isCurrent
                                  ? Colors.white
                                  : _activeBrandColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDarkQuotaBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: PAYMENT GATEWAYS
  // ===========================================================================
  Widget _buildPaymentGatewaysTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Checkout & Payment Gateways',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cash on Delivery (COD), SSLCommerz, bKash o Nagad setup korun',
            style: TextStyle(fontSize: 11, color: _secondaryText),
          ),
          const SizedBox(height: 14),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: _activeBrandColor,
            title: Text(
              'Enable Cash on Delivery (COD)',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: _primaryText),
            ),
            subtitle: Text(
              'Customer product hate peye taka porishod korte parbe',
              style: TextStyle(fontSize: 11, color: _secondaryText),
            ),
            value: _enableCod,
            onChanged: (val) => setState(() => _enableCod = val),
          ),
          Divider(color: _cardBorder),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: _activeBrandColor,
            title: Text(
              'Enable Online Payment (SSLCommerz / MFS)',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: _primaryText),
            ),
            subtitle: Text(
              'bKash, Nagad, Rocket o Card payment accept korun',
              style: TextStyle(fontSize: 11, color: _secondaryText),
            ),
            value: _enableOnlinePayment,
            onChanged: (val) => setState(() => _enableOnlinePayment = val),
          ),
          const SizedBox(height: 12),

          _buildTextField(
              'SSLCommerz Store ID', _sslStoreIdCtrl, Icons.vpn_key_outlined),
          const SizedBox(height: 12),
          _buildTextField('SSLCommerz Store Password', _sslStorePassCtrl,
              Icons.lock_outline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField('bKash Merchant / Personal No',
                    _bkashNumberCtrl, Icons.phone_android),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField('Nagad Merchant / Personal No',
                    _nagadNumberCtrl, Icons.phone_iphone),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.amber.shade700,
            title: Text(
              'SSLCommerz Sandbox (Test Mode)',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: _primaryText),
            ),
            value: _sslSandbox,
            onChanged: (val) => setState(() => _sslSandbox = val),
          ),
          const SizedBox(height: 14),

          _buildGradientActionButton(
            label: 'Save Payment Gateways',
            icon: Icons.check_circle_outline,
            onPressed: _isSaving
                ? null
                : () {
                    final updatedThemeCfg =
                        Map<String, dynamic>.from(_themeConfig);
                    updatedThemeCfg['payment_gateways'] = {
                      'ssl_store_id': _sslStoreIdCtrl.text.trim(),
                      'ssl_store_pass': _sslStorePassCtrl.text.trim(),
                      'bkash_number': _bkashNumberCtrl.text.trim(),
                      'nagad_number': _nagadNumberCtrl.text.trim(),
                      'ssl_sandbox': _sslSandbox,
                    };
                    _saveStoreSettings({
                      'enable_cod': _enableCod,
                      'enable_online_payment': _enableOnlinePayment,
                      'theme_config': updatedThemeCfg,
                    }, successMsg: 'Payment Gateways save hoyeche!');
                  },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: SECURITY & 2FA
  // ===========================================================================
  Widget _buildSecurity2FATab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 2FA Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Two-Factor Authentication (2FA)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Login security ebong verification mobile number setup korun',
                style: TextStyle(fontSize: 11, color: _secondaryText),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _activeBrandColor,
                title: Text(
                  'Enable Two-Factor Authentication (2FA)',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: _primaryText),
                ),
                subtitle: Text(
                  _twoFactorEnabled
                      ? 'Status: Enabled (Protected)'
                      : 'Status: Disabled',
                  style: TextStyle(
                      fontSize: 11,
                      color: _twoFactorEnabled
                          ? _activeBrandColor
                          : _secondaryText),
                ),
                value: _twoFactorEnabled,
                onChanged: (val) => setState(() => _twoFactorEnabled = val),
              ),
              const SizedBox(height: 8),
              _buildTextField(
                  'Merchant Email', _securityEmailCtrl, Icons.email_outlined),
              const SizedBox(height: 12),
              _buildTextField('2FA Security Phone Number', _securityPhoneCtrl,
                  Icons.phone_locked_rounded),
              const SizedBox(height: 14),
              _buildGradientActionButton(
                label: 'Update 2FA & Security Info',
                icon: Icons.verified_user_outlined,
                onPressed: _isSaving ? null : _saveSecuritySettings,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Change Password Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2. Change Merchant Password',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordCtrl,
                obscureText: _obscurePass,
                style: TextStyle(color: _primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'New Password (min 6 chars)',
                  labelStyle: TextStyle(color: _secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.lock_outline,
                      color: _activeBrandColor, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: _secondaryText,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  filled: true,
                  fillColor: _inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: _obscurePass,
                style: TextStyle(color: _primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(color: _secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.lock_reset_rounded,
                      color: _activeBrandColor, size: 18),
                  filled: true,
                  fillColor: _inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _changeMerchantPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text(
                    'Update Password Now',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: ANNOUNCEMENTS & ALERTS
  // ===========================================================================
  Widget _buildAnnouncementsAlertsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Storefront Top Announcement Bar Settings
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Main Storefront Top Marquee Bar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _activeBrandColor,
                title: Text(
                  'Show Top Announcement Bar on Storefront',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _primaryText),
                ),
                value: _showAnnouncementBar,
                onChanged: (val) => setState(() => _showAnnouncementBar = val),
              ),
              _buildTextField('Top Bar Announcement Message',
                  _headerAnnouncementTextCtrl, Icons.campaign_rounded),
              const SizedBox(height: 10),
              _buildTextField('Hotline Phone in Top Bar',
                  _headerAnnouncementPhoneCtrl, Icons.phone_in_talk_rounded),
              const SizedBox(height: 12),
              _buildGradientActionButton(
                label: 'Update Top Bar Live',
                icon: Icons.publish_rounded,
                onPressed: _isSaving
                    ? null
                    : () {
                        _saveStoreSettings({
                          'show_announcement_bar': _showAnnouncementBar,
                          'announcement_text':
                              _headerAnnouncementTextCtrl.text.trim(),
                          'announcement_phone':
                              _headerAnnouncementPhoneCtrl.text.trim(),
                        }, successMsg: 'Top Announcement Bar update hoyeche!');
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Create New Storefront Promo Announcement
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2. Create Storefront Customer Announcement',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField('Badge / Title (e.g. EID SALE)', _newAnnTitleCtrl,
                  Icons.label_important_outline),
              const SizedBox(height: 10),
              _buildTextField('Announcement Message', _newAnnMsgCtrl,
                  Icons.announcement_outlined,
                  maxLines: 2),
              const SizedBox(height: 12),
              _buildGradientActionButton(
                label: 'Publish Storefront Announcement',
                icon: Icons.add_alert_rounded,
                onPressed: _isSaving ? null : _createStoreAnnouncement,
              ),
              if (_storeAnnouncements.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(color: _cardBorder),
                ..._storeAnnouncements.map((ann) {
                  final int id = int.tryParse((ann['id'] ?? 0).toString()) ?? 0;
                  final String title =
                      (ann['title'] ?? 'Announcement').toString();
                  final String msg = (ann['message'] ?? '').toString();
                  final bool isSynced = ann['sync_to_header_bar'] == true;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      title,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: _primaryText),
                    ),
                    subtitle: Text(
                      msg,
                      style: TextStyle(fontSize: 11.5, color: _secondaryText),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sync to Top Bar',
                          icon: Icon(
                            Icons.check_circle_rounded,
                            color: isSynced
                                ? _activeBrandColor
                                : _secondaryText,
                          ),
                          onPressed: () => _activateAnnouncementOnHeader(id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteStoreAnnouncement(id),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. System & Order Alerts
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '3. Platform Notices & Store Alerts (${_adminNotifications.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 10),
              if (_adminNotifications.isEmpty)
                Text(
                  'Kono system alert ba notification nei.',
                  style: TextStyle(fontSize: 12, color: _secondaryText),
                )
              else
                ..._adminNotifications.take(8).map((n) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.notifications_active_outlined,
                        color: _activeBrandColor, size: 20),
                    title: Text(
                      (n['title'] ?? 'Alert').toString(),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: _primaryText),
                    ),
                    subtitle: Text(
                      (n['message'] ?? '').toString(),
                      style: TextStyle(fontSize: 11, color: _secondaryText),
                    ),
                    trailing: Text(
                      (n['created_at'] ?? '').toString(),
                      style: TextStyle(fontSize: 9.5, color: _secondaryText),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
          color: _primaryText, fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _secondaryText, fontSize: 12),
        prefixIcon: Icon(icon, color: _activeBrandColor, size: 18),
        filled: true,
        fillColor: _inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _cardBorder),
        ),
      ),
    );
  }
}