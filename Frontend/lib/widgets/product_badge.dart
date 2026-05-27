import 'package:flutter/material.dart';

class ProductBadge extends StatelessWidget {
  const ProductBadge({
    super.key,
    required this.label,
    this.backgroundColor = const Color(0xFFE8F4FF),
    this.foregroundColor = const Color(0xFF1F67E2),
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
