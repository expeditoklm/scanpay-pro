import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/product.dart';
import '../../core/utils/product_image.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/utils/qr_hmac.dart';
import '../auth/auth_provider.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth == null) return const SizedBox.shrink();

    final payload = QrPayload(
      version: 1,
      productId: product.id,
      companyId: product.companyId,
      signatureHex: hmacSignProductCompany(
        productId: product.id,
        companyId: product.companyId,
        secretKey: auth.secretKey,
      ),
    );
    final qrData = encodeQrJson(payload);

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(formatPriceEuro(product.price), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Stock : ${product.stock}', style: Theme.of(context).textTheme.bodyLarge),
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
            ],
            const SizedBox(height: 24),
            Text('QR sécurisé (HMAC)', style: Theme.of(context).textTheme.titleMedium),
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
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              qrData,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Impression étiquette'),
                    content: const Text(
                      'Branchez une imprimante thermique et utilisez le service d’impression '
                      '(à brancher dans core/services) ou partagez une capture du QR.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Impression (placeholder)'),
            ),
          ],
        ),
      ),
    );
  }
}
