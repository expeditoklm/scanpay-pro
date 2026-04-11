import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/utils/price_formatter.dart';
import '../pos/invoice_pdf.dart';
import 'billing_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInvoices = ref.watch(invoicesListProvider);

    return asyncInvoices.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erreur: $error')),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune facture pour l’instant. Validez une vente depuis la caisse.'),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final invoice = invoices[index];
            return Card(
              child: ListTile(
                title: Text(invoice.reference.isNotEmpty
                    ? invoice.reference
                    : 'Facture ${invoice.id.substring(0, 8)}...'),
                subtitle: Text(
                  '${_dateFmt.format(invoice.createdAt)} · ${invoice.lines.length} ligne(s)${invoice.pendingSync ? ' · Sync en attente' : ''}',
                ),
                trailing: Text(formatPriceEuro(invoice.total)),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Aperçu PDF')),
                        body: PdfPreview(
                          build: (format) => buildInvoicePdf(invoice, format),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
