import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../../core/services/xprinter_service.dart';

class XPrinterConfigSheet extends StatefulWidget {
  const XPrinterConfigSheet({super.key});

  @override
  State<XPrinterConfigSheet> createState() => _XPrinterConfigSheetState();
}

class _XPrinterConfigSheetState extends State<XPrinterConfigSheet> {
  final XPrinterService _service = const XPrinterService();
  late Future<List<XPrinterDevice>> _devicesFuture;
  XPrinterDevice? _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _devicesFuture = _service.pairedPrinters();
    _service.savedPrinter().then((printer) {
      if (mounted) setState(() => _saved = printer);
    });
  }

  Future<void> _select(XPrinterDevice device) async {
    setState(() => _saving = true);
    await _service.savePrinter(device);
    if (!mounted) return;
    setState(() {
      _saved = device;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${device.name} configuree pour les recus')),
    );
  }

  Future<void> _clear() async {
    await _service.clearPrinter();
    if (!mounted) return;
    setState(() => _saved = null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Configuration device',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _saved == null
                  ? 'Associez votre XPrinter au Bluetooth du telephone, puis selectionnez-la ici.'
                  : 'Imprimante active: ${_saved!.name}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      AppSettings.openAppSettings(
                        type: AppSettingsType.bluetooth,
                      );
                    },
                    icon: const Icon(Icons.bluetooth_rounded),
                    label: const Text('Bluetooth'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Actualiser',
                  onPressed: () => setState(_load),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<XPrinterDevice>>(
              future: _devicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final devices = snapshot.data ?? const [];
                if (devices.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Aucune imprimante appairee trouvee. Appairez la XPrinter dans Bluetooth puis actualisez.',
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final selected = _saved?.mac == device.mac;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.print_rounded,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(device.name),
                        subtitle: Text(device.mac),
                        trailing: selected
                            ? const Text('Active')
                            : const Icon(Icons.chevron_right_rounded),
                        enabled: !_saving,
                        onTap: () => _select(device),
                      );
                    },
                  ),
                );
              },
            ),
            if (_saved != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Retirer cette imprimante'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
