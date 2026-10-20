// lib/screens/workspace_domain_screen.dart
// Spec V2.4 Section 2: Universal Slack-Style Workspace Domain Resolver Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

class WorkspaceDomainScreen extends StatefulWidget {
  const WorkspaceDomainScreen({super.key});

  @override
  State<WorkspaceDomainScreen> createState() => _WorkspaceDomainScreenState();
}

class _WorkspaceDomainScreenState extends State<WorkspaceDomainScreen> {
  final TextEditingController _domainCtrl = TextEditingController(text: 'nextlook');
  final TextEditingController _serverCtrl = TextEditingController(text: 'http://10.0.2.2:8000');
  bool _showAdvancedServer = false;
  String? _error;

  Future<void> _handleResolve() async {
    setState(() => _error = null);
    final provider = context.read<AdminProvider>();
    try {
      await provider.connectWorkspaceDomain(
        _domainCtrl.text,
        serverUrl: _showAdvancedServer ? _serverCtrl.text : null,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'XYLO SAAS WORKSPACE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Connect Your Store Domain',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'আপনার স্টোরের Subdomain (যেমন: nextlook) অথবা কাস্টম ডোমেইন দিন। অ্যাপটি /api/v1/stores/tenant/resolve/ কল করে অটোমেটিক আপনার স্টোরের সাথে যুক্ত হবে।',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _domainCtrl,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Store Subdomain or Domain',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      hintText: 'nextlook or store1.com',
                      prefixIcon: const Icon(Icons.language_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFF020617),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showAdvancedServer = !_showAdvancedServer),
                      icon: Icon(
                        _showAdvancedServer ? Icons.expand_less : Icons.settings_ethernet,
                        size: 16,
                        color: const Color(0xFF38BDF8),
                      ),
                      label: const Text(
                        'Local / Emulator Server URL (Optional)',
                        style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                  if (_showAdvancedServer) ...[
                    TextField(
                      controller: _serverCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Backend Host (10.0.2.2:8000 for Android Emulator)',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF020617),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: provider.isLoading ? null : _handleResolve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bolt_rounded),
                    label: Text(
                      provider.isLoading ? 'Resolving Workspace...' : 'Connect Store Workspace',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
