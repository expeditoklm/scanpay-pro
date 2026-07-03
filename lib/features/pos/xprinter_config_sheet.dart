import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../../core/services/xprinter_service.dart';

// ─── Palette dégradé bleu cohérente avec l'app ───────────────────────────────
const _kBlue1 = Color(0xFF1565D8);
const _kBlue2 = Color(0xFF0D47A1);
const _kBlueLight = Color(0xFFE8F0FE);
const _kBlueMid = Color(0xFF1976D2);
const _kBlueAccent = Color(0xFF64B5F6); // bleu clair pour dégradé visible

class XPrinterConfigSheet extends StatefulWidget {
  const XPrinterConfigSheet({super.key});

  @override
  State<XPrinterConfigSheet> createState() => _XPrinterConfigSheetState();
}

class _XPrinterConfigSheetState extends State<XPrinterConfigSheet>
    with SingleTickerProviderStateMixin {
  final XPrinterService _service = const XPrinterService();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '9100',
  );

  late TabController _tabController;
  late Future<List<XPrinterDevice>> _bluetoothFuture;
  late Future<List<XPrinterDevice>> _usbFuture;
  XPrinterDevice? _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      SnackBar(
        content: Text('${device.name} configuree pour les recus',
              textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kBlue1,
      ),
    );
  }

  Future<void> _saveNetworkPrinter() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;
    if (host.isEmpty || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse IP ou port invalide',
              textAlign: TextAlign.center)),
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(
            color: Colors.white,
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header dégradé ────────────────────────────────────────────
            _Header(saved: _saved),

            // ── Tabs ──────────────────────────────────────────────────────
            _StyledTabBar(controller: _tabController),

            // ── Contenu ───────────────────────────────────────────────────
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: TabBarView(
                  controller: _tabController,
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
            ),

            // ── Bouton retirer ────────────────────────────────────────────
            if (_saved != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text('Retirer cette imprimante'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 20),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

// ─── Header avec dégradé bleu ─────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.saved});
  final XPrinterDevice? saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBlue1, _kBlue2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // Pas de borderRadius ici : le ClipRRect parent s'en charge
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Pill
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Row(
              children: [
                // Icône imprimante dans cercle semi-transparent
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configuration imprimante',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        saved == null
                            ? 'Choisissez une connexion pour les recus.'
                            : '${saved!.name}  •  ${saved!.subtitle}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (saved != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.6),
                      ),
                    ),
                    child: const Text(
                      'Connectee',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TabBar stylisé ───────────────────────────────────────────────────────────
class _StyledTabBar extends StatelessWidget {
  const _StyledTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBlue2,
      child: TabBar(
        controller: controller,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.bluetooth_rounded, size: 20), text: 'Bluetooth'),
          Tab(icon: Icon(Icons.wifi_rounded, size: 20), text: 'LAN'),
          Tab(icon: Icon(Icons.usb_rounded, size: 20), text: 'USB'),
        ],
      ),
    );
  }
}

// ─── Tab Bluetooth ────────────────────────────────────────────────────────────
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _GradientButton(
                icon: Icons.bluetooth_rounded,
                label: 'Ouvrir Bluetooth',
                onTap: () => AppSettings.openAppSettings(
                  type: AppSettingsType.bluetooth,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _RefreshBtn(onTap: onRefresh),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _PrinterList(
            devicesFuture: devicesFuture,
            emptyText:
                'Aucune imprimante appairee.\nAppairez la XPrinter dans Bluetooth puis actualisez.',
            emptyIcon: Icons.bluetooth_searching_rounded,
            saved: saved,
            saving: saving,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

// ─── Tab Réseau ───────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.only(top: 16),
      children: [
        _StyledField(
          controller: hostController,
          label: 'Adresse IP',
          hint: '192.168.1.50',
          icon: Icons.router_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        _StyledField(
          controller: portController,
          label: 'Port',
          hint: '9100',
          icon: Icons.settings_ethernet_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 18),
        _GradientButton(
          icon: Icons.save_rounded,
          label: 'Enregistrer LAN / Wi-Fi',
          onTap: saving ? null : onSave,
        ),
      ],
    );
  }
}

// ─── Tab USB ──────────────────────────────────────────────────────────────────
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
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: _RefreshBtn(onTap: onRefresh),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _PrinterList(
            devicesFuture: devicesFuture,
            emptyText:
                'Aucune imprimante USB detectee.\nBranchez la XPrinter avec un adaptateur OTG puis actualisez.',
            emptyIcon: Icons.usb_off_rounded,
            saved: saved,
            saving: saving,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

// ─── Liste imprimantes ────────────────────────────────────────────────────────
class _PrinterList extends StatelessWidget {
  const _PrinterList({
    required this.devicesFuture,
    required this.emptyText,
    required this.emptyIcon,
    required this.saved,
    required this.saving,
    required this.onSelect,
  });

  final Future<List<XPrinterDevice>> devicesFuture;
  final String emptyText;
  final IconData emptyIcon;
  final XPrinterDevice? saved;
  final bool saving;
  final ValueChanged<XPrinterDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XPrinterDevice>>(
      future: devicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _kBlue1),
          );
        }
        final devices = snapshot.data ?? const [];

        if (devices.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kBlueLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBlue1.withOpacity(0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(emptyIcon, size: 40, color: _kBlueMid.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kBlue2.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 58),
          itemBuilder: (context, index) {
            final device = devices[index];
            final selected = saved?.storageValue == device.storageValue;

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: saving ? null : () => onSelect(device),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? _kBlueLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? Border.all(color: _kBlue1.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                colors: [_kBlue1, _kBlueMid],
                              )
                            : null,
                        color: selected ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        selected
                            ? Icons.check_rounded
                            : Icons.print_rounded,
                        color: selected ? Colors.white : Colors.grey.shade500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: selected ? _kBlue1 : null,
                            ),
                          ),
                          Text(
                            device.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _kBlue1,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Bouton dégradé bleu ──────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBlue2, _kBlue1, _kBlueAccent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _kBlue1.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bouton refresh rond ──────────────────────────────────────────────────────
class _RefreshBtn extends StatelessWidget {
  const _RefreshBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: _kBlueLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBlue1.withOpacity(0.2)),
        ),
        child: const Icon(Icons.refresh_rounded, color: _kBlue1, size: 22),
      ),
    );
  }
}

// ─── Champ texte stylisé ──────────────────────────────────────────────────────
class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _kBlueMid),
        filled: true,
        fillColor: _kBlueLight,
        prefixIcon: Icon(icon, color: _kBlue1, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _kBlue1.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBlue1, width: 1.5),
        ),
      ),
    );
  }
}
