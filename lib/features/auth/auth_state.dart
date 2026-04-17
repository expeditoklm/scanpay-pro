class AuthState {
  const AuthState({
    required this.userId,
    required this.companyId,
    required this.companyName,
    this.companyLogoUrl,
    required this.secretKey,
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.plan,
  });

  final String userId;
  final String companyId;
  final String companyName;
  final String? companyLogoUrl;
  final String secretKey;
  final String accessToken;
  final String refreshToken;
  final String role;
  final String plan;

  bool get isAuthenticated =>
      userId.isNotEmpty &&
      companyId.isNotEmpty &&
      accessToken.isNotEmpty &&
      refreshToken.isNotEmpty &&
      secretKey.isNotEmpty;

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'company_id': companyId,
        'company_name': companyName,
        'company_logo_url': companyLogoUrl,
        'secret_key': secretKey,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'role': role,
        'plan': plan,
      };

  factory AuthState.fromJson(Map<String, dynamic> json) {
    return AuthState(
      userId: (json['user_id'] ?? '') as String,
      companyId: (json['company_id'] ?? '') as String,
      companyName: (json['company_name'] ?? '') as String,
      companyLogoUrl: json['company_logo_url'] as String?,
      secretKey: (json['secret_key'] ?? '') as String,
      accessToken: (json['access_token'] ?? '') as String,
      refreshToken: (json['refresh_token'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      plan: (json['plan'] ?? '') as String,
    );
  }

  AuthState copyWith({
    String? userId,
    String? companyId,
    String? companyName,
    String? companyLogoUrl,
    String? secretKey,
    String? accessToken,
    String? refreshToken,
    String? role,
    String? plan,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      secretKey: secretKey ?? this.secretKey,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      role: role ?? this.role,
      plan: plan ?? this.plan,
    );
  }
}
