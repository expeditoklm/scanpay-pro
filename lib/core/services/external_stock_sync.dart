import 'dart:convert';

import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════
//  CONFIGURATION ERP — Modifier ici uniquement
// ═══════════════════════════════════════════════════════════════
//
//  ⚠️ Choisir l'URL selon votre appareil de test :
//
//  Émulateur Android  → 'http://10.0.2.2:8000'
//  Vrai téléphone     → 'http://192.168.X.X:8000'   (IP de votre PC)
//  iOS simulateur     → 'http://localhost:8000'
//
//  Votre IP Windows : ouvrir cmd → ipconfig → "Adresse IPv4"
// ═══════════════════════════════════════════════════════════════
const String _kErpBaseUrl = 'http://10.91.193.223:8000';
const String _kErpApiKey  = 'erp-secret-key-2024';

/// Appel sortant vers l'ERP FastAPI (système existant).
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
        'sku': sku,
        'quantity': quantity,
      };
}

class HttpExternalStockSync implements ExternalStockSync {
  HttpExternalStockSync({http.Client? client}) : _client = client ?? http.Client();

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
      'company_id': companyId,
      'total': 0,
      'items': [for (final l in lines) l.toJson()],
    });

    final res = await _client.post(
      endpoint,
      headers: {
        'content-type': 'application/json',
        'X-API-Key': _kErpApiKey,
      },
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('ERP API error \${res.statusCode}: \${res.body}');
    }
  }
}

/// URL du webhook ERP prête à l'emploi
Uri get erpWebhookUri => Uri.parse('\$_kErpBaseUrl/api/webhook/sale');
