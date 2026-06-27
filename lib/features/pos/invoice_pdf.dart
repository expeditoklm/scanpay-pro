import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/invoice.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

Future<Uint8List> buildInvoicePdf(Invoice invoice, PdfPageFormat _) async {
  final doc = pw.Document();

  final lineCount = invoice.lines.length;
  // Hauteur calculée au plus juste : base compacte + 10mm par ligne
  final receiptHeight = (78.0 + lineCount * 10.0) * PdfPageFormat.mm;
  final receiptFormat = PdfPageFormat(
    72 * PdfPageFormat.mm,
    receiptHeight,
    marginAll: 5 * PdfPageFormat.mm,
  );

  doc.addPage(
    pw.Page(
      pageFormat: receiptFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [

          // ── En-tete ───────────────────────────────────────────────────
          pw.Center(
            child: pw.Text(
              invoice.companyName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Center(
            child: pw.Text(
              'QuickSellPay - Recu de vente',
              style: const pw.TextStyle(fontSize: 6.5),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 1.2),

          // ── Infos transaction ─────────────────────────────────────────
          pw.SizedBox(height: 3),
          _row2('Ref :', invoice.reference, bold: true, fontSize: 7),
          pw.SizedBox(height: 2),
          _row2('Date :', _dateFmt.format(invoice.createdAt), fontSize: 6.5),
          pw.SizedBox(height: 2),
          _row2('Boutique :', invoice.companyId, fontSize: 6.5),
          if ((invoice.customer ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            _row2('Client :', invoice.customer!.trim(), fontSize: 6.5),
          ],
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5),

          // ── En-tete tableau ───────────────────────────────────────────
          pw.SizedBox(height: 2),
          pw.Row(
            children: [
              pw.SizedBox(
                width: 20,
                child: pw.Text('Qte',
                    style: pw.TextStyle(
                        fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(
                child: pw.Text('Article',
                    style: pw.TextStyle(
                        fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text('Montant',
                  style: pw.TextStyle(
                      fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Divider(thickness: 0.4),

          // ── Lignes produits ───────────────────────────────────────────
          for (final line in invoice.lines) ...[
            pw.SizedBox(height: 3),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 20,
                  child: pw.Text('${line.quantity}x',
                      style: const pw.TextStyle(fontSize: 7)),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(line.name,
                          style: pw.TextStyle(
                              fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${line.unitPrice.toStringAsFixed(0)} FCFA/u',
                          style: const pw.TextStyle(fontSize: 5.8)),
                    ],
                  ),
                ),
                pw.Text('${line.lineTotal.toStringAsFixed(0)} F',
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Divider(
                thickness: 0.3, color: PdfColor.fromHex('#CCCCCC')),
          ],

          // ── Sous-total ────────────────────────────────────────────────
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sous-total',
                  style: const pw.TextStyle(fontSize: 6.5)),
              pw.Text('${invoice.total.toStringAsFixed(0)} FCFA',
                  style: const pw.TextStyle(fontSize: 6.5)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 1.2),

          // ── Total ─────────────────────────────────────────────────────
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5)),
              pw.Text('${invoice.total.toStringAsFixed(0)} FCFA',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Divider(thickness: 1.2),

          // ── Note / Sync ───────────────────────────────────────────────
          if ((invoice.note ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(_ascii(invoice.note!.trim()),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.center),
            ),
          ],
          if (invoice.pendingSync) ...[
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text('[ SYNC EN ATTENTE ]',
                  style: pw.TextStyle(
                      fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
            ),
          ],

          // ── Message ───────────────────────────────────────────────────
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text('Merci pour votre achat !',
                style: pw.TextStyle(
                    fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center),
          ),
          pw.SizedBox(height: 1),
          pw.Center(
            child: pw.Text("Conservez ce recu comme preuve d'achat.",
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.center),
          ),
          pw.SizedBox(height: 6),

          // ── Code-barres Code128 ───────────────────────────────────────
          pw.BarcodeWidget(
            data: invoice.reference.isNotEmpty
                ? invoice.reference
                : invoice.id,
            barcode: pw.Barcode.code128(),
            height: 26,
            width: double.infinity,
            drawText: true,
            textPadding: 2,
            textStyle:
                const pw.TextStyle(fontSize: 5.5, letterSpacing: 0.8),
            color: PdfColors.black,
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.3),
          pw.SizedBox(height: 2),

          // ── Pied de page ──────────────────────────────────────────────
          pw.Center(
            child: pw.Text('QuickSellPay - vente securisee et tracable',
                style: const pw.TextStyle(fontSize: 5.5),
                textAlign: pw.TextAlign.center),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

// Remplace les caracteres speciaux par des equivalents ASCII
String _ascii(String s) => s
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('·', '.')
    .replaceAll('é', 'e')
    .replaceAll('è', 'e')
    .replaceAll('ê', 'e')
    .replaceAll('à', 'a')
    .replaceAll('â', 'a')
    .replaceAll('ô', 'o')
    .replaceAll('û', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('î', 'i')
    .replaceAll('ç', 'c')
    .replaceAll('É', 'E')
    .replaceAll('À', 'A')
    .replaceAll('&', 'et');

pw.Widget _row2(
  String label,
  String value, {
  bool bold = false,
  double fontSize = 6.5,
}) =>
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 6.5)),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(
            _ascii(value),
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : null,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
