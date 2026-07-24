import '../core/models/product.dart';

class ProductsPage {
  const ProductsPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<Product> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

abstract class ProductsRepository {
  Future<List<Product>> listProducts(String companyId);
  Future<ProductsPage> listProductsPage({
    required String companyId,
    required int page,
    required int perPage,
    String query = '',
  });
  Future<Product?> getById(String companyId, String productId);
  Future<Product?> getBySku(String companyId, String sku);
  Future<Product?> getByConsumerCode(String companyId, String consumerCode);
  Future<Product> upsert(Product product);
  Future<void> bulkUpsert(String companyId, List<Product> products);
  Future<void> delete(String companyId, String productId);
  Future<Product?> decrementStock(
      String companyId, String productId, int quantity);
}
