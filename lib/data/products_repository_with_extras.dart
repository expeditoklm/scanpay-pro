import '../core/models/product.dart';
import 'product_extras_repository.dart';
import 'products_repository.dart';

/// Decorateur qui reapplique les extras locaux (image de reference + hash).
class ProductsRepositoryWithExtras implements ProductsRepository {
  ProductsRepositoryWithExtras(this._delegate, this._extras);

  final ProductsRepository _delegate;
  final ProductExtrasRepository _extras;

  Future<Product> _apply(Product product) async {
    final extras = await _extras.get(
      companyId: product.companyId,
      productId: product.id,
    );
    if (extras == null) return product;
    return product.copyWith(
      referenceImagePath: extras.referenceImagePath ?? product.referenceImagePath,
      referenceImageHash: extras.referenceImageHash ?? product.referenceImageHash,
    );
  }

  Future<List<Product>> _applyList(List<Product> products) async {
    final out = <Product>[];
    for (final product in products) {
      out.add(await _apply(product));
    }
    return out;
  }

  @override
  Future<List<Product>> listProducts(String companyId) async {
    final items = await _delegate.listProducts(companyId);
    return _applyList(items);
  }

  @override
  Future<ProductsPage> listProductsPage({
    required String companyId,
    required int page,
    required int perPage,
    String query = '',
  }) async {
    final remotePage = await _delegate.listProductsPage(
      companyId: companyId,
      page: page,
      perPage: perPage,
      query: query,
    );
    return ProductsPage(
      items: await _applyList(remotePage.items),
      page: remotePage.page,
      perPage: remotePage.perPage,
      total: remotePage.total,
      totalPages: remotePage.totalPages,
    );
  }

  @override
  Future<Product?> getById(String companyId, String productId) async {
    final product = await _delegate.getById(companyId, productId);
    if (product == null) return null;
    return _apply(product);
  }

  @override
  Future<Product?> getBySku(String companyId, String sku) async {
    final product = await _delegate.getBySku(companyId, sku);
    if (product == null) return null;
    return _apply(product);
  }

  @override
  Future<Product?> getByConsumerCode(String companyId, String consumerCode) async {
    final product = await _delegate.getByConsumerCode(companyId, consumerCode);
    if (product == null) return null;
    return _apply(product);
  }

  @override
  Future<Product> upsert(Product product) async {
    final saved = await _delegate.upsert(product);
    if (product.referenceImagePath != null || product.referenceImageHash != null) {
      final existing = await _extras.get(
        companyId: saved.companyId,
        productId: saved.id,
      );
      await _extras.set(
        companyId: saved.companyId,
        productId: saved.id,
        extras: ProductExtras(
          referenceImagePath: product.referenceImagePath,
          referenceImageHash: product.referenceImageHash,
          pendingUpload: existing?.pendingUpload ?? false,
        ),
      );
    }
    return _apply(saved);
  }

  @override
  Future<void> bulkUpsert(String companyId, List<Product> products) async {
    await _delegate.bulkUpsert(companyId, products);
  }

  @override
  Future<void> delete(String companyId, String productId) =>
      _delegate.delete(companyId, productId);

  @override
  Future<Product?> decrementStock(
    String companyId,
    String productId,
    int quantity,
  ) =>
      _delegate.decrementStock(companyId, productId, quantity);
}
