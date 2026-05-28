int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

String? _toString(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

class GhnPreviewCategory {
  final String level1;

  GhnPreviewCategory({required this.level1});

  Map<String, dynamic> toJson() => {'level1': level1};
}

class GhnPreviewItem {
  final String name;
  final String code;
  final int quantity;
  final int price;
  final int length;
  final int width;
  final int height;
  final int weight;
  final GhnPreviewCategory category;

  GhnPreviewItem({
    required this.name,
    required this.code,
    required this.quantity,
    required this.price,
    required this.length,
    required this.width,
    required this.height,
    required this.weight,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'quantity': quantity,
        'price': price,
        'length': length,
        'width': width,
        'height': height,
        'weight': weight,
        'category': category.toJson(),
      };
}

class GhnShippingPreviewRequest {
  final int paymentTypeId;
  final String note;
  final String requiredNote;
  final String returnPhone;
  final String returnAddress;
  final int? returnDistrictId;
  final String? returnWardCode;
  final String clientOrderCode;
  final String fromName;
  final String fromPhone;
  final String fromAddress;
  final String fromWardName;
  final String fromDistrictName;
  final String fromProvinceName;
  final String toName;
  final String toPhone;
  final String toAddress;
  final String toWardName;
  final String toWardCode;
  final String toDistrictName;
  final String toProvinceName;
  final int codAmount;
  final String content;
  final int weight;
  final int length;
  final int width;
  final int height;
  final int? pickStationId;
  final int? deliverStationId;
  final int insuranceValue;
  final int serviceTypeId;
  final String? coupon;
  final int? pickupTime;
  final List<int> pickShift;
  final int codFailedAmount;
  final List<GhnPreviewItem> items;

  GhnShippingPreviewRequest({
    required this.paymentTypeId,
    required this.note,
    required this.requiredNote,
    required this.returnPhone,
    required this.returnAddress,
    this.returnDistrictId,
    this.returnWardCode,
    this.clientOrderCode = '',
    required this.fromName,
    required this.fromPhone,
    required this.fromAddress,
    required this.fromWardName,
    required this.fromDistrictName,
    required this.fromProvinceName,
    required this.toName,
    required this.toPhone,
    required this.toAddress,
    required this.toWardName,
    required this.toWardCode,
    required this.toDistrictName,
    required this.toProvinceName,
    required this.codAmount,
    required this.content,
    required this.weight,
    required this.length,
    required this.width,
    required this.height,
    this.pickStationId,
    this.deliverStationId,
    required this.insuranceValue,
    required this.serviceTypeId,
    this.coupon,
    this.pickupTime,
    this.pickShift = const [],
    this.codFailedAmount = 0,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'payment_type_id': paymentTypeId,
        'note': note,
        'required_note': requiredNote,
        'return_phone': returnPhone,
        'return_address': returnAddress,
        'return_district_id': returnDistrictId,
        'return_ward_code': returnWardCode,
        'client_order_code': clientOrderCode,
        'from_name': fromName,
        'from_phone': fromPhone,
        'from_address': fromAddress,
        'from_ward_name': fromWardName,
        'from_district_name': fromDistrictName,
        'from_province_name': fromProvinceName,
        'to_name': toName,
        'to_phone': toPhone,
        'to_address': toAddress,
        'to_ward_name': toWardName,
        'to_ward_code': toWardCode,
        'to_district_name': toDistrictName,
        'to_province_name': toProvinceName,
        'cod_amount': codAmount,
        'content': content,
        'weight': weight,
        'length': length,
        'width': width,
        'height': height,
        'pick_station_id': pickStationId,
        'deliver_station_id': deliverStationId,
        'insurance_value': insuranceValue,
        'service_type_id': serviceTypeId,
        'coupon': coupon,
        'pickup_time': pickupTime,
        'pick_shift': pickShift,
        'cod_failed_amount': codFailedAmount,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

class GhnShippingPreviewFee {
  final int? mainService;
  final int? insurance;
  final int? stationDo;
  final int? stationPu;
  final int? returnFee;
  final int? r2s;
  final int? coupon;
  final int? codFailedFee;

  GhnShippingPreviewFee({
    this.mainService,
    this.insurance,
    this.stationDo,
    this.stationPu,
    this.returnFee,
    this.r2s,
    this.coupon,
    this.codFailedFee,
  });

  factory GhnShippingPreviewFee.fromJson(Map<String, dynamic> json) {
    return GhnShippingPreviewFee(
      mainService: _toInt(json['main_service']),
      insurance: _toInt(json['insurance']),
      stationDo: _toInt(json['station_do']),
      stationPu: _toInt(json['station_pu']),
      returnFee: _toInt(json['return']),
      r2s: _toInt(json['r2s']),
      coupon: _toInt(json['coupon']),
      codFailedFee: _toInt(json['cod_failed_fee']),
    );
  }
}

class GhnShippingPreviewData {
  final String? orderCode;
  final String? sortCode;
  final String? transType;
  final String? wardEncode;
  final String? districtEncode;
  final GhnShippingPreviewFee? fee;
  final int? totalFee;
  final DateTime? expectedDeliveryTime;

  GhnShippingPreviewData({
    this.orderCode,
    this.sortCode,
    this.transType,
    this.wardEncode,
    this.districtEncode,
    this.fee,
    this.totalFee,
    this.expectedDeliveryTime,
  });

  factory GhnShippingPreviewData.fromJson(Map<String, dynamic> json) {
    return GhnShippingPreviewData(
      orderCode: _toString(json['order_code']),
      sortCode: _toString(json['sort_code']),
      transType: _toString(json['trans_type']),
      wardEncode: _toString(json['ward_encode']),
      districtEncode: _toString(json['district_encode']),
      fee: json['fee'] is Map<String, dynamic>
          ? GhnShippingPreviewFee.fromJson(json['fee'] as Map<String, dynamic>)
          : null,
      totalFee: _toInt(json['total_fee']),
      expectedDeliveryTime: DateTime.tryParse(
        _toString(json['expected_delivery_time']) ?? '',
      ),
    );
  }
}

class GhnShippingPreviewResponse {
  final int? code;
  final String? message;
  final GhnShippingPreviewData? data;

  GhnShippingPreviewResponse({this.code, this.message, this.data});

  bool get isSuccess => code == 200;

  factory GhnShippingPreviewResponse.fromJson(Map<String, dynamic> json) {
    return GhnShippingPreviewResponse(
      code: _toInt(json['code']),
      message: _toString(json['message']),
      data: json['data'] is Map<String, dynamic>
          ? GhnShippingPreviewData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}
