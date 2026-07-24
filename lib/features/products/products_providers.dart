import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/product.dart';
import '../../data/offline_storage.dart';
import '../../data/repository_providers.dart';
import '../../data/products_repository.dart';
import '../auth/auth_provider.dart';

class ProductsPageRequest {
  const ProductsPageRequest(
      {required this.page, this.query = '', this.perPage = 20});

  final int page;
  final String query;
  final int perPage;

  @override
  bool operator ==(Object other) =>
      other is ProductsPageRequest &&
      other.page == page &&
      other.query == query &&
      other.perPage == perPage;

  @override
  int get hashCode => Object.hash(page, query, perPage);
}

/// Page de produits récupérée directement depuis l'API, jamais toute la liste.
final productsPageProvider =
    FutureProvider.family<ProductsPage, ProductsPageRequest>(
        (ref, request) async {
  final auth = ref.watch(authProvider);
  if (auth == null) {
    return const ProductsPage(
        items: [], page: 1, perPage: 20, total: 0, totalPages: 1);
  }
  return ref.watch(productsRepositoryProvider).listProductsPage(
        companyId: auth.companyId,
        page: request.page,
        perPage: request.perPage,
        query: request.query,
      );
});

/// Provider produits — PAS autoDispose pour survivre au changement d'onglet.
/// Fallback garanti sur le cache local en cas d'erreur réseau.
final productsListProvider = FutureProvider<List<Product>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth == null) return [];

  final repo = ref.watch(productsRepositoryProvider);

  try {
    return await repo.listProducts(auth.companyId);
  } catch (_) {
    // Réseau mort → lecture directe du cache persisté sur disque
    final cached = await OfflineStorage().loadProducts(auth.companyId);
    if (cached.isNotEmpty) return cached;
    // Cache vide → on remonte pour afficher le message hors-ligne
    rethrow;
  }
});
