import 'dart:typed_data';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/invoice.dart';

final _dateFmt = DateFormat.yMMMd('fr_FR');

Future<Uint8List> buildInvoicePdf(Invoice invoice, PdfPageFormat format) async {
  final doc = pw.Document();
  final qrData = jsonEncode({
    'type': 'receipt',
    'companyId': invoice.companyId,
    'invoiceId': invoice.id,
    'total': invoice.total,
    'createdAt': invoice.createdAt.toIso8601String(),
  });
  doc.addPage(
    pw.Page(
      pageFormat: format,
      build: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.all(18),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('REÇU', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Entreprise: ${invoice.companyId}', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Date: ${_dateFmt.format(invoice.createdAt)}', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('N°: ${invoice.id}', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
                pw.Container(
                  width: 92,
                  height: 92,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(color: PdfColors.grey700),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text('Article', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(width: 8),
                pw.Text('Qté', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 10),
                pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 8),
            for (final l in invoice.lines)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        l.name,
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text('${l.quantity}'),
                    pw.SizedBox(width: 10),
                    pw.Text('${l.lineTotal.toStringAsFixed(2)} €'),
                  ],
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey700),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${invoice.total.toStringAsFixed(2)} €',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                'Merci pour votre achat',
                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
