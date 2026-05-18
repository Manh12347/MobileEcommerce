class LoginResponse {
  final int? accountId;
  final String? email;
  final String? role;
  final String? accessToken;
  final String? refreshToken;
  final bool? require2FA;
  final String? message;

  LoginResponse({
    this.accountId,
    this.email,
    this.role,
    this.accessToken,
    this.refreshToken,
    this.require2FA,
    this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accountId: json['accountId'] is int
          ? json['accountId'] as int
          : int.tryParse('${json['accountId'] ?? ''}'),
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      accessToken: json['accessToken']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      require2FA: json['require2FA'] is bool ? json['require2FA'] as bool : null,
      message: json['message']?.toString(),
    );
  }
}
