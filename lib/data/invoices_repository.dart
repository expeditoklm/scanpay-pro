import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/erp_config.dart';
import '../core/models/invoice.dart';
import '../core/models/product.dart';
import '../features/auth/auth_provider.dart';

class InvoicesRepository {
  InvoicesRepository({
    required this.ref,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;
  final Map<String, List<Invoice>> _cache = {};

  Map<String, String> get _headers {
    final auth = ref.read(authProvider);
    if (auth == null) {
      return const {'Content-Type': 'application/json'};
    }
    return auth.authHeaders;
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    var response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));
      }
    }
    return response;
  }

  Future<http.Response> _postWithRetry(Uri uri, String body) async {
    var response = await _client
        .post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        response = await _client
            .post(uri, headers: _headers, body: body)
            .timeout(const Duration(seconds: 8));
      }
    }
    return response;
  }

  Future<List<Invoice>> listForCompany(String companyId) async {
    final auth = ref.read(authProvider);
    if (auth == null) return const [];

    try {
      final response = await _getWithRetry(Uri.parse('$kErpBaseUrl/api/sales'));
      if (response.statusCode != 200) {
        throw Exception('ERP HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final invoices = data
          .map((item) => _fromSaleJson(
                item as Map<String, dynamic>,
                companyId: companyId,
                companyName: auth.companyName,
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cache[companyId] = invoices;
      return invoices;
    } catch (_) {
      return _cache[companyId] ?? const [];
    }
  }

  Future<Invoice?> recordSale({
    required String companyId,
    required String invoiceId,
    required List<({Product product, int qty})> lines,
  }) async {
    final auth = ref.read(authProvider);
    if (auth == null) return null;

    final payload = {
      'items': [
        for (final line in lines)
          {
            'product_id': line.product.id,
            'quantity': line.qty,
          },
      ],
      'source': 'mobile_app',
      'note': 'Vente enregistrée depuis l’application mobile',
    };

    final response = await _postWithRetry(
      Uri.parse('$kErpBaseUrl/api/sales'),
      jsonEncode(payload),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Création vente ERP impossible (${response.statusCode})');
    }

    final sale = jsonDecode(response.body) as Map<String, dynamic>;
    final invoice = _fromSaleJson(
      sale,
      companyId: companyId,
      companyName: auth.companyName,
    );

    final existing = List<Invoice>.from(_cache[companyId] ?? const []);
    existing.removeWhere((item) => item.id == invoice.id);
    existing.insert(0, invoice);
    _cache[companyId] = existing;
    return invoice;
  }

  Invoice _fromSaleJson(
    Map<String, dynamic> json, {
    required String companyId,
    required String companyName,
  }) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);
    return Invoice(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      companyId: companyId,
      companyName: companyName,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      customer: json['customer'] as String?,
      note: json['note'] as String?,
      source: json['source'] as String? ?? 'mobile_app',
      lines: rawItems.map((item) {
        final map = item as Map<String, dynamic>;
        return InvoiceLine(
          productId: map['product_id'] as String? ?? '',
          name: map['product_name'] as String? ?? map['name'] as String? ?? 'Produit',
          unitPrice: (map['unit_price'] as num? ?? 0).toDouble(),
          quantity: (map['quantity'] as num? ?? 0).toInt(),
        );
      }).toList(),
    );
  }
}
