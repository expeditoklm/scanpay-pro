// lib/data/erp_products_repository.dart
//
// Dépôt qui charge les produits depuis l'ERP FastAPI.
// Remplace InMemoryProductsRepository pour avoir les vrais produits.

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/models/product.dart';
import 'products_repository.dart';

// ── Configuration ERP (même que external_stock_sync.dart) ──────────────────
const String _kErpBaseUrl = 'http://10.91.193.223:8000';
const String _kErpApiKey  = 'erp-secret-key-2024';

class ErpProductsRepository implements ProductsRepository {
  ErpProductsRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  // Cache local pour éviter trop d'appels réseau
  final Map<String, Product> _cache = {};

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': _kErpApiKey,
      };

  // ── Convertir un produit ERP → modèle Flutter ────────────────────────────
  Product _fromErpJson(Map<String, dynamic> json, String companyId) {
    return Product(
      id: json['id'] as String,
      companyId: companyId,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: (json['stock'] as num).toInt(),
      sku: json['sku'] as String?,
      description: json['description'] as String?,
    );
  }

  // ── Convertir un produit Flutter → payload ERP ───────────────────────────
  Map<String, dynamic> _toErpJson(Product p) => {
        'name': p.name,
        'price': p.price,
        'stock': p.stock,
        'sku': p.sku,
        'description': p.description,
      };

  // ── LIST ──────────────────────────────────────────────────────────────────
  @override
  Future<List<Product>> listProducts(String companyId) async {
    try {
      final res = await _client
          .get(Uri.parse('$_kErpBaseUrl/api/products'), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final products = data
            .map((e) => _fromErpJson(e as Map<String, dynamic>, companyId))
            .toList();

        // Mettre à jour le cache
        _cache.clear();
        for (final p in products) {
          _cache[p.id] = p;
        }
        return products..sort((a, b) => a.name.compareTo(b.name));
      }
      throw Exception('ERP HTTP ${res.statusCode}');
    } catch (e) {
      // En cas d'erreur réseau → retourner le cache si disponible
      if (_cache.isNotEmpty) {
        return _cache.values
            .where((p) => p.companyId == companyId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
      rethrow;
    }
  }

  @override
  Future<ProductsPage> listProductsPage({
    required String companyId,
    required int limit,
    String? startAfterName,
    String? startAfterId,
  }) async {
    // ERP actuel: pas d’endpoint pagination → fallback en mémoire.
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

  // ── GET BY ID ─────────────────────────────────────────────────────────────
  @override
  Future<Product?> getById(String companyId, String productId) async {
    try {
      final res = await _client
          .get(Uri.parse('$_kErpBaseUrl/api/products/$productId'),
              headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final p = _fromErpJson(
            jsonDecode(res.body) as Map<String, dynamic>, companyId);
        _cache[p.id] = p;
        return p;
      }
      if (res.statusCode == 404) return null;
      throw Exception('ERP HTTP ${res.statusCode}');
    } catch (_) {
      return _cache[productId];
    }
  }

  @override
  Future<Product?> getBySku(String companyId, String sku) async {
    final s = sku.trim();
    if (s.isEmpty) return null;
    for (final p in _cache.values) {
      if (p.companyId == companyId && (p.sku ?? '') == s) return p;
    }
    final all = await listProducts(companyId);
    for (final p in all) {
      if ((p.sku ?? '') == s) return p;
    }
    return null;
  }

  @override
  Future<Product?> getByConsumerCode(String companyId, String consumerCode) async {
    final c = consumerCode.trim();
    if (c.isEmpty) return null;
    for (final p in _cache.values) {
      if (p.companyId == companyId && (p.consumerCode ?? '') == c) return p;
    }
    final all = await listProducts(companyId);
    for (final p in all) {
      if ((p.consumerCode ?? '') == c) return p;
    }
    return null;
  }

  // ── UPSERT (créer ou modifier) ────────────────────────────────────────────
  @override
  Future<Product> upsert(Product product) async {
    final isNew = product.id.isEmpty;
    final http.Response res;

    if (isNew) {
      // Création
      res = await _client
          .post(
            Uri.parse('$_kErpBaseUrl/api/products'),
            headers: _headers,
            body: jsonEncode(_toErpJson(product)),
          )
          .timeout(const Duration(seconds: 5));
    } else {
      // Mise à jour
      res = await _client
          .put(
            Uri.parse('$_kErpBaseUrl/api/products/${product.id}'),
            headers: _headers,
            body: jsonEncode(_toErpJson(product)),
          )
          .timeout(const Duration(seconds: 5));
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      final saved = _fromErpJson(
          jsonDecode(res.body) as Map<String, dynamic>, product.companyId);
      _cache[saved.id] = saved;
      return saved;
    }
    throw Exception('ERP upsert error ${res.statusCode}: ${res.body}');
  }

  // ── BULK UPSERT ───────────────────────────────────────────────────────────
  @override
  Future<void> bulkUpsert(String companyId, List<Product> products) async {
    for (final p in products) {
      await upsert(p.copyWith(companyId: companyId));
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  @override
  Future<void> delete(String companyId, String productId) async {
    final res = await _client
        .delete(Uri.parse('$_kErpBaseUrl/api/products/$productId'),
            headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      _cache.remove(productId);
    } else {
      throw Exception('ERP delete error ${res.statusCode}');
    }
  }

  // ── DECREMENT STOCK ───────────────────────────────────────────────────────
  @override
  Future<Product?> decrementStock(
      String companyId, String productId, int quantity) async {
    try {
      final res = await _client
          .patch(
            Uri.parse('$_kErpBaseUrl/api/products/$productId/stock'),
            headers: _headers,
            body: jsonEncode({'delta': -quantity, 'reason': 'sale'}),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final updated = _fromErpJson(
            jsonDecode(res.body) as Map<String, dynamic>, companyId);
        _cache[updated.id] = updated;
        return updated;
      }
      // Si l'ERP refuse (ex: stock déjà 0), on utilise le cache local
      // pour ne pas bloquer la vente
      final cached = _cache[productId];
      if (cached == null) return null;
      if (cached.stock < quantity) return null; // vraiment insuffisant
      final updated = cached.copyWith(stock: cached.stock - quantity);
      _cache[productId] = updated;
      return updated;
    } catch (_) {
      // Réseau coupé → décrémenter dans le cache local
      final cached = _cache[productId];
      if (cached == null || cached.stock < quantity) return null;
      final updated = cached.copyWith(stock: cached.stock - quantity);
      _cache[productId] = updated;
      return updated;
    }
  }
}
