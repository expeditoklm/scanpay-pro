import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/invoice.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

Future<Uint8List> buildInvoicePdf(Invoice invoice, PdfPageFormat _) async {
  final doc = pw.Document();
  final receiptHeight = (165 + (invoice.lines.length * 18)).toDouble() *
      PdfPageFormat.mm;
  final receiptFormat = PdfPageFormat(
    58 * PdfPageFormat.mm,
    receiptHeight,
    marginAll: 4 * PdfPageFormat.mm,
  );

  doc.addPage(
    pw.Page(
      pageFormat: receiptFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              invoice.companyName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'QuickSellPay Receipt',
              style: const pw.TextStyle(fontSize: 6.5),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'REF: ${invoice.reference}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'DATE: ${_dateFmt.format(invoice.createdAt)}',
            style: const pw.TextStyle(fontSize: 6.8),
          ),
          pw.Text(
            'BOUTIQUE: ${invoice.companyId}',
            style: const pw.TextStyle(fontSize: 6.8),
          ),
          if (invoice.pendingSync)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF1DC'),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  'SYNC EN ATTENTE',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    color: PdfColor.fromHex('#B45309'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColor.fromHex('#D9D9D9')),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('QTY', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                  child: pw.Text(
                    'DESC',
                    style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
              pw.Text('AMT', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 4),
          for (final line in invoice.lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 18,
                    child: pw.Text(
                      '${line.quantity}',
                      style: const pw.TextStyle(fontSize: 6.8),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            line.name.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 6.8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${line.unitPrice.toStringAsFixed(0)} FCFA',
                            style: const pw.TextStyle(fontSize: 6.1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.Text(
                    '${line.lineTotal.toStringAsFixed(0)}',
                    style: const pw.TextStyle(fontSize: 6.8),
                  ),
                ],
              ),
            ),
          pw.Divider(color: PdfColor.fromHex('#D9D9D9')),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SUBTOTAL', style: const pw.TextStyle(fontSize: 6.8)),
              pw.Text('${invoice.total.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 6.8)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'AMOUNT',
                style: pw.TextStyle(fontSize: 8.6, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${invoice.total.toStringAsFixed(0)} FCFA',
                style: pw.TextStyle(fontSize: 8.6, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          if ((invoice.customer ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('CLIENT: ${invoice.customer!.trim()}', style: const pw.TextStyle(fontSize: 6.6)),
          ],
          if ((invoice.note ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('NOTE: ${invoice.note!.trim()}', style: const pw.TextStyle(fontSize: 6.4)),
          ],
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              '*** THANK YOU ***',
              style: pw.TextStyle(fontSize: 6.6, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 18,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#111827'), width: 0.8),
            ),
            child: pw.Row(
              children: List.generate(
                24,
                (index) => pw.Container(
                  width: index.isEven ? 3 : 1.5,
                  color: index.isEven ? PdfColors.black : PdfColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}
