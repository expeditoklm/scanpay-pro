import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/erp_config.dart';
import 'auth_state.dart';

const kAuthStorageKey = 'erp_auth_state_v2';

final initialAuthStateProvider = Provider<AuthState?>((ref) => null);

final authProvider = NotifierProvider<AuthNotifier, AuthState?>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState?> {
  final http.Client _client = http.Client();
  static final RegExp _jsonLike = RegExp(r'^\s*[\{\[]');

  @override
  AuthState? build() => ref.watch(initialAuthStateProvider);

  Future<void> _persist(AuthState? next) async {
    final prefs = await SharedPreferences.getInstance();
    if (next == null) {
      await prefs.remove(kAuthStorageKey);
      return;
    }
    await prefs.setString(kAuthStorageKey, jsonEncode(next.toJson()));
  }

  Future<void> setSession(AuthState next) async {
    state = next;
    await _persist(next);
  }

  Future<AuthState> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kErpBaseUrl/auth/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': identifier.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final session = _decodeAuthResponse(res);
    await setSession(session);
    return session;
  }

  Future<AuthState> register({
    required String companyName,
    required String commercialName,
    required String rccm,
    required String ifu,
    required String address,
    required String phone,
    required String contactEmail,
    required String email,
    required String password,
    required String confirmPassword,
    String? logoPath,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kErpBaseUrl/auth/register'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'company_name': companyName.trim(),
            'commercial_name': commercialName.trim(),
            'rccm': rccm.trim(),
            'ifu': ifu.trim(),
            'address': address.trim(),
            'phone': phone.trim(),
            'contact_email': contactEmail.trim(),
            'email': email.trim(),
            'password': password,
            'confirm_password': confirmPassword,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final session = _decodeAuthResponse(res);
    await setSession(session);
    if (logoPath != null && logoPath.trim().isNotEmpty) {
      final updated = await _uploadCompanyLogo(session, logoPath.trim());
      await setSession(updated);
      return updated;
    }
    return session;
  }

  Future<bool> refreshIfNeeded() async {
    final current = state;
    if (current == null || current.refreshToken.isEmpty) {
      return false;
    }

    try {
      final res = await _client
          .post(
            Uri.parse('$kErpBaseUrl/auth/refresh'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': current.refreshToken}),
          )
          .timeout(const Duration(seconds: 12));
      final refreshed = _decodeAuthResponse(res);
      await setSession(
        refreshed.copyWith(
          secretKey: refreshed.secretKey.isEmpty
              ? current.secretKey
              : refreshed.secretKey,
        ),
      );
      return true;
    } catch (_) {
      await signOut();
      return false;
    }
  }

  Future<void> signOut() async {
    state = null;
    await _persist(null);
  }

  Future<AuthState> _uploadCompanyLogo(AuthState session, String logoPath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$kErpBaseUrl/auth/company-logo'),
    );
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    request.files.add(await http.MultipartFile.fromPath('file', logoPath));
    final streamed = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return session.copyWith(
        companyLogoUrl: body['company_logo_url'] as String?,
        companyName: body['company_name']?.toString() ?? session.companyName,
      );
    }
    final detail = body['detail']?.toString() ?? 'Erreur inconnue';
    throw Exception(detail);
  }

  Future<String> forgotPassword({required String email}) async {
    final res = await _client
        .post(
          Uri.parse('$kErpBaseUrl/auth/forgot-password'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 12));
    return _decodeMessageResponse(res);
  }

  Future<String> resendVerificationEmail({required String email}) async {
    final res = await _client
        .post(
          Uri.parse('$kErpBaseUrl/auth/send-verification-email'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 12));
    return _decodeMessageResponse(res);
  }

  AuthState _decodeAuthResponse(http.Response res) {
    final body = _decodeBody(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return AuthState.fromJson(body);
    }
    final detail = body['detail']?.toString() ?? 'Erreur inconnue';
    throw Exception(detail);
  }

  static AuthState? decodeStoredState(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    final state = AuthState.fromJson(json);
    return state.isAuthenticated ? state : null;
  }

  String _decodeMessageResponse(http.Response res) {
    final body = _decodeBody(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body['message']?.toString() ?? 'Operation reussie';
    }
    final detail = body['detail']?.toString() ?? 'Erreur inconnue';
    throw Exception(detail);
  }

  Map<String, dynamic> _decodeBody(http.Response res) {
    if (res.body.isEmpty) return <String, dynamic>{};
    if (!_jsonLike.hasMatch(res.body)) {
      return {
        'detail': res.statusCode >= 500
            ? 'Erreur interne du serveur'
            : res.body,
      };
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'detail': 'Reponse serveur invalide'};
  }
}
