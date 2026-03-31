import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Charge utile encodée dans le QR (JSON). Signature HMAC-SHA256 sur [productId][companyId].
///
/// La clé secrète reste côté entreprise ; une autre société ne peut pas forger la signature.
class QrPayload {
  const QrPayload({
    required this.version,
    required this.productId,
    required this.companyId,
    required this.signatureHex,
  });

  final int version;
  final String productId;
  final String companyId;
  final String signatureHex;

  Map<String, dynamic> toJson() => {
        'v': version,
        'pid': productId,
        'cid': companyId,
        'sig': signatureHex,
      };

  factory QrPayload.fromJson(Map<String, dynamic> json) {
    return QrPayload(
      version: (json['v'] as num?)?.toInt() ?? 1,
      productId: json['pid'] as String,
      companyId: json['cid'] as String,
      signatureHex: json['sig'] as String,
    );
  }
}

/// Calcule HMAC-SHA256(utf8(productId + companyId), clé secrète UTF-8), retour hex minuscule.
String  hmacSignProductCompany({
  required String productId,
  required String companyId,
  required String secretKey,
}) {
  final message = '$productId$companyId';
  final key = utf8.encode(secretKey);
  final bytes = utf8.encode(message);
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(bytes);
  return digest.toString();
}

String encodeQrJson(QrPayload payload) => jsonEncode(payload.toJson());

QrPayload? decodeQrJson(String raw) {
  try {
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
  );
  return expected == payload.signatureHex;
}
