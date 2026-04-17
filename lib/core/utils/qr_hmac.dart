import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Charge utile encodee dans le QR.
///
/// Version 1: ancien JSON signe avec produit + boutique.
/// Version 2: URL publique vers la page d'authenticite avec code unique par QR.
class QrPayload {
  const QrPayload({
    required this.version,
    required this.productId,
    required this.companyId,
    required this.signatureHex,
    this.authCode,
  });

  final int version;
  final String productId;
  final String companyId;
  final String signatureHex;
  final String? authCode;

  Map<String, dynamic> toJson() => {
        'v': version,
        'pid': productId,
        'cid': companyId,
        'sig': signatureHex,
        if (authCode != null && authCode!.isNotEmpty) 'code': authCode,
      };

  factory QrPayload.fromJson(Map<String, dynamic> json) {
    return QrPayload(
      version: (json['v'] as num?)?.toInt() ?? 1,
      productId: json['pid'] as String,
      companyId: json['cid'] as String,
      signatureHex: json['sig'] as String,
      authCode: json['code'] as String?,
    );
  }
}

/// Calcule HMAC-SHA256(utf8(productId + companyId + authCode), cle secrete UTF-8).
String hmacSignProductCompany({
  required String productId,
  required String companyId,
  required String secretKey,
  String? authCode,
}) {
  final message = '$productId|$companyId|${authCode ?? ''}';
  final key = utf8.encode(secretKey);
  final bytes = utf8.encode(message);
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(bytes);
  return digest.toString();
}

String encodeQrJson(QrPayload payload) => jsonEncode(payload.toJson());

String encodePublicQrUrl({
  required String baseUrl,
  required QrPayload payload,
}) {
  final origin = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  return Uri.parse('$origin/verify').replace(
    queryParameters: {
      'code': payload.authCode ?? '',
      'pid': payload.productId,
      'cid': payload.companyId,
      'sig': payload.signatureHex,
      'v': payload.version.toString(),
    },
  ).toString();
}

QrPayload? decodeQrJson(String raw) {
  try {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme.isNotEmpty && uri.queryParameters.isNotEmpty) {
      final pid = uri.queryParameters['pid'];
      final cid = uri.queryParameters['cid'];
      final sig = uri.queryParameters['sig'];
      if (pid != null && cid != null && sig != null) {
        return QrPayload(
          version: int.tryParse(uri.queryParameters['v'] ?? '2') ?? 2,
          productId: pid,
          companyId: cid,
          signatureHex: sig,
          authCode: uri.queryParameters['code'],
        );
      }
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return QrPayload.fromJson(decoded);
  } catch (_) {
    return null;
  }
}

bool verifyQrPayload(QrPayload payload, String secretKey) {
  final expected = hmacSignProductCompany(
    productId: payload.productId,
    companyId: payload.companyId,
    secretKey: secretKey,
    authCode: payload.authCode,
  );
  return expected == payload.signatureHex;
}
