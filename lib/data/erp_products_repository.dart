/// erp_products_repository.dart — v3.0
/// Synchronisation ERP + persistance locale + file d'attente offline.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tpe_qr_saas/core/config/erp_config.dart';
import 'package:uuid/uuid.dart';

import '../core/models/product.dart';
import '../features/auth/auth_provider.dart';
import 'offline_storage.dart';
import 'product_extras_repository.dart';
import 'products_repository.dart';

class ErpProductsRepository implements ProductsRepository {
  ErpProductsRepository({
    required this.ref,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;
  final Map<String, Product> _cache = {};
  final OfflineStorage _offlineStorage = OfflineStorage();
  final ProductExtrasRepository _productExtrasRepository = ProductExtrasRepository();
  final Uuid _uuid = const Uuid();

  Map<String, String> get _headers {
    final auth = ref.read(authProvider);
    if (auth == null) return {'Content-Type': 'application/json'};
    return auth.authHeaders;
  }

  String get _base => kErpBaseUrl;

  Product _fromErpJson(Map<String, dynamic> json, String companyId) {
    final imageUrl = (json['image_url'] as String?)?.trim();
    final referenceImageUrl = (json['reference_image_url'] as String?)?.trim();
    return Product(
      id: json['id'] as String,
      companyId: companyId,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: (json['stock'] as num).toInt(),
      sku: json['sku'] as String?,
      description: json['description'] as String?,
      referenceImagePath: null,
      referenceImageUrl: referenceImageUrl != null && referenceImageUrl.isNotEmpty
          ? referenceImageUrl
          : imageUrl,
      referenceImageHash: json['reference_image_hash'] as String?,
      consumerCode: json['consumer_code'] as String?,
    );
  }

  Map<String, dynamic> _toErpJson(Product p) => {
        'name': p.name,
        'price': p.price,
        'stock': p.stock,
        'sku': p.sku,
        'description': p.description,
      };

  Future<void> _persistCache(String companyId) async {
    final products = _cache.values
        .where((product) => product.companyId == companyId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    await _offlineStorage.saveProducts(companyId, products);
  }

  Future<List<Map<String, dynamic>>> _pendingOps(String companyId) {
    return _offlineStorage.loadPendingProductOps(companyId);
  }

  Future<void> _savePendingOps(
    String companyId,
    List<Map<String, dynamic>> ops,
  ) {
    return _offlineStorage.savePendingProductOps(companyId, ops);
  }

  Future<List<Product>> _mergeWithPending(String companyId, List<Product> base) async {
    final merged = {for (final product in base) product.id: product};
    final ops = await _pendingOps(companyId);
    for (final op in ops) {
      final type = op['type']?.toString();
      final productId = op['product_id']?.toString() ?? '';
      if (type == 'delete') {
        merged.remove(productId);
        continue;
      }
      if (type == 'upsert') {
        final product = Product.fromJson(
          Map<String, dynamic>.from(op['product'] as Map),
        );
        merged[product.id] = product;
      }
    }
    return merged.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _queueUpsert(Product product) async {
    final ops = await _pendingOps(product.companyId);
    ops.removeWhere((op) => op['product_id'] == product.id);
    ops.add({
      'type': 'upsert',
      'product_id': product.id,
      'product': product.toJson(),
    });
    await _savePendingOps(product.companyId, ops);
  }

  Future<void> _queueDelete(String companyId, String productId) async {
    final ops = await _pendingOps(companyId);
    ops.removeWhere((op) => op['product_id'] == productId);
    ops.add({
      'type': 'delete',
      'product_id': productId,
    });
    await _savePendingOps(companyId, ops);
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    var res =
        await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        res = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));
      }
    }
    return res;
  }

