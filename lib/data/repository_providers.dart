import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/product_image_service.dart';
import 'erp_products_repository.dart';
import 'invoices_repository.dart';
import 'product_extras_repository.dart';
import 'products_repository.dart';
import 'products_repository_with_extras.dart';

final productImageServiceProvider = Provider<ProductImageService>((ref) {
  return ProductImageService();
});

final productExtrasRepositoryProvider = Provider<ProductExtrasRepository>((ref) {
  return ProductExtrasRepository();
});

final erpProductsRepositoryProvider = Provider<ErpProductsRepository>((ref) {
  return ErpProductsRepository(ref: ref);
});

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final delegate = ref.watch(erpProductsRepositoryProvider);
  final extras = ref.watch(productExtrasRepositoryProvider);
  return ProductsRepositoryWithExtras(delegate, extras);
});

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref: ref);
});
