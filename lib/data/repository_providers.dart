import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/external_stock_sync.dart';
import 'erp_products_repository.dart';
import 'invoices_repository.dart';
import 'products_repository.dart';

// ── Utilise ErpProductsRepository → charge les produits depuis FastAPI ──────
final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ErpProductsRepository();
});

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  final products = ref.watch(productsRepositoryProvider);
  return InvoicesRepository(products);
});

final externalStockSyncProvider = Provider<ExternalStockSync>((ref) {
  return HttpExternalStockSync();
});
