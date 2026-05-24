class OAuthLoginRequest {
  final String provider;
  final String providerUserId;
  final String email;
  final String? fullName;
  final String? avatarUrl;

  OAuthLoginRequest({
    required this.provider,
    required this.providerUserId,
    required this.email,
    this.fullName,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'providerUserId': providerUserId,
      'email': email,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
    };
  }
}
