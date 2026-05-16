import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/invoice.dart';

class XPrinterDevice {
  const XPrinterDevice({
    required this.name,
    required this.mac,
  });

  final String name;
  final String mac;
}

class XPrinterResult {
  const XPrinterResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class XPrinterService {
  const XPrinterService();

  static const _printerMacKey = 'xprinter_mac_v1';
  static const _printerNameKey = 'xprinter_name_v1';
  static const _lineWidth = 32;

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<XPrinterDevice?> savedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_printerMacKey);
    if (mac == null || mac.trim().isEmpty) return null;
    return XPrinterDevice(
      name: prefs.getString(_printerNameKey) ?? 'XPrinter',
      mac: mac,
    );
  }

  Future<void> savePrinter(XPrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerMacKey, device.mac);
    await prefs.setString(_printerNameKey, device.name);
  }

  Future<void> clearPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_printerMacKey);
    await prefs.remove(_printerNameKey);
  }

  Future<List<XPrinterDevice>> pairedPrinters() async {
    final allowed = await requestPermissions();
    if (!allowed) return const [];
    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices
          .map(
            (device) => XPrinterDevice(
              name: _clean(device.name).isEmpty ? 'XPrinter' : device.name,
              mac: device.macAdress,
            ),
          )
          .where((device) => device.mac.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<XPrinterResult> printSavedInvoice(Invoice invoice) async {
    final printer = await savedPrinter();
    if (printer == null) {
      return const XPrinterResult(
        success: false,
        message: 'Aucune XPrinter configuree.',
      );
    }
    return printInvoice(invoice: invoice, printer: printer);
  }

  Future<XPrinterResult> printInvoice({
    required Invoice invoice,
    required XPrinterDevice printer,
  }) async {
    final allowed = await requestPermissions();
    if (!allowed) {
      return const XPrinterResult(
        success: false,
        message: 'Permissions Bluetooth refusees.',
      );
    }

    try {
      var connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: printer.mac,
        );
      }
      if (!connected) {
        return XPrinterResult(
          success: false,
          message: 'Connexion impossible a ${printer.name}.',
        );
      }

      await PrintBluetoothThermal.writeBytes(_buildReceipt(invoice));
      return XPrinterResult(
        success: true,
        message: 'Recu imprime sur ${printer.name}.',
      );
    } catch (error) {
      return XPrinterResult(
        success: false,
        message: 'Impression impossible: $error',
      );
    }
  }

  List<int> _buildReceipt(Invoice invoice) {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(invoice.createdAt);
    final reference = invoice.reference.isNotEmpty ? invoice.reference : invoice.id;
    final bytes = <int>[
      ..._init,
      ..._alignCenter,
      ..._boldOn,
      ..._largeText,
      ..._text(invoice.companyName.toUpperCase()),
      ..._lf,
      ..._normalText,
      ..._boldOff,
      ..._text('QuickSellPay'),
      ..._lf,
      ..._text(date),
      ..._lf,
      ..._alignLeft,
      ..._rule(),
      ..._text('REF ${_clean(reference)}'),
      ..._lf,
      if (invoice.pendingSync) ...[
        ..._text('VENTE HORS LIGNE'),
        ..._lf,
      ],
      ..._rule(),
      ..._text(_twoColumns('ARTICLE', 'TOTAL')),
      ..._lf,
      ..._rule(),
    ];

    for (final item in invoice.lines) {
      final label = '${item.quantity} x ${item.name}';
      final total = item.lineTotal.toStringAsFixed(0);
      bytes
        ..addAll(_text(_twoColumns(label, total)))
        ..addAll(_lf)
        ..addAll(_text('  ${item.unitPrice.toStringAsFixed(0)} FCFA'))
        ..addAll(_lf);
    }

    bytes
      ..addAll(_rule())
      ..addAll(_alignRight)
      ..addAll(_boldOn)
      ..addAll(_text('TOTAL ${invoice.total.toStringAsFixed(0)} FCFA'))
      ..addAll(_lf)
      ..addAll(_boldOff)
      ..addAll(_alignCenter)
      ..addAll(_lf)
      ..addAll(_text('Merci pour votre achat'))
      ..addAll(_lf)
      ..addAll(_text('Ticket genere par QuickSellPay'))
      ..addAll(_lf)
      ..addAll(_lf)
      ..addAll(_lf)
      ..addAll(_cut);

    return bytes;
  }

  static List<int> get _init => const [0x1B, 0x40];
  static List<int> get _alignLeft => const [0x1B, 0x61, 0x00];
  static List<int> get _alignCenter => const [0x1B, 0x61, 0x01];
  static List<int> get _alignRight => const [0x1B, 0x61, 0x02];
  static List<int> get _boldOn => const [0x1B, 0x45, 0x01];
  static List<int> get _boldOff => const [0x1B, 0x45, 0x00];
  static List<int> get _normalText => const [0x1D, 0x21, 0x00];
  static List<int> get _largeText => const [0x1D, 0x21, 0x11];
  static List<int> get _lf => const [0x0A];
  static List<int> get _cut => const [0x1D, 0x56, 0x42, 0x00];

  static List<int> _rule() => _text('-' * _lineWidth)..addAll(_lf);

  static List<int> _text(String value) => _clean(value).codeUnits;

  static String _twoColumns(String left, String right) {
    final cleanLeft = _clean(left);
    final cleanRight = _clean(right);
    final available = _lineWidth - cleanRight.length - 1;
    final clippedLeft = cleanLeft.length > available
        ? cleanLeft.substring(0, available)
        : cleanLeft;
    return clippedLeft.padRight(_lineWidth - cleanRight.length) + cleanRight;
  }

  static String _clean(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x20 && rune <= 0x7E) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