  Future<http.Response> _postWithRetry(Uri uri, String body) async {
    var res = await _client
        .post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        res = await _client
            .post(uri, headers: _headers, body: body)
            .timeout(const Duration(seconds: 8));
      }
    }
    return res;
  }

  Future<http.Response> _putWithRetry(Uri uri, String body) async {
    var res =
        await _client.put(uri, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        res = await _client
            .put(uri, headers: _headers, body: body)
            .timeout(const Duration(seconds: 8));
      }
    }
    return res;
  }

  Future<http.Response> _patchWithRetry(Uri uri, String body) async {
    var res = await _client
        .patch(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        res = await _client
            .patch(uri, headers: _headers, body: body)
            .timeout(const Duration(seconds: 8));
      }
    }
    return res;
  }

  Future<http.Response> _deleteWithRetry(Uri uri) async {
    var res = await _client
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        res = await _client
            .delete(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));
      }
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
    await _persistCache(companyId);
    return updated;
  }

  Future<void> syncPendingImages(String companyId) async {
    final pending = await _productExtrasRepository.listPendingUploads(
      companyId: companyId,
    );
    if (pending.isEmpty) return;

    for (final entry in pending.entries) {
      final productId = entry.key;
      final extras = entry.value;
      if (productId.startsWith('local-')) continue;
      final sourcePath = extras.referenceImagePath;
      if (sourcePath == null || sourcePath.isEmpty) continue;
      if (!await File(sourcePath).exists()) continue;

      try {
        await uploadProductImage(
          companyId: companyId,
          productId: productId,
          sourcePath: sourcePath,
          referenceImageHash: extras.referenceImageHash,
        );
        await _productExtrasRepository.markUploadSynced(
          companyId: companyId,
          productId: productId,
        );
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> syncPendingChanges(String companyId) async {
    final ops = await _pendingOps(companyId);
    if (ops.isEmpty) {
      await syncPendingImages(companyId);
      return;
    }

    final remaining = <Map<String, dynamic>>[];
    for (final op in ops) {
      try {
        if (op['type'] == 'delete') {
          final productId = op['product_id']?.toString() ?? '';
          if (productId.startsWith('local-')) {
            _cache.remove(productId);
            continue;
          }
          final response = await _deleteWithRetry(
            Uri.parse('$_base/api/products/$productId'),
          );
          if (response.statusCode != 200) throw Exception('delete failed');
          _cache.remove(productId);
          continue;
        }

        final product = Product.fromJson(
          Map<String, dynamic>.from(op['product'] as Map),
        );
        final body = jsonEncode(_toErpJson(product));
        final response = product.id.startsWith('local-')
            ? await _postWithRetry(Uri.parse('$_base/api/products'), body)
            : await _putWithRetry(
                Uri.parse('$_base/api/products/${product.id}'),
                body,
              );
        // 409 Conflict = doublon de nom côté serveur → erreur irrécupérable,
        // on supprime le produit local du cache et on abandonne l'opération.
        if (response.statusCode == 409) {
          _cache.remove(product.id);
          continue;
        }
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('upsert failed');
        }
        final saved = _fromErpJson(
          jsonDecode(response.body) as Map<String, dynamic>,
          companyId,
        );
        if (product.id != saved.id) {
          await _productExtrasRepository.move(
            companyId: companyId,
            fromProductId: product.id,
            toProductId: saved.id,
          );
          _cache.remove(product.id);
          await _offlineStorage.replaceProductIdEverywhere(
            companyId: companyId,
            oldProductId: product.id,
            newProduct: saved,
          );
        }
        _cache[saved.id] = saved;
      } catch (_) {
        remaining.add(op);
      }
    }

    await _savePendingOps(companyId, remaining);
    await syncPendingImages(companyId);
    await _persistCache(companyId);
  }

  @override
  Future<List<Product>> listProducts(String companyId) async {
    try {
      await syncPendingChanges(companyId);
      final res = await _getWithRetry(Uri.parse('$_base/api/products'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final remote = data
            .map((e) => _fromErpJson(e as Map<String, dynamic>, companyId))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final merged = await _mergeWithPending(companyId, remote);
        _cache
          ..removeWhere((_, value) => value.companyId == companyId)
          ..addAll({for (final product in merged) product.id: product});
        await _persistCache(companyId);
        return merged;
      }
      if (res.statusCode == 402) {
        throw Exception('Quota dépassé. Passez à un plan supérieur.');
      }
      throw Exception('ERP HTTP ${res.statusCode}');
    } catch (_) {
      final persisted = await _offlineStorage.loadProducts(companyId);
      final fallback = persisted.isNotEmpty
          ? persisted
          : _cache.values.where((p) => p.companyId == companyId).toList();
      if (fallback.isEmpty) rethrow;
      final merged = await _mergeWithPending(companyId, fallback);
      _cache
        ..removeWhere((_, value) => value.companyId == companyId)
        ..addAll({for (final product in merged) product.id: product});
      return merged;
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
        (p) => p.name == startAfterName && p.id == startAfterId,
      );
      if (start >= 0) start++;
      if (start < 0) start = 0;
    }
    final slice = all.skip(start).take(limit).toList();
    final next = slice.isEmpty || start + slice.length >= all.length
        ? null
        : ProductsCursor(name: slice.last.name, id: slice.last.id);
    return ProductsPage(items: slice, nextCursor: next);
  }

  @override
  Future<Product?> getById(String companyId, String productId) async {
    try {
      final res = await _getWithRetry(Uri.parse('$_base/api/products/$productId'));
      if (res.statusCode == 200) {
        final product = _fromErpJson(
          jsonDecode(res.body) as Map<String, dynamic>,
          companyId,
        );
        _cache[product.id] = product;
        await _persistCache(companyId);
        return product;
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
    for (final product in _cache.values) {
      if (product.companyId == companyId && (product.sku ?? '') == s) {
        return product;
      }
    }
    return (await listProducts(companyId))
        .cast<Product?>()
        .firstWhere((p) => (p!.sku ?? '') == s, orElse: () => null);
  }

  @override
  Future<Product?> getByConsumerCode(String companyId, String consumerCode) async {
    final code = consumerCode.trim();
    if (code.isEmpty) return null;
    for (final product in _cache.values) {
      if (product.companyId == companyId &&
          (product.consumerCode ?? '') == code) {
        return product;
      }
    }
    return (await listProducts(companyId))
        .cast<Product?>()
        .firstWhere((p) => (p!.consumerCode ?? '') == code, orElse: () => null);
  }

  @override
  Future<Product> upsert(Product product) async {
    final local = product.id.isEmpty
        ? product.copyWith(id: 'local-${_uuid.v4()}')
        : product;
    final body = jsonEncode(_toErpJson(local));
    try {
      final res = product.id.isEmpty
          ? await _postWithRetry(Uri.parse('$_base/api/products'), body)
          : await _putWithRetry(Uri.parse('$_base/api/products/${product.id}'), body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final saved = _fromErpJson(
          jsonDecode(res.body) as Map<String, dynamic>,
          local.companyId,
        );
        _cache[saved.id] = saved;
        await _persistCache(local.companyId);
        return saved;
      }
      if (res.statusCode == 402) {
        throw Exception('Quota produits dépassé. Passez à un plan supérieur.');
      }
      throw Exception('ERP upsert ${res.statusCode}');
    } catch (e) {
      final msg = e.toString();
      // Erreurs métier connues : quota (402) ou doublon (409) → on remonte
      // sans mettre en file offline, l'utilisateur doit corriger
      final isBusinessError = msg.contains('402') ||
          msg.contains('409') ||
          msg.contains('Quota') ||
          msg.contains('dépassé') ||
          msg.contains('supérieur');
      if (isBusinessError) rethrow;
      // Erreur réseau / timeout → mise en file offline
      final offlineLocal = local.copyWith(pendingSync: true);
      _cache[offlineLocal.id] = offlineLocal;
      await _queueUpsert(offlineLocal);
      await _persistCache(offlineLocal.companyId);
      return offlineLocal;
    }
  }

  @override
  Future<void> bulkUpsert(String companyId, List<Product> products) async {
    for (final product in products) {
      await upsert(product.copyWith(companyId: companyId));
    }
  }

  @override
  Future<void> delete(String companyId, String productId) async {
    try {
      final res = await _deleteWithRetry(Uri.parse('$_base/api/products/$productId'));
      if (res.statusCode != 200) {
        throw Exception('ERP delete ${res.statusCode}');
      }
    } catch (_) {
      await _queueDelete(companyId, productId);
    }
    _cache.remove(productId);
    await _productExtrasRepository.remove(
      companyId: companyId,
      productId: productId,
    );
    await _persistCache(companyId);
  }

  @override
  Future<Product?> decrementStock(String companyId, String productId, int quantity) async {
    try {
      final res = await _patchWithRetry(
        Uri.parse('$_base/api/products/$productId/stock'),
        jsonEncode({'delta': -quantity, 'reason': 'sale'}),
      );
      if (res.statusCode == 200) {
        final updated = _fromErpJson(
          jsonDecode(res.body) as Map<String, dynamic>,
          companyId,
        );
        _cache[updated.id] = updated;
        await _persistCache(companyId);
        return updated;
      }
      throw Exception('stock failed');
    } catch (_) {
      final cached = _cache[productId];
      if (cached == null || cached.stock < quantity) return null;
      final updated = cached.copyWith(stock: cached.stock - quantity);
      _cache[productId] = updated;
      await _persistCache(companyId);
      return updated;
    }
  }
}