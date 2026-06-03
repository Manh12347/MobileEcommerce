class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String text;
  final DateTime timestamp;
  final List<RetrievedProduct>? products;

  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.products,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

class RetrievedProduct {
  final int productItemId;
  final String productName;
  final double price;
  final double? salePrice;
  final int stock;
  final int? warrantyMonths;
  final double similarity;
  final String? sku;
  final String? description;
  final String? mainImageUrl;
  final String? categoryName;

  RetrievedProduct({
    required this.productItemId,
    required this.productName,
    required this.price,
    this.salePrice,
    required this.stock,
    this.warrantyMonths,
    required this.similarity,
    this.sku,
    this.description,
    this.mainImageUrl,
    this.categoryName,
  });

  factory RetrievedProduct.fromJson(Map<String, dynamic> json) {
    return RetrievedProduct(
      productItemId: json['product_item_id'] as int,
      productName: json['product_name'] as String,
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : (json['price'] as num).toDouble(),
      salePrice: json['sale_price'] != null
          ? (json['sale_price'] is int)
              ? (json['sale_price'] as int).toDouble()
              : (json['sale_price'] as num).toDouble()
          : null,
      stock: json['stock'] as int,
      warrantyMonths: json['warranty_months'] as int?,
      similarity: (json['similarity'] is num)
          ? (json['similarity'] as num).toDouble()
          : 0.0,
      sku: json['sku'] as String?,
      description: json['description'] as String?,
      mainImageUrl: json['main_image_url'] as String?,
      categoryName: json['category_name'] as String?,
    );
  }
}

class ChatSession {
  final String sessionId;
  final List<ChatMessage> messages;

  ChatSession({
    required this.sessionId,
    required this.messages,
  });
}
