class AuthState {
  const AuthState({
    required this.userId,
    required this.companyId,
    required this.companyName,
    this.companyLogoUrl,
    this.companyIfu,
    this.companyRc,
    this.companyAddress,
    this.companyPhone,
    this.isVatRegistered = true,
    this.mecefToken,
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

  /// IFU (Identifiant Fiscal Unique) — fourni par la DGI Benin
  final String? companyIfu;

  /// Numero Registre du Commerce
  final String? companyRc;

  /// Adresse physique de la boutique
  final String? companyAddress;

  /// Telephone de la boutique
  final String? companyPhone;

  /// true = boutique assujettie TVA 18% | false = regime simplifie / exonere
  final bool isVatRegistered;

  /// Token API DGI MECeF (obtenu sur developper.impots.bj apres enregistrement SFE)
  /// Null = utilise les cles placeholder (mode mock local)
  final String? mecefToken;

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

  /// true si les vraies cles DGI sont configurees (IFU + token)
  bool get hasMecefCredentials =>
      (companyIfu ?? '').isNotEmpty && (mecefToken ?? '').isNotEmpty;

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'company_id': companyId,
        'company_name': companyName,
        'company_logo_url': companyLogoUrl,
        'company_ifu': companyIfu,
        'company_rc': companyRc,
        'company_address': companyAddress,
        'company_phone': companyPhone,
        'is_vat_registered': isVatRegistered,
        'mecef_token': mecefToken,
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
      companyIfu: json['company_ifu'] as String?,
      companyRc: json['company_rc'] as String?,
      companyAddress: json['company_address'] as String?,
      companyPhone: json['company_phone'] as String?,
      isVatRegistered: json['is_vat_registered'] as bool? ?? true,
      mecefToken: json['mecef_token'] as String?,
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
    String? companyIfu,
    String? companyRc,
    String? companyAddress,
    String? companyPhone,
    bool? isVatRegistered,
    String? mecefToken,
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
      companyIfu: companyIfu ?? this.companyIfu,
      companyRc: companyRc ?? this.companyRc,
      companyAddress: companyAddress ?? this.companyAddress,
      companyPhone: companyPhone ?? this.companyPhone,
      isVatRegistered: isVatRegistered ?? this.isVatRegistered,
      mecefToken: mecefToken ?? this.mecefToken,
      secretKey: secretKey ?? this.secretKey,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      role: role ?? this.role,
      plan: plan ?? this.plan,
    );
  }
}
