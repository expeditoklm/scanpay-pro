import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/invoice.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

Future<Uint8List> buildInvoicePdf(Invoice invoice, PdfPageFormat format) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      build: (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      invoice.companyName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Identifiant boutique : ${invoice.companyId}'),
                    pw.Text('Référence facture : ${invoice.reference}'),
                    pw.Text('Date : ${_dateFmt.format(invoice.createdAt)}'),
                    pw.Text('Canal : ${invoice.source}'),
                    if ((invoice.customer ?? '').trim().isNotEmpty)
                      pw.Text('Client : ${invoice.customer!.trim()}'),
                    if ((invoice.note ?? '').trim().isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Text('Note : ${invoice.note!.trim()}'),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.BarcodeWidget(
                data: invoice.qrPayload,
                barcode: pw.Barcode.qrCode(),
                width: 110,
                height: 110,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('Produit', bold: true),
                _cell('Qté', bold: true),
                _cell('PU', bold: true),
                _cell('Total', bold: true),
              ],
            ),
            for (final line in invoice.lines)
              pw.TableRow(
                children: [
                  _cell(line.name),
                  _cell('${line.quantity}'),
                  _cell('${line.unitPrice.toStringAsFixed(2)} EUR'),
                  _cell('${line.lineTotal.toStringAsFixed(2)} EUR'),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total : ${invoice.total.toStringAsFixed(2)} EUR',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _cell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
