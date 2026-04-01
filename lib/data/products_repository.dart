import '../core/models/product.dart';

/// Accès aux produits — toutes les opérations sont scoppées par [companyId] (multi-tenant).
abstract class ProductsRepository {
  Future<List<Product>> listProducts(String companyId);
  Future<ProductsPage> listProductsPage({
    required String companyId,
    required int limit,
    String? startAfterName,
    String? startAfterId,
  });
  Future<Product?> getById(String companyId, String productId);
  Future<Product?> getBySku(String companyId, String sku);
  Future<Product?> getByConsumerCode(String companyId, String consumerCode);
  Future<Product> upsert(Product product);
  Future<void> bulkUpsert(String companyId, List<Product> products);
  Future<void> delete(String companyId, String productId);
  Future<Product?> decrementStock(String companyId, String productId, int quantity);
}

class ProductsPage {
  const ProductsPage({required this.items, required this.nextCursor});

  final List<Product> items;
  final ProductsCursor? nextCursor;
}

class ProductsCursor {
  const ProductsCursor({required this.name, required this.id});

  final String name;
  final String id;
}
