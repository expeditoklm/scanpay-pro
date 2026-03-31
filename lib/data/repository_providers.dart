import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'in_memory_products_repository.dart';
import 'invoices_repository.dart';
import 'products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return InMemoryProductsRepository();
});

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  final products = ref.watch(productsRepositoryProvider);
  return InvoicesRepository(products);
});
