import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/product.dart';
import '../../core/utils/csv_products_parser.dart';
import '../../core/utils/plan_quota.dart';
import '../../core/utils/spreadsheet_products_parser.dart';
import '../../core/utils/zip_products_import_parser.dart';
import '../../data/offline_storage.dart';
import '../../data/product_extras_repository.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';
import 'products_providers.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBlue1  = Color(0xFF1565D8);
const _kBlue2  = Color(0xFF0D47A1);
const _kTeal   = Color(0xFF22C1C3);
const _kBg     = Color(0xFFF0F4FA);
const _kCard   = Colors.white;
const _kBorder = Color(0xFFD7E2F2);

class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  ConsumerState<ImportProductsScreen> createState() =>
      _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen> {
  bool _loading = false;
  List<String> _errors = const [];
  int _imported = 0;
  int _skippedDuplicate = 0;
  int _skippedQuota = 0;
  int _importedImages = 0;

  Future<void> _pickAndImport() async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    setState(() {
      _loading = true;
      _errors = const [];
      _imported = 0;
      _skippedDuplicate = 0;
      _skippedQuota = 0;
      _importedImages = 0;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _errors = ['Impossible de lire le fichier selectionne.']);
        return;
      }

      final extension = (file.extension ?? '').toLowerCase();
      final parsed = extension == 'zip'
          ? await parseProductsZipBytes(bytes: bytes, companyId: auth.companyId)
          : extension == 'xlsx'
              ? parseProductsSpreadsheetBytes(
                  bytes: bytes, companyId: auth.companyId)
              : parseProductsCsvBytes(bytes: bytes, companyId: auth.companyId);

      final parseErrors = List<String>.from(parsed.errors);
      if (parsed.products.isEmpty) {
        setState(() => _errors = parseErrors.isNotEmpty
            ? parseErrors
            : ['Aucun produit valide trouve dans le fichier.']);
        return;
      }

      List<Product> existing;
      try {
        existing = await ref
            .read(productsRepositoryProvider)
            .listProducts(auth.companyId);
      } catch (_) {
        existing = await OfflineStorage().loadProducts(auth.companyId);
      }

      final existingCount = existing.length;
      final existingNames =
          existing.map((p) => p.name.trim().toLowerCase()).toSet();
      final plan = auth.plan.isEmpty ? 'free' : auth.plan;
      final quotaCheck = checkProductQuota(
        plan: plan,
        existingCount: existingCount,
        toAdd: parsed.products.length,
      );

      if (!quotaCheck.allowed) {
        final remaining = quotaCheck.limit - existingCount;
        if (remaining <= 0) {
          setState(() => _errors = [quotaCheck.errorMessage]);
          return;
        }
        parseErrors.add(
          'Quota plan $plan : $remaining produit${remaining > 1 ? 's' : ''} restant${remaining > 1 ? 's' : ''} '
          '(limite ${quotaCheck.limit}). '
          'Les ${parsed.products.length - remaining} produit${parsed.products.length - remaining > 1 ? 's' : ''} '
          'en exces ont ete ignores.',
        );
        _skippedQuota = parsed.products.length - remaining;
      }

      final repo = ref.read(productsRepositoryProvider);
      final toImport = <Product>[];
      final namesAdding = <String>{};
      int slotsLeft = quotaCheck.limit - existingCount;

      for (final product in parsed.products) {
        if (slotsLeft <= 0) {
          _skippedQuota++;
          continue;
        }
        final nameKey = product.name.trim().toLowerCase();
        if (existingNames.contains(nameKey) || namesAdding.contains(nameKey)) {
          _skippedDuplicate++;
          parseErrors.add('Doublon ignore : "${product.name}"');
          continue;
        }
        toImport.add(product);
        namesAdding.add(nameKey);
        slotsLeft--;
      }

      if (toImport.isEmpty) {
        setState(() {
          _errors = parseErrors.isNotEmpty
              ? parseErrors
              : ['Aucun produit a importer (doublons ou quota atteint).'];
        });
        return;
      }

      final erpRepo = ref.read(erpProductsRepositoryProvider);
      final extrasRepo = ref.read(productExtrasRepositoryProvider);
      final imageService = ref.read(productImageServiceProvider);
      var importedImages = 0;
      for (final product in toImport) {
        final saved = await repo.upsert(product);
        final imagePath = product.referenceImagePath;
        if (imagePath == null || imagePath.isEmpty || !File(imagePath).existsSync()) {
          continue;
        }

        final persisted = await imageService.persistReferenceImage(
          companyId: auth.companyId,
          productId: saved.id,
          sourcePath: imagePath,
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
        await repo.upsert(saved.copyWith(
          referenceImagePath: persisted.path,
          referenceImageHash: persisted.sha256,
        ));
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
          importedImages++;
        } catch (_) {
          parseErrors.add('Image de "${product.name}" en attente de synchronisation.');
        }
      }
      ref.invalidate(productsListProvider);
      if (!mounted) return;
      setState(() {
        _imported = toImport.length;
        _importedImages = importedImages;
        _errors = parseErrors;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errors = [error.toString()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDone = _imported > 0;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Header dégradé ────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kBlue2, _kBlue1, _kTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.upload_file_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Importer des produits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'CSV, Excel ou ZIP avec images',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Corps ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Guide format ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A0F172A),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 16, color: _kBlue1),
                              SizedBox(width: 8),
                              Text(
                                'Structure du fichier',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.check_circle_outline_rounded,
                            color: const Color(0xFF059669),
                            label: 'Formats acceptes',
                            value: 'CSV, Excel (.xlsx) et ZIP',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.star_rounded,
                            color: _kBlue1,
                            label: 'Colonnes obligatoires',
                            value: 'name, price, stock',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.tune_rounded,
                            color: const Color(0xFF7C3AED),
                            label: 'Colonnes optionnelles',
                            value: 'sku, description, image_url',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.image_outlined,
                            color: const Color(0xFFDB2777),
                            label: 'Image par produit',
                            value: 'image_url ou ZIP + image_file',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.copy_rounded,
                            color: const Color(0xFFF59E0B),
                            label: 'Doublons',
                            value: 'Ignores automatiquement',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Bouton choisir fichier ─────────────────────────
                    GestureDetector(
                      onTap: _loading ? null : _pickAndImport,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: _loading
                              ? null
                              : const LinearGradient(
                                  colors: [_kBlue2, _kBlue1, Color(0xFF64B5F6)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: _loading
                              ? const Color(0xFFE2E8F0)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _loading
                              ? null
                              : [
                                  BoxShadow(
                                    color: _kBlue1.withOpacity(0.30),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: _loading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: _kBlue1),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Import en cours...',
                                    style: TextStyle(
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload_file_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Choisir un fichier',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // ── Résultat succès ────────────────────────────────
                    if (hasDone) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF6EE7B7)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_imported produit${_imported > 1 ? 's' : ''} importe${_imported > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                  if (_skippedDuplicate > 0)
                                    Text(
                                      '$_skippedDuplicate doublon${_skippedDuplicate > 1 ? 's' : ''} ignore${_skippedDuplicate > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF059669)),
                                    ),
                                  if (_importedImages > 0)
                                    Text(
                                      '$_importedImages image${_importedImages > 1 ? 's' : ''} associe${_importedImages > 1 ? 'es' : 'e'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  if (_skippedQuota > 0)
                                    Text(
                                      '$_skippedQuota ignore${_skippedQuota > 1 ? 's' : ''} (quota)',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFF59E0B)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Erreurs / avertissements ───────────────────────
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: hasDone
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: hasDone
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFFDA4AF),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  hasDone
                                      ? Icons.warning_amber_rounded
                                      : Icons.error_outline_rounded,
                                  size: 16,
                                  color: hasDone
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hasDone
                                      ? 'Avertissements'
                                      : 'Erreurs d\'import',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: hasDone
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF9F1239),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ..._errors.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: TextStyle(
                                        color: hasDone
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFFE11D48),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        e,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: hasDone
                                              ? const Color(0xFF92400E)
                                              : const Color(0xFFBE123C),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ligne d'info ─────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
