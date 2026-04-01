import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/models/invoice.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';

const String _kErpBaseUrl = 'http://10.91.193.223:8000';
const String _kErpApiKey  = 'erp-secret-key-2024';

/// Incrémenter après une vente pour rafraîchir la liste.
final salesRefreshProvider = StateProvider<int>((ref) => 0);

/// Charge les ventes depuis l'ERP FastAPI (non autoDispose → liste persistante)
final invoicesListProvider = FutureProvider<List<Invoice>>((ref) async {
  ref.watch(salesRefreshProvider); // se rafraîchit après chaque vente
  final auth = ref.watch(authProvider);
  if (auth == null) return [];

  try {
    final res = await http.get(
      Uri.parse('$_kErpBaseUrl/api/sales'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': _kErpApiKey,
      },
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      final sales = data
          .map((e) => _erpSaleToInvoice(e as Map<String, dynamic>, auth.companyId))
          .toList();
      // Plus récentes en premier
      sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sales;
    }
    return [];
  } catch (_) {
    // Fallback sur les factures locales si ERP injoignable
    return ref.read(invoicesRepositoryProvider).listForCompany(auth.companyId);
  }
});

/// Convertit une vente ERP → Invoice Flutter
Invoice _erpSaleToInvoice(Map<String, dynamic> sale, String companyId) {
  final items = (sale['items'] as List? ?? []);
  final lines = items.map((item) {
    final m = item as Map<String, dynamic>;
    return InvoiceLine(
      productId: m['product_id']?.toString() ?? '',
      name: m['product_name']?.toString() ?? m['name']?.toString() ?? 'Produit',
      unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
      quantity: (m['quantity'] as num?)?.toInt() ?? 1,
    );
  }).toList();

  return Invoice(
    id: sale['id']?.toString() ?? '',
    companyId: companyId,
    createdAt: DateTime.tryParse(sale['created_at']?.toString() ?? '') ?? DateTime.now(),
    lines: lines,
  );
}
