// lib/widgets/order/order_notify_modal.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';
import 'order_utils.dart';

class OrderNotifyModal extends StatefulWidget {
  final Map order;
  final String initialTab; // 'sms' or 'email'
  final CatalogThemeConfig theme;
  final Map? customerLookup;

  const OrderNotifyModal({
    super.key,
    required this.order,
    required this.initialTab,
    required this.theme,
    this.customerLookup,
  });

  @override
  State<OrderNotifyModal> createState() => _OrderNotifyModalState();
}

class _OrderNotifyModalState extends State<OrderNotifyModal> {
  late String _activeTab;
  late TextEditingController _phoneCtrl;
  late TextEditingController _smsTextCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _emailBodyCtrl;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    final st = (widget.order['status'] ?? 'processing').toString();
    final sub = widget.theme.subdomain;

    _phoneCtrl = TextEditingController(
      text: OrderUtils.customerPhone(widget.order),
    );
    _smsTextCtrl = TextEditingController(
      text: OrderUtils.buildSmsMessage(widget.order, st, sub),
    );
    _emailCtrl = TextEditingController(
      text: OrderUtils.customerEmail(widget.order, widget.customerLookup),
    );
    _subjectCtrl = TextEditingController(
      text: OrderUtils.buildEmailSubject(widget.order, st, sub),
    );
    _emailBodyCtrl = TextEditingController(
      text: OrderUtils.buildEmailBody(widget.order, st, sub),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _smsTextCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _emailBodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendSms() async {
    final phone = _phoneCtrl.text.trim();
    final msg = _smsTextCtrl.text.trim();
    if (phone.length < 11 || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সঠিক ১১ ডিজিটের মোবাইল নম্বর এবং মেসেজ দিন।'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final sub = widget.theme.subdomain;
      final uri = Uri.parse(
        '${widget.theme.apiBase}/api/v1/sms/send-individual/?subdomain=$sub',
      );
      final res = await http.post(
        uri,
        headers: widget.theme.headers,
        body: jsonEncode({
          'numbers': phone,
          'phone': phone,
          'message': msg,
          'order_number': OrderUtils.orderNumber(widget.order),
          'status': widget.order['status'] ?? 'processing',
        }),
      );

      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS সফলভাবে পাঠানো হয়েছে ($phone)!'),
            backgroundColor: widget.theme.primaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS পাঠানো যায়নি (${res.statusCode})'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS Gateway Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendEmail() async {
    final email = _emailCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final body = _emailBodyCtrl.text.trim();
    if (!email.contains('@') || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('গ্রাহকের সঠিক ইমেইল এবং মেসেজ লিখুন।'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final sub = widget.theme.subdomain;
      final uri = Uri.parse(
        '${widget.theme.apiBase}/api/v1/emails/send-test/?subdomain=$sub',
      );
      final res = await http.post(
        uri,
        headers: widget.theme.headers,
        body: jsonEncode({
          'to_email': email,
          'subject': subject,
          'message': body,
          'order_number': OrderUtils.orderNumber(widget.order),
        }),
      );

      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ইমেইল সফলভাবে পাঠানো হয়েছে ($email)!'),
            backgroundColor: widget.theme.primaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ইমেইল পাঠানো যায়নি (${res.statusCode})'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email Gateway Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final ordNum = OrderUtils.orderNumber(widget.order);

    return Container(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: t.cardBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: t.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: OrderUtils.primaryDecoration(t, radius: 12),
                  child: Icon(
                    _activeTab == 'sms'
                        ? Icons.sms_rounded
                        : Icons.mark_email_unread_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notify Customer • #$ordNum',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: t.primaryText,
                        ),
                      ),
                      Text(
                        'Send instant Order SMS or Email update',
                        style: TextStyle(fontSize: 11, color: t.secondaryText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: t.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 'sms'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: _activeTab == 'sms'
                          ? OrderUtils.primaryDecoration(t, radius: 12)
                          : BoxDecoration(
                              color: t.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: t.cardBorder),
                            ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sms_outlined,
                            size: 15,
                            color: _activeTab == 'sms'
                                ? Colors.white
                                : t.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SMS Gateway',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _activeTab == 'sms'
                                  ? Colors.white
                                  : t.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 'email'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: _activeTab == 'email'
                          ? OrderUtils.primaryDecoration(t, radius: 12)
                          : BoxDecoration(
                              color: t.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: t.cardBorder),
                            ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 15,
                            color: _activeTab == 'email'
                                ? Colors.white
                                : t.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Email Update',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _activeTab == 'email'
                                  ? Colors.white
                                  : t.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_activeTab == 'sms') ...[
              TextField(
                controller: _phoneCtrl,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Recipient Phone Number',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  prefixIcon: Icon(Icons.phone_rounded, color: t.primaryColor),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _smsTextCtrl,
                maxLines: 4,
                style: TextStyle(color: t.primaryText, fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'SMS Text Content',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _isSending ? null : _sendSms,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: OrderUtils.primaryDecoration(t, radius: 14),
                  alignment: Alignment.center,
                  child: Text(
                    _isSending ? 'Sending SMS...' : 'Send Order SMS Now',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _emailCtrl,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Customer Email Address',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  prefixIcon:
                      Icon(Icons.alternate_email_rounded, color: t.primaryColor),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _subjectCtrl,
                style: TextStyle(color: t.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Email Subject',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailBodyCtrl,
                maxLines: 5,
                style: TextStyle(color: t.primaryText, fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Email Body',
                  labelStyle: TextStyle(color: t.secondaryText, fontSize: 12),
                  filled: true,
                  fillColor: t.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _isSending ? null : _sendEmail,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: OrderUtils.primaryDecoration(t, radius: 14),
                  alignment: Alignment.center,
                  child: Text(
                    _isSending ? 'Sending Email...' : 'Send Order Email Now',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}