import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/utils/price_formatter.dart';
import '../pos/invoice_pdf.dart';
import 'billing_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
final _compactReceiptPreviewFormat = PdfPageFormat(
  72 * PdfPageFormat.mm,
  220 * PdfPageFormat.mm,
  marginAll: 6 * PdfPageFormat.mm,
);

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
              child: Text(
                'Aucune facture pour le moment. Validez une vente depuis la caisse.',
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final invoice = invoices[index];

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: invoice.pendingSync
                      ? const Color(0xFFFFC37A)
                      : const Color(0xFFD7E2F2),
                ),
              ),
              child: ListTile(
                title: Text(
                  invoice.reference.isNotEmpty
                      ? invoice.reference
                      : 'Facture ${invoice.id.substring(0, 8)}...',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_dateFmt.format(invoice.createdAt)} - ${invoice.lines.length} ligne(s)',
                    ),
                    if (invoice.pendingSync) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1DC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Sync en attente',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Text(formatPriceEuro(invoice.total)),
                isThreeLine: invoice.pendingSync,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Apercu ticket')),
                        body: PdfPreview(
                          initialPageFormat: _compactReceiptPreviewFormat,
                          canChangePageFormat: false,
                          canDebug: false,
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
