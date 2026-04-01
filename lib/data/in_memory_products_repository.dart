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
    final all = await listProducts(companyId);
    var startIndex = 0;
    if (startAfterName != null && startAfterId != null) {
      startIndex = all.indexWhere((p) => p.name == startAfterName && p.id == startAfterId);
      if (startIndex >= 0) startIndex++;
      if (startIndex < 0) startIndex = 0;
    }
    final slice = all.skip(startIndex).take(limit).toList();
    final next = slice.isEmpty
        ? null
        : (startIndex + slice.length >= all.length)
            ? null
            : ProductsCursor(name: slice.last.name, id: slice.last.id);
    return ProductsPage(items: slice, nextCursor: next);
  }

  @override
  Future<Product?> getById(String companyId, String productId) async {
    return _byKey[_key(companyId, productId)];
  }

  @override
  Future<Product?> getBySku(String companyId, String sku) async {
    final s = sku.trim();
    if (s.isEmpty) return null;
    for (final p in _byKey.values) {
      if (p.companyId == companyId && (p.sku ?? '') == s) return p;
    }
    return null;
  }

  @override
  Future<Product?> getByConsumerCode(String companyId, String consumerCode) async {
    final c = consumerCode.trim();
    if (c.isEmpty) return null;
    for (final p in _byKey.values) {
      if (p.companyId == companyId && (p.consumerCode ?? '') == c) return p;
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
    for (final p in products) {
      if (p.companyId != companyId) continue;
      final sku = (p.sku ?? '').trim();
      if (sku.isNotEmpty) {
        // Update "après import": retrouver le produit existant via SKU,
        // puis mettre à jour l'image (path/hash), stock/prix, etc.
        final existing = _byKey.values.cast<Product?>().firstWhere(
              (x) => x != null && x.companyId == companyId && (x.sku ?? '') == sku,
              orElse: () => null,
            );
        if (existing != null) {
          await upsert(
            existing.copyWith(
              name: p.name,
              price: p.price,
              stock: p.stock,
              description: p.description,
              referenceImagePath: p.referenceImagePath ?? existing.referenceImagePath,
              referenceImageUrl: p.referenceImageUrl ?? existing.referenceImageUrl,
              referenceImageHash: p.referenceImageHash ?? existing.referenceImageHash,
              consumerCode: p.consumerCode ?? existing.consumerCode,
            ),
          );
          continue;
        }
      }

      await upsert(p);
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
