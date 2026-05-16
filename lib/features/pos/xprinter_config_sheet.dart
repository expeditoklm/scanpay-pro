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
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '9100',
  );
  late Future<List<XPrinterDevice>> _bluetoothFuture;
  late Future<List<XPrinterDevice>> _usbFuture;
  XPrinterDevice? _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _load() {
    _bluetoothFuture = _service.pairedPrinters();
    _usbFuture = _service.usbPrinters();
    _service.savedPrinter().then((printer) {
      if (!mounted) return;
      setState(() {
        _saved = printer;
        if (printer?.type == XPrinterConnectionType.network) {
          _hostController.text = printer?.host ?? '';
          _portController.text = '${printer?.port ?? 9100}';
        }
      });
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

  Future<void> _saveNetworkPrinter() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;
    if (host.isEmpty || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse IP ou port invalide')),
      );
      return;
    }
    await _select(
      _service.networkPrinter(
        host: host,
        port: port,
        name: 'XPrinter $host',
      ),
    );
  }

  Future<void> _clear() async {
    await _service.clearPrinter();
    if (!mounted) return;
    setState(() => _saved = null);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      child: DefaultTabController(
        length: 3,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configuration imprimante',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _saved == null
                      ? 'Choisissez une connexion pour les recus.'
                      : 'Imprimante active: ${_saved!.name} (${_saved!.subtitle})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.bluetooth_rounded), text: 'Bluetooth'),
                    Tab(icon: Icon(Icons.wifi_rounded), text: 'LAN'),
                    Tab(icon: Icon(Icons.usb_rounded), text: 'USB'),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: TabBarView(
                    children: [
                      _BluetoothPrinterTab(
                        devicesFuture: _bluetoothFuture,
                        saved: _saved,
                        saving: _saving,
                        onRefresh: () => setState(_load),
                        onSelect: _select,
                      ),
                      _NetworkPrinterTab(
                        hostController: _hostController,
                        portController: _portController,
                        saving: _saving,
                        onSave: _saveNetworkPrinter,
                      ),
                      _UsbPrinterTab(
                        devicesFuture: _usbFuture,
                        saved: _saved,
                        saving: _saving,
                        onRefresh: () => setState(_load),
                        onSelect: _select,
                      ),
                    ],
                  ),
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
        ),
      ),
    );
  }
}

class _BluetoothPrinterTab extends StatelessWidget {
  const _BluetoothPrinterTab({
    required this.devicesFuture,
    required this.saved,
    required this.saving,
    required this.onRefresh,
    required this.onSelect,
  });

  final Future<List<XPrinterDevice>> devicesFuture;
  final XPrinterDevice? saved;
  final bool saving;
  final VoidCallback onRefresh;
  final ValueChanged<XPrinterDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                },
                icon: const Icon(Icons.bluetooth_rounded),
                label: const Text('Bluetooth'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Actualiser',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _PrinterList(
            devicesFuture: devicesFuture,
            emptyText:
                'Aucune imprimante appairee trouvee. Appairez la XPrinter dans Bluetooth puis actualisez.',
            saved: saved,
            saving: saving,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

class _NetworkPrinterTab extends StatelessWidget {
  const _NetworkPrinterTab({
    required this.hostController,
    required this.portController,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController hostController;
  final TextEditingController portController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextField(
          controller: hostController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Adresse IP',
            hintText: '192.168.1.50',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.router_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: portController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Port',
            hintText: '9100',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.settings_ethernet_rounded),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Enregistrer LAN / Wi-Fi'),
        ),
      ],
    );
  }
}

class _UsbPrinterTab extends StatelessWidget {
  const _UsbPrinterTab({
    required this.devicesFuture,
    required this.saved,
    required this.saving,
    required this.onRefresh,
    required this.onSelect,
  });

  final Future<List<XPrinterDevice>> devicesFuture;
  final XPrinterDevice? saved;
  final bool saving;
  final VoidCallback onRefresh;
  final ValueChanged<XPrinterDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton.filledTonal(
            tooltip: 'Actualiser',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _PrinterList(
            devicesFuture: devicesFuture,
            emptyText:
                'Aucune imprimante USB detectee. Branchez la XPrinter avec un adaptateur OTG puis actualisez.',
            saved: saved,
            saving: saving,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

class _PrinterList extends StatelessWidget {
  const _PrinterList({
    required this.devicesFuture,
    required this.emptyText,
    required this.saved,
    required this.saving,
    required this.onSelect,
  });

  final Future<List<XPrinterDevice>> devicesFuture;
  final String emptyText;
  final XPrinterDevice? saved;
  final bool saving;
  final ValueChanged<XPrinterDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XPrinterDevice>>(
      future: devicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final devices = snapshot.data ?? const [];
        if (devices.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(emptyText),
          );
        }
        return ListView.separated(
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = devices[index];
            final selected = saved?.storageValue == device.storageValue;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                selected ? Icons.check_circle_rounded : Icons.print_rounded,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(device.name),
              subtitle: Text(device.subtitle),
              trailing:
                  selected ? const Text('Active') : const Icon(Icons.chevron_right_rounded),
              enabled: !saving,
              onTap: () => onSelect(device),
            );
          },
        );
      },
    );
  }
}
