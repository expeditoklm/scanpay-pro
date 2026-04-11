import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProductExtras {
  const ProductExtras({
    required this.referenceImagePath,
    required this.referenceImageHash,
    this.pendingUpload = false,
  });

  final String? referenceImagePath;
  final String? referenceImageHash;
  final bool pendingUpload;

  Map<String, dynamic> toJson() => {
        'referenceImagePath': referenceImagePath,
        'referenceImageHash': referenceImageHash,
        'pendingUpload': pendingUpload,
      };

  factory ProductExtras.fromJson(Map<String, dynamic> json) {
    return ProductExtras(
      referenceImagePath: json['referenceImagePath'] as String?,
      referenceImageHash: json['referenceImageHash'] as String?,
      pendingUpload: json['pendingUpload'] as bool? ?? false,
    );
  }
}

/// Stockage local des "extras" produit (image référence + hash).
/// Utile quand les produits viennent d’un ERP qui ne stocke pas ces champs.
class ProductExtrasRepository {
  static const _kPrefix = 'product_extras::';

  String _key(String companyId, String productId) => '$_kPrefix$companyId::$productId';

  Future<ProductExtras?> get({
    required String companyId,
    required String productId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(companyId, productId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ProductExtras.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> set({
    required String companyId,
    required String productId,
    required ProductExtras extras,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(companyId, productId),
      jsonEncode(extras.toJson()),
    );
  }

  Future<void> remove({
    required String companyId,
    required String productId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(companyId, productId));
  }

  Future<void> move({
    required String companyId,
    required String fromProductId,
    required String toProductId,
  }) async {
    if (fromProductId == toProductId) return;
    final existing = await get(companyId: companyId, productId: fromProductId);
    if (existing == null) return;
    await set(companyId: companyId, productId: toProductId, extras: existing);
    await remove(companyId: companyId, productId: fromProductId);
  }

  Future<void> markUploadSynced({
    required String companyId,
    required String productId,
  }) async {
    final existing = await get(companyId: companyId, productId: productId);
    if (existing == null) return;
    await set(
      companyId: companyId,
      productId: productId,
      extras: ProductExtras(
        referenceImagePath: existing.referenceImagePath,
        referenceImageHash: existing.referenceImageHash,
        pendingUpload: false,
      ),
    );
  }

  Future<Map<String, ProductExtras>> listPendingUploads({
    required String companyId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_kPrefix$companyId::';
    final pending = <String, ProductExtras>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        final extras = ProductExtras.fromJson(decoded);
        if (!extras.pendingUpload) continue;
        final productId = key.substring(prefix.length);
        pending[productId] = extras;
      } catch (_) {
        continue;
      }
    }
    return pending;
  }
}

