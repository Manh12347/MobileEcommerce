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
