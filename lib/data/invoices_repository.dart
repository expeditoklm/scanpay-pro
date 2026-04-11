import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/erp_config.dart';
import '../core/models/invoice.dart';
import '../core/models/product.dart';
import '../features/auth/auth_provider.dart';
import 'offline_storage.dart';

class InvoicesRepository {
  InvoicesRepository({
    required this.ref,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;
  final Map<String, List<Invoice>> _cache = {};
  final OfflineStorage _offlineStorage = OfflineStorage();

  Map<String, String> get _headers {
    final auth = ref.read(authProvider);
    if (auth == null) {
      return const {'Content-Type': 'application/json'};
    }
    return auth.authHeaders;
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    var response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));
      }
    }
    return response;
  }

  Future<http.Response> _postWithRetry(Uri uri, String body) async {
    var response = await _client
        .post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 401) {
      final ok = await ref.read(authProvider.notifier).refreshIfNeeded();
      if (ok) {
        response = await _client
            .post(uri, headers: _headers, body: body)
            .timeout(const Duration(seconds: 8));
      }
    }
    return response;
  }

  Future<List<Invoice>> listForCompany(String companyId) async {
    final auth = ref.read(authProvider);
    if (auth == null) return const [];

    try {
      await syncPendingSales(companyId);
      final response = await _getWithRetry(Uri.parse('$kErpBaseUrl/api/sales'));
      if (response.statusCode != 200) {
        throw Exception('ERP HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final remoteInvoices = data
          .map((item) => _fromSaleJson(
                item as Map<String, dynamic>,
                companyId: companyId,
                companyName: auth.companyName,
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final localPending = (await _offlineStorage.loadInvoices(companyId))
          .where((invoice) => invoice.pendingSync)
          .toList();
      final merged = [...localPending, ...remoteInvoices]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cache[companyId] = merged;
      await _offlineStorage.saveInvoices(companyId, merged);
      return merged;
    } catch (_) {
      final persisted = await _offlineStorage.loadInvoices(companyId);
      if (persisted.isNotEmpty) {
        _cache[companyId] = persisted;
        return persisted;
      }
      return _cache[companyId] ?? const [];
    }
  }

  Future<Invoice?> recordSale({
    required String companyId,
    required String invoiceId,
    required List<({Product product, int qty})> lines,
  }) async {
    final auth = ref.read(authProvider);
    if (auth == null) return null;

    final payload = {
      'items': [
        for (final line in lines)
          {
            'product_id': line.product.id,
            'quantity': line.qty,
          },
      ],
      'source': 'mobile_app',
      'note': 'Vente enregistree depuis l’application mobile',
    };

    try {
      final response = await _postWithRetry(
        Uri.parse('$kErpBaseUrl/api/sales'),
        jsonEncode(payload),
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Creation vente ERP impossible (${response.statusCode})');
      }

      final sale = jsonDecode(response.body) as Map<String, dynamic>;
      final invoice = _fromSaleJson(
        sale,
        companyId: companyId,
        companyName: auth.companyName,
      );

      final existing = List<Invoice>.from(_cache[companyId] ?? const []);
      existing.removeWhere((item) => item.id == invoice.id);
      existing.insert(0, invoice);
      _cache[companyId] = existing;
      await _offlineStorage.saveInvoices(companyId, existing);
      return invoice;
    } catch (_) {
      final offlineInvoice = Invoice(
        id: invoiceId,
        reference: 'OFF-${invoiceId.substring(0, 8).toUpperCase()}',
        companyId: companyId,
        companyName: auth.companyName,
        createdAt: DateTime.now(),
        note: payload['note'] as String?,
        source: 'mobile_offline',
        pendingSync: true,
        lines: [
          for (final line in lines)
            InvoiceLine(
              productId: line.product.id,
              name: line.product.name,
              unitPrice: line.product.price,
              quantity: line.qty,
            ),
        ],
      );

      final existing = List<Invoice>.from(
        _cache[companyId] ?? await _offlineStorage.loadInvoices(companyId),
      );
      existing.removeWhere((item) => item.id == offlineInvoice.id);
      existing.insert(0, offlineInvoice);
      _cache[companyId] = existing;
      await _offlineStorage.saveInvoices(companyId, existing);

      final pendingSales = await _offlineStorage.loadPendingSales(companyId);
      pendingSales.add({
        'invoice_id': invoiceId,
        'payload': payload,
      });
      await _offlineStorage.savePendingSales(companyId, pendingSales);
      return offlineInvoice;
    }
  }

  Future<void> syncPendingSales(String companyId) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final pendingSales = await _rebuildMissingPendingSales(companyId);
    if (pendingSales.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    final invoices = List<Invoice>.from(
      _cache[companyId] ?? await _offlineStorage.loadInvoices(companyId),
    );

    for (final entry in pendingSales) {
      try {
        final payload = Map<String, dynamic>.from(entry['payload'] as Map);

        // Si des lignes référencent encore des produits locaux (local-xxx),
        // on ne peut pas encore les envoyer au serveur → on les reporte.
        final items = (payload['items'] as List<dynamic>? ?? const []);
        final hasLocalIds = items.any((item) {
          final pid = (item as Map<String, dynamic>)['product_id']?.toString() ?? '';
          return pid.startsWith('local-');
        });
        if (hasLocalIds) {
          remaining.add(entry);
          continue;
        }

        final response = await _postWithRetry(
          Uri.parse('$kErpBaseUrl/api/sales'),
          jsonEncode(payload),
        );

        // 404 = produit introuvable sur le serveur (supprimé ou jamais synchro)
        // 400 = stock insuffisant côté serveur
        // Ces cas sont irrécupérables → on retire la vente de la queue
        // plutôt que de réessayer en boucle
        if (response.statusCode == 404 || response.statusCode == 400) {
          final body = response.body;
          print('[SYNC] Vente ignorée (${response.statusCode}): $body');
          // On retire de remaining → la vente sera définitivement marquée comme non-sync
          // On met à jour la facture locale pour retirer le pendingSync
          final oldInvoiceId = entry['invoice_id']?.toString();
          final idx = invoices.indexWhere((inv) => inv.id == oldInvoiceId);
          if (idx >= 0) {
            invoices[idx] = invoices[idx].copyWith(
              pendingSync: false,
              source: 'mobile_offline_failed',
            );
          }
          continue; // Ne pas ajouter à remaining
        }

        if (response.statusCode != 201 && response.statusCode != 200) {
          throw Exception('sync failed ${response.statusCode}');
        }
        final sale = jsonDecode(response.body) as Map<String, dynamic>;
        final syncedInvoice = _fromSaleJson(
          sale,
          companyId: companyId,
          companyName: auth.companyName,
        );
        final oldInvoiceId = entry['invoice_id']?.toString();
        invoices.removeWhere((invoice) => invoice.id == oldInvoiceId);
        invoices.insert(0, syncedInvoice);
      } catch (_) {
        remaining.add(entry);
      }
    }

    _cache[companyId] = invoices;
    await _offlineStorage.saveInvoices(companyId, invoices);
    await _offlineStorage.savePendingSales(companyId, remaining);
  }

  Future<List<Map<String, dynamic>>> _rebuildMissingPendingSales(
    String companyId,
  ) async {
    final pendingSales = await _offlineStorage.loadPendingSales(companyId);
    final invoices = await _offlineStorage.loadInvoices(companyId);
    final knownInvoiceIds = pendingSales
        .map((entry) => entry['invoice_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    var changed = false;
    for (final invoice in invoices.where((item) => item.pendingSync)) {
      if (knownInvoiceIds.contains(invoice.id)) continue;
      pendingSales.add({
        'invoice_id': invoice.id,
        'payload': {
          'items': [
            for (final line in invoice.lines)
              {
                'product_id': line.productId,
                'quantity': line.quantity,
              },
          ],
          'source': invoice.source.isEmpty ? 'mobile_offline' : invoice.source,
          'note': invoice.note ?? 'Vente restauree pour synchronisation',
        },
      });
      knownInvoiceIds.add(invoice.id);
      changed = true;
    }

    if (changed) {
      await _offlineStorage.savePendingSales(companyId, pendingSales);
    }
    return pendingSales;
  }

  Invoice _fromSaleJson(
    Map<String, dynamic> json, {
    required String companyId,
    required String companyName,
  }) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);
    return Invoice(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      companyId: companyId,
      companyName: companyName,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      customer: json['customer'] as String?,
      note: json['note'] as String?,
      source: json['source'] as String? ?? 'mobile_app',
      pendingSync: false,
      lines: rawItems.map((item) {
        final map = item as Map<String, dynamic>;
        return InvoiceLine(
          productId: map['product_id'] as String? ?? '',
          name: map['product_name'] as String? ??
              map['name'] as String? ??
              'Produit',
          unitPrice: (map['unit_price'] as num? ?? 0).toDouble(),
          quantity: (map['quantity'] as num? ?? 0).toInt(),
        );
      }).toList(),
    );
  }
}