import 'package:uuid/uuid.dart';

import '../core/models/product.dart';
import 'products_repository.dart';

/// Dépôt mémoire pour tests sur téléphone sans Firebase.
/// Pour la prod, remplacer par Firestore avec chemins `companies/{companyId}/products/...`.
class InMemoryProductsRepository implements ProductsRepository {
  final Map<String, Product> _byKey = {};
  final _uuid = const Uuid();

  String _key(String companyId, String productId) => '$companyId::$productId';

  @override
  Future<List<Product>> listProducts(String companyId) async {
    return _byKey.values.where((p) => p.companyId == companyId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<ProductsPage> listProductsPage({
    required String companyId,
    required int limit,
    String? startAfterName,
    String? startAfterId,
  }) async {
    final items = await listProducts(companyId);
    var start = 0;
    if (startAfterName != null && startAfterId != null) {
      final index = items.indexWhere(
        (product) => product.name == startAfterName && product.id == startAfterId,
      );
      start = index >= 0 ? index + 1 : 0;
    }
    final slice = items.skip(start).take(limit).toList();
    return ProductsPage(
      items: slice,
      nextCursor: slice.length < limit
          ? null
          : ProductsCursor(name: slice.last.name, id: slice.last.id),
    );
  }

  @override
  Future<Product?> getById(String companyId, String productId) async {
    return _byKey[_key(companyId, productId)];
  }

  @override
  Future<Product?> getBySku(String companyId, String sku) async {
    final products = await listProducts(companyId);
    for (final product in products) {
      if ((product.sku ?? '') == sku) return product;
    }
    return null;
  }

  @override
  Future<Product?> getByConsumerCode(String companyId, String consumerCode) async {
    final products = await listProducts(companyId);
    for (final product in products) {
      if ((product.consumerCode ?? '') == consumerCode) return product;
    }
    return null;
  }

  @override
  Future<Product> upsert(Product product) async {
    final id = product.id.isEmpty ? _uuid.v4() : product.id;
    final saved = product.copyWith(id: id);
    _byKey[_key(saved.companyId, saved.id)] = saved;
    return saved;
  }

  @override
  Future<void> bulkUpsert(String companyId, List<Product> products) async {
    for (final product in products) {
      await upsert(product.copyWith(companyId: companyId));
    }
  }

  @override
  Future<void> delete(String companyId, String productId) async {
    _byKey.remove(_key(companyId, productId));
  }

  @override
  Future<Product?> decrementStock(String companyId, String productId, int quantity) async {
    final p = await getById(companyId, productId);
    if (p == null) return null;
    if (p.stock < quantity) return null;
    final updated = p.copyWith(stock: p.stock - quantity);
    _byKey[_key(companyId, productId)] = updated;
    return updated;
  }
}
