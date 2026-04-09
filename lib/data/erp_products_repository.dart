/// erp_products_repository.dart — v2.0
/// Charge et synchronise les produits avec l'ERP FastAPI via JWT Bearer.
/// Plus d'API Key hardcodée — le token est injecté à chaque requête.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tpe_qr_saas/core/config/erp_config.dart';

import '../core/models/product.dart';
import '../features/auth/auth_provider.dart';
import 'products_repository.dart';

class ErpProductsRepository implements ProductsRepository {
  ErpProductsRepository({
    required this.ref,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;
  final Map<String, Product> _cache = {};

  // ── Headers JWT dynamiques — lus depuis le provider à chaque requête ─────
  Map<String, String> get _headers {
    final auth = ref.read(authProvider);
    if (auth == null) return {'Content-Type': 'application/json'};
    return auth.authHeaders;
  }

  String get _base => kErpBaseUrl;

  // ── Conversion ERP → Flutter ──────────────────────────────────────────────
  Product _fromErpJson(Map<String, dynamic> json, String companyId) {
    final imageUrl = (json['image_url'] as String?)?.trim();
    final referenceImageUrl = (json['reference_image_url'] as String?)?.trim();
    return Product(
      id:                   json['id']          as String,
      companyId:            companyId,
      name:                 json['name']         as String,
      price:                (json['price']       as num).toDouble(),
      stock:                (json['stock']       as num).toInt(),
      sku:                  json['sku']          as String?,
      description:          json['description']  as String?,
      referenceImagePath:   null,
      referenceImageUrl:    referenceImageUrl != null && referenceImageUrl.isNotEmpty
          ? referenceImageUrl
          : imageUrl,
      referenceImageHash:   json['reference_image_hash'] as String?,
      consumerCode:         json['consumer_code'] as String?,
    );
  }

  Map<String, dynamic> _toErpJson(Product p) => {
        'name':        p.name,
        'price':       p.price,
        'stock':       p.stock,
        'sku':         p.sku,
        'description': p.description,
      };

  // ── Gestion 401 → refresh automatique ────────────────────────────────────
  Future<http.Response> _getWithRetry(Uri uri) async {
    var res = await _client.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) res = await _client.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
    }
    return res;
  }

