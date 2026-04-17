import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/product.dart';

class ProductQrSheetEntry {
  const ProductQrSheetEntry({
    required this.code,
    required this.qrData,
  });

  final String code;
  final String qrData;
}

Future<Uint8List> buildProductCodesPdf({
  required Product product,
  required String companyName,
  required List<ProductQrSheetEntry> entries,
}) async {
  final doc = pw.Document();
  const pageFormat = PdfPageFormat.a4;
  const horizontalSpacing = 8.0;
  const verticalSpacing = 10.0;
  final cardWidth =
      (pageFormat.availableWidth - (horizontalSpacing * 2)) / 3;

  doc.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => [
        pw.Text(
          'Planche QR produit',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(companyName),
        pw.Text('Produit : ${product.name}'),
        pw.Text('Quantite : ${entries.length} QR'),
        pw.SizedBox(height: 14),
        pw.Wrap(
          spacing: horizontalSpacing,
          runSpacing: verticalSpacing,
          children: [
            for (final entry in entries)
              pw.Container(
                width: cardWidth,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      product.name,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.BarcodeWidget(
                      data: entry.qrData,
                      barcode: pw.Barcode.qrCode(),
                      width: cardWidth - 26,
                      height: cardWidth - 26,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      entry.code,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Verification de provenance',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}
