double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

class CartItem {
  final int cartItemId;
  final int productItemId;
  final int quantity;
  final String? sku;
  final String? productName;
  final String? mainImageUrl;
  final double? price;
  final double? salePrice;
  final double? lineTotal;

  CartItem({
    required this.cartItemId,
    required this.productItemId,
    required this.quantity,
    this.sku,
    this.productName,
    this.mainImageUrl,
    this.price,
    this.salePrice,
    this.lineTotal,
  });

  double get unitPrice =>
      salePrice != null && salePrice! > 0 && price != null && salePrice! < price!
          ? salePrice!
          : (price ?? salePrice ?? 0);

  bool get hasPromotion =>
      salePrice != null && salePrice! > 0 && price != null && salePrice! < price!;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartItemId: _toInt(json['cartItemId']) ?? 0,
      productItemId: _toInt(json['productItemId']) ?? 0,
      quantity: _toInt(json['quantity']) ?? 0,
      sku: json['sku']?.toString(),
      productName: json['productName']?.toString(),
      mainImageUrl: json['mainImageUrl']?.toString(),
      price: _toDouble(json['price']),
      salePrice: _toDouble(json['salePrice']),
      lineTotal: _toDouble(json['lineTotal']),
    );
  }
}

class Cart {
  final int cartId;
  final int accountId;
  final String? createdOn;
  final String? updatedOn;
  final List<CartItem> items;
  final int totalItems;
  final double totalAmount;

  Cart({
    required this.cartId,
    required this.accountId,
    this.createdOn,
    this.updatedOn,
    required this.items,
    required this.totalItems,
    required this.totalAmount,
  });

  double get promotionSavings {
    var savings = 0.0;
    for (final item in items) {
      if (item.hasPromotion && item.price != null) {
        savings += (item.price! - item.unitPrice) * item.quantity;
      }
    }
    return savings;
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(CartItem.fromJson)
            .toList()
        : <CartItem>[];

    return Cart(
      cartId: _toInt(json['cartId']) ?? 0,
      accountId: _toInt(json['accountId']) ?? 0,
      createdOn: json['createdOn']?.toString(),
      updatedOn: json['updatedOn']?.toString(),
      items: items,
      totalItems: _toInt(json['totalItems']) ?? items.length,
      totalAmount: _toDouble(json['totalAmount']) ?? 0,
    );
  }
}
