double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

class OrderSerial {
  final int? serialId;
  final String? serialCode;
  final String? status;

  OrderSerial({this.serialId, this.serialCode, this.status});

  factory OrderSerial.fromJson(Map<String, dynamic> json) {
    return OrderSerial(
      serialId: _toInt(json['serialId']),
      serialCode: json['serialCode']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class OrderItem {
  final int orderItemId;
  final int productItemId;
  final String? sku;
  final String? productName;
  final String? mainImageUrl;
  final int quantity;
  final double? price;
  final double? lineTotal;
  final List<OrderSerial> serials;

  OrderItem({
    required this.orderItemId,
    required this.productItemId,
    this.sku,
    this.productName,
    this.mainImageUrl,
    required this.quantity,
    this.price,
    this.lineTotal,
    required this.serials,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final rawSerials = json['serials'];
    return OrderItem(
      orderItemId: _toInt(json['orderItemId']) ?? 0,
      productItemId: _toInt(json['productItemId']) ?? 0,
      sku: json['sku']?.toString(),
      productName: json['productName']?.toString(),
      mainImageUrl: json['mainImageUrl']?.toString(),
      quantity: _toInt(json['quantity']) ?? 0,
      price: _toDouble(json['price']),
      lineTotal: _toDouble(json['lineTotal']),
      serials: rawSerials is List
          ? rawSerials
                .whereType<Map<String, dynamic>>()
                .map(OrderSerial.fromJson)
                .toList()
          : const [],
    );
  }
}

class OrderSummary {
  final int orderId;
  final String orderCode;
  final String? status;
  final String? paymentStatus;
  final double? totalPrice;
  final String? createdOn;
  final int itemCount;

  OrderSummary({
    required this.orderId,
    required this.orderCode,
    this.status,
    this.paymentStatus,
    this.totalPrice,
    this.createdOn,
    required this.itemCount,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      orderId: _toInt(json['orderId']) ?? 0,
      orderCode: json['orderCode']?.toString() ?? '',
      status: json['status']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      totalPrice: _toDouble(json['totalPrice']),
      createdOn: json['createdOn']?.toString(),
      itemCount: _toInt(json['itemCount']) ?? 0,
    );
  }
}

class OrderDetail {
  final int orderId;
  final String orderCode;
  final String? gencode;
  final int accountId;
  final String? status;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? shippingMethod;
  final String? shippingAddress;
  final String? phone;
  final String? customerName;
  final int? provinceId;
  final int? districtId;
  final String? wardCode;
  final String? provinceName;
  final String? districtName;
  final String? wardName;
  final double? totalPrice;
  final double? shippingFee;
  final String? createdOn;
  final List<OrderItem> items;

  OrderDetail({
    required this.orderId,
    required this.orderCode,
    this.gencode,
    required this.accountId,
    this.status,
    this.paymentStatus,
    this.paymentMethod,
    this.shippingMethod,
    this.shippingAddress,
    this.phone,
    this.customerName,
    this.provinceId,
    this.districtId,
    this.wardCode,
    this.provinceName,
    this.districtName,
    this.wardName,
    this.totalPrice,
    this.shippingFee,
    this.createdOn,
    required this.items,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return OrderDetail(
      orderId: _toInt(json['orderId']) ?? 0,
      orderCode: json['orderCode']?.toString() ?? '',
      gencode: json['gencode']?.toString(),
      accountId: _toInt(json['accountId']) ?? 0,
      status: json['status']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      shippingMethod: json['shippingMethod']?.toString() ?? json['shipping_method']?.toString() ?? json['shippingMethodName']?.toString(),
      shippingAddress: json['shippingAddress']?.toString(),
      phone: json['phone']?.toString(),
      customerName: json['customerName']?.toString(),
      provinceId: _toInt(json['provinceId']),
      districtId: _toInt(json['districtId']),
      wardCode: json['wardCode']?.toString(),
      provinceName: json['provinceName']?.toString(),
      districtName: json['districtName']?.toString(),
      wardName: json['wardName']?.toString(),
      totalPrice: _toDouble(json['totalPrice']),
      shippingFee: _toDouble(json['shippingFee']),
      createdOn: json['createdOn']?.toString(),
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(OrderItem.fromJson)
                .toList()
          : const [],
    );
  }
}

class OrderStatusStep {
  final String? status;
  final String? label;
  final bool completed;
  final bool current;

  OrderStatusStep({
    this.status,
    this.label,
    required this.completed,
    required this.current,
  });

  factory OrderStatusStep.fromJson(Map<String, dynamic> json) {
    return OrderStatusStep(
      status: json['status']?.toString(),
      label: json['label']?.toString(),
      completed: json['completed'] == true,
      current: json['current'] == true,
    );
  }
}

class OrderTrack {
  final int orderId;
  final String orderCode;
  final String? currentStatus;
  final String? statusMessage;
  final List<OrderStatusStep> timeline;

  OrderTrack({
    required this.orderId,
    required this.orderCode,
    this.currentStatus,
    this.statusMessage,
    required this.timeline,
  });

  factory OrderTrack.fromJson(Map<String, dynamic> json) {
    final rawTimeline = json['timeline'];
    return OrderTrack(
      orderId: _toInt(json['orderId']) ?? 0,
      orderCode: json['orderCode']?.toString() ?? '',
      currentStatus: json['currentStatus']?.toString(),
      statusMessage: json['statusMessage']?.toString(),
      timeline: rawTimeline is List
          ? rawTimeline
                .whereType<Map<String, dynamic>>()
                .map(OrderStatusStep.fromJson)
                .toList()
          : const [],
    );
  }
}

class CreateOrderRequest {
  final String shippingAddress;
  final String phone;
  final int? provinceId;
  final int? districtId;
  final String? wardCode;
  final String? provinceName;
  final String? districtName;
  final String? wardName;
  final String paymentMethod;

  CreateOrderRequest({
    required this.shippingAddress,
    required this.phone,
    this.provinceId,
    this.districtId,
    this.wardCode,
    this.provinceName,
    this.districtName,
    this.wardName,
    this.paymentMethod = 'COD',
  });

  Map<String, dynamic> toJson() => {
    'shippingAddress': shippingAddress,
    'phone': phone,
    'provinceId': provinceId,
    'districtId': districtId,
    'wardCode': wardCode,
    'provinceName': provinceName,
    'districtName': districtName,
    'wardName': wardName,
    'paymentMethod': paymentMethod,
  };
}
