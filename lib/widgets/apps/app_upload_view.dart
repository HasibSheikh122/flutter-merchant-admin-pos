// lib/widgets/apps/app_upload_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';

class AppUploadView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialSection;
  final VoidCallback? onOpenGenerateTab;
  final VoidCallback? onDataChanged;

  const AppUploadView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.initialSection = 'upload',
    this.onOpenGenerateTab,
    this.onDataChanged,
  });

  @override
  State<AppUploadView> createState() => _AppUploadViewState();
}

class _AppUploadViewState extends State<AppUploadView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _loading = true;
  bool _saving = false;

  Map _appConfig = {};

  final TextEditingController _storeApkUrlCtrl = TextEditingController();
  final TextEditingController _storeIosUrlCtrl = TextEditingController();
  final TextEditingController _storeWinUrlCtrl = TextEditingController();
  final TextEditingController _adminApkUrlCtrl = TextEditingController();
  final TextEditingController _adminIosUrlCtrl = TextEditingController();
  final TextEditingController _adminWinUrlCtrl = TextEditingController();
  final TextEditingController _navbarBadgeCtrl = TextEditingController();

  bool _showAppsInNavbar = true;
  bool _showAdminAppsInNavbar = false;

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant AppUploadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
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
    await _fetchAppConfig();
  }

  Future<void> _fetchAppConfig() async {
    setState(() => _loading = true);
    try {
      final String sub = Uri.encodeComponent(_theme.subdomain);
      final Uri url = Uri.parse(
        '${_theme.apiBase}/api/v1/stores/app-builder/?subdomain=$sub',
      );
      final response = await http
          .get(url, headers: _theme.headers)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['app_config'] is Map) {
          final Map cfg = decoded['app_config'];
          setState(() {
            _appConfig = cfg;
            _storeApkUrlCtrl.text = (cfg['store_apk_url'] ?? '').toString();
            _storeIosUrlCtrl.text = (cfg['store_ios_url'] ?? '').toString();
            _storeWinUrlCtrl.text = (cfg['store_windows_url'] ?? '').toString();
            _adminApkUrlCtrl.text = (cfg['admin_apk_url'] ?? '').toString();
            _adminIosUrlCtrl.text = (cfg['admin_ios_url'] ?? '').toString();
            _adminWinUrlCtrl.text = (cfg['admin_windows_url'] ?? '').toString();
            _navbarBadgeCtrl.text =
                (cfg['navbar_badge_text'] ?? 'Download App').toString();
            _showAppsInNavbar = cfg['show_apps_in_navbar'] != false;
            _showAdminAppsInNavbar = cfg['show_admin_apps_in_navbar'] == true;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _saveUrlsAndNavbarConfig() async {
    setState(() => _saving = true);
    try {
      final String sub = Uri.encodeComponent(_theme.subdomain);
      final Uri url = Uri.parse(
        '${_theme.apiBase}/api/v1/stores/app-builder/upload/?subdomain=$sub',
      );
      final Map payload = {
        'store_apk_url': _storeApkUrlCtrl.text.trim(),
        'store_ios_url': _storeIosUrlCtrl.text.trim(),
        'store_windows_url': _storeWinUrlCtrl.text.trim(),
        'admin_apk_url': _adminApkUrlCtrl.text.trim(),
        'admin_ios_url': _adminIosUrlCtrl.text.trim(),
        'admin_windows_url': _adminWinUrlCtrl.text.trim(),
        'navbar_badge_text': _navbarBadgeCtrl.text.trim(),
        'show_apps_in_navbar': _showAppsInNavbar,
        'show_admin_apps_in_navbar': _showAdminAppsInNavbar,
      };

      final response = await http
          .post(
            url,
            headers: _theme.headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() => _saving = false);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showToast('অ্যাপ ডাউনলোড লিংক ও Navbar সেটিংস সফলভাবে সেভ হয়েছে!');
        await _fetchAppConfig();
        if (widget.onDataChanged != null) widget.onDataChanged!();
      } else {
        _showToast('সেভ করতে সমস্যা হয়েছে।', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showToast('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    }
  }

  String _autoGeneratedDownloadEndpoint(String platformSlug) {
    final String sub = Uri.encodeComponent(_theme.subdomain);
    return '${_theme.apiBase}/api/v1/stores/app-builder/download/$platformSlug/?subdomain=$sub';
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

  void _copyLink(String url) {
    if (url.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    _showToast('ডাউনলোড লিংক কপি করা হয়েছে!');
  }

  @override
  void dispose() {
    _storeApkUrlCtrl.dispose();
    _storeIosUrlCtrl.dispose();
    _storeWinUrlCtrl.dispose();
    _adminApkUrlCtrl.dispose();
    _adminIosUrlCtrl.dispose();
    _adminWinUrlCtrl.dispose();
    _navbarBadgeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(18),
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
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload APK / iOS / Windows & Navbar App Links',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: t.primaryText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'আপনার APK, iOS (.ipa) ও Windows (.exe) অ্যাপের ডাউনলোড লিংক সেট করুন এবং Storefront Navbar-এ লাইভ করুন',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onOpenGenerateTab != null)
                    OutlinedButton.icon(
                      onPressed: widget.onOpenGenerateTab,
                      icon: Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: t.primaryColor,
                      ),
                      label: Text(
                        'Go to Generate Apps',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _fetchAppConfig,
                    icon: Icon(Icons.refresh_rounded, color: t.primaryColor),
                  ),
                ],
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
          // 1. Customer Storefront Apps Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Customer Storefront App Binaries & Links (Android APK, iOS IPA, Windows EXE)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBinaryLinkRow(
                  t,
                  title: 'Customer Android App (.apk)',
                  platformSlug: 'apk',
                  urlController: _storeApkUrlCtrl,
                  resolvedDownloadUrl:
                      (_appConfig['apk_download_url'] ?? '').toString(),
                  hasFile: _appConfig['has_store_apk_file'] == true,
                  icon: Icons.android_rounded,
                ),
                const SizedBox(height: 10),
                _buildBinaryLinkRow(
                  t,
                  title: 'Customer Apple iOS App (.ipa / App Store)',
                  platformSlug: 'ios',
                  urlController: _storeIosUrlCtrl,
                  resolvedDownloadUrl:
                      (_appConfig['ios_download_url'] ?? '').toString(),
                  hasFile: _appConfig['has_store_ios_file'] == true,
                  icon: Icons.phone_iphone_rounded,
                ),
                const SizedBox(height: 10),
                _buildBinaryLinkRow(
                  t,
                  title: 'Customer Windows Desktop App (.exe / .msix)',
                  platformSlug: 'windows',
                  urlController: _storeWinUrlCtrl,
                  resolvedDownloadUrl:
                      (_appConfig['windows_download_url'] ?? '').toString(),
                  hasFile: _appConfig['has_store_windows_file'] == true,
                  icon: Icons.desktop_windows_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Merchant Admin & POS Apps Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Merchant Admin & POS App Binaries & Links (Android APK, iOS, Windows POS)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBinaryLinkRow(
                  t,
                  title: 'Merchant Admin & POS Android (.apk)',
                  platformSlug: 'admin_apk',
                  urlController: _adminApkUrlCtrl,
                  resolvedDownloadUrl:
                      (_appConfig['admin_apk_download_url'] ?? '').toString(),
                  hasFile: _appConfig['has_admin_apk_file'] == true,
                  icon: Icons.admin_panel_settings_rounded,
                ),
                const SizedBox(height: 10),
                _buildBinaryLinkRow(
                  t,
                  title: 'Merchant Admin & POS iOS / macOS (.ipa / .dmg)',
                  platformSlug: 'admin_ios',
                  urlController: _adminIosUrlCtrl,
                  resolvedDownloadUrl:
                      (_appConfig['admin_ios_download_url'] ?? '').toString(),
                  hasFile: _appConfig['has_admin_ios_file'] == true,
                  icon: Icons.tablet_mac_rounded,
                ),
                const SizedBox(height: 10),
                _buildBinaryLinkRow(
                  t,
                  title: 'Merchant Admin & POS Windows Counter (.exe)',
                  platformSlug: 'admin_windows',
                  urlController: _adminWinUrlCtrl,
                  resolvedDownloadUrl:
                      (_appConfig['admin_windows_download_url'] ?? '')
                          .toString(),
                  hasFile: _appConfig['has_admin_windows_file'] == true,
                  icon: Icons.point_of_sale_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Storefront Navbar Visibility & Live Links
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3. Storefront Navbar App Download Button Control',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _navbarBadgeCtrl,
                  style: TextStyle(color: t.primaryText, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Navbar Button Text (e.g. Download App)',
                    filled: true,
                    fillColor: t.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _showAppsInNavbar,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Show Customer App Download Buttons (APK / iOS / Windows) in Storefront Navbar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                  onChanged: (v) => setState(() => _showAppsInNavbar = v),
                ),
                SwitchListTile(
                  value: _showAdminAppsInNavbar,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Also Show Merchant Admin & POS App Download Links in Storefront Navbar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                  onChanged: (v) => setState(() => _showAdminAppsInNavbar = v),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveUrlsAndNavbarConfig,
                  icon: const Icon(Icons.save_rounded, size: 17),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : 'Save All Download Links & Navbar Visibility',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBinaryLinkRow(
    CatalogThemeConfig t, {
    required String title,
    required String platformSlug,
    required TextEditingController urlController,
    required String resolvedDownloadUrl,
    required bool hasFile,
    required IconData icon,
  }) {
    final String autoUrl = _autoGeneratedDownloadEndpoint(platformSlug);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: t.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: t.primaryText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: hasFile
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF64748B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasFile ? 'READY / LIVE' : 'NOT SET',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: hasFile
                            ? const Color(0xFF10B981)
                            : t.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        urlController.text = autoUrl;
                      });
                      _showToast(
                          'ব্যাকএন্ডের অটো-জেনারেটেড ডাউনলোড লিংক বসানো হয়েছে! এখন নিচে Save বাটনে ক্লিক করুন।');
                    },
                    icon: Icon(
                      Icons.auto_fix_high_rounded,
                      size: 14,
                      color: t.primaryColor,
                    ),
                    label: Text(
                      'Use Generated Bundle URL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: t.primaryText,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.cardBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                    ),
                  ),
                  if (resolvedDownloadUrl.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _copyLink(resolvedDownloadUrl),
                      tooltip: 'Copy Resolved Download URL',
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: t.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: urlController,
            style: TextStyle(color: t.primaryText, fontSize: 12.5),
            decoration: InputDecoration(
              hintText:
                  'Paste direct APK / IPA / EXE URL or Play Store / App Store link...',
              hintStyle: TextStyle(color: t.secondaryText, fontSize: 11.5),
              filled: true,
              fillColor: t.cardBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.cardBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}