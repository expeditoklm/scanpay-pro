import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/invoice.dart';

final _dateFmt = DateFormat.yMMMd('fr_FR');

Future<Uint8List> buildInvoicePdf(Invoice invoice, PdfPageFormat format) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: format,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Facture', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('N° ${invoice.id}'),
          pw.Text('Date : ${_dateFmt.format(invoice.createdAt)}'),
          pw.Text('Entreprise : ${invoice.companyId}'),
          pw.SizedBox(height: 16),
          for (final l in invoice.lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text(l.name)),
                  pw.Text('${l.quantity} × ${l.unitPrice.toStringAsFixed(2)} €'),
                  pw.SizedBox(width: 8),
                  pw.Text('${l.lineTotal.toStringAsFixed(2)} €'),
                ],
              ),
            ),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total : ${invoice.total.toStringAsFixed(2)} €',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
