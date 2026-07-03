import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/invoice.dart';

final _dateFmt    = DateFormat('dd/MM/yyyy HH:mm');
final _dateFmtSec = DateFormat('dd/MM/yyyy HH:mm:ss');

Future<Uint8List> buildInvoicePdf(Invoice invoice, PdfPageFormat _) async {
  final doc = pw.Document();

  final lineCount     = invoice.lines.length;
  final hasMecef      = invoice.isMecefCertified;

  // PROFORMA = non assujetti TVA sans certification MECeF effective
  // NORMALISÉE = assujetti avec ou sans certification (pending ou certified)
  final isProforma    = !invoice.isVatRegistered && !hasMecef;
  final showMecef     = !isProforma && (hasMecef || invoice.mecefStatus == MecefStatus.pending);
  final showVat       = invoice.isVatRegistered && !isProforma;

  // ── Lignes d'en-tête optionnelles ──────────────────────────────────────────
  final hasAddress = (invoice.companyAddress ?? '').trim().isNotEmpty;
  final hasPhone   = (invoice.companyPhone   ?? '').trim().isNotEmpty;
  final hasIfu     = (invoice.companyIfu     ?? '').trim().isNotEmpty;
  final hasRc      = (invoice.companyRc      ?? '').trim().isNotEmpty;
  final headerExtra = (hasAddress ? 1 : 0) + (hasPhone ? 1 : 0) +
      ((hasIfu || hasRc) ? 1 : 0);

  // ── Paiement ────────────────────────────────────────────────────────────────
  final isEspece = invoice.paymentMethod == 'Espece';
  final hasChange = isEspece && invoice.change > 0;
  final payLines  = 1 + (isEspece ? 1 : 0) + (hasChange ? 1 : 0);

  // ── Hauteur de page ─────────────────────────────────────────────────────────
  final receiptHeight = (
        148.0
      + headerExtra * 5.0
      + lineCount   * 12.0
      + payLines    * 7.0
      + (showVat    ? 14.0 : 0.0)
      + (showMecef  ? 95.0 : 0.0)
    ) * PdfPageFormat.mm;

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

          // ── En-tête société ───────────────────────────────────────────
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
              isProforma ? 'FACTURE PROFORMA' : 'FACTURE NORMALISEE',
              style: pw.TextStyle(
                fontSize: isProforma ? 8.5 : 7,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.8,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Center(
            child: pw.Text(
              'QuickSellPay - Recu de vente',
              style: const pw.TextStyle(fontSize: 6),
              textAlign: pw.TextAlign.center,
            ),
          ),
          if (hasAddress) ...[
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                _ascii(invoice.companyAddress!.trim()),
                style: const pw.TextStyle(fontSize: 6.5),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
          if (hasPhone) ...[
            pw.SizedBox(height: 1),
            pw.Center(
              child: pw.Text(
                'Tel : ${invoice.companyPhone!.trim()}',
                style: const pw.TextStyle(fontSize: 6.5),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
          if (hasIfu || hasRc) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (hasIfu)
                  pw.Text('IFU : ${invoice.companyIfu!.trim()}',
                      style: const pw.TextStyle(fontSize: 6)),
                if (hasIfu && hasRc)
                  pw.Text('   |   ', style: const pw.TextStyle(fontSize: 6)),
                if (hasRc)
                  pw.Text('RC : ${invoice.companyRc!.trim()}',
                      style: const pw.TextStyle(fontSize: 6)),
              ],
            ),
          ],
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

          // ── En-tête tableau ───────────────────────────────────────────
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
          pw.SizedBox(height: 3),

          // ── Ventilation TVA (boutiques assujetties uniquement) ────────
          if (showVat) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('BASE IMPOSABLE [B] 18%',
                    style: const pw.TextStyle(fontSize: 5.8)),
                pw.Text('${invoice.totalHT.toStringAsFixed(0)} FCFA',
                    style: const pw.TextStyle(fontSize: 5.8)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL TVA [B] 18%',
                    style: const pw.TextStyle(fontSize: 5.8)),
                pw.Text('${invoice.tva.toStringAsFixed(0)} FCFA',
                    style: const pw.TextStyle(fontSize: 5.8)),
              ],
            ),
            pw.SizedBox(height: 4),
          ],
          pw.Divider(thickness: 1.2),

          // ── Total TTC ─────────────────────────────────────────────────
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL TTC',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5)),
              pw.Text('${invoice.total.toStringAsFixed(0)} FCFA',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 1.2),

          // ── Paiement ──────────────────────────────────────────────────
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Mode paiement',
                  style: const pw.TextStyle(fontSize: 6.5)),
              pw.Text(_ascii(invoice.paymentMethod),
                  style: pw.TextStyle(
                      fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          if (isEspece && invoice.amountPaid > 0) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Espece',
                    style: const pw.TextStyle(fontSize: 6.5)),
                pw.Text('${invoice.amountPaid.toStringAsFixed(0)} FCFA',
                    style: const pw.TextStyle(fontSize: 6.5)),
              ],
            ),
            if (hasChange) ...[
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rendu',
                      style: pw.TextStyle(
                          fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${invoice.change.toStringAsFixed(0)} FCFA',
                      style: pw.TextStyle(
                          fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ],
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5),

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

          // ── Section MECeF (DGI Bénin) ────────────────────────────────
          if (showMecef) ...[
            pw.Divider(thickness: 1.0),
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FACTURE NORMALISEE',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.Text(
                  invoice.mecefStatus.label.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            if (hasMecef) ...[
              // Code Unique
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Code MECeF/DGI :',
                      style: const pw.TextStyle(fontSize: 5.8)),
                  pw.SizedBox(width: 3),
                  pw.Expanded(
                    child: pw.Text(
                      invoice.mecefCU ?? '',
                      style: pw.TextStyle(
                        fontSize: 5.8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              // NIM
              if ((invoice.mecefNim ?? '').isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MECeF NIM :',
                        style: const pw.TextStyle(fontSize: 5.8)),
                    pw.Text(invoice.mecefNim!,
                        style: const pw.TextStyle(fontSize: 5.8)),
                  ],
                ),
              ],
              // Compteur
              if ((invoice.mecefCompteur ?? '').isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MECeF Compteur :',
                        style: const pw.TextStyle(fontSize: 5.8)),
                    pw.Text(invoice.mecefCompteur!,
                        style: const pw.TextStyle(fontSize: 5.8)),
                  ],
                ),
              ],
              // Heure
              if ((invoice.mecefDatetime ?? '').isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MECeF Heure :',
                        style: const pw.TextStyle(fontSize: 5.8)),
                    pw.Text(
                      _formatMecefDateSec(invoice.mecefDatetime!),
                      style: const pw.TextStyle(fontSize: 5.8),
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 5),
              // QR code
              pw.Center(
                child: pw.BarcodeWidget(
                  data: invoice.mecefCU!,
                  barcode: pw.Barcode.qrCode(),
                  width: 58,
                  height: 58,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'Scannez pour verifier aupres de la DGI',
                  style: const pw.TextStyle(fontSize: 5.2),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ] else ...[
              pw.Center(
                child: pw.Text(
                  'Certification DGI en attente de connexion.',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'Le QR code sera disponible apres synchronisation.',
                  style: const pw.TextStyle(fontSize: 5.5),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1.0),
          ],

          // ── Code-barres Code128 ───────────────────────────────────────
          pw.SizedBox(height: 3),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatMecefDate(String iso) {
  try {
    return _dateFmt.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

String _formatMecefDateSec(String iso) {
  try {
    return _dateFmtSec.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

String _ascii(String s) => s
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('–', '-')
    .replaceAll('—', '-')
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
