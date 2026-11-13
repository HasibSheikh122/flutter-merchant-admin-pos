// lib/widgets/order/order_detail_modal.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../catalog/catalog_theme_scope.dart';
import 'order_utils.dart';
import 'order_notify_modal.dart';

class OrderDetailModal extends StatefulWidget {
  final Map order;
  final CatalogThemeConfig theme;
  final Map? customerLookup;
  final Map? bookedInfo;
  final String defaultCourier;
  final Future<void> Function(String orderNumber, String newStatus)
      onStatusChange;
  final Future<void> Function(Map order, String provider) onBookCourier;

  const OrderDetailModal({
    super.key,
    required this.order,
    required this.theme,
    this.customerLookup,
    this.bookedInfo,
    this.defaultCourier = 'steadfast',
    required this.onStatusChange,
    required this.onBookCourier,
  });

  @override
  State<OrderDetailModal> createState() => _OrderDetailModalState();
}

class _OrderDetailModalState extends State<OrderDetailModal> {
  late String _currentStatus;
  late String _selectedCourier;
  bool _isUpdatingStatus = false;
  bool _isBookingCourier = false;
  bool _isCheckingFraud = false;
  Map? _liveFraudResult;

  static const List<String> _allStatuses = [
    'pending',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
  ];

  static const List<String> _courierProviders = [
    'steadfast',
    'pathao',
    'redx',
    'paperfly',
    'ecourier',
    'carrybee',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus =
        (widget.order['status'] ?? 'pending').toString().toLowerCase();
    _selectedCourier = widget.defaultCourier;
    if (widget.order['fraud_analysis'] is Map) {
      _liveFraudResult = widget.order['fraud_analysis'] as Map;
    }
  }

  Future<void> _changeStatus(String nextStatus) async {
    setState(() => _isUpdatingStatus = true);
    await widget.onStatusChange(
      OrderUtils.orderNumber(widget.order),
      nextStatus,
    );
    if (mounted) {
      setState(() {
        _currentStatus = nextStatus;
        _isUpdatingStatus = false;
      });
    }
  }

  Future<void> _bookCourierNow() async {
    setState(() => _isBookingCourier = true);
    await widget.onBookCourier(widget.order, _selectedCourier);
    if (mounted) {
      setState(() => _isBookingCourier = false);
    }
  }

