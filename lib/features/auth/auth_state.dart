class AuthState {
  const AuthState({
    required this.companyId,
    required this.companyName,
    required this.secretKey,
  });

  final String companyId;
  final String companyName;
  final String secretKey;

  bool get isAuthenticated => companyId.isNotEmpty && secretKey.isNotEmpty;
}
