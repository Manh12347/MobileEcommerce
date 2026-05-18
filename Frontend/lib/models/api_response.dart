class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final dynamic rawData = json['data'];
    return ApiResponse<T>(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: rawData is Map<String, dynamic> ? fromJsonT(rawData) : null,
      statusCode: json['statusCode'] is int
          ? json['statusCode'] as int
          : int.tryParse('${json['statusCode'] ?? ''}'),
    );
  }
}