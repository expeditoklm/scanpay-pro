import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/product.dart';
import '../../core/utils/csv_products_parser.dart';
import '../../core/utils/plan_quota.dart';
import '../../core/utils/spreadsheet_products_parser.dart';
import '../../data/offline_storage.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';
import 'products_providers.dart';

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
  // Résumé de ce qui a été importé vs ignoré
  int _skippedDuplicate = 0;
  int _skippedQuota = 0;

  Future<void> _pickAndImport() async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    setState(() {
      _loading = true;
      _errors = const [];
      _imported = 0;
      _skippedDuplicate = 0;
      _skippedQuota = 0;
    });

    try {
      // ── 1. Sélection du fichier ─────────────────────────────────────────
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _errors = ['Impossible de lire le fichier sélectionné.']);
        return;
      }

      // ── 2. Parsing CSV / XLSX ───────────────────────────────────────────
      final extension = (file.extension ?? '').toLowerCase();
      final parsed = extension == 'xlsx'
          ? parseProductsSpreadsheetBytes(bytes: bytes, companyId: auth.companyId)
          : parseProductsCsvBytes(bytes: bytes, companyId: auth.companyId);

      final parseErrors = List<String>.from(parsed.errors);
      if (parsed.products.isEmpty) {
        setState(() => _errors = parseErrors.isNotEmpty
            ? parseErrors
            : ['Aucun produit valide trouvé dans le fichier.']);
        return;
      }

      // ── 3. Récupérer le catalogue actuel (serveur + offline) ────────────
      final storage = OfflineStorage();
      List<Product> existing;
      try {
        existing = await ref
            .read(productsRepositoryProvider)
            .listProducts(auth.companyId);
      } catch (_) {
        existing = await storage.loadProducts(auth.companyId);
      }

      final existingCount = existing.length;
      final existingNames = existing
          .map((p) => p.name.trim().toLowerCase())
          .toSet();

      // ── 4. Contrôle quota global ────────────────────────────────────────
      final plan = auth.plan.isEmpty ? 'free' : auth.plan;
      final quotaCheck = checkProductQuota(
        plan: plan,
        existingCount: existingCount,
        toAdd: parsed.products.length,
      );

      if (!quotaCheck.allowed) {
        // On calcule combien on peut encore accepter
        final remaining = quotaCheck.limit - existingCount;
        if (remaining <= 0) {
          // Plus aucune place — blocage total
          setState(() => _errors = [quotaCheck.errorMessage]);
          return;
        }
        // On tronque au nombre restant et on prévient
        parseErrors.add(
          'Quota plan $plan : $remaining produit${remaining > 1 ? 's' : ''} restant${remaining > 1 ? 's' : ''} '
          '(limite ${ quotaCheck.limit}). '
          'Les ${parsed.products.length - remaining} produit${parsed.products.length - remaining > 1 ? 's' : ''} '
          'en excès ont été ignorés.',
        );
        _skippedQuota = parsed.products.length - remaining;
      }

      // ── 5. Filtrage doublon + application quota ligne à ligne ───────────
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
          parseErrors.add('Doublon ignoré : "${product.name}"');
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
              : ['Aucun produit à importer (doublons ou quota atteint).'];
        });
        return;
      }

      // ── 6. Import effectif ──────────────────────────────────────────────
      await repo.bulkUpsert(auth.companyId, toImport);
      ref.invalidate(productsListProvider);

      if (!mounted) return;
      setState(() {
        _imported = toImport.length;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Importer des produits')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Info format fichier ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Formats acceptés : CSV et Excel (.xlsx)\n'
                'Colonnes obligatoires : name, price, stock\n'
                'Colonnes optionnelles : sku, description\n'
                'Les doublons (même libellé) sont automatiquement ignorés.',
              ),
            ),
            const SizedBox(height: 16),

            // ── Bouton import ────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _loading ? null : _pickAndImport,
              icon: const Icon(Icons.upload_file),
              label: Text(_loading ? 'Import en cours…' : 'Choisir un fichier'),
            ),

            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],

            // ── Résultat succès ──────────────────────────────────────────
            if (_imported > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$_imported produit${_imported > 1 ? 's' : ''} importé${_imported > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    if (_skippedDuplicate > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$_skippedDuplicate doublon${_skippedDuplicate > 1 ? 's' : ''} ignoré${_skippedDuplicate > 1 ? 's' : ''}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ],
                    if (_skippedQuota > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$_skippedQuota produit${_skippedQuota > 1 ? 's' : ''} ignoré${_skippedQuota > 1 ? 's' : ''} (quota)',
                        style:
                            TextStyle(fontSize: 12, color: Colors.orange.shade700),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── Erreurs / avertissements ─────────────────────────────────
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _imported > 0
                        ? Colors.orange.shade50
                        : colorScheme.errorContainer.withOpacity(0.3),
                    border: Border.all(
                      color: _imported > 0
                          ? Colors.orange.shade300
                          : colorScheme.error.withOpacity(0.4),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _errors.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${_errors[i]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _imported > 0
                              ? Colors.orange.shade900
                              : colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}