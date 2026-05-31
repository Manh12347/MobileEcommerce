import 'dart:convert';

double? _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value');
}

int? _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value');
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse('$value');
}

Map<String, dynamic>? _decodeMapValue(Object? rawValue) {
  if (rawValue == null) {
    return null;
  }
  if (rawValue is Map<String, dynamic>) {
    return rawValue;
  }
  if (rawValue is String && rawValue.trim().isNotEmpty) {
    final decoded = jsonDecode(rawValue);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  }
  return null;
}

List<String> _decodeStringList(Object? rawValue) {
  if (rawValue == null) {
    return const [];
  }
  if (rawValue is List) {
    return rawValue.map((value) => '$value').toList();
  }
  if (rawValue is String && rawValue.trim().isNotEmpty) {
    final trimmed = rawValue.trim();
    if (trimmed.startsWith('[')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((value) => '$value').toList();
      }
    }
    return [trimmed];
  }
  return ['$rawValue'];
}

String _normalizeProductStatus(String? status) {
  return status?.trim().toLowerCase() ?? '';
}

bool isActiveProductStatus(String? status) {
  switch (_normalizeProductStatus(status)) {
    case 'active':
    case 'available':
    case 'enabled':
    case 'publish':
      return true;
    default:
      return false;
  }
}

bool isInactiveProductStatus(String? status) {
  switch (_normalizeProductStatus(status)) {
    case 'disable':
    case 'disabled':
    case 'inactive':
    case 'discontinued':
    case 'hidden':
    case 'archived':
      return true;
    default:
      return false;
  }
}

String productStatusLabel(String? status) {
  if (isActiveProductStatus(status)) {
    return 'Hoạt động';
  }
  if (isInactiveProductStatus(status)) {
    return 'Không hoạt động';
  }
  final normalized = status?.trim();
  return normalized == null || normalized.isEmpty
      ? 'Không xác định'
      : normalized;
}

class ProductBrand {
  final int? brandId;
  final String? name;
  final String? country;
  final String? status;

  ProductBrand({this.brandId, this.name, this.country, this.status});

