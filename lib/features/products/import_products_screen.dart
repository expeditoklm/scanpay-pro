import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/csv_products_parser.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';
import 'products_providers.dart';

class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  ConsumerState<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen> {
  bool _loading = false;
  List<String> _errors = const [];
  int _imported = 0;

  Future<void> _pickAndImport() async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    setState(() {
      _loading = true;
      _errors = const [];
      _imported = 0;
    });

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final bytes = res.files.first.bytes;
      if (bytes == null) {
        setState(() => _errors = const ['Impossible de lire le fichier (bytes null).']);
        return;
      }

      final parsed = parseProductsCsvBytes(bytes: bytes, companyId: auth.companyId);
      if (parsed.errors.isNotEmpty) {
        setState(() => _errors = parsed.errors);
        return;
      }

      final repo = ref.read(productsRepositoryProvider);
      await repo.bulkUpsert(auth.companyId, parsed.products);
      ref.invalidate(productsListProvider);
      setState(() => _imported = parsed.products.length);
    } catch (e) {
      setState(() => _errors = [e.toString()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer des produits (CSV)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Format CSV attendu (en-têtes obligatoires): name, price, stock.\n'
              'Optionnel: id, sku, description.\n'
              'Le companyId est appliqué automatiquement (multi-tenant).',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _pickAndImport,
              icon: const Icon(Icons.upload_file),
              label: _loading ? const Text('Import en cours...') : const Text('Choisir un CSV et importer'),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_imported > 0) ...[
              const SizedBox(height: 12),
              Text('Import terminé: $_imported produit(s).', style: Theme.of(context).textTheme.titleMedium),
            ],
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Erreurs:', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _errors.length,
                  itemBuilder: (context, i) => Text('• ${_errors[i]}'),
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

