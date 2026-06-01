import 'package:flutter/material.dart';

String formatCurrency(num? value) {
  if (value == null) {
    return '0đ';
  }
  final rounded = value.round();
  final text = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(text[i]);
  }
  return '$bufferđ';
}

String orderStatusLabel(String? status) {
  switch (status) {
    case 'pending':
      return 'Chờ xử lý';
    case 'shipping':
      return 'Đang giao hàng';
    case 'completed':
      return 'Hoàn thành';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return status ?? '-';
  }
}

Color orderStatusColor(String? status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFF59E0B);
    case 'shipping':
      return const Color(0xFF1F67E2);
    case 'completed':
      return const Color(0xFF10B981);
    case 'cancelled':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF6B7893);
  }
}

String paymentStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'paid':
    case 'completed':
    case 'success':
      return 'Đã thanh toán';
    case 'pending':
    case 'waiting':
      return 'Chờ thanh toán';
    case 'failed':
    case 'error':
      return 'Thanh toán thất bại';
    case 'refunded':
      return 'Đã hoàn tiền';
    default:
      return status ?? '-';
  }
}

String paymentMethodLabel(String? method) {
  if (method == null || method.isEmpty) return '-';
  switch (method.toUpperCase()) {
    case 'COD':
      return 'Thanh toán khi nhận hàng (COD)';
    case 'PICKUP':
    case 'AT_STORE':
    case 'IN_STORE':
    case 'STORE':
      return 'Tại cửa hàng';
    case 'TRANSFER':
    case 'BANK_TRANSFER':
    case 'CHUYEN_KHOAN':
    case 'INTERNET_BANKING':
      return 'Chuyển khoản ngân hàng';
    default:
      return method;
  }
}

String formatOrderDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  try {
    final dt = DateTime.parse(raw);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} lúc ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return raw;
  }
}
