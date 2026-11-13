// lib/widgets/order/order_utils.dart
import 'package:flutter/material.dart';
import '../catalog/catalog_theme_scope.dart';

class OrderUtils {
  static BoxDecoration primaryDecoration(
    CatalogThemeConfig theme, {
    double radius = 14,
  }) {
    return BoxDecoration(
      gradient: theme.useGradient ? theme.brandGradient : null,
      color: theme.useGradient ? null : theme.primaryColor,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static String orderNumber(Map ord) {
    final raw = (ord['order_number'] ?? ord['id'] ?? '').toString().trim();
    return raw.isEmpty ? 'ORD-000' : raw;
  }

  static double orderTotal(Map ord) {
    return double.tryParse(
          (ord['total'] ??
                  ord['total_amount'] ??
                  ord['grand_total'] ??
                  ord['subtotal'] ??
                  '0')
              .toString(),
        ) ??
        0.0;
  }

  static String customerName(Map ord, [Map? customerLookup]) {
    if (ord['shipping_address'] is Map) {
      final sa = ord['shipping_address'] as Map;
      final saName = (sa['full_name'] ??
              sa['name'] ??
              sa['customer_name'] ??
              '${sa['first_name'] ?? ''} ${sa['last_name'] ?? ''}'.trim())
          .toString()
          .trim();
      if (saName.isNotEmpty && saName.toLowerCase() != 'customer') {
        return saName;
      }
    }

    if (ord['customer_data'] is Map) {
      final cd = ord['customer_data'] as Map;
      final cdName = (cd['full_name'] ??
              cd['name'] ??
              '${cd['first_name'] ?? ''} ${cd['last_name'] ?? ''}'.trim())
          .toString()
          .trim();
      if (cdName.isNotEmpty && cdName.toLowerCase() != 'customer') {
        return cdName;
      }
    }

    final direct = (ord['customer_name'] ?? '').toString().trim();
    if (direct.isNotEmpty && direct.toLowerCase() != 'customer') {
      return direct;
    }

    final phone = customerPhone(ord);
    if (customerLookup != null && phone.isNotEmpty) {
      final rec = customerLookup['phone_$phone'];
      if (rec is Map && (rec['name'] ?? '').toString().isNotEmpty) {
        return rec['name'].toString();
      }
    }

    return direct.isNotEmpty ? direct : 'Walk-in Customer';
  }

  static String customerPhone(Map ord) {
    String raw = '';
    if (ord['customer_phone'] != null &&
        ord['customer_phone'].toString() != 'N/A') {
      raw = ord['customer_phone'].toString();
    } else if (ord['shipping_address'] is Map &&
        (ord['shipping_address'] as Map)['phone'] != null) {
      raw = (ord['shipping_address'] as Map)['phone'].toString();
    } else if (ord['customer_data'] is Map &&
        (ord['customer_data'] as Map)['phone'] != null) {
      raw = (ord['customer_data'] as Map)['phone'].toString();
    }
    return raw.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  static String customerEmail(Map ord, [Map? customerLookup]) {
    final direct = (ord['customer_email'] ?? '').toString().trim();
    if (direct.contains('@') && !direct.endsWith('.local')) return direct;

    if (ord['customer_data'] is Map) {
      final e = ((ord['customer_data'] as Map)['email'] ?? '').toString().trim();
      if (e.contains('@') && !e.endsWith('.local')) return e;
    }

    if (ord['shipping_address'] is Map) {
      final e =
          ((ord['shipping_address'] as Map)['email'] ?? '').toString().trim();
      if (e.contains('@') && !e.endsWith('.local')) return e;
    }

    final phone = customerPhone(ord);
    if (customerLookup != null && phone.isNotEmpty) {
      final rec = customerLookup['phone_$phone'];
      if (rec is Map && (rec['email'] ?? '').toString().contains('@')) {
        return rec['email'].toString();
      }
    }
    return '';
  }

  static String deliveryAddress(Map ord) {
    final full = (ord['full_address'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;

    if (ord['shipping_address'] is Map) {
      final sa = ord['shipping_address'] as Map;
      final street =
          (sa['address'] ?? sa['street_address'] ?? '').toString().trim();
      final city = (sa['city'] ?? '').toString().trim();
      if (street.isNotEmpty && city.isNotEmpty) return '$street, $city';
      if (street.isNotEmpty) return street;
    } else if (ord['shipping_address'] is String &&
        ord['shipping_address'].toString().trim().isNotEmpty) {
      return ord['shipping_address'].toString().trim();
    }
    return 'Fulbarigate, Khulna';
  }

  static bool isB2BOrder(Map ord) {
    final numStr = orderNumber(ord);
    final pay = (ord['payment_method'] ?? '').toString().toLowerCase();
    final addr = deliveryAddress(ord);
    return numStr.startsWith('B2B-') ||
        pay == 'b2b_cross_sell' ||
        addr.contains('B2B Partner');
  }

  static bool hasGpsCoordinates(Map ord) {
    final lat = double.tryParse((ord['latitude'] ?? '').toString());
    final lng = double.tryParse((ord['longitude'] ?? '').toString());
    return lat != null && lng != null;
  }

  static String formatDateShort(dynamic rawDate) {
    if (rawDate == null) return 'Recent';
    final str = rawDate.toString();
    final dt = DateTime.tryParse(str);
    if (dt == null) {
      return str.length >= 10 ? str.substring(0, 10) : str;
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}, $hour12:$min $amPm';
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'processing':
        return const Color(0xFF3B82F6);
      case 'shipped':
        return const Color(0xFF8B5CF6);
      case 'delivered':
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
      case 'refunded':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  static IconData statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'processing':
        return Icons.autorenew_rounded;
      case 'shipped':
        return Icons.local_shipping_rounded;
      case 'delivered':
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
      case 'refunded':
        return Icons.cancel_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  static String buildSmsMessage(Map ord, String status, String subdomain) {
    final name = customerName(ord);
    final numStr = orderNumber(ord);
    final amount = orderTotal(ord).toStringAsFixed(0);
    final store = subdomain.toUpperCase();

    switch (status.toUpperCase()) {
      case 'PROCESSING':
        return 'Dear $name, your order #$numStr of Tk $amount at $store is now being processed. Thank you!';
      case 'SHIPPED':
        return 'Dear $name, your order #$numStr has been shipped via courier. Please keep Tk $amount ready. Thank you!';
      case 'DELIVERED':
        return 'Dear $name, your order #$numStr has been delivered successfully. Thank you for shopping with $store!';
      case 'CANCELLED':
        return 'Dear $name, your order #$numStr has been cancelled. Contact support for any queries. - $store';
      default:
        return 'Dear $name, update on your order #$numStr: status is ${status.toUpperCase()}. Total: Tk $amount. - $store';
    }
  }

  static String buildEmailSubject(Map ord, String status, String subdomain) {
    final numStr = orderNumber(ord);
    final store = subdomain.toUpperCase();
    return 'Order #$numStr Status Update: ${status.toUpperCase()} - $store';
  }

  static String buildEmailBody(Map ord, String status, String subdomain) {
    final name = customerName(ord);
    final numStr = orderNumber(ord);
    final amount = orderTotal(ord).toStringAsFixed(0);
    final store = subdomain.toUpperCase();
    final address = deliveryAddress(ord);

    return 'Hello $name,\n\n'
        'Thank you for shopping with $store!\n\n'
        'Order Update:\n'
        '• Order ID: #$numStr\n'
        '• Current Status: ${status.toUpperCase()}\n'
        '• Total Bill: ৳$amount\n'
        '• Delivery Address: $address\n\n'
        'Best regards,\n$store Team';
  }
}