  Future<http.Response> _postWithRetry(Uri uri, String body) async {
    var res = await _client.post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) res = await _client.post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 8));
    }
    return res;
  }

  Future<http.Response> _putWithRetry(Uri uri, String body) async {
    var res = await _client.put(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) res = await _client.put(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 8));
    }
    return res;
  }

  Future<http.Response> _patchWithRetry(Uri uri, String body) async {
    var res = await _client.patch(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) res = await _client.patch(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 8));
    }
    return res;
  }

  Future<http.Response> _deleteWithRetry(Uri uri) async {
    var res = await _client.delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) res = await _client.delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
    }
    return res;
  }

  Future<Product> uploadProductImage({
    required String companyId,
    required String productId,
    required String sourcePath,
    String? referenceImageHash,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/api/products/$productId/image'),
    );
    request.headers.addAll({
      'Authorization': _headers['Authorization'] ?? '',
    });
    request.files.add(await http.MultipartFile.fromPath('file', sourcePath));

    var streamed = await request.send().timeout(const Duration(seconds: 20));
    if (streamed.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        request = http.MultipartRequest(
          'POST',
          Uri.parse('$_base/api/products/$productId/image'),
        );
        request.headers.addAll({
          'Authorization': _headers['Authorization'] ?? '',
        });
        request.files.add(await http.MultipartFile.fromPath('file', sourcePath));
        streamed = await request.send().timeout(const Duration(seconds: 20));
      }
    }

    final uploadResponse = await http.Response.fromStream(streamed);
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception('Upload image ERP impossible (${uploadResponse.statusCode})');
    }

    final uploadJson = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
    final remoteImageUrl = uploadJson['image_url'] as String?;
    final patchBody = jsonEncode({
      'reference_image_url': remoteImageUrl,
      'reference_image_hash': referenceImageHash,
    });
    final patchResponse = await _patchWithRetry(
      Uri.parse('$_base/api/products/$productId/image'),
      patchBody,
    );
    if (patchResponse.statusCode < 200 || patchResponse.statusCode >= 300) {
      throw Exception('Mise à jour image ERP impossible (${patchResponse.statusCode})');
    }

    final updated = _fromErpJson(
      jsonDecode(patchResponse.body) as Map<String, dynamic>,
      companyId,
    );
    _cache[updated.id] = updated;
    return updated;
  }

  // ─── LIST ─────────────────────────────────────────────────────────────────
  @override
  Future<List<Product>> listProducts(String companyId) async {
    try {
      final res = await _getWithRetry(Uri.parse('$_base/api/products'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final products = data
            .map((e) => _fromErpJson(e as Map<String, dynamic>, companyId))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _cache
          ..clear()
          ..addAll({for (final p in products) p.id: p});
        return products;
      }
      if (res.statusCode == 402) {
        throw Exception('Quota dépassé. Passez à un plan supérieur.');
      }
      throw Exception('ERP HTTP ${res.statusCode}');
    } catch (e) {
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
    final all = await listProducts(companyId);
    var start = 0;
    if (startAfterName != null && startAfterId != null) {
      start = all.indexWhere(
          (p) => p.name == startAfterName && p.id == startAfterId);
      if (start >= 0) start++;
      if (start < 0) start = 0;
    }
    final slice = all.skip(start).take(limit).toList();
    final next = slice.isEmpty || start + slice.length >= all.length
        ? null
        : ProductsCursor(name: slice.last.name, id: slice.last.id);
    return ProductsPage(items: slice, nextCursor: next);
  }

  // ─── GET ──────────────────────────────────────────────────────────────────
  @override
  Future<Product?> getById(String companyId, String productId) async {
    try {
      final res = await _getWithRetry(
          Uri.parse('$_base/api/products/$productId'));
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
    return (await listProducts(companyId))
        .cast<Product?>()
        .firstWhere((p) => (p!.sku ?? '') == s, orElse: () => null);
  }

  @override
  Future<Product?> getByConsumerCode(
      String companyId, String consumerCode) async {
    final c = consumerCode.trim();
    if (c.isEmpty) return null;
    for (final p in _cache.values) {
      if (p.companyId == companyId && (p.consumerCode ?? '') == c) return p;
    }
    return (await listProducts(companyId))
        .cast<Product?>()
        .firstWhere((p) => (p!.consumerCode ?? '') == c, orElse: () => null);
  }

  // ─── UPSERT ───────────────────────────────────────────────────────────────
  @override
  Future<Product> upsert(Product product) async {
    final body = jsonEncode(_toErpJson(product));
    final http.Response res;

    if (product.id.isEmpty) {
      res = await _postWithRetry(Uri.parse('$_base/api/products'), body);
    } else {
      res = await _putWithRetry(
          Uri.parse('$_base/api/products/${product.id}'), body);
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      final saved = _fromErpJson(
          jsonDecode(res.body) as Map<String, dynamic>, product.companyId);
      _cache[saved.id] = saved;
      return saved;
    }
    if (res.statusCode == 402) {
      throw Exception('Quota produits dépassé. Passez à un plan supérieur.');
    }
    throw Exception('ERP upsert ${res.statusCode}: ${res.body}');
  }

  @override
  Future<void> bulkUpsert(String companyId, List<Product> products) async {
    for (final p in products) {
      await upsert(p.copyWith(companyId: companyId));
    }
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────
  @override
  Future<void> delete(String companyId, String productId) async {
    final res = await _deleteWithRetry(
        Uri.parse('$_base/api/products/$productId'));
    if (res.statusCode == 200) {
      _cache.remove(productId);
    } else {
      throw Exception('ERP delete ${res.statusCode}');
    }
  }

  // ─── DECREMENT STOCK ──────────────────────────────────────────────────────
  @override
  Future<Product?> decrementStock(
      String companyId, String productId, int quantity) async {
    try {
      final res = await _patchWithRetry(
        Uri.parse('$_base/api/products/$productId/stock'),
        jsonEncode({'delta': -quantity, 'reason': 'sale'}),
      );
      if (res.statusCode == 200) {
        final updated = _fromErpJson(
            jsonDecode(res.body) as Map<String, dynamic>, companyId);
        _cache[updated.id] = updated;
        return updated;
      }
      // Fallback cache local si API refuse
      final cached = _cache[productId];
      if (cached == null || cached.stock < quantity) return null;
      final updated = cached.copyWith(stock: cached.stock - quantity);
      _cache[productId] = updated;
      return updated;
    } catch (_) {
      final cached = _cache[productId];
      if (cached == null || cached.stock < quantity) return null;
      final updated = cached.copyWith(stock: cached.stock - quantity);
      _cache[productId] = updated;
      return updated;
    }
  }
}

