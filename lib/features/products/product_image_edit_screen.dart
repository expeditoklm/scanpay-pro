import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/product.dart';
import '../../core/utils/product_image.dart';
import '../../data/product_extras_repository.dart';
import '../../data/repository_providers.dart';

class ProductImageEditScreen extends ConsumerStatefulWidget {
  const ProductImageEditScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductImageEditScreen> createState() => _ProductImageEditScreenState();
}

class _ProductImageEditScreenState extends ConsumerState<ProductImageEditScreen> {
  final _picker = ImagePicker();
  String? _tmpPath;
  bool _saving = false;
  String? _error;

  Future<void> _takeOrPick(ImageSource source) async {
    final x = await _picker.pickImage(source: source, maxWidth: 1600);
    if (x == null) return;
    setState(() {
      _tmpPath = x.path;
      _error = null;
    });
  }

  Future<void> _save() async {
    final tmp = _tmpPath;
    if (tmp == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final img = ref.read(productImageServiceProvider);
      final erpRepo = ref.read(erpProductsRepositoryProvider);
      final extrasRepo = ref.read(productExtrasRepositoryProvider);
      final saved = await img.persistReferenceImage(
        companyId: widget.product.companyId,
        productId: widget.product.id,
        sourcePath: tmp,
      );

      await extrasRepo.set(
        companyId: widget.product.companyId,
        productId: widget.product.id,
        extras: ProductExtras(
          referenceImagePath: saved.path,
          referenceImageHash: saved.sha256,
          pendingUpload: true,
        ),
      );

      final repo = ref.read(productsRepositoryProvider);
      await repo.upsert(
        widget.product.copyWith(
          referenceImagePath: saved.path,
          referenceImageHash: saved.sha256,
        ),
      );
      var syncedRemotely = true;
      try {
        await erpRepo.uploadProductImage(
          companyId: widget.product.companyId,
          productId: widget.product.id,
          sourcePath: saved.path,
          referenceImageHash: saved.sha256,
        );
        await extrasRepo.markUploadSynced(
          companyId: widget.product.companyId,
          productId: widget.product.id,
        );
      } catch (_) {
        syncedRemotely = false;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedRemotely
                ? 'Image sauvegardée'
                : 'Image sauvegardée localement. Synchronisation serveur en attente.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier image')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.product.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _tmpPath != null
                    ? Image.file(File(_tmpPath!), fit: BoxFit.cover)
                    : buildProductImage(
                        product: widget.product,
                        fit: BoxFit.cover,
                        fallback: Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 42)),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _takeOrPick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galerie'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _takeOrPick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_tmpPath == null || _saving) ? null : _save,
              child: _saving
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer l’image'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
