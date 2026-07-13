import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/invoice.dart';

enum XPrinterConnectionType {
  bluetooth,
  network,
  usb,
}

class XPrinterDevice {
  const XPrinterDevice({
    required this.name,
    required this.type,
    this.mac,
    this.host,
    this.port = 9100,
    this.usbDeviceId,
    this.usbVendorId,
    this.usbProductId,
  });

  final String name;
  final XPrinterConnectionType type;
  final String? mac;
  final String? host;
  final int port;
  final int? usbDeviceId;
  final int? usbVendorId;
  final int? usbProductId;

  String get subtitle {
    switch (type) {
      case XPrinterConnectionType.bluetooth:
        return mac ?? '';
      case XPrinterConnectionType.network:
        return '${host ?? ''}:$port';
      case XPrinterConnectionType.usb:
        final vendor = usbVendorId?.toRadixString(16).padLeft(4, '0') ?? '----';
        final product = usbProductId?.toRadixString(16).padLeft(4, '0') ?? '----';
        return 'USB $vendor:$product';
    }
  }

  String get storageValue {
    switch (type) {
      case XPrinterConnectionType.bluetooth:
        return 'bluetooth|${name.replaceAll('|', ' ')}|${mac ?? ''}';
      case XPrinterConnectionType.network:
        return 'network|${name.replaceAll('|', ' ')}|${host ?? ''}|$port';
      case XPrinterConnectionType.usb:
        return 'usb|${name.replaceAll('|', ' ')}|${usbVendorId ?? ''}|${usbProductId ?? ''}|${usbDeviceId ?? ''}';
    }
  }

