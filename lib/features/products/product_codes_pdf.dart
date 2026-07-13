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
  // Une colonne sur un rouleau de 72 mm : compatible avec les imprimantes
  // thermiques. La hauteur augmente avec le nombre d'etiquettes generees.
  const labelHeightMm = 72.0;
  final receiptHeight = (30.0 + (entries.length * labelHeightMm)) *
      PdfPageFormat.mm;
  final receiptFormat = PdfPageFormat(
    72 * PdfPageFormat.mm,
    receiptHeight,
    marginAll: 4 * PdfPageFormat.mm,
  );
  final labelWidth = receiptFormat.availableWidth;

  doc.addPage(
    pw.Page(
      pageFormat: receiptFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              'ETIQUETTES QR',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              companyName,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Center(
            child: pw.Text(
              '${entries.length} etiquette${entries.length > 1 ? 's' : ''} - ${product.name}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.SizedBox(height: 7),
          for (final entry in entries)
            pw.Container(
              width: labelWidth,
              height: labelHeightMm * PdfPageFormat.mm,
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    product.name,
                    textAlign: pw.TextAlign.center,
                    maxLines: 2,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.BarcodeWidget(
                    data: entry.qrData,
                    barcode: pw.Barcode.qrCode(),
                    width: 48 * PdfPageFormat.mm,
                    height: 48 * PdfPageFormat.mm,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    entry.code,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.Text(
                    'Verifier la provenance',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  return doc.save();
}
