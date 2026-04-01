import '../core/models/product.dart';

/// Accès aux produits — toutes les opérations sont scoppées par [companyId] (multi-tenant).
abstract class ProductsRepository {
  Future<List<Product>> listProducts(String companyId);
  Future<Product?> getById(String companyId, String productId);
  Future<Product> upsert(Product product);
  Future<void> bulkUpsert(String companyId, List<Product> products);
  Future<void> delete(String companyId, String productId);
  Future<Product?> decrementStock(String companyId, String productId, int quantity);
}