  static XPrinterDevice? fromStorageValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split('|');
    if (parts.length < 3) return null;
    final type = parts[0];
    final name = parts[1].trim().isEmpty ? 'XPrinter' : parts[1].trim();
    if (type == 'bluetooth') {
      final mac = parts[2].trim();
      if (mac.isEmpty) return null;
      return XPrinterDevice(
        name: name,
        type: XPrinterConnectionType.bluetooth,
        mac: mac,
      );
    }
    if (type == 'network') {
      final host = parts[2].trim();
      final port = parts.length > 3 ? int.tryParse(parts[3]) ?? 9100 : 9100;
      if (host.isEmpty) return null;
      return XPrinterDevice(
        name: name,
        type: XPrinterConnectionType.network,
        host: host,
        port: port,
      );
    }
    if (type == 'usb') {
      return XPrinterDevice(
        name: name,
        type: XPrinterConnectionType.usb,
        usbVendorId: parts.length > 2 ? int.tryParse(parts[2]) : null,
        usbProductId: parts.length > 3 ? int.tryParse(parts[3]) : null,
        usbDeviceId: parts.length > 4 ? int.tryParse(parts[4]) : null,
      );
    }
    return null;
  }
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

  static const _channel = MethodChannel('quick_sell_pay/xprinter_usb');
  static const _printerDeviceKey = 'xprinter_device_v2';
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
    final saved = XPrinterDevice.fromStorageValue(
      prefs.getString(_printerDeviceKey),
    );
    if (saved != null) return saved;

    final mac = prefs.getString(_printerMacKey);
    if (mac == null || mac.trim().isEmpty) return null;
    return XPrinterDevice(
      name: prefs.getString(_printerNameKey) ?? 'XPrinter',
      type: XPrinterConnectionType.bluetooth,
      mac: mac,
    );
  }

  Future<void> savePrinter(XPrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerDeviceKey, device.storageValue);
    if (device.mac != null) {
      await prefs.setString(_printerMacKey, device.mac!);
    }
    await prefs.setString(_printerNameKey, device.name);
  }

  Future<void> clearPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_printerDeviceKey);
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
              type: XPrinterConnectionType.bluetooth,
              mac: device.macAdress,
            ),
          )
          .where((device) => (device.mac ?? '').trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<XPrinterDevice>> usbPrinters() async {
    try {
      final rawDevices = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'listPrinters',
      );
      if (rawDevices == null) return const [];
      return rawDevices.map((raw) {
        final name = (raw['name'] as String? ?? '').trim();
        return XPrinterDevice(
          name: name.isEmpty ? 'XPrinter USB' : name,
          type: XPrinterConnectionType.usb,
          usbDeviceId: raw['deviceId'] as int?,
          usbVendorId: raw['vendorId'] as int?,
          usbProductId: raw['productId'] as int?,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  XPrinterDevice networkPrinter({
    required String host,
    int port = 9100,
    String name = 'XPrinter LAN',
  }) {
    return XPrinterDevice(
      name: name.trim().isEmpty ? 'XPrinter LAN' : name.trim(),
      type: XPrinterConnectionType.network,
      host: host.trim(),
      port: port,
    );
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
    switch (printer.type) {
      case XPrinterConnectionType.bluetooth:
        return _printBluetoothInvoice(invoice: invoice, printer: printer);
      case XPrinterConnectionType.network:
        return _printNetworkInvoice(invoice: invoice, printer: printer);
      case XPrinterConnectionType.usb:
        return _printUsbInvoice(invoice: invoice, printer: printer);
    }
  }

  Future<XPrinterResult> _printBluetoothInvoice({
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
        final mac = printer.mac;
        if (mac == null || mac.trim().isEmpty) {
          return const XPrinterResult(
            success: false,
            message: 'Adresse Bluetooth manquante.',
          );
        }
        connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: mac,
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

  Future<XPrinterResult> _printNetworkInvoice({
    required Invoice invoice,
    required XPrinterDevice printer,
  }) async {
    final host = printer.host?.trim() ?? '';
    if (host.isEmpty) {
      return const XPrinterResult(
        success: false,
        message: 'Adresse IP de l imprimante manquante.',
      );
    }

    try {
      final socket = await Socket.connect(
        host,
        printer.port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(_buildReceipt(invoice));
      await socket.flush();
      await socket.close();
      return XPrinterResult(
        success: true,
        message: 'Recu imprime sur ${printer.name}.',
      );
    } on TimeoutException {
      return XPrinterResult(
        success: false,
        message: 'Connexion LAN impossible a ${printer.subtitle}.',
      );
    } on SocketException catch (error) {
      return XPrinterResult(
        success: false,
        message: 'Impression LAN impossible: ${error.message}',
      );
    } catch (error) {
      return XPrinterResult(
        success: false,
        message: 'Impression LAN impossible: $error',
      );
    }
  }

  Future<XPrinterResult> _printUsbInvoice({
    required Invoice invoice,
    required XPrinterDevice printer,
  }) async {
    try {
      final success = await _channel.invokeMethod<bool>('print', {
        'deviceId': printer.usbDeviceId,
        'vendorId': printer.usbVendorId,
        'productId': printer.usbProductId,
        'bytes': Uint8List.fromList(_buildReceipt(invoice)),
      });
      if (success == true) {
        return XPrinterResult(
          success: true,
          message: 'Recu imprime sur ${printer.name}.',
        );
      }
      return XPrinterResult(
        success: false,
        message: 'Impression USB impossible sur ${printer.name}.',
      );
    } on PlatformException catch (error) {
      return XPrinterResult(
        success: false,
        message: error.message ?? 'Impression USB impossible.',
      );
    } catch (error) {
      return XPrinterResult(
        success: false,
        message: 'Impression USB impossible: $error',
      );
    }
  }

  List<int> _buildReceipt(Invoice invoice) {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(invoice.createdAt);
    final reference = invoice.reference.isNotEmpty ? invoice.reference : invoice.id;
    final bytes = <int>[
      ..._init,
      ..._codepage,
      ..._alignCenter,
      ..._boldOn,
      ..._largeText,
      ..._text(invoice.companyName.toUpperCase()),
      ..._lf,
      ..._normalText,
      ..._boldOff,
      ..._text(invoice.isVatRegistered ? 'FACTURE NORMALISEE' : 'FACTURE PROFORMA'),
      ..._lf,
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
  // FS .  (0x1C 0x2E) => annule le mode caracteres chinois (sinon les octets
  //                      >= 0x80 sont lus comme des ideogrammes sur 2 octets)
  // ESC t 16 (0x1B 0x74 0x10) => page de codes WPC1252 (Windows-1252) pour les accents
  static List<int> get _codepage => const [0x1C, 0x2E, 0x1B, 0x74, 16];
  static List<int> get _alignLeft => const [0x1B, 0x61, 0x00];
  static List<int> get _alignCenter => const [0x1B, 0x61, 0x01];
  static List<int> get _alignRight => const [0x1B, 0x61, 0x02];
  static List<int> get _boldOn => const [0x1B, 0x45, 0x01];
  static List<int> get _boldOff => const [0x1B, 0x45, 0x00];
  static List<int> get _normalText => const [0x1D, 0x21, 0x00];
  static List<int> get _largeText => const [0x1D, 0x21, 0x11];
  static List<int> get _lf => const [0x0A];
  static List<int> get _cut => const [0x1D, 0x56, 0x42, 0x00];

  static List<int> _rule() => [..._text('-' * _lineWidth), ..._lf];

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
      if ((rune >= 0x20 && rune <= 0x7E) || (rune >= 0xA0 && rune <= 0xFF)) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
