import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProductExtras {
  const ProductExtras({
    required this.referenceImagePath,
    required this.referenceImageHash,
  });

  final String? referenceImagePath;
  final String? referenceImageHash;

  Map<String, dynamic> toJson() => {
        'referenceImagePath': referenceImagePath,
        'referenceImageHash': referenceImageHash,
      };

  factory ProductExtras.fromJson(Map<String, dynamic> json) {
    return ProductExtras(
      referenceImagePath: json['referenceImagePath'] as String?,
      referenceImageHash: json['referenceImageHash'] as String?,
    );
  }
}

/// Stockage local des "extras" produit (image référence + hash).
/// Utile quand les produits viennent d’un ERP qui ne stocke pas ces champs.
class ProductExtrasRepository {
  static const _kPrefix = 'product_extras::';

  Future<ProductExtras?> get({
    required String companyId,
    required String productId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$companyId::$productId');
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
      '$_kPrefix$companyId::$productId',
      jsonEncode(extras.toJson()),
    );
  }
}

