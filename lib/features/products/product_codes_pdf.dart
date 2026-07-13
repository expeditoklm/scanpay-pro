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
  // Deux etiquettes par ligne sur un rouleau de 80 mm. La hauteur augmente
  // avec le nombre de lignes, pour les imprimantes thermiques autocollantes.
  const labelHeightMm = 48.0;
  const labelsPerRow = 2;
  final rowCount = (entries.length + labelsPerRow - 1) ~/ labelsPerRow;
  final receiptHeight = (30.0 + (rowCount * labelHeightMm)) *
      PdfPageFormat.mm;
  final receiptFormat = PdfPageFormat(
    80 * PdfPageFormat.mm,
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
          for (var index = 0; index < entries.length; index += labelsPerRow)
            pw.Container(
              width: labelWidth,
              height: labelHeightMm * PdfPageFormat.mm,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    child: _buildQrLabel(product, entries[index]),
                  ),
                  pw.SizedBox(width: 2 * PdfPageFormat.mm),
                  pw.Expanded(
                    child: index + 1 < entries.length
                        ? _buildQrLabel(product, entries[index + 1])
                        : pw.SizedBox(),
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

pw.Widget _buildQrLabel(Product product, ProductQrSheetEntry entry) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          product.name,
          textAlign: pw.TextAlign.center,
          maxLines: 1,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.BarcodeWidget(
          data: entry.qrData,
          barcode: pw.Barcode.qrCode(),
          width: 29 * PdfPageFormat.mm,
          height: 29 * PdfPageFormat.mm,
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          entry.code,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        pw.Text(
          'Verifier la provenance',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 5.5),
        ),
      ],
    ),
  );
}
