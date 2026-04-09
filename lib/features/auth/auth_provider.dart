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
    required String email,
    required String password,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kErpBaseUrl/auth/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
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
    required String email,
    required String password,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$kErpBaseUrl/auth/register'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'company_name': companyName.trim(),
            'email': email.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final session = _decodeAuthResponse(res);
    await setSession(session);
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

  AuthState _decodeAuthResponse(http.Response res) {
    final Map<String, dynamic> body = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
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
}
