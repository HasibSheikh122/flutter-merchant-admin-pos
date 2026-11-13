// lib/widgets/metric_stat_card.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MetricStatCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const MetricStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  State<MetricStatCard> createState() => _MetricStatCardState();
}

class _MetricStatCardState extends State<MetricStatCard> {
  late Color _primaryColor;
  late Color _secondaryColor;
  bool _useGradient = true;

  @override
  void initState() {
    super.initState();
    _primaryColor = widget.accentColor;
    _secondaryColor = const Color(0xFF1E3A1A);
    _loadSavedMobileColors();
  }

  @override
  void didUpdateWidget(covariant MetricStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSavedMobileColors();
  }

  Future<void> _loadSavedMobileColors() async {
    final prefs = await SharedPreferences.getInstance();
    final String? pHex = prefs.getString('mobile_app_primary_color');
    final String? sHex = prefs.getString('mobile_app_secondary_color');
    final bool useGrad = prefs.getBool('mobile_app_use_gradient') ?? true;

    if (!mounted) return;
    setState(() {
      _primaryColor = _parseHex(pHex, widget.accentColor);
      _secondaryColor = _parseHex(sHex, const Color(0xFF1E3A1A));
      _useGradient = useGrad;
    });
  }

  Color _parseHex(String? hexStr, Color fallback) {
    if (hexStr == null || hexStr.trim().isEmpty) return fallback;
    String clean = hexStr.trim().replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _useGradient ? null : const Color(0xFF0F172A),
        gradient: _useGradient
            ? LinearGradient(
                colors: [
                  const Color(0xFF0F172A),
                  Color.lerp(const Color(0xFF0F172A), _secondaryColor, 0.45) ??
                      const Color(0xFF1E293B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _useGradient
                      ? null
                      : _primaryColor.withValues(alpha: 0.15),
                  gradient: _useGradient
                      ? LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: _useGradient ? Colors.white : _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}