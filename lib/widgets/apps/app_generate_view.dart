// lib/widgets/apps/app_generate_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';

class AppGenerateView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final VoidCallback? onOpenUploadTab;
  final VoidCallback? onDataChanged;

  const AppGenerateView({
    super.key,
    this.isDarkMode = false,
    this.brandGreen = const Color(0xFF16A34A),
    this.onOpenUploadTab,
    this.onDataChanged,
  });

  @override
  State<AppGenerateView> createState() => _AppGenerateViewState();
}

class _AppGenerateViewState extends State<AppGenerateView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  bool _loading = true;
  bool _generating = false;
  bool _savingConfig = false;

  Map _appConfig = {};
  Map _templates = {};

  final TextEditingController _adminRepoCtrl = TextEditingController();
  final TextEditingController _storeRepoCtrl = TextEditingController();
  final TextEditingController _branchCtrl = TextEditingController();
  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _webhookCtrl = TextEditingController();
  final TextEditingController _appNameCtrl = TextEditingController();
  final TextEditingController _appSloganCtrl = TextEditingController();
  final TextEditingController _bundleIdCtrl = TextEditingController();
  final TextEditingController _appVersionCtrl = TextEditingController();
  final TextEditingController _primaryColorCtrl = TextEditingController();
  final TextEditingController _secondaryColorCtrl = TextEditingController();

  String _deliveryStrategy = 'headless_cicd';
  String _buildTarget = 'all';

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void didUpdateWidget(covariant AppGenerateView oldWidget) {
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
    await _fetchAppBuilderConfig();
  }

  Future<void> _fetchAppBuilderConfig() async {
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
        if (decoded is Map) {
          final Map cfg =
              decoded['app_config'] is Map ? decoded['app_config'] : {};
          final Map tmpl =
              decoded['templates'] is Map ? decoded['templates'] : {};
          setState(() {
            _appConfig = cfg;
            _templates = tmpl;
            _populateControllers(cfg);
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _populateControllers(Map cfg) {
    _adminRepoCtrl.text = (cfg['admin_flutter_repo_url'] ??
            'https://github.com/xylosaas/flutter-merchant-admin-pos')
        .toString();
    _storeRepoCtrl.text = (cfg['store_flutter_repo_url'] ??
            'https://github.com/xylosaas/flutter-customer-storefront')
        .toString();
    _branchCtrl.text = (cfg['github_branch'] ?? 'main').toString();
    _tokenCtrl.text = (cfg['github_workflow_token'] ?? '').toString();
    _webhookCtrl.text = (cfg['ci_webhook_url'] ?? '').toString();
    _appNameCtrl.text = (cfg['app_name'] ?? '').toString();
    _appSloganCtrl.text =
        (cfg['app_slogan'] ?? 'Authentic Online Shopping').toString();
    _bundleIdCtrl.text = (cfg['bundle_id'] ?? '').toString();
    _appVersionCtrl.text = (cfg['app_version'] ?? '1.0.0').toString();
    _primaryColorCtrl.text = (cfg['primary_color'] ?? '#059669').toString();
    _secondaryColorCtrl.text = (cfg['secondary_color'] ?? '#047857').toString();
    _deliveryStrategy =
        (cfg['delivery_strategy'] ?? 'headless_cicd').toString();
    _buildTarget = (cfg['build_target'] ?? 'all').toString();
  }

  Future<void> _saveOrGenerate({required bool isGenerate}) async {
    setState(() {
      if (isGenerate) {
        _generating = true;
      } else {
        _savingConfig = true;
      }
    });

    try {
      final String sub = Uri.encodeComponent(_theme.subdomain);
      final String endpoint = isGenerate
          ? '${_theme.apiBase}/api/v1/stores/app-builder/generate/?subdomain=$sub'
          : '${_theme.apiBase}/api/v1/stores/app-builder/?subdomain=$sub';

      final Map payload = {
        'action': isGenerate ? 'generate' : 'save',
        'admin_flutter_repo_url': _adminRepoCtrl.text.trim(),
        'store_flutter_repo_url': _storeRepoCtrl.text.trim(),
        'github_branch': _branchCtrl.text.trim(),
        'github_workflow_token': _tokenCtrl.text.trim(),
        'ci_webhook_url': _webhookCtrl.text.trim(),
        'app_name': _appNameCtrl.text.trim(),
        'app_slogan': _appSloganCtrl.text.trim(),
        'bundle_id': _bundleIdCtrl.text.trim(),
        'app_version': _appVersionCtrl.text.trim(),
        'primary_color': _primaryColorCtrl.text.trim(),
        'secondary_color': _secondaryColorCtrl.text.trim(),
        'delivery_strategy': _deliveryStrategy,
        'build_target': _buildTarget,
      };

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: _theme.headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      setState(() {
        _generating = false;
        _savingConfig = false;
      });

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map) {
          setState(() {
            if (decoded['app_config'] is Map) {
              _appConfig = decoded['app_config'];
              _populateControllers(_appConfig);
            }
            if (decoded['templates'] is Map) {
              _templates = decoded['templates'];
            }
          });
        }
        _showToast(
          (decoded is Map && decoded['message'] != null)
              ? decoded['message'].toString()
              : 'অ্যাপ জেনারেট সম্পন্ন হয়েছে!',
        );
        if (widget.onDataChanged != null) widget.onDataChanged!();
      } else {
        _showToast(
          (decoded is Map && decoded['detail'] != null)
              ? decoded['detail'].toString()
              : 'অপারেশন ব্যর্থ হয়েছে।',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _savingConfig = false;
      });
      _showToast('নেটওয়ার্ক ত্রুটি: $e', isError: true);
    }
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

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast('$label কপি করা হয়েছে!');
  }

  @override
  void dispose() {
    _adminRepoCtrl.dispose();
    _storeRepoCtrl.dispose();
    _branchCtrl.dispose();
    _tokenCtrl.dispose();
    _webhookCtrl.dispose();
    _appNameCtrl.dispose();
    _appSloganCtrl.dispose();
    _bundleIdCtrl.dispose();
    _appVersionCtrl.dispose();
    _primaryColorCtrl.dispose();
    _secondaryColorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final String buildStatus =
        (_appConfig['build_status'] ?? 'idle').toString().toUpperCase();
    final List buildLogs =
        _appConfig['build_logs'] is List ? _appConfig['build_logs'] : [];
    final Map cliCommands =
        _appConfig['cli_commands'] is Map ? _appConfig['cli_commands'] : {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Card
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
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Generate White-Label Mobile & Desktop Apps',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: t.primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: buildStatus == 'READY'
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.15)
                                    : const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                buildStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: buildStatus == 'READY'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '২টি GitHub Flutter প্রজেক্ট (Admin POS ও Customer Storefront) থেকে সরাসরি APK, iOS ও Windows অ্যাপ জেনারেট করুন',
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
                  if (widget.onOpenUploadTab != null)
                    OutlinedButton.icon(
                      onPressed: widget.onOpenUploadTab,
                      icon: Icon(
                        Icons.upload_file_rounded,
                        size: 16,
                        color: t.primaryColor,
                      ),
                      label: Text(
                        'Go to Upload APK / iOS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _fetchAppBuilderConfig,
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
          // 1. Two GitHub Flutter Project Repositories Card
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
                  '1. Two GitHub Flutter Project Repositories (Admin App & Storefront App)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                _buildField(
                  t,
                  controller: _adminRepoCtrl,
                  label: '1. Merchant Admin & POS Flutter GitHub Repo URL',
                  icon: Icons.admin_panel_settings_outlined,
                ),
                const SizedBox(height: 10),
                _buildField(
                  t,
                  controller: _storeRepoCtrl,
                  label: '2. Customer Storefront Flutter GitHub Repo URL',
                  icon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 200,
                      child: _buildField(
                        t,
                        controller: _branchCtrl,
                        label: 'GitHub Branch (e.g. main)',
                        icon: Icons.account_tree_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: _buildField(
                        t,
                        controller: _tokenCtrl,
                        label: 'GitHub Actions Workflow Token (Optional)',
                        icon: Icons.key_rounded,
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: _buildField(
                        t,
                        controller: _webhookCtrl,
                        label: 'Custom CI/CD Webhook URL (Optional)',
                        icon: Icons.webhook_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. White-Label Branding & Build Target Card
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
                  '2. White-Label App Identity & Compile-Time (--dart-define) Parameters',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: t.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 240,
                      child: _buildField(
                        t,
                        controller: _appNameCtrl,
                        label: 'App Name',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: _buildField(
                        t,
                        controller: _appSloganCtrl,
                        label: 'App Slogan / Tagline',
                        icon: Icons.short_text_rounded,
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: _buildField(
                        t,
                        controller: _bundleIdCtrl,
                        label: 'Bundle / Package ID',
                        icon: Icons.android_rounded,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: _buildField(
                        t,
                        controller: _appVersionCtrl,
                        label: 'App Version',
                        icon: Icons.numbers_rounded,
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: _buildField(
                        t,
                        controller: _primaryColorCtrl,
                        label: 'Primary Hex (#059669)',
                        icon: Icons.palette_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: _buildField(
                        t,
                        controller: _secondaryColorCtrl,
                        label: 'Secondary Hex (#047857)',
                        icon: Icons.color_lens_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Select Build Target',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: t.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    {
                      'id': 'all',
                      'label': 'Both Apps (Customer Storefront + Admin POS)'
                    },
                    {'id': 'store_app', 'label': 'Customer Storefront App Only'},
                    {'id': 'admin_app', 'label': 'Merchant Admin & POS App Only'},
                  ].map((item) {
                    final String id = item['id'].toString();
                    final bool sel = _buildTarget == id;
                    return ChoiceChip(
                      label: Text(
                        item['label'].toString(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : t.primaryText,
                        ),
                      ),
                      selected: sel,
                      selectedColor: t.primaryColor,
                      backgroundColor: t.inputBg,
                      onSelected: (_) => setState(() => _buildTarget = id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _generating
                          ? null
                          : () => _saveOrGenerate(isGenerate: true),
                      icon: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.rocket_launch_rounded, size: 17),
                      label: Text(
                        _generating
                            ? 'Generating Apps...'
                            : 'Generate APK, iOS & Windows Apps Now',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _savingConfig
                          ? null
                          : () => _saveOrGenerate(isGenerate: false),
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save Repo & Branding Config'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.primaryText,
                        side: BorderSide(color: t.cardBorder),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Generated CLI Commands & Pipeline Steps
          if (cliCommands.isNotEmpty)
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
                    '3. Generated Flutter Build Commands (--dart-define)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...cliCommands.entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: t.inputBg,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key.toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: t.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  entry.value.toString(),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontFamily: 'monospace',
                                    color: t.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _copyText(
                              entry.value.toString(),
                              entry.key.toString(),
                            ),
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: t.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          if (buildLogs.isNotEmpty) ...[
            const SizedBox(height: 14),
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
                    '4. CI/CD Build Pipeline Execution Logs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...buildLogs.map((raw) {
                    final Map log = raw is Map ? raw : {};
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.inputBg,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Step ${log['step'] ?? ''}: ${log['title'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: t.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (log['detail'] ?? '').toString(),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            (log['time'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: t.secondaryText,
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
        ],
      ],
    );
  }

  Widget _buildField(
    CatalogThemeConfig t, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: t.primaryText, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
        prefixIcon: Icon(icon, size: 17, color: t.primaryColor),
        filled: true,
        fillColor: t.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: t.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: t.cardBorder),
        ),
      ),
    );
  }
}