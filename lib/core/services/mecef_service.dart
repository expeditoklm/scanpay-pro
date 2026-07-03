import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/invoice.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MECEF SERVICE — Mécanisme de Certification des Factures (DGI Bénin)
//
// CREDENTIALS DE TEST (placeholders) :
//   → Obtenez vos vraies clés sur : https://developper.impots.bj/sygmef-emcf/registration
//   → Remplacez kPlaceholderIfu et kPlaceholderToken par vos valeurs DGI
//
// URLs :
//   - Test  : https://developper.impots.bj/sygmef-test
//   - Prod  : https://sygmef.impots.bj
// ─────────────────────────────────────────────────────────────────────────────

class MecefConfig {
  /// IFU (Numéro Identifiant Fiscal Unique) de la boutique
  final String ifu;

  /// Jeton d'accès fourni par la DGI après enregistrement sur e-MECeF
  final String token;

  /// true = serveur de test DGI | false = serveur de production DGI
  final bool useTestMode;

  const MecefConfig({
    required this.ifu,
    required this.token,
    this.useTestMode = true,
  });

  bool get isPlaceholder =>
      ifu == MecefService.kPlaceholderIfu ||
      token == MecefService.kPlaceholderToken;

  /// Config par défaut avec clés placeholder — mode simulation locale
  static const placeholder = MecefConfig(
    ifu: MecefService.kPlaceholderIfu,
    token: MecefService.kPlaceholderToken,
    useTestMode: true,
  );
}

// ─── Résultat de la certification ────────────────────────────────────────────

class MecefResult {
  const MecefResult({
    required this.success,
    this.cu,
    this.qrBase64,
    this.datetime,
    this.isMock = false,
    this.nim,
    this.compteur,
    this.error,
  });

  /// Succès de la certification
  final bool success;

  /// Code Unique retourné par la DGI (ex: "CU-XXXXX-XXXXX-XXXXX")
  final String? cu;

  /// QR code en base64 PNG retourné par la DGI (null en mode mock → généré en PDF)
  final String? qrBase64;

  /// Timestamp serveur DGI au format ISO8601
  final String? datetime;

  /// true si résultat simulé localement (clés placeholder)
  final bool isMock;

  /// NIM — Numéro d'Identification du Mécanisme (identifiant unique du SFE)
  final String? nim;

  /// Compteur séquentiel (ex: "03768/91280 FV")
  final String? compteur;

  /// Message d'erreur en cas d'échec
  final String? error;

  MecefStatus get status {
    if (success && isMock) return MecefStatus.mock;
    if (success) return MecefStatus.certified;
    return MecefStatus.failed;
  }
}

// ─── Service principal ────────────────────────────────────────────────────────

class MecefService {
  MecefService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ── Credentials placeholder — À REMPLACER avec les vraies clés DGI ──────
  static const kPlaceholderIfu   = '0000000000000';
  static const kPlaceholderToken = 'TOKEN_TEST_MECEF_PLACEHOLDER';

  // ── URLs officielles DGI Bénin ──────────────────────────────────────────
  static const _kTestBaseUrl = 'https://developper.impots.bj/sygmef-test/api';
  static const _kProdBaseUrl = 'https://sygmef.impots.bj/api';

