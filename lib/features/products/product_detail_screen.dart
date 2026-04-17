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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
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
                icon: const Icon(Icons.image_outlined),
                label: const Text('Modifier l image du produit'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
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
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Ajouter une image produit'),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: previewQrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
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
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de QR'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantite a generer',
            hintText: 'Ex: 12',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = int.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(quantity);
            },
            child: const Text('Generer'),
          ),
        ],
      ),
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
