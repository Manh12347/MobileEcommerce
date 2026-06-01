import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_item.dart';

class ViewHistoryEntry {
  final int productId;
  final String name;
  final String? mainImageUrl;
  final double? salePrice;
  final double? price;
  final DateTime viewedAt;

  ViewHistoryEntry({
    required this.productId,
    required this.name,
    this.mainImageUrl,
    this.salePrice,
    this.price,
    required this.viewedAt,
  });

  factory ViewHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ViewHistoryEntry(
      productId: json['productId'] as int,
      name: json['name'] as String,
      mainImageUrl: json['mainImageUrl'] as String?,
      salePrice: (json['salePrice'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      viewedAt: DateTime.parse(json['viewedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'mainImageUrl': mainImageUrl,
        'salePrice': salePrice,
        'price': price,
        'viewedAt': viewedAt.toIso8601String(),
      };

  static ViewHistoryEntry fromSummary(ProductItemSummary summary) {
    return ViewHistoryEntry(
      productId: summary.productId ?? summary.productItemId ?? 0,
      name: summary.name,
      mainImageUrl: summary.mainImageUrl,
      salePrice: summary.salePrice,
      price: summary.price,
      viewedAt: DateTime.now(),
    );
  }

  static ViewHistoryEntry fromVariant(
    ProductItemVariantSummary variant,
    String name, {
    required int productId,
    String? summaryImageUrl,
  }) {
    return ViewHistoryEntry(
      productId: productId,
      name: name,
      mainImageUrl:
          variant.mainImageUrl ?? (variant.images.isNotEmpty ? variant.images.first : summaryImageUrl),
      salePrice: variant.salePrice,
      price: variant.price,
      viewedAt: DateTime.now(),
    );
  }
}

class ProductViewHistoryProvider extends ChangeNotifier {
  static const String _key = 'product_view_history';
  static const int _maxEntries = 20;

  List<ViewHistoryEntry> _history = [];
  bool _isLoaded = false;

  List<ViewHistoryEntry> get history {
    if (!_isLoaded) return [];
    return _history;
  }

  List<ViewHistoryEntry> get recentHistory {
    if (!_isLoaded) return [];
    return _history.take(10).toList();
  }

  Future<void> loadHistory() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        _history = list
            .whereType<Map<String, dynamic>>()
            .map(ViewHistoryEntry.fromJson)
            .toList();
        _isLoaded = true;
        notifyListeners();
      } else {
        _isLoaded = true;
      }
    } catch (_) {
      _isLoaded = true;
    }
  }

  Future<void> recordView(ViewHistoryEntry entry) async {
    await loadHistory();

    // Deduplicate by productId — same product, different variant = same entry
    _history.removeWhere((e) => e.productId == entry.productId);
    _history.insert(0, entry);

    if (_history.length > _maxEntries) {
      _history = _history.sublist(0, _maxEntries);
    }

    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_history.map((e) => e.toJson()).toList());
      await prefs.setString(_key, raw);
    } catch (_) {}
  }
}
