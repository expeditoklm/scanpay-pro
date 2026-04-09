import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/product.dart';
import '../../core/services/image_label_match.dart';
import '../../core/utils/product_image.dart';
import '../../data/repository_providers.dart';

class AntiFraudSheet extends ConsumerStatefulWidget {
  const AntiFraudSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<AntiFraudSheet> createState() => _AntiFraudSheetState();
}

class _AntiFraudSheetState extends ConsumerState<AntiFraudSheet> {
  final _picker = ImagePicker();
  String? _livePath;
  bool _loading = false;
  double? _score;
  String? _error;
  String? _resolvedReferencePath;

  Future<void> _capture() async {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600);
    if (x == null) return;
    setState(() {
      _livePath = x.path;
      _score = null;
      _error = null;
    });
  }

  Future<String?> _resolveReferencePath() async {
    final service = ref.read(productImageServiceProvider);
    final saved = await service.ensureLocalReferenceImage(
      companyId: widget.product.companyId,
      productId: widget.product.id,
      localPath: widget.product.referenceImagePath,
      remoteUrl: widget.product.referenceImageUrl,
    );
    return saved?.path;
  }

  Future<void> _runCompare() async {
    final live = _livePath;
    if (live == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final refPath = await _resolveReferencePath();
      if (refPath == null) {
        setState(() => _error = 'Aucune image de référence disponible pour la vérification.');
        return;
      }

      final score = await ImageLabelMatch.similarityScore(refPath, live);
      if (!mounted) return;
      setState(() {
        _resolvedReferencePath = refPath;
        _score = score;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReferenceImage =
        (widget.product.referenceImagePath ?? '').isNotEmpty ||
        (widget.product.referenceImageUrl ?? '').isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Anti-fraude — ${widget.product.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Comparez une photo du produit avec l’image de référence. '
              'Si l’image vient du web, elle sera téléchargée localement avant la vérification ML Kit.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (hasReferenceImage)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Référence'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _resolvedReferencePath != null
                                ? Image.file(File(_resolvedReferencePath!), fit: BoxFit.cover)
                                : buildProductImage(
                                    product: widget.product,
                                    fit: BoxFit.cover,
                                    fallback: Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.image_not_supported_outlined, size: 42),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Caisse'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _livePath != null
                                ? Image.file(File(_livePath!), fit: BoxFit.cover)
                                : Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.photo_camera_outlined, size: 48),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              const Text('Pas d’image de référence : validation ignorée.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _capture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Prendre une photo'),
            ),
            if (hasReferenceImage && _livePath != null) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loading ? null : _runCompare,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Comparer (ML Kit)'),
              ),
            ],
            if (_score != null) ...[
              const SizedBox(height: 12),
              Text(
                'Score de similarité : ${(_score! * 100).toStringAsFixed(0)} %',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                _score! >= 0.25
                    ? 'Correspondance acceptable.'
                    : 'Écart important, vérifiez le produit.',
                style: TextStyle(
                  color: _score! >= 0.25
                      ? Colors.green.shade800
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Passer (démo)'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: !hasReferenceImage
                      ? () => Navigator.of(context).pop(true)
                      : (_livePath != null && (_score ?? 0) >= 0.25)
                          ? () => Navigator.of(context).pop(true)
                          : null,
                  child: const Text('Valider'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