  Future<void> _runLiveFraudCheck() async {
    setState(() => _isCheckingFraud = true);
    try {
      final ordNum = OrderUtils.orderNumber(widget.order);
      final t = widget.theme;
      final res = await http.get(
        Uri.parse(
          '${t.apiBase}/api/v1/orders/$ordNum/fraud-check/?subdomain=${t.subdomain}',
        ),
        headers: t.headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['analysis'] is Map) {
          setState(() => _liveFraudResult = decoded['analysis'] as Map);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isCheckingFraud = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final ord = widget.order;
    final ordNum = OrderUtils.orderNumber(ord);
    final custName = OrderUtils.customerName(ord, widget.customerLookup);
    final custPhone = OrderUtils.customerPhone(ord);
    final custEmail = OrderUtils.customerEmail(ord, widget.customerLookup);
    final address = OrderUtils.deliveryAddress(ord);
    final total = OrderUtils.orderTotal(ord);
    final subtotal =
        double.tryParse((ord['subtotal'] ?? total).toString()) ?? total;
    final shipCost =
        double.tryParse((ord['shipping_cost'] ?? '0').toString()) ?? 0.0;
    final discount =
        double.tryParse((ord['discount'] ?? '0').toString()) ?? 0.0;
    final payMethod = (ord['payment_method'] ?? 'cod').toString().toUpperCase();
    final payStatus =
        (ord['payment_status'] ?? 'pending').toString().toUpperCase();
    final items = (ord['items'] is List) ? (ord['items'] as List) : [];

    final fraudRiskLevel =
        (_liveFraudResult?['risk_level'] ?? 'low').toString().toLowerCase();
    final fraudScore = double.tryParse(
          (_liveFraudResult?['risk_score'] ?? '5').toString(),
        ) ??
        5.0;
    final fraudRec = (_liveFraudResult?['recommendation'] ??
            'Order appears safe for processing.')
        .toString();

    final Color fraudColor = fraudRiskLevel == 'high'
        ? Colors.redAccent
        : (fraudRiskLevel == 'medium'
            ? Colors.amber.shade700
            : const Color(0xFF10B981));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: t.cardBorder,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: OrderUtils.primaryDecoration(t, radius: 14),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #$ordNum',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: t.primaryText,
                      ),
                    ),
                    Text(
                      OrderUtils.formatDateShort(ord['created_at']),
                      style: TextStyle(fontSize: 11, color: t.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => OrderNotifyModal(
                      order: ord,
                      initialTab: 'sms',
                      theme: t,
                      customerLookup: widget.customerLookup,
                    ),
                  );
                },
                icon: Icon(Icons.sms_outlined, color: t.primaryColor, size: 20),
                tooltip: 'Send SMS / Email',
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: t.secondaryText),
              ),
            ],
          ),
          const Divider(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Selector Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Update Order Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: t.primaryText,
                        ),
                      ),
                      if (_isUpdatingStatus)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.primaryColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _allStatuses.map((st) {
                      final active = _currentStatus == st;
                      final col = OrderUtils.statusColor(st);
                      return GestureDetector(
                        onTap: _isUpdatingStatus ? null : () => _changeStatus(st),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: active
                              ? OrderUtils.primaryDecoration(t, radius: 10)
                              : BoxDecoration(
                                  color: col.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: col.withValues(alpha: 0.35),
                                  ),
                                ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                OrderUtils.statusIcon(st),
                                size: 13,
                                color: active ? Colors.white : col,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                st.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: active ? Colors.white : col,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Customer Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_pin_circle_rounded,
                              color: t.primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Customer & Delivery Address',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.person_outline, 'Name', custName, t),
                        if (custPhone.isNotEmpty)
                          _buildInfoRow(
                            Icons.phone_outlined,
                            'Phone',
                            custPhone,
                            t,
                          ),
                        if (custEmail.isNotEmpty)
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Email',
                            custEmail,
                            t,
                          ),
                        _buildInfoRow(
                          Icons.location_on_outlined,
                          'Address',
                          address,
                          t,
                        ),
                        _buildInfoRow(
                          Icons.payments_outlined,
                          'Payment',
                          '$payMethod ($payStatus)',
                          t,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // AI COD Fraud Shield Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: fraudColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: fraudColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: fraudColor,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'AI COD Fraud Shield • ${fraudRiskLevel.toUpperCase()} RISK (${fraudScore.toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: fraudColor,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap:
                                  _isCheckingFraud ? null : _runLiveFraudCheck,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _isCheckingFraud
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: fraudColor,
                                        ),
                                      )
                                    : Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                        color: fraudColor,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fraudRec,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Courier Booking Section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              color: t.primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Courier Dispatch & Tracking',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (widget.bookedInfo != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF10B981),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Booked with ${(widget.bookedInfo!['provider_name'] ?? widget.bookedInfo!['provider'] ?? 'Courier').toString().toUpperCase()}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                      Text(
                                        'Tracking: ${widget.bookedInfo!['tracking_code'] ?? 'N/A'} • CID: ${widget.bookedInfo!['consignment_id'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: t.primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: t.cardBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCourier,
                                      isExpanded: true,
                                      dropdownColor: t.cardBg,
                                      style: TextStyle(
                                        color: t.primaryText,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      items: _courierProviders.map((prov) {
                                        return DropdownMenuItem<String>(
                                          value: prov,
                                          child: Text(prov.toUpperCase()),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _selectedCourier = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap:
                                    _isBookingCourier ? null : _bookCourierNow,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: OrderUtils.primaryDecoration(
                                    t,
                                    radius: 12,
                                  ),
                                  child: Text(
                                    _isBookingCourier
                                        ? 'Booking...'
                                        : 'Send to Courier',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Order Items List
                  Text(
                    'Ordered Products (${items.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: t.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    Text(
                      'No line items attached.',
                      style: TextStyle(fontSize: 12, color: t.secondaryText),
                    )
                  else
                    ...items.map((it) {
                      if (it is! Map) return const SizedBox.shrink();
                      final pName =
                          (it['product_name'] ?? it['name'] ?? 'Product')
                              .toString();
                      final sku = (it['product_sku'] ?? '').toString();
                      final qty =
                          int.tryParse((it['quantity'] ?? 1).toString()) ?? 1;
                      final unitP = double.tryParse(
                            (it['unit_price'] ?? it['price'] ?? 0).toString(),
                          ) ??
                          0.0;
                      final lineTotal = double.tryParse(
                            (it['total_price'] ?? (unitP * qty)).toString(),
                          ) ??
                          (unitP * qty);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.inputBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration:
                                  OrderUtils.primaryDecoration(t, radius: 10),
                              child: Text(
                                '${qty}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pName,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: t.primaryText,
                                    ),
                                  ),
                                  Text(
                                    '৳${unitP.toStringAsFixed(0)} each${sku.isNotEmpty ? " • SKU: $sku" : ""}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: t.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '৳${lineTotal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: t.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 10),
                  // Bill Breakdown
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Column(
                      children: [
                        _buildBillRow(
                          'Subtotal',
                          '৳${subtotal.toStringAsFixed(2)}',
                          t,
                        ),
                        const SizedBox(height: 6),
                        _buildBillRow(
                          'Shipping (${ord['shipping_method'] ?? 'Standard'})',
                          '৳${shipCost.toStringAsFixed(2)}',
                          t,
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 6),
                          _buildBillRow(
                            'Discount',
                            '-৳${discount.toStringAsFixed(2)}',
                            t,
                          ),
                        ],
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grand Total',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              '৳${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: t.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    CatalogThemeConfig t,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: t.secondaryText),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: t.secondaryText,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: t.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String val, CatalogThemeConfig t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: t.secondaryText),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: t.primaryText,
          ),
        ),
      ],
    );
  }
}