  factory ProductBrand.fromJson(Map<String, dynamic> json) {
    return ProductBrand(
      brandId: _toInt(json['brandId']),
      name: json['name']?.toString(),
      country: json['country']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class ProductCategory {
  final int? categoryId;
  final String? name;
  final String? status;

  ProductCategory({this.categoryId, this.name, this.status});

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      categoryId: _toInt(json['categoryId']),
      name: json['name']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class ProductItemSummary {
  final int? productItemId;
  final int? productId;
  final String? sku;
  final String? description;
  final int? stockQuantity;
  final int? soldQuantity;
  final String? status;
  final double? price;
  final double? salePrice;
  final String? mainImageUrl;
  final String? productName;
  final DateTime? createdAt;
  final ProductBrand? brand;
  final ProductCategory? category;

  ProductItemSummary({
    this.productItemId,
    this.productId,
    this.sku,
    this.description,
    this.stockQuantity,
    this.soldQuantity,
    this.status,
    this.price,
    this.salePrice,
    this.mainImageUrl,
    this.productName,
    this.createdAt,
    this.brand,
    this.category,
  });

  int? get id => productItemId ?? productId;

  String get name => productName ?? 'Sản phẩm';

  bool get hasSalePrice =>
      salePrice != null && price != null && salePrice! < price!;

  factory ProductItemSummary.fromJson(Map<String, dynamic> json) {
    final brandJson = json['brand'];
    final categoryJson = json['category'];

    return ProductItemSummary(
      productItemId: _toInt(json['productItemId']),
      productId: _toInt(json['productId']),
      sku: json['sku']?.toString(),
      description: json['description']?.toString(),
      stockQuantity: _toInt(json['stockQuantity']),
      soldQuantity: _toInt(json['soldQuantity']),
      status: json['status']?.toString(),
      price: _toDouble(json['price']),
      salePrice: _toDouble(json['salePrice']),
      mainImageUrl: json['mainImageUrl']?.toString(),
      productName: json['productName']?.toString() ?? json['name']?.toString(),
      createdAt: _toDateTime(json['createdAt']),
      brand: brandJson is Map<String, dynamic>
          ? ProductBrand.fromJson(brandJson)
          : null,
      category: categoryJson is Map<String, dynamic>
          ? ProductCategory.fromJson(categoryJson)
          : null,
    );
  }
}

class ProductSerial {
  final int? serialId;
  final String? serialCode;
  final String? status;
  final DateTime? importDate;

  ProductSerial({this.serialId, this.serialCode, this.status, this.importDate});

  factory ProductSerial.fromJson(Map<String, dynamic> json) {
    return ProductSerial(
      serialId: _toInt(json['serialId']),
      serialCode: json['serialCode']?.toString(),
      status: json['status']?.toString(),
      importDate: _toDateTime(json['importDate']),
    );
  }
}

class ProductItemDetail {
  final int? productItemId;
  final String? sku;
  final String? description;
  final int? stockQuantity;
  final String? status;
  final double? price;
  final double? salePrice;
  final Object? specificationsRaw;
  final Object? imagesRaw;
  final String? mainImageUrl;
  final String? embeddingText;
  final int? productId;
  final String? productName;
  final List<ProductSerial> serials;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductItemDetail({
    this.productItemId,
    this.sku,
    this.description,
    this.stockQuantity,
    this.status,
    this.price,
    this.salePrice,
    this.specificationsRaw,
    this.imagesRaw,
    this.mainImageUrl,
    this.embeddingText,
    this.productId,
    this.productName,
    required this.serials,
    this.createdAt,
    this.updatedAt,
  });

  int? get id => productItemId ?? productId;

  bool get hasSalePrice =>
      salePrice != null && price != null && salePrice! < price!;

  Map<String, dynamic> get specifications {
    return _decodeMapValue(specificationsRaw) ?? const {};
  }

  List<String> get images => _decodeStringList(imagesRaw);

  factory ProductItemDetail.fromJson(Map<String, dynamic> json) {
    final serialJson = json['serials'];
    return ProductItemDetail(
      productItemId: _toInt(json['productItemId']),
      sku: json['sku']?.toString(),
      description: json['description']?.toString(),
      stockQuantity: _toInt(json['stockQuantity']),
      status: json['status']?.toString(),
      price: _toDouble(json['price']),
      salePrice: _toDouble(json['salePrice']),
      specificationsRaw: json['specifications'],
      imagesRaw: json['images'],
      mainImageUrl: json['mainImageUrl']?.toString(),
      embeddingText: json['embeddingText']?.toString(),
      productId: _toInt(json['productId']),
      productName: json['productName']?.toString(),
      serials: serialJson is List
          ? serialJson
                .whereType<Map<String, dynamic>>()
                .map(ProductSerial.fromJson)
                .toList()
          : const [],
      createdAt: _toDateTime(json['createdAt']),
      updatedAt: _toDateTime(json['updatedAt']),
    );
  }
}

class ProductItemVariantSummary {
  final int? productItemId;
  final String? sku;
  final String? description;
  final int? stockQuantity;
  final String? status;
  final double? price;
  final double? salePrice;
  final Object? imagesRaw;
  final String? mainImageUrl;

  ProductItemVariantSummary({
    this.productItemId,
    this.sku,
    this.description,
    this.stockQuantity,
    this.status,
    this.price,
    this.salePrice,
    this.imagesRaw,
    this.mainImageUrl,
  });

  factory ProductItemVariantSummary.fromJson(Map<String, dynamic> json) {
    return ProductItemVariantSummary(
      productItemId: _toInt(json['productItemId']),
      sku: json['sku']?.toString(),
      description: json['description']?.toString(),
      stockQuantity: _toInt(json['stockQuantity']),
      status: json['status']?.toString(),
      price: _toDouble(json['price']),
      salePrice: _toDouble(json['salePrice']),
      imagesRaw: json['images'],
      mainImageUrl: json['mainImageUrl']?.toString(),
    );
  }

  bool get hasSalePrice => salePrice != null && price != null && salePrice! < price!;

  String get label {
    final code = sku?.trim();
    if (code != null && code.isNotEmpty) {
      return code;
    }
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      return desc;
    }
    return 'Biến thể';
  }

  List<String> get images => _decodeStringList(imagesRaw);
}
