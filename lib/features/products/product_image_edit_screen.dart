import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/product.dart';
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
      final saved = await img.persistReferenceImage(
        companyId: widget.product.companyId,
        productId: widget.product.id,
        sourcePath: tmp,
      );

      final repo = ref.read(productsRepositoryProvider);
      await repo.upsert(
        widget.product.copyWith(
          referenceImagePath: saved.path,
          referenceImageHash: saved.sha256,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image sauvegardée')),
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
    final current = widget.product.referenceImagePath;

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
                    : (current != null && current.isNotEmpty)
                        ? Image.file(File(current), fit: BoxFit.cover)
                        : Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 42)),
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

