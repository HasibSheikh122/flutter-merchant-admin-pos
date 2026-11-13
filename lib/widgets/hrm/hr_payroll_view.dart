import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../catalog/catalog_theme_scope.dart';

class HrPayrollView extends StatefulWidget {
  final bool isDarkMode;
  final Color brandGreen;
  final String initialTab;

  const HrPayrollView({
    super.key,
    required this.isDarkMode,
    required this.brandGreen,
    this.initialTab = 'employees',
  });

  @override
  State<HrPayrollView> createState() => _HrPayrollViewState();
}

class _HrPayrollViewState extends State<HrPayrollView> {
  CatalogThemeConfig _theme = const CatalogThemeConfig();
  late String _activeTab;
  bool _isLoading = true;

  List _employees = [];
  List _departments = [];
  Map _dailyAttendance = {};

  final TextEditingController _empNameCtrl = TextEditingController();
  final TextEditingController _empRoleCtrl =
      TextEditingController(text: 'Sales Executive');
  final TextEditingController _empDeptCtrl =
      TextEditingController(text: 'Sales & Counter');
  final TextEditingController _empPhoneCtrl = TextEditingController();
  final TextEditingController _empSalaryCtrl =
      TextEditingController(text: '18000');

  final TextEditingController _deptNameCtrl = TextEditingController();
  final TextEditingController _deptLeadCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeTab = _normalizeTab(widget.initialTab);
    _initHrModule();
  }

  @override
  void didUpdateWidget(covariant HrPayrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _activeTab = _normalizeTab(widget.initialTab));
    }
    if (oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.brandGreen != widget.brandGreen) {
      _reloadTheme();
    }
  }

  String _normalizeTab(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('attend')) return 'attendance';
    if (lower.contains('pay') || lower.contains('salary')) return 'payroll';
    if (lower.contains('dept') || lower.contains('department')) {
      return 'departments';
    }
    return 'employees';
  }

  Future _reloadTheme() async {
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) setState(() => _theme = loaded);
  }

  Future _initHrModule() async {
    setState(() => _isLoading = true);
    final loaded = await CatalogThemeConfig.load(
      isDarkMode: widget.isDarkMode,
      fallbackBrandGreen: widget.brandGreen,
    );
    if (mounted) setState(() => _theme = loaded);

    await _loadLocalHrState();
    await _syncHrWithBackend();

    if (mounted) setState(() => _isLoading = false);
  }

  Future _loadLocalHrState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _theme.subdomain;
      final empStr = prefs.getString('xylo_hr_emp_$sub');
      final deptStr = prefs.getString('xylo_hr_dept_$sub');
      final attStr = prefs.getString('xylo_hr_att_$sub');

      if (empStr != null && empStr.isNotEmpty) {
        final d = jsonDecode(empStr);
        if (d is List) _employees = List.from(d);
      }
      if (deptStr != null && deptStr.isNotEmpty) {
        final d = jsonDecode(deptStr);
        if (d is List) _departments = List.from(d);
      }
      if (attStr != null && attStr.isNotEmpty) {
        final d = jsonDecode(attStr);
        if (d is Map) _dailyAttendance = Map.from(d);
      }
    } catch (_) {}

    if (_employees.isEmpty) {
      _employees = [
        {
          'id': 'EMP-101',
          'name': 'Mehedi Hasan',
          'role': 'Store Manager',
          'department': 'Operations & POS',
          'phone': '01711223344',
          'salary': 28000.0,
          'bonus': 2000.0,
          'paid': true,
        },
        {
          'id': 'EMP-102',
          'name': 'Sadia Afrin',
          'role': 'Customer Support Lead',
          'department': 'Live Chat & CRM',
          'phone': '01819283746',
          'salary': 20000.0,
          'bonus': 1000.0,
          'paid': false,
        },
        {
          'id': 'EMP-103',
          'name': 'Rakibul Islam',
          'role': 'Inventory & Courier Executive',
          'department': 'Warehouse & Dispatch',
          'phone': '01911887766',
          'salary': 16500.0,
          'bonus': 500.0,
          'paid': false,
        },
      ];
    }

    if (_departments.isEmpty) {
      _departments = [
        {
          'id': 'dept_1',
          'name': 'Operations & POS',
          'lead': 'Mehedi Hasan',
          'roles': 'Store Manager, Cashier',
        },
        {
          'id': 'dept_2',
          'name': 'Live Chat & CRM',
          'lead': 'Sadia Afrin',
          'roles': 'Support Agent, Telemarketing',
        },
        {
          'id': 'dept_3',
          'name': 'Warehouse & Dispatch',
          'lead': 'Rakibul Islam',
          'roles': 'Inventory Clerk, Courier Dispatcher',
        },
      ];
    }
  }

  Future _saveLocalHrState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _theme.subdomain;
      await prefs.setString('xylo_hr_emp_$sub', jsonEncode(_employees));
      await prefs.setString('xylo_hr_dept_$sub', jsonEncode(_departments));
      await prefs.setString('xylo_hr_att_$sub', jsonEncode(_dailyAttendance));
    } catch (_) {}
  }

  Future _syncHrWithBackend() async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '${_theme.apiBase}/api/v1/hrm/employees/?subdomain=${_theme.subdomain}'),
            headers: _theme.headers,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map && decoded['results'] is List
                ? decoded['results'] as List
                : []);
        if (list.isNotEmpty && mounted) {
          setState(() {
            for (final item in list) {
              if (item is Map) {
                final id = 'EMP-${item['id']}';
                if (!_employees.any((e) => e['id'] == id)) {
                  _employees.add({
                    'id': id,
                    'name': (item['name'] ?? item['full_name'] ?? 'Staff')
                        .toString(),
                    'role': (item['position'] ?? item['role'] ?? 'Staff')
                        .toString(),
                    'department':
                        (item['department'] ?? 'General').toString(),
                    'phone': (item['phone'] ?? 'N/A').toString(),
                    'salary': double.tryParse(
                            (item['salary'] ?? '15000').toString()) ??
                        15000.0,
                    'bonus': 0.0,
                    'paid': false,
                  });
                }
              }
            }
          });
          await _saveLocalHrState();
        }
      }
    } catch (_) {}
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(color: t.primaryColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroBanner(t),
        const SizedBox(height: 14),
        _buildSubTabsBar(t),
        const SizedBox(height: 16),
        if (_activeTab == 'employees') _buildEmployeesSection(t),
        if (_activeTab == 'attendance') _buildAttendanceSection(t),
        if (_activeTab == 'payroll') _buildPayrollSection(t),
        if (_activeTab == 'departments') _buildDepartmentsSection(t),
      ],
    );
  }

  Widget _buildHeroBanner(CatalogThemeConfig t) {
    double monthlyPayroll = 0.0;
    for (final e in _employees) {
      if (e is Map) {
        monthlyPayroll +=
            (double.tryParse((e['salary'] ?? '0').toString()) ?? 0.0) +
                (double.tryParse((e['bonus'] ?? '0').toString()) ?? 0.0);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: t.useGradient
            ? t.brandGradient
            : LinearGradient(
                colors: [t.primaryColor, t.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HR, Attendance & Payroll Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Staff Directory, Daily Attendance Tracker, Salary Sheet & Department Roles',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroPill(
                  Icons.people_alt_outlined, 'Staff: ${_employees.length}'),
              _buildHeroPill(Icons.workspaces_outlined,
                  'Departments: ${_departments.length}'),
              _buildHeroPill(Icons.payments_outlined,
                  'Monthly Payroll: ৳${monthlyPayroll.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabsBar(CatalogThemeConfig t) {
    final tabs = [
      {
        'key': 'employees',
        'label': 'Employee List',
        'icon': Icons.badge_rounded,
      },
      {
        'key': 'attendance',
        'label': 'Attendance Daily',
        'icon': Icons.how_to_reg_outlined,
      },
      {
        'key': 'payroll',
        'label': 'Salary Sheet & Payslip',
        'icon': Icons.receipt_outlined,
      },
      {
        'key': 'departments',
        'label': 'Departments & Roles',
        'icon': Icons.workspaces_outlined,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab['key'] as String),
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient:
                      isSelected && t.useGradient ? t.brandGradient : null,
                  color: isSelected
                      ? (t.useGradient ? null : t.primaryColor)
                      : t.cardBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isSelected ? t.primaryColor : t.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : t.secondaryText,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : t.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmployeesSection(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Employee / Staff',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(t, 'Full Name *', _empNameCtrl,
                        'e.g. Tanvir Hasan'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                        t, 'Phone Number *', _empPhoneCtrl, '017XXXXXXXX'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                        t, 'Designation / Role', _empRoleCtrl, 'Cashier'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                        t, 'Department', _empDeptCtrl, 'POS & Counter'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                        t, 'Monthly Salary (BDT)', _empSalaryCtrl, '18000'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final name = _empNameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setState(() {
                      _employees.insert(0, {
                        'id':
                            'EMP-${100 + _employees.length + 1}',
                        'name': name,
                        'role': _empRoleCtrl.text.trim(),
                        'department': _empDeptCtrl.text.trim(),
                        'phone': _empPhoneCtrl.text.trim().isEmpty
                            ? '01700000000'
                            : _empPhoneCtrl.text.trim(),
                        'salary': double.tryParse(
                                _empSalaryCtrl.text.trim()) ??
                            18000.0,
                        'bonus': 0.0,
                        'paid': false,
                      });
                      _empNameCtrl.clear();
                      _empPhoneCtrl.clear();
                    });
                    await _saveLocalHrState();
                    _showToast('Employee "$name" added!');
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: const Text(
                    'Save Employee',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._employees.map((emp) {
          if (emp is! Map) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: t.cardBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: t.primaryColor.withValues(alpha: 0.14),
                  child: Text(
                    (emp['name'] ?? 'S')
                        .toString()
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: t.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${emp['name']} (${emp['id']})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${emp['role']} • ${emp['department']} • ${emp['phone']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: t.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '৳${(emp['salary'] ?? 0).toString()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: t.primaryColor,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () async {
                    setState(() {
                      _employees.removeWhere((e) => e['id'] == emp['id']);
                    });
                    await _saveLocalHrState();
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttendanceSection(CatalogThemeConfig t) {
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Staff Attendance ($todayKey)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  setState(() {
                    for (final e in _employees) {
                      if (e is Map) {
                        _dailyAttendance['${todayKey}_${e['id']}'] = 'PRESENT';
                      }
                    }
                  });
                  await _saveLocalHrState();
                  _showToast('All staff marked Present for today!');
                },
                icon: Icon(Icons.done_all_rounded,
                    size: 16, color: t.primaryColor),
                label: Text(
                  'Mark All Present',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: t.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._employees.map((emp) {
            if (emp is! Map) return const SizedBox.shrink();
            final key = '${todayKey}_${emp['id']}';
            final currentStatus =
                (_dailyAttendance[key] ?? 'PRESENT').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: t.inputBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: t.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (emp['name'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: t.primaryText,
                          ),
                        ),
                        Text(
                          '${emp['role']} • ${emp['department']}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: ['PRESENT', 'LATE', 'ABSENT', 'LEAVE'].map((st) {
                      final active = currentStatus == st;
                      Color c = const Color(0xFF16A34A);
                      if (st == 'LATE') c = const Color(0xFFD97706);
                      if (st == 'ABSENT') c = Colors.redAccent;
                      if (st == 'LEAVE') c = const Color(0xFF3B82F6);

                      return InkWell(
                        onTap: () async {
                          setState(() => _dailyAttendance[key] = st);
                          await _saveLocalHrState();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active ? c : t.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active ? c : t.cardBorder,
                            ),
                          ),
                          child: Text(
                            st,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: active ? Colors.white : t.secondaryText,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPayrollSection(CatalogThemeConfig t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Salary Sheet & Instant Payslip Disbursal',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: t.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          ..._employees.map((emp) {
            if (emp is! Map) return const SizedBox.shrink();
            final baseSal =
                double.tryParse((emp['salary'] ?? '0').toString()) ?? 0.0;
            final bonus =
                double.tryParse((emp['bonus'] ?? '0').toString()) ?? 0.0;
            final netPay = baseSal + bonus;
            final isPaid = emp['paid'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.inputBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: t.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${emp['name']} (${emp['role']})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: t.primaryText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Base: ৳${baseSal.toStringAsFixed(0)}  |  Bonus: ৳${bonus.toStringAsFixed(0)}  |  Net: ৳${netPay.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPaid
                          ? const Color(0xFF16A34A)
                          : t.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      setState(() {
                        emp['paid'] = !isPaid;
                      });
                      await _saveLocalHrState();
                      _showToast(emp['paid'] == true
                          ? 'Salary marked PAID for ${emp['name']}!'
                          : 'Salary marked UNPAID');
                    },
                    icon: Icon(
                      isPaid
                          ? Icons.check_circle_rounded
                          : Icons.payments_outlined,
                      size: 15,
                    ),
                    label: Text(
                      isPaid ? 'PAID' : 'Pay Now',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDepartmentsSection(CatalogThemeConfig t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Store Department & Role Group',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(t, 'Department Name *', _deptNameCtrl,
                        'e.g. Digital Marketing'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(t, 'Department Lead', _deptLeadCtrl,
                        'e.g. Farhan Ahmed'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final nm = _deptNameCtrl.text.trim();
                    if (nm.isEmpty) return;
                    setState(() {
                      _departments.insert(0, {
                        'id':
                            'dept_${DateTime.now().millisecondsSinceEpoch}',
                        'name': nm,
                        'lead': _deptLeadCtrl.text.trim().isEmpty
                            ? 'Store Admin'
                            : _deptLeadCtrl.text.trim(),
                        'roles': 'Manager, Executive',
                      });
                      _deptNameCtrl.clear();
                      _deptLeadCtrl.clear();
                    });
                    await _saveLocalHrState();
                    _showToast('Department "$nm" created!');
                  },
                  icon: const Icon(Icons.add_business_outlined, size: 17),
                  label: const Text(
                    'Add Department',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._departments.map((d) {
          if (d is! Map) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: t.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.workspaces_outlined,
                    color: t.primaryColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (d['name'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: t.primaryText,
                        ),
                      ),
                      Text(
                        'Lead: ${d['lead']} • Roles: ${d['roles']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: t.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInput(
    CatalogThemeConfig t,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          style: TextStyle(color: t.primaryText, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.secondaryText, fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: t.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.cardBorder),
            ),
          ),
        ),
      ],
    );
  }
}