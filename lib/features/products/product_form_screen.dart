import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/product.dart';
import '../../data/product_extras_repository.dart';
import '../../core/utils/plan_quota.dart';
import '../../data/offline_storage.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _picker = ImagePicker();
  String? _imagePath;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    setState(() => _imagePath = x.path);
  }

  Future<void> _takePhoto() async {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600);
    if (x == null) return;
    setState(() => _imagePath = x.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authProvider);
    if (auth == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // ── Récupérer la liste actuelle (avec fallback cache) ──────────────
      List existing;
      try {
        existing = await ref
            .read(productsRepositoryProvider)
            .listProducts(auth.companyId);
      } catch (_) {
        existing = await OfflineStorage().loadProducts(auth.companyId);
      }

      // ── Contrôle doublon ───────────────────────────────────────────────
      final normalizedName = _nameCtrl.text.trim().toLowerCase();
      final duplicate = existing.any(
        (product) => product.name.trim().toLowerCase() == normalizedName,
      );
      if (duplicate) {
        throw Exception(
          'Un produit avec le libellé "${_nameCtrl.text.trim()}" existe déjà.\n'
          'Choisissez un nom différent.',
        );
      }

      // ── Contrôle quota plan ────────────────────────────────────────────
      final plan = auth.plan.isEmpty ? 'free' : auth.plan;
      final quotaCheck = checkProductQuota(
        plan: plan,
        existingCount: existing.length,
      );
      if (!quotaCheck.allowed) {
        throw Exception(quotaCheck.errorMessage);
      }
      final price = double.parse(_priceCtrl.text.replaceAll(',', '.'));
      final stock = int.parse(_stockCtrl.text.trim());
      final repo = ref.read(productsRepositoryProvider);
      final erpRepo = ref.read(erpProductsRepositoryProvider);
      final extrasRepo = ref.read(productExtrasRepositoryProvider);
      final imgService = ref.read(productImageServiceProvider);
      final product = Product(
        id: '',
        companyId: auth.companyId,
        name: _nameCtrl.text.trim(),
        price: price,
        stock: stock,
      );
      final saved = await repo.upsert(product);
      var syncedRemotely = true;
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        final persisted = await imgService.persistReferenceImage(
          companyId: auth.companyId,
          productId: saved.id,
          sourcePath: _imagePath!,
        );
        await extrasRepo.set(
          companyId: auth.companyId,
          productId: saved.id,
          extras: ProductExtras(
            referenceImagePath: persisted.path,
            referenceImageHash: persisted.sha256,
            pendingUpload: true,
          ),
        );
        await repo.upsert(
          saved.copyWith(
            referenceImagePath: persisted.path,
            referenceImageHash: persisted.sha256,
          ),
        );
        try {
          await erpRepo.uploadProductImage(
            companyId: auth.companyId,
            productId: saved.id,
            sourcePath: persisted.path,
            referenceImageHash: persisted.sha256,
          );
          await extrasRepo.markUploadSynced(
            companyId: auth.companyId,
            productId: saved.id,
          );
        } catch (_) {
          syncedRemotely = false;
        }
      }
      if (!mounted) return;
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedRemotely
                  ? 'Produit et image sauvegardes'
                  : 'Produit sauvegarde localement. Image en attente de synchronisation.',
            ),
          ),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      final msg = e.toString();
      final isNetwork = msg.contains('SocketException') ||
          msg.contains('ClientException') ||
          msg.contains('Connection') ||
          msg.contains('Network is unreachable');
      if (isNetwork) {
        // Produit sauvegardé offline par le repo — on ferme et on informe
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produit enregistré hors connexion — sera synchronisé automatiquement.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() => _error = msg
            .replaceAll('Exception: ', '')
            .replaceAll('Exception(', '')
            .replaceFirst(RegExp(r'\)$'), ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau produit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Prix (FCFA)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  final p = double.tryParse(v.replaceAll(',', '.'));
                  if (p == null || p < 0) return 'Prix invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  final s = int.tryParse(v.trim());
                  if (s == null || s < 0) return 'Stock invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Image de référence (anti-fraude)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galerie'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Photo'),
                  ),
                ],
              ),
              if (_imagePath != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.4),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}