import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/erp_config.dart';
import '../core/models/invoice.dart';
import '../core/models/product.dart';
import '../core/services/mecef_service.dart';
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
  final MecefService _mecef = MecefService();

  Future<InvoicesPage> listPage({
    required String companyId,
    required int page,
    int perPage = 20,
  }) async {
    final auth = ref.read(authProvider);
    if (auth == null) return const InvoicesPage(items: [], page: 1, total: 0, totalPages: 1);
    final safePage = page < 1 ? 1 : page;
    final uri = Uri.parse('$kErpBaseUrl/api/sales').replace(queryParameters: {
      'page': '$safePage',
      'per_page': '$perPage',
    });
    try {
      final response = await _getWithRetry(uri);
      if (response.statusCode != 200) {
        throw Exception('ERP HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const [])
          .map((item) => _fromSaleJson(
                item as Map<String, dynamic>,
                companyId: companyId,
                companyName: auth.companyName,
                isVatRegistered: auth.isVatRegistered,
                companyIfu: auth.companyIfu,
                companyRc: auth.companyRc,
                companyAddress: auth.companyAddress,
                companyPhone: auth.companyPhone,
            ))
          .toList();
      await _cacheSalesForOffline(companyId, items);
      return InvoicesPage(
        items: items,
        page: (data['page'] as num?)?.toInt() ?? safePage,
        total: (data['total'] as num?)?.toInt() ?? items.length,
        totalPages: (data['total_pages'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {
      // Hors ligne : les ventes deja synchronisees et les ventes locales
      // restent consultables sans essayer d'afficher l'erreur reseau brute.
      return _localSalesPage(companyId, page: safePage, perPage: perPage);
    }
  }

  Future<void> _cacheSalesForOffline(
    String companyId,
    List<Invoice> remoteItems,
  ) async {
    final persisted = await _offlineStorage.loadInvoices(companyId);
    final byId = <String, Invoice>{
      for (final invoice in persisted) invoice.id: invoice,
      for (final invoice in remoteItems) invoice.id: invoice,
    };
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache[companyId] = merged;
    await _offlineStorage.saveInvoices(companyId, merged);
  }

  Future<InvoicesPage> _localSalesPage(
    String companyId, {
    required int page,
    required int perPage,
  }) async {
    final persisted = await _offlineStorage.loadInvoices(companyId);
    final invoices = persisted.isNotEmpty
        ? persisted
        : List<Invoice>.from(_cache[companyId] ?? const []);
    invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache[companyId] = invoices;

    final safePerPage = perPage < 1 ? 20 : perPage;
    final total = invoices.length;
    final totalPages = math.max(1, (total / safePerPage).ceil());
    final start = (page - 1) * safePerPage;
    final items = start >= total
        ? const <Invoice>[]
        : invoices.sublist(start, math.min(start + safePerPage, total));
    return InvoicesPage(
      items: items,
      page: page,
      total: total,
      totalPages: totalPages,
    );
  }

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
      final response =
          await _getWithRetry(Uri.parse('$kErpBaseUrl/api/sales'));
      if (response.statusCode != 200) {
        throw Exception('ERP HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final remoteInvoices = data
          .map((item) => _fromSaleJson(
                item as Map<String, dynamic>,
                companyId: companyId,
                companyName: auth.companyName,
                isVatRegistered: auth.isVatRegistered,
                companyIfu: auth.companyIfu,
                companyRc: auth.companyRc,
                companyAddress: auth.companyAddress,
                companyPhone: auth.companyPhone,
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
    String paymentMethod = 'Espece',
    double amountPaid = 0,
  }) async {
    // Relit le profil avant la vente : une modification du régime TVA dans
    // la boutique doit s'appliquer immédiatement aux nouveaux tickets.
    var auth = ref.read(authProvider);
    if (auth != null) {
      await ref.read(authProvider.notifier).refreshIfNeeded();
      // Variable séparée : évite que la promotion de null-safety impose
      // à Riverpod un provider non-nullable au moment de la relecture.
      final refreshedAuth = ref.read(authProvider);
      if (refreshedAuth == null) return null;
      auth = refreshedAuth;
    }
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
      'note': "Vente enregistree depuis l'application mobile",
    };

    try {
      final response = await _postWithRetry(
        Uri.parse('$kErpBaseUrl/api/sales'),
        jsonEncode(payload),
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
            'Creation vente ERP impossible (${response.statusCode})');
      }

      final sale = jsonDecode(response.body) as Map<String, dynamic>;
      var invoice = _fromSaleJson(
        sale,
        companyId: companyId,
        companyName: auth.companyName,
        companyIfu: auth.companyIfu,
        companyRc: auth.companyRc,
        companyAddress: auth.companyAddress,
        companyPhone: auth.companyPhone,
        isVatRegistered: auth.isVatRegistered,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
      );

      // Une boutique non assujettie n'émet pas de facture normalisée :
      // aucune TVA, aucune certification MECeF et aucun QR fiscal.
      if (auth.isVatRegistered) {
        // Certification e-MECeF (DGI Benin) pour les boutiques assujetties.
        final mecefConfig = auth.hasMecefCredentials
            ? MecefConfig(ifu: auth.companyIfu!, token: auth.mecefToken!)
            : MecefConfig.placeholder;
        final mecefResult = await _mecef.certifyInvoice(
          invoice,
          config: mecefConfig,
        );
        if (mecefResult.success) {
          invoice = invoice.copyWith(
            mecefCU: mecefResult.cu,
            mecefQrBase64: mecefResult.qrBase64,
            mecefDatetime: mecefResult.datetime,
            mecefStatus: mecefResult.status,
            mecefNim: mecefResult.nim,
            mecefCompteur: mecefResult.compteur,
          );
        } else {
          invoice = invoice.copyWith(mecefStatus: MecefStatus.pending);
        }
      }

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
        isVatRegistered: auth.isVatRegistered,
        companyIfu: auth.companyIfu,
        companyRc: auth.companyRc,
        companyAddress: auth.companyAddress,
        companyPhone: auth.companyPhone,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
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
        final payload =
            Map<String, dynamic>.from(entry['payload'] as Map);

        final items = (payload['items'] as List<dynamic>? ?? const []);
        final hasLocalIds = items.any((item) {
          final pid =
              (item as Map<String, dynamic>)['product_id']?.toString() ?? '';
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

        if (response.statusCode == 404 || response.statusCode == 400) {
          final body = response.body;
          print('[SYNC] Vente ignoree (${response.statusCode}): $body');
          final oldInvoiceId = entry['invoice_id']?.toString();
          final idx = invoices.indexWhere((inv) => inv.id == oldInvoiceId);
          if (idx >= 0) {
            invoices[idx] = invoices[idx].copyWith(
              pendingSync: false,
              source: 'mobile_offline_failed',
            );
          }
          continue;
        }

        if (response.statusCode != 201 && response.statusCode != 200) {
          throw Exception('sync failed ${response.statusCode}');
        }
        final sale = jsonDecode(response.body) as Map<String, dynamic>;
        final syncedInvoice = _fromSaleJson(
          sale,
          companyId: companyId,
          companyName: auth.companyName,
          isVatRegistered: auth.isVatRegistered,
          companyIfu: auth.companyIfu,
          companyRc: auth.companyRc,
          companyAddress: auth.companyAddress,
          companyPhone: auth.companyPhone,
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
          'source':
              invoice.source.isEmpty ? 'mobile_offline' : invoice.source,
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
    bool isVatRegistered = true,
    String? companyIfu,
    String? companyRc,
    String? companyAddress,
    String? companyPhone,
    String paymentMethod = 'Espece',
    double amountPaid = 0,
  }) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);
    return Invoice(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      companyId: companyId,
      companyName: companyName,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
      customer: json['customer'] as String?,
      note: json['note'] as String?,
      source: json['source'] as String? ?? 'mobile_app',
      pendingSync: false,
      isVatRegistered: isVatRegistered,
      companyIfu: companyIfu,
      companyRc: companyRc,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
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

class InvoicesPage {
  const InvoicesPage({
    required this.items,
    required this.page,
    required this.total,
    required this.totalPages,
  });

  final List<Invoice> items;
  final int page;
  final int total;
  final int totalPages;
}