  /// Certifie une facture auprès du serveur e-MECeF de la DGI.
  ///
  /// Si [config.isPlaceholder] → retourne une simulation locale (mode mock).
  /// Quand les vraies clés DGI seront disponibles, aucune ligne de code
  /// à changer ici — remplacez juste kPlaceholderIfu et kPlaceholderToken.
  Future<MecefResult> certifyInvoice(
    Invoice invoice, {
    MecefConfig config = MecefConfig.placeholder,
  }) async {
    // ── Mode simulation (clés placeholder) ──────────────────────────────
    if (config.isPlaceholder) {
      return _mockResult(invoice);
    }

    // ── Vrai appel API DGI ───────────────────────────────────────────────
    final baseUrl = config.useTestMode ? _kTestBaseUrl : _kProdBaseUrl;
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/certification'),
            headers: {
              'Content-Type': 'application/json',
              // NOTE : vérifier le format d'auth exact dans la doc DGI
              // Certaines implémentations utilisent 'Token <token>' au lieu de 'Bearer'
              'Authorization': 'Bearer ${config.token}', 
            },
            body: jsonEncode(_buildPayload(invoice, config.ifu)),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // NOTE : les noms de champs exacts seront dans la doc officielle DGI.
        // Adaptez cu/qr_code/datetime_serveur selon la réponse réelle.
        return MecefResult(
          success: true,
          cu: (data['code_unique'] ?? data['cu'] ?? data['codeUnique'])?.toString(),
          qrBase64: (data['qr_code'] ?? data['qr'] ?? data['qrCode'])?.toString(),
          datetime: (data['datetime_serveur'] ?? data['dateHeure'])?.toString(),
          nim: (data['nim'] ?? data['mecef_nim'])?.toString(),
          compteur: (data['compteur'] ?? data['mecef_compteur'])?.toString(),
          isMock: false,
        );
      } else {
        final body = response.body;
        return MecefResult(
          success: false,
          error: 'DGI HTTP ${response.statusCode} : $body',
        );
      }
    } on Exception catch (e) {
      return MecefResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Certifie un avoir (note de crédit) auprès du serveur e-MECeF.
  Future<MecefResult> certifyAvoir(
    Invoice avoir,
    String referencedInvoiceCU, {
    MecefConfig config = MecefConfig.placeholder,
  }) async {
    if (config.isPlaceholder) {
      return _mockResult(avoir, type: 'FA');
    }

    final baseUrl = config.useTestMode ? _kTestBaseUrl : _kProdBaseUrl;
    try {
      final payload = _buildPayload(avoir, config.ifu, type: 'FA');
      // Référence à la facture originale
      payload['facture_origine'] = referencedInvoiceCU;

      final response = await _client
          .post(
            Uri.parse('$baseUrl/certification'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.token}',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return MecefResult(
          success: true,
          cu: (data['code_unique'] ?? data['cu'])?.toString(),
          qrBase64: (data['qr_code'] ?? data['qr'])?.toString(),
          datetime: (data['datetime_serveur'])?.toString(),
          isMock: false,
        );
      }
      return MecefResult(
        success: false,
        error: 'DGI HTTP ${response.statusCode}',
      );
    } on Exception catch (e) {
      return MecefResult(success: false, error: e.toString());
    }
  }

  // ── Payload API ────────────────────────────────────────────────────────────
  //
  // Structure basée sur les systèmes e-MECeF UEMOA similaires (Togo, Sénégal).
  // NOTE : À VALIDER contre la documentation officielle DGI Bénin disponible
  // sur https://developper.impots.bj/sygmef-test après enregistrement.
  Map<String, dynamic> _buildPayload(
    Invoice invoice,
    String ifu, {
    String type = 'FV', // FV = Facture de Vente | FA = Facture d'Avoir
  }) {
    final totalTTC = invoice.total;
    // Si la boutique est assujettie à la TVA à 18% :
    //   totalHT  = totalTTC / 1.18
    //   tva      = totalTTC - totalHT
    //   aib (1%) = totalHT * 0.01
    // Sinon (régime simplifié) : totalHT = totalTTC, tva = 0, aib = 0
    final totalHT = double.parse((totalTTC / 1.18).toStringAsFixed(2));
    final tva     = double.parse((totalTTC - totalHT).toStringAsFixed(2));
    final aib     = double.parse((totalHT * 0.01).toStringAsFixed(2));

    return {
      'ifu'  : ifu,
      'type' : type,
      // AIB : A=5%, B=1% (commerce général), C=0% (exonéré)
      'aib'  : 'B',
      'client': {
        'ifu': '0000000000000', // IFU client (0 si particulier/comptoir)
        'nom': invoice.customer?.isNotEmpty == true
            ? invoice.customer!
            : 'Client comptoir',
      },
      'items': [
        for (final line in invoice.lines)
          {
            'nom'          : line.name,
            'quantite'     : line.quantity,
            'prix_unitaire': line.unitPrice,
            'montant'      : line.lineTotal,
            // Groupe de taxe : A=TVA 18%, B=Exonéré TVA
            'taxe'         : 'A',
          }
      ],
      'total_ht'    : totalHT,
      'tva'         : tva,
      'aib_montant' : aib,
      'total_ttc'   : totalTTC,
      'reference'   : invoice.reference,
    };
  }

  // ── Mode mock (clés placeholder) ──────────────────────────────────────────

  MecefResult _mockResult(Invoice invoice, {String type = 'FV'}) {
    // Code Unique fictif pour les tests locaux — Format : CU-TYPE-TIMESTAMP
    final ts = DateTime.now().millisecondsSinceEpoch;
    final mockCU = 'CU-$type-MOCK-$ts';

    // Compteur fictif : incrémenté à chaque vente dans la session (non persisté)
    // Le vrai compteur viendra de la DGI lors de la certification réelle
    final mockCompteur = '${ts % 99999}/99999 $type';

    return MecefResult(
      success   : true,
      cu        : mockCU,
      qrBase64  : null, // Le PDF génèrera le QR directement depuis le CU
      datetime  : DateTime.now().toIso8601String(),
      isMock    : true,
      nim       : 'NIM-MOCK-TEST',   // Remplacé par le vrai NIM DGI à l'enregistrement
      compteur  : mockCompteur,
    );
  }
}
