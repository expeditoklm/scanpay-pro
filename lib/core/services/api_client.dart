import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/auth_provider.dart';
import '../config/erp_config.dart';

class ApiClient {
  ApiClient(this._ref);

  final Ref _ref;
  final _http = http.Client();

  Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!withAuth) return headers;
    final token = _ref.read(authProvider)?.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() request, {
    bool withAuth = true,
  }) async {
    var response = await request();
    if (withAuth && response.statusCode == 401) {
      final refreshed = await _ref.read(authProvider.notifier).refreshIfNeeded();
      if (refreshed) {
        response = await request();
      }
    }
    return response;
  }

  Future<dynamic> get(String path) async {
    final response = await _sendWithRetry(
      () => _http
          .get(Uri.parse('$kErpBaseUrl$path'), headers: _headers())
          .timeout(const Duration(seconds: 10)),
    );
    return _handle(response);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    final response = await _sendWithRetry(
      () => _http
          .post(
            Uri.parse('$kErpBaseUrl$path'),
            headers: _headers(withAuth: withAuth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10)),
      withAuth: withAuth,
    );
    return _handle(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await _sendWithRetry(
      () => _http
          .put(
            Uri.parse('$kErpBaseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10)),
    );
    return _handle(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await _sendWithRetry(
      () => _http
          .patch(
            Uri.parse('$kErpBaseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10)),
    );
    return _handle(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _sendWithRetry(
      () => _http
          .delete(Uri.parse('$kErpBaseUrl$path'), headers: _headers())
          .timeout(const Duration(seconds: 10)),
    );
    return _handle(response);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }

    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final detail = body['detail']?.toString() ?? res.body;
      throw Exception('HTTP ${res.statusCode}: $detail');
    } catch (_) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));
