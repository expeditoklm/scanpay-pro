import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/erp_config.dart';
import '../../core/models/product.dart';
import '../../core/utils/product_image.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/utils/qr_hmac.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import 'product_codes_pdf.dart';
import 'product_image_edit_screen.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth == null) return const SizedBox.shrink();

    final previewPayload = QrPayload(
      version: 2,
      productId: product.id,
      companyId: product.companyId,
      authCode: product.consumerCode,
      signatureHex: hmacSignProductCompany(
        productId: product.id,
        companyId: product.companyId,
        secretKey: auth.secretKey,
        authCode: product.consumerCode,
      ),
    );
    final previewQrData = encodeQrJson(previewPayload);

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatPriceEuro(product.price),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Stock : ${product.stock}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if ((product.referenceImagePath ?? '').isNotEmpty ||
                (product.referenceImageUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: buildProductImage(
                        product: product,
                        fit: BoxFit.cover,
                        fallback: Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined, size: 42),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () async {
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ProductImageEditScreen(product: product),
                          ),
                        );
                        if (updated == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image produit mise a jour')),
                          );
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x441565D8),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final updated = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ProductImageEditScreen(product: product),
                    ),
                  );
                  if (updated == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image produit ajoutee')),
                    );
                  }
                },
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD7E2F2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 30,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ajouter une image',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'QR de vente et de provenance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD7E2F2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: previewQrData,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'QuickSellPay — QR Authentique',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Le QR imprime pour les etiquettes ouvre la plateforme publique hors APK et reste lisible par l APK pour la vente.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openQrSheetFlow(context, ref, auth),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generer des QR en PDF A4'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQrSheetFlow(
    BuildContext context,
    WidgetRef ref,
    AuthState auth,
  ) async {
    final quantity = await _askQuantity(context);
    if (quantity == null || quantity <= 0 || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final entries = await _generateQrEntries(auth, quantity);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Planche QR A4')),
            body: PdfPreview(
              build: (_) => buildProductCodesPdf(
                product: product,
                companyName: auth.companyName,
                entries: entries,
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<int?> _askQuantity(BuildContext context) async {
    final controller = TextEditingController(text: '12');
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QrQuantitySheet(controller: controller),
    );
  }

  Future<List<ProductQrSheetEntry>> _generateQrEntries(
    AuthState auth,
    int quantity,
  ) async {
    final response = await http
        .post(
          Uri.parse('$kErpBaseUrl/api/products/${product.id}/generate-codes'),
          headers: auth.authHeaders,
          body: jsonEncode({'quantity': quantity}),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString() ?? 'Generation impossible'
          : 'Generation impossible';
      throw Exception(detail);
    }
    if (decoded is! List) {
      throw Exception('Reponse de generation invalide');
    }

    return decoded.map<ProductQrSheetEntry>((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final code = map['code']?.toString() ?? '';
      final payload = QrPayload(
        version: 2,
        productId: product.id,
        companyId: product.companyId,
        authCode: code,
        signatureHex: hmacSignProductCompany(
          productId: product.id,
          companyId: product.companyId,
          secretKey: auth.secretKey,
          authCode: code,
        ),
      );
      return ProductQrSheetEntry(
        code: code,
        qrData: encodePublicQrUrl(
          baseUrl: kErpBaseUrl,
          payload: payload,
        ),
      );
    }).toList();
  }
}

// ─── Bottom sheet : saisie quantité QR ───────────────────────────────────────
class _QrQuantitySheet extends StatelessWidget {
  const _QrQuantitySheet({required this.controller});
  final TextEditingController controller;

  static const _kBlue1 = Color(0xFF1565D8);
  static const _kBlue2 = Color(0xFF0D47A1);
  static const _kTeal  = Color(0xFF22C1C3);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Header dégradé ──────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kBlue2, _kBlue1, _kTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  children: [
                    // Pill
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generer des QR codes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Choisissez la quantite a imprimer',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Corps ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Champ quantité
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantite',
                        labelStyle: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFE8F0FE),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: _kBlue1.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: _kBlue1, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Text(
                      'Chaque QR code est unique et signe cryptographiquement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 22),

                    // Boutons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(
                                  color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Annuler',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              final qty = int.tryParse(
                                  controller.text.trim());
                              Navigator.of(context).pop(qty);
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_kBlue2, _kBlue1, _kTeal],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kBlue1.withOpacity(0.30),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Generer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
