import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:qr/qr.dart';
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

  /// Imprime les QR codes directement sur la XPrinter configurée, sans passer
  /// par la boîte de dialogue d'impression Android.
  Future<XPrinterResult> printProductQrLabels({
    required String productName,
    required List<String> qrData,
    required List<String> codes,
  }) async {
    final printer = await savedPrinter();
    if (printer == null) {
      return const XPrinterResult(
        success: false,
        message: 'Aucune XPrinter configurée. Configurez-la dans la caisse avant d’imprimer.',
      );
    }
    if (qrData.isEmpty || qrData.length != codes.length) {
      return const XPrinterResult(
        success: false,
        message: 'Les étiquettes QR à imprimer sont invalides.',
      );
    }

    final bytes = _buildQrLabels(
      productName: productName,
      qrData: qrData,
      codes: codes,
    );
    return _sendBytes(
      printer: printer,
      bytes: bytes,
      successMessage: '${qrData.length} étiquette(s) QR envoyée(s) à ${printer.name}.',
    );
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

  Future<XPrinterResult> _sendBytes({
    required XPrinterDevice printer,
    required List<int> bytes,
    required String successMessage,
  }) async {
    switch (printer.type) {
      case XPrinterConnectionType.bluetooth:
        final allowed = await requestPermissions();
        if (!allowed) {
          return const XPrinterResult(
            success: false,
            message: 'Permissions Bluetooth refusées. Autorisez le Bluetooth puis réessayez.',
          );
        }
        try {
          var connected = await PrintBluetoothThermal.connectionStatus;
          if (!connected) {
            final mac = printer.mac;
            if (mac == null || mac.trim().isEmpty) {
              return const XPrinterResult(
                success: false,
                message: 'Adresse Bluetooth de la XPrinter manquante.',
              );
            }
            connected = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
          }
          if (!connected) {
            return XPrinterResult(
              success: false,
              message: 'XPrinter non connectée : allumez ${printer.name} et vérifiez le Bluetooth.',
            );
          }
          await PrintBluetoothThermal.writeBytes(bytes);
          return XPrinterResult(success: true, message: successMessage);
        } catch (_) {
          return XPrinterResult(
            success: false,
            message: 'Impression impossible : ${printer.name} est peut-être éteinte ou hors de portée.',
          );
        }

      case XPrinterConnectionType.network:
        final host = printer.host?.trim() ?? '';
        if (host.isEmpty) {
          return const XPrinterResult(
            success: false,
            message: 'Adresse IP de la XPrinter manquante.',
          );
        }
        try {
          final socket = await Socket.connect(
            host,
            printer.port,
            timeout: const Duration(seconds: 5),
          );
          socket.add(bytes);
          await socket.flush();
          await socket.close();
          return XPrinterResult(success: true, message: successMessage);
        } catch (_) {
          return XPrinterResult(
            success: false,
            message: 'XPrinter réseau non joignable à ${printer.subtitle}.',
          );
        }

      case XPrinterConnectionType.usb:
        try {
          final success = await _channel.invokeMethod<bool>('print', {
            'deviceId': printer.usbDeviceId,
            'vendorId': printer.usbVendorId,
            'productId': printer.usbProductId,
            'bytes': Uint8List.fromList(bytes),
          });
          if (success == true) {
            return XPrinterResult(success: true, message: successMessage);
          }
          return XPrinterResult(
            success: false,
            message: 'XPrinter USB non détectée : vérifiez le câble ou l’adaptateur OTG.',
          );
        } catch (_) {
          return XPrinterResult(
            success: false,
            message: 'Impression USB impossible. Vérifiez la connexion de ${printer.name}.',
          );
        }
    }
  }

  List<int> _buildQrLabels({
    required String productName,
    required List<String> qrData,
    required List<String> codes,
  }) {
    final bytes = <int>[
      ..._init,
      ..._codepage,
      ..._alignCenter,
      ..._boldOn,
      ..._text(_clean(productName).toUpperCase()),
      ..._lf,
      ..._boldOff,
    ];

    for (var index = 0; index < qrData.length; index += 2) {
      final rightIndex = index + 1;
      final hasRightQr = rightIndex < qrData.length;
      final leftCenter = _qrCenter(qrData[index], hasRightQr: hasRightQr);
      final rightCenter = hasRightQr
          ? _qrCenter(qrData[rightIndex], hasRightQr: true, isRight: true)
          : null;
      final rightProductName = rightIndex < qrData.length ? productName : null;
      bytes.addAll(
        _twoLabelTextRow(
          leftText: productName,
          rightText: rightProductName,
          leftCenter: leftCenter,
          rightCenter: rightCenter,
          bold: true,
        ),
      );
      bytes.addAll(_twoQrRaster(
        leftData: qrData[index],
        rightData: rightIndex < qrData.length ? qrData[rightIndex] : null,
      ));
      bytes.addAll(_qrCodeLine(
        leftCode: codes[index],
        rightCode: rightIndex < codes.length ? codes[rightIndex] : null,
        leftCenter: leftCenter,
        rightCenter: rightCenter,
      ));
      bytes.addAll(
        _twoLabelTextRow(
          leftText: 'Verifier la',
          rightText: rightIndex < codes.length ? 'Verifier la' : null,
          leftCenter: leftCenter,
          rightCenter: rightCenter,
          compact: true,
        ),
      );
      bytes.addAll(
        _twoLabelTextRow(
          leftText: 'provenance',
          rightText: rightIndex < codes.length ? 'provenance' : null,
          leftCenter: leftCenter,
          rightCenter: rightCenter,
          compact: true,
        ),
      );
      bytes.addAll(_lf);
      bytes.addAll(_rule());
    }

    bytes.addAll(_cut);
    return bytes;
  }

  List<int> _twoQrRaster({required String leftData, String? rightData}) {
    const paperWidth = 576;
    const twoLabelsLeftOffset = 34;
    const rightOffset = 322;
    const moduleScale = 3;
    const quietZone = 4;
    final left = _qrImage(leftData);
    final right = rightData == null ? null : _qrImage(rightData);
    final leftSize = (left.moduleCount + quietZone * 2) * moduleScale;
    final rightSize = right == null
        ? 0
        : (right.moduleCount + quietZone * 2) * moduleScale;
    final height = leftSize > rightSize ? leftSize : rightSize;
    final leftOffset = right == null
        ? (paperWidth - leftSize) ~/ 2
        : twoLabelsLeftOffset;
    final widthBytes = paperWidth ~/ 8;
    final raster = List<int>.filled(widthBytes * height, 0);

    _drawQr(
      raster: raster,
      widthBytes: widthBytes,
      qr: left,
      offsetX: leftOffset,
      scale: moduleScale,
      quietZone: quietZone,
    );
    if (right != null) {
      _drawQr(
        raster: raster,
        widthBytes: widthBytes,
        qr: right,
        offsetX: rightOffset,
        scale: moduleScale,
        quietZone: quietZone,
      );
    }

    return [
      0x1D, 0x76, 0x30, 0x00,
      widthBytes & 0xFF, (widthBytes >> 8) & 0xFF,
      height & 0xFF, (height >> 8) & 0xFF,
      ...raster,
    ];
  }

  int _qrCenter(
    String data, {
    required bool hasRightQr,
    bool isRight = false,
  }) {
    const paperWidth = 576;
    const twoLabelsLeftOffset = 34;
    const rightOffset = 322;
    const moduleScale = 3;
    const quietZone = 4;
    final size = (_qrImage(data).moduleCount + quietZone * 2) * moduleScale;
    final offset = !hasRightQr
        ? (paperWidth - size) ~/ 2
        : (isRight ? rightOffset : twoLabelsLeftOffset);
    return offset + size ~/ 2;
  }

  QrImage _qrImage(String data) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    return QrImage(code);
  }

  void _drawQr({
    required List<int> raster,
    required int widthBytes,
    required QrImage qr,
    required int offsetX,
    required int scale,
    required int quietZone,
  }) {
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var column = 0; column < qr.moduleCount; column++) {
        if (!qr.isDark(row, column)) continue;
        final startX = offsetX + (column + quietZone) * scale;
        final startY = (row + quietZone) * scale;
        for (var y = startY; y < startY + scale; y++) {
          for (var x = startX; x < startX + scale; x++) {
            final index = y * widthBytes + (x ~/ 8);
            raster[index] |= 0x80 >> (x % 8);
          }
        }
      }
    }
  }

  List<int> _qrCodeLine({
    required String leftCode,
    required int leftCenter,
    String? rightCode,
    int? rightCenter,
  }) {
    final bytes = <int>[
      ..._alignLeft,
      ..._absolutePosition(_centeredTextOffset(leftCode, leftCenter)),
      ..._text(leftCode),
    ];
    if (rightCode != null) {
      bytes.addAll(_absolutePosition(
        _centeredTextOffset(rightCode, rightCenter ?? leftCenter),
      ));
      bytes.addAll(_text(rightCode));
    }
    return bytes;
  }

  /// Texte placé au-dessus ou au-dessous de chaque QR dans une rangée.
  /// Les deux colonnes correspondent aux mêmes positions que les QR raster.
  List<int> _twoLabelTextRow({
    required String leftText,
    required int leftCenter,
    String? rightText,
    int? rightCenter,
    bool bold = false,
    bool compact = false,
  }) {
    final maxCharacters = compact ? 20 : 18;
    final left = _labelText(leftText, maxCharacters);
    final right = rightText == null ? null : _labelText(rightText, maxCharacters);
    final bytes = <int>[..._alignLeft];
    if (compact) bytes.addAll(_fontB);
    if (bold) bytes.addAll(_boldOn);
    bytes
      ..addAll(_absolutePosition(_centeredTextOffset(
        left,
        leftCenter,
        compact: compact,
      )))
      ..addAll(_text(left));
    if (right != null) {
      bytes
        ..addAll(_absolutePosition(_centeredTextOffset(
          right,
          rightCenter ?? leftCenter,
          compact: compact,
        )))
        ..addAll(_text(right));
    }
    bytes.addAll(_lf);
    if (bold) bytes.addAll(_boldOff);
    if (compact) bytes.addAll(_fontA);
    return bytes;
  }

  static String _labelText(String value, int maxCharacters) {
    final clean = _clean(value);
    if (clean.length <= maxCharacters) return clean;
    return '${clean.substring(0, maxCharacters - 1)}.';
  }

  static int _centeredTextOffset(
    String text,
    int center, {
    bool compact = false,
  }) {
    // Font A fait environ 12 points de large, Font B environ 9.
    final characterWidth = compact ? 9 : 12;
    return (center - (text.length * characterWidth) ~/ 2)
        .clamp(0, 575)
        .toInt();
  }

  static List<int> _absolutePosition(int dots) => [
        0x1B,
        0x24,
        dots & 0xFF,
        (dots >> 8) & 0xFF,
      ];

  static List<String> _wrapReceiptText(String value, int width) {
    final clean = _clean(value);
    if (clean.length <= width) return [clean];
    final words = clean.split(' ');
    final lines = <String>[];
    var line = '';
    for (final word in words) {
      final candidate = line.isEmpty ? word : '$line $word';
      if (candidate.length <= width) {
        line = candidate;
      } else {
        if (line.isNotEmpty) lines.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
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
      if ((invoice.companyAddress ?? '').trim().isNotEmpty) ...[
        ..._text(_clean(invoice.companyAddress!.trim())),
        ..._lf,
      ],
      if ((invoice.companyPhone ?? '').trim().isNotEmpty) ...[
        ..._text('Tel : ${_clean(invoice.companyPhone!.trim())}'),
        ..._lf,
      ],
      if ((invoice.companyIfu ?? '').trim().isNotEmpty) ...[
        ..._text('IFU : ${_clean(invoice.companyIfu!.trim())}'),
        ..._lf,
      ],
      if ((invoice.companyRc ?? '').trim().isNotEmpty) ...[
        ..._text('RCCM : ${_clean(invoice.companyRc!.trim())}'),
        ..._lf,
      ],
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
      for (final line
          in _wrapReceiptText(label, _lineWidth - total.length - 1)) {
        bytes
          ..addAll(_text(line))
          ..addAll(_lf);
      }
      bytes
        ..addAll(_text(_twoColumns('', total)))
        ..addAll(_lf)
        ..addAll(_text('  ${item.unitPrice.toStringAsFixed(0)} FCFA'))
        ..addAll(_lf);
    }

    bytes
      ..addAll(_rule())
      ..addAll(_text(_twoColumns('Sous-total', '${invoice.total.toStringAsFixed(0)} FCFA')))
      ..addAll(_lf);

    if (invoice.isVatRegistered) {
      bytes
        ..addAll(_text(_twoColumns('BASE IMPOSABLE [B] 18%', '${invoice.totalHT.toStringAsFixed(0)} FCFA')))
        ..addAll(_lf)
        ..addAll(_text(_twoColumns('TOTAL TVA [B] 18%', '${invoice.tva.toStringAsFixed(0)} FCFA')))
        ..addAll(_lf);
    }

    bytes
      ..addAll(_rule())
      ..addAll(_alignRight)
      ..addAll(_boldOn)
      ..addAll(_text('TOTAL TTC ${invoice.total.toStringAsFixed(0)} FCFA'))
      ..addAll(_lf)
      ..addAll(_boldOff)
      ..addAll(_alignLeft)
      ..addAll(_text(_twoColumns('Mode paiement', invoice.paymentMethod)))
      ..addAll(_lf)
      ..addAll(_alignCenter)
      ..addAll(_lf)
      ..addAll(_text('Vente enregistree depuis l application mobile'))
      ..addAll(_lf)
      ..addAll(_text('Merci pour votre achat'))
      ..addAll(_lf)
      ..addAll(_text('Conservez ce recu comme preuve d achat'))
      ..addAll(_lf)
      ..addAll(_rule());

    if (invoice.isMecefCertified) {
      bytes
        ..addAll(_alignCenter)
        ..addAll(_boldOn)
        ..addAll(_text('FACTURE NORMALISEE - CERTIFIEE'))
        ..addAll(_lf)
        ..addAll(_boldOff)
        ..addAll(_text('QR MECeF - VERIFICATION DGI'))
        ..addAll(_lf)
        ..addAll(_twoQrRaster(leftData: invoice.mecefCU!, rightData: null))
        ..addAll(_lf)
        ..addAll(_text('Scannez pour verifier aupres de la DGI'))
        ..addAll(_lf);
    } else if (invoice.isVatRegistered) {
      bytes
        ..addAll(_alignCenter)
        ..addAll(_boldOn)
        ..addAll(_text('FACTURE NORMALISEE - EN ATTENTE'))
        ..addAll(_lf)
        ..addAll(_boldOff)
        ..addAll(_text('Certification DGI en attente'))
        ..addAll(_lf)
        ..addAll(_text('Le QR MECeF sera imprime apres synchronisation'))
        ..addAll(_lf);
    }

    bytes
      ..addAll(_alignCenter)
      ..addAll(_code128(reference))
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
  static List<int> get _fontA => const [0x1B, 0x4D, 0x00];
  static List<int> get _fontB => const [0x1B, 0x4D, 0x01];
  static List<int> get _largeText => const [0x1D, 0x21, 0x11];
  static List<int> get _lf => const [0x0A];
  static List<int> get _cut => const [0x1D, 0x56, 0x42, 0x00];

  static List<int> _rule() => [..._text('-' * _lineWidth), ..._lf];

  /// Code-barres de la référence, également visible sur l'aperçu PDF.
  /// La plupart des XPrinter 80 mm prennent en charge ESC/POS Code 128.
  static List<int> _code128(String value) {
    final data = '{B${_clean(value)}';
    final limited = data.length > 250 ? data.substring(0, 250) : data;
    return [
      0x1D, 0x68, 72, // hauteur
      0x1D, 0x77, 2, // largeur du trait
      0x1D, 0x48, 2, // texte lisible sous le code
      0x1D, 0x6B, 73, limited.length,
      ...limited.codeUnits,
    ];
  }

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
