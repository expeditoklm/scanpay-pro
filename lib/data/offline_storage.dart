import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/invoice.dart';
import '../core/models/product.dart';

class OfflineStorage {
  static const _productsPrefix = 'offline_products::';
  static const _productOpsPrefix = 'offline_product_ops::';
  static const _invoicesPrefix = 'offline_invoices::';
  static const _pendingSalesPrefix = 'offline_pending_sales::';

  Future<List<Product>> loadProducts(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_productsPrefix$companyId');
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> saveProducts(String companyId, List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_productsPrefix$companyId',
      jsonEncode([for (final product in products) product.toJson()]),
    );
  }

  Future<List<Map<String, dynamic>>> loadPendingProductOps(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_productOpsPrefix$companyId');
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> savePendingProductOps(
    String companyId,
    List<Map<String, dynamic>> ops,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_productOpsPrefix$companyId', jsonEncode(ops));
  }

  Future<List<Invoice>> loadInvoices(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_invoicesPrefix$companyId');
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Invoice.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> saveInvoices(String companyId, List<Invoice> invoices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_invoicesPrefix$companyId',
      jsonEncode([for (final invoice in invoices) invoice.toJson()]),
    );
  }

  Future<List<Map<String, dynamic>>> loadPendingSales(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_pendingSalesPrefix$companyId');
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> savePendingSales(
    String companyId,
    List<Map<String, dynamic>> sales,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_pendingSalesPrefix$companyId', jsonEncode(sales));
  }

  Future<void> replaceProductIdEverywhere({
    required String companyId,
    required String oldProductId,
    required Product newProduct,
  }) async {
    final products = await loadProducts(companyId);
    final updatedProducts = products
        .map((product) => product.id == oldProductId ? newProduct : product)
        .toList();
    await saveProducts(companyId, updatedProducts);

    final productOps = await loadPendingProductOps(companyId);
    final updatedOps = productOps.map((op) {
      if (op['product_id'] != oldProductId) return op;
      if (op['type'] == 'delete') {
        return {
          'type': 'delete',
          'product_id': newProduct.id,
        };
      }
      return {
        'type': 'upsert',
        'product_id': newProduct.id,
        'product': newProduct.toJson(),
      };
    }).toList();
    await savePendingProductOps(companyId, updatedOps);

    final invoices = await loadInvoices(companyId);
    final updatedInvoices = invoices.map((invoice) {
      final lines = invoice.lines.map((line) {
        if (line.productId != oldProductId) return line;
        return InvoiceLine(
          productId: newProduct.id,
          name: line.name,
          unitPrice: line.unitPrice,
          quantity: line.quantity,
        );
      }).toList();
      return invoice.copyWith(lines: lines);
    }).toList();
    await saveInvoices(companyId, updatedInvoices);

    final pendingSales = await loadPendingSales(companyId);
    final updatedSales = pendingSales.map((sale) {
      final payload = Map<String, dynamic>.from(sale['payload'] as Map);
      final items = (payload['items'] as List<dynamic>? ?? const []).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map['product_id'] == oldProductId) {
          map['product_id'] = newProduct.id;
        }
        return map;
      }).toList();
      payload['items'] = items;
      return {
        ...sale,
        'payload': payload,
      };
    }).toList();
    await savePendingSales(companyId, updatedSales);
  }
}
