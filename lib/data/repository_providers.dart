import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/external_stock_sync.dart';
import '../core/services/product_image_service.dart';
import 'erp_products_repository.dart';
import 'invoices_repository.dart';
import 'product_extras_repository.dart';
import 'products_repository.dart';
import 'products_repository_with_extras.dart';

// ── Utilise ErpProductsRepository → charge les produits depuis FastAPI ──────
final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final base = ErpProductsRepository();
  final extras = ref.watch(productExtrasRepositoryProvider);
  return ProductsRepositoryWithExtras(base, extras);
});

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  final products = ref.watch(productsRepositoryProvider);
  return InvoicesRepository(products);
});

final externalStockSyncProvider = Provider<ExternalStockSync>((ref) {
  return HttpExternalStockSync();
});

final productExtrasRepositoryProvider = Provider<ProductExtrasRepository>((ref) {
  return ProductExtrasRepository();
});

final productImageServiceProvider = Provider<ProductImageService>((ref) {
  return ProductImageService();
});
