/// external_stock_sync.dart — v2.0
/// Synchronisation des ventes vers l'ERP FastAPI via JWT Bearer.
/// L'URL et le token sont passés dynamiquement depuis auth_provider.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tpe_qr_saas/core/config/erp_config.dart';


abstract class ExternalStockSync {
  Future<void> sendSale({
    required Uri endpoint,
    required String companyId,
    required String saleId,
    required List<ExternalSaleLine> lines,
    required String bearerToken,
  });
}

class ExternalSaleLine {
  const ExternalSaleLine({
    required this.productId,
    required this.quantity,
    this.sku,
  });

  final String productId;
  final int quantity;
  final String? sku;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'sku':        sku,
        'quantity':   quantity,
      };
}

class HttpExternalStockSync implements ExternalStockSync {
  HttpExternalStockSync({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<void> sendSale({
    required Uri endpoint,
    required String companyId,
    required String saleId,
    required List<ExternalSaleLine> lines,
    required String bearerToken,
  }) async {
    final body = jsonEncode({
      'sale_reference': saleId,
      'company_id':     companyId,
      'total':          0,
      'items':          [for (final l in lines) l.toJson()],
    });

    final res = await _client.post(
      endpoint,
      headers: {
        'Content-Type':  'application/json',
        // JWT Bearer (v2) ou API Key legacy (v1) selon ce qui est fourni
        'Authorization': 'Bearer $bearerToken',
      },
      body: body,
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('ERP webhook ${res.statusCode}: ${res.body}');
    }
  }
}

/// URI du webhook ERP
Uri get erpWebhookUri => Uri.parse('$kErpBaseUrl/api/webhook/sale');