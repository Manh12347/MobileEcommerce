class PaymentQrData {
  final String qrUrl;
  final String gencode;
  final double amount;
  final String accountNumber;
  final String bankName;

  PaymentQrData({
    required this.qrUrl,
    required this.gencode,
    required this.amount,
    required this.accountNumber,
    required this.bankName,
  });

  factory PaymentQrData.fromJson(Map<String, dynamic> json) {
    return PaymentQrData(
      qrUrl: json['qrUrl']?.toString() ?? '',
      gencode: json['gencode']?.toString() ?? '',
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0.0,
      accountNumber: json['accountNumber']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
    );
  }
}

class PaymentStatusData {
  final String gencode;
  final String status;
  final int? orderId;
  final double? totalAmount;

  PaymentStatusData({
    required this.gencode,
    required this.status,
    this.orderId,
    this.totalAmount,
  });

  factory PaymentStatusData.fromJson(Map<String, dynamic> json) {
    return PaymentStatusData(
      gencode: json['gencode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      orderId: json['orderId'] is int ? json['orderId'] : int.tryParse('${json['orderId'] ?? 0}'),
      totalAmount: double.tryParse('${json['totalAmount'] ?? 0}'),
    );
  }

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';
  bool get isExpired => status == 'expired_or_unknown';
}

class PaymentNotificationPayload {
  final String gencode;
  final int? orderId;
  final String? orderCode;
  final String paymentStatus;
  final String? message;
  final int? timestamp;

  PaymentNotificationPayload({
    required this.gencode,
    required this.paymentStatus,
    this.orderId,
    this.orderCode,
    this.message,
    this.timestamp,
  });

  factory PaymentNotificationPayload.fromJson(Map<String, dynamic> json) {
    return PaymentNotificationPayload(
      gencode: json['gencode']?.toString() ?? '',
      orderId: json['orderId'] is int ? json['orderId'] as int : int.tryParse('${json['orderId'] ?? ''}'),
      orderCode: json['orderCode']?.toString(),
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      message: json['message']?.toString(),
      timestamp: json['timestamp'] is int ? json['timestamp'] as int : int.tryParse('${json['timestamp'] ?? ''}'),
    );
  }

  bool get isPaid => paymentStatus == 'paid';
}
