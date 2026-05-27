int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

class Warranty {
  final int warrantyId;
  final int? serialId;
  final String? serialCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;

  Warranty({
    required this.warrantyId,
    this.serialId,
    this.serialCode,
    this.startDate,
    this.endDate,
    this.status,
  });

  factory Warranty.fromJson(Map<String, dynamic> json) {
    return Warranty(
      warrantyId: _toInt(json['warrantyId']) ?? 0,
      serialId: _toInt(json['serialId']),
      serialCode: json['serialCode']?.toString(),
      startDate: _toDateTime(json['startDate']),
      endDate: _toDateTime(json['endDate']),
      status: json['status']?.toString(),
    );
  }

  int? remainingDays(DateTime now) {
    if (endDate == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return end.difference(today).inDays;
  }

  bool get isActive => status?.toLowerCase() == 'active';
}

class WarrantyClaim {
  final int claimId;
  final int? serialId;
  final String? serialCode;
  final String? serialSeries;
  final int? productId;
  final String? productName;
  final String? productSku;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final String? warrantyStatus;
  final String? issueDescription;
  final String? status;
  final DateTime? createdAt;

  WarrantyClaim({
    required this.claimId,
    this.serialId,
    this.serialCode,
    this.serialSeries,
    this.productId,
    this.productName,
    this.productSku,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.warrantyStatus,
    this.issueDescription,
    this.status,
    this.createdAt,
  });

  factory WarrantyClaim.fromJson(Map<String, dynamic> json) {
    return WarrantyClaim(
      claimId: _toInt(json['claimId']) ?? 0,
      serialId: _toInt(json['serialId']),
      serialCode: json['serialCode']?.toString(),
      serialSeries: json['serialSeries']?.toString(),
      productId: _toInt(json['productId']),
      productName: json['productName']?.toString(),
      productSku: json['productSku']?.toString(),
      warrantyStartDate: _toDateTime(json['warrantyStartDate']),
      warrantyEndDate: _toDateTime(json['warrantyEndDate']),
      warrantyStatus: json['warrantyStatus']?.toString(),
      issueDescription: json['issueDescription']?.toString(),
      status: json['status']?.toString(),
      createdAt: _toDateTime(json['createdAt']),
    );
  }
}
