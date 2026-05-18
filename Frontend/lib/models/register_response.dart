class RegisterResponse {
  final int? accountId;
  final String? email;
  final String? message;
  final bool? requiresCaptcha;

  RegisterResponse({
    this.accountId,
    this.email,
    this.message,
    this.requiresCaptcha,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      accountId: json['accountId'] is int
          ? json['accountId'] as int
          : int.tryParse('${json['accountId'] ?? ''}'),
      email: json['email']?.toString(),
      message: json['message']?.toString(),
      requiresCaptcha:
          json['requiresCaptcha'] is bool ? json['requiresCaptcha'] as bool : null,
    );
  }
}