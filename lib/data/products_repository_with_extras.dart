import '../core/models/product.dart';
import 'product_extras_repository.dart';
import 'products_repository.dart';

/// Décorateur qui ré-applique les extras (image référence + hash) depuis le stockage local.
class ProductsRepositoryWithExtras implements ProductsRepository {
  ProductsRepositoryWithExtras(this._delegate, this._extras);

  final ProductsRepository _delegate;
  final ProductExtrasRepository _extras;

  Future<Product> _apply(Product p) async {
    final ex = await _extras.get(companyId: p.companyId, productId: p.id);
    if (ex == null) return p;
    return p.copyWith(
      referenceImagePath: ex.referenceImagePath ?? p.referenceImagePath,
      referenceImageHash: ex.referenceImageHash ?? p.referenceImageHash,
    );
  }

  Future<List<Product>> _applyList(List<Product> list) async {
    final out = <Product>[];
    for (final p in list) {
      out.add(await _apply(p));
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
    required int limit,
    String? startAfterName,
    String? startAfterId,
  }) async {
    final page = await _delegate.listProductsPage(
      companyId: companyId,
      limit: limit,
      startAfterName: startAfterName,
      startAfterId: startAfterId,
    );
    return ProductsPage(items: await _applyList(page.items), nextCursor: page.nextCursor);
  }

  @override
  Future<Product?> getById(String companyId, String productId) async {
    final p = await _delegate.getById(companyId, productId);
    if (p == null) return null;
    return _apply(p);
  }

  @override
  Future<Product?> getBySku(String companyId, String sku) async {
    final p = await _delegate.getBySku(companyId, sku);
    if (p == null) return null;
    return _apply(p);
  }

  @override
  Future<Product?> getByConsumerCode(String companyId, String consumerCode) async {
    final p = await _delegate.getByConsumerCode(companyId, consumerCode);
    if (p == null) return null;
    return _apply(p);
  }

  @override
  Future<Product> upsert(Product product) async {
    // Si l’utilisateur a défini une image, on sauvegarde l’extra localement.
    if (product.referenceImagePath != null || product.referenceImageHash != null) {
      await _extras.set(
        companyId: product.companyId,
        productId: product.id,
        extras: ProductExtras(
          referenceImagePath: product.referenceImagePath,
          referenceImageHash: product.referenceImageHash,
        ),
      );
    }
    final saved = await _delegate.upsert(product);
    return _apply(saved);
  }

  @override
  Future<void> bulkUpsert(String companyId, List<Product> products) async {
    // On laisse le délégué gérer la création/maj; les extras se géreront via upsert individuel si besoin.
    await _delegate.bulkUpsert(companyId, products);
  }

  @override
  Future<void> delete(String companyId, String productId) => _delegate.delete(companyId, productId);

  @override
  Future<Product?> decrementStock(String companyId, String productId, int quantity) =>
      _delegate.decrementStock(companyId, productId, quantity);
}

