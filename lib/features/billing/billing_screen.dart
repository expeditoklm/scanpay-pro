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
    final invoices = ref.watch(invoicesListProvider);

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
      itemBuilder: (context, i) {
        final inv = invoices[i];
        return Card(
          child: ListTile(
            title: Text('Facture ${inv.id.substring(0, 8)}…'),
            subtitle: Text('${_dateFmt.format(inv.createdAt)} · ${inv.lines.length} ligne(s)'),
            trailing: Text(formatPriceEuro(inv.total)),
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
    );
  }
}
