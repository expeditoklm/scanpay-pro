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
  Future<Product?> getById(String companyId, String productId) async {
    return _byKey[_key(companyId, productId)];
  }

  @override
  Future<Product> upsert(Product product) async {
    final id = product.id.isEmpty ? _uuid.v4() : product.id;
    final saved = product.copyWith(id: id);
    _byKey[_key(saved.companyId, saved.id)] = saved;
    return saved;
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
