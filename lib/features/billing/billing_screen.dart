import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/utils/price_formatter.dart';
import '../pos/invoice_pdf.dart';
import 'billing_providers.dart';

final _dateFmt = DateFormat.yMMMd('fr_FR');

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesListProvider);

    return invoicesAsync.when(
      // ── Chargement ──────────────────────────────────────────────────────
      loading: () => const Center(child: CircularProgressIndicator()),

      // ── Erreur ──────────────────────────────────────────────────────────
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text('Impossible de charger les ventes\n$e',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(invoicesListProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),

      // ── Données ─────────────────────────────────────────────────────────
      data: (invoices) {
        if (invoices.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Aucune vente pour l\'instant.\nValidez une vente depuis la caisse.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(invoicesListProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, i) {
              final inv = invoices[i];
              final shortId = inv.id.length >= 8
                  ? inv.id.substring(0, 8)
                  : inv.id;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_outlined),
                  title: Text('Facture $shortId…'),
                  subtitle: Text(
                    '${_dateFmt.format(inv.createdAt)} · ${inv.lines.length} article(s)',
                  ),
                  trailing: Text(
                    formatPriceEuro(inv.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Aperçu PDF')),
                          body: PdfPreview(
                            build: (format) => buildInvoicePdf(inv, format),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
