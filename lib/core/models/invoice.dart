import 'dart:convert';

// ── Statut de certification MECeF ─────────────────────────────────────────────
enum MecefStatus {
  /// Pas encore envoyé à la DGI (hors ligne ou en attente)
  pending,

  /// Certifié par la DGI avec de vraies clés
  certified,

  /// Certifié avec des clés placeholder (mode test local)
  mock,

  /// Rejeté par la DGI ou erreur réseau définitive
  failed,
}

extension MecefStatusX on MecefStatus {
  String get label {
    switch (this) {
      case MecefStatus.pending:    return 'En attente';
      case MecefStatus.certified:  return 'Certifiée';
      case MecefStatus.mock:       return 'Test local';
      case MecefStatus.failed:     return 'Echec';
    }
  }

  String get storedValue {
    switch (this) {
      case MecefStatus.pending:    return 'pending';
      case MecefStatus.certified:  return 'certified';
      case MecefStatus.mock:       return 'mock';
      case MecefStatus.failed:     return 'failed';
    }
  }

  static MecefStatus fromString(String? value) {
    switch (value) {
      case 'certified': return MecefStatus.certified;
      case 'mock':      return MecefStatus.mock;
      case 'failed':    return MecefStatus.failed;
      default:          return MecefStatus.pending;
    }
  }
}

// ── Ligne de facture ──────────────────────────────────────────────────────────

class InvoiceLine {
  const InvoiceLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'unit_price': unitPrice,
        'quantity': quantity,
        'line_total': lineTotal,
      };
}

// ── Facture ───────────────────────────────────────────────────────────────────

class Invoice {
  const Invoice({
    required this.id,
    required this.reference,
    required this.companyId,
    required this.companyName,
    required this.createdAt,
    required this.lines,
    this.customer,
    this.note,
    this.source = 'mobile_app',
    this.pendingSync = false,
    // ── Infos société (pour l'impression) ──
    this.companyIfu,
    this.companyRc,
    this.companyAddress,
    this.companyPhone,
    // ── Paiement ──
    // ── Fiscalité ──
    this.isVatRegistered = true,
    // ── Paiement ──
    this.paymentMethod = 'Espece',
    this.amountPaid = 0,
    // ── Champs MECeF (DGI Bénin) ──
    this.mecefCU,
    this.mecefQrBase64,
    this.mecefDatetime,
    this.mecefStatus = MecefStatus.pending,
    this.mecefNim,
    this.mecefCompteur,
  });

  final String id;
  final String reference;
  final String companyId;
  final String companyName;
  final DateTime createdAt;
  final List<InvoiceLine> lines;
  final String? customer;
  final String? note;
  final String source;
  final bool pendingSync;

  // ── Infos société ─────────────────────────────────────────────────────────
  /// IFU de la boutique (Identifiant Fiscal Unique — DGI Bénin)
  final String? companyIfu;

  /// Numéro Registre du Commerce
  final String? companyRc;

  /// Adresse physique de la boutique
  final String? companyAddress;

  /// Téléphone de la boutique
  final String? companyPhone;

  // ── Fiscalité ─────────────────────────────────────────────────────────────
  /// true = boutique assujettie TVA 18% + AIB [B] 1%
  /// false = regime simplifie / exonere (pas de TVA sur ticket)
  final bool isVatRegistered;

  // ── Paiement ──────────────────────────────────────────────────────────────
  /// Mode de paiement : 'Espece' | 'Carte' | 'Mobile Money'
  final String paymentMethod;

  /// Montant remis par le client (0 = non renseigné ou paiement carte)
  final double amountPaid;

  /// Rendu monnaie (calculé automatiquement)
  double get change => amountPaid > total ? amountPaid - total : 0;

  // ── MECeF ─────────────────────────────────────────────────────────────────
  /// Code Unique retourné par la DGI Bénin
  final String? mecefCU;

  /// QR code en base64 PNG retourné par la DGI (null = généré en PDF depuis mecefCU)
  final String? mecefQrBase64;

  /// Timestamp de certification sur le serveur DGI
  final String? mecefDatetime;

  /// Statut de la certification e-MECeF
  final MecefStatus mecefStatus;

  /// NIM — Numéro d'Identification du Mécanisme (fourni par la DGI à l'enregistrement)
  final String? mecefNim;

  /// Compteur séquentiel MECeF (ex: "03768/91280 FV")
  final String? mecefCompteur;

  /// true si la facture a un Code Unique (réel ou mock)
  bool get isMecefCertified =>
      mecefCU != null &&
      mecefCU!.isNotEmpty &&
      (mecefStatus == MecefStatus.certified || mecefStatus == MecefStatus.mock);

  // ── Totaux ────────────────────────────────────────────────────────────────
  double get total    => lines.fold<double>(0, (s, l) => s + l.lineTotal);
  double get totalHT  => double.parse((total / 1.18).toStringAsFixed(2));
  double get tva      => double.parse((total - totalHT).toStringAsFixed(2));
  double get aib      => double.parse((totalHT * 0.01).toStringAsFixed(2));

  String get qrPayload => jsonEncode({
        'invoice_id'  : id,
        'reference'   : reference,
        'company_id'  : companyId,
        'company_name': companyName,
        'created_at'  : createdAt.toIso8601String(),
        'total'       : total,
        'source'      : source,
        'mecef_cu'    : mecefCU,
        'lines'       : [for (final l in lines) l.toJson()],
      });

  // ── Sérialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id'              : id,
        'reference'       : reference,
        'company_id'      : companyId,
        'company_name'    : companyName,
        'created_at'      : createdAt.toIso8601String(),
        'customer'        : customer,
        'note'            : note,
        'source'          : source,
        'pending_sync'    : pendingSync,
        // Fiscalite
        'is_vat_registered': isVatRegistered,
        // Société
        'company_ifu'     : companyIfu,
        'company_rc'      : companyRc,
        'company_address' : companyAddress,
        'company_phone'   : companyPhone,
        // Paiement
        'payment_method'  : paymentMethod,
        'amount_paid'     : amountPaid,
        // MECeF
        'mecef_cu'        : mecefCU,
        'mecef_qr_base64' : mecefQrBase64,
        'mecef_datetime'  : mecefDatetime,
        'mecef_status'    : mecefStatus.storedValue,
        'mecef_nim'       : mecefNim,
        'mecef_compteur'  : mecefCompteur,
        'lines'           : [for (final l in lines) l.toJson()],
      };

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List<dynamic>? ?? const []);
    return Invoice(
      id          : json['id']           as String? ?? '',
      reference   : json['reference']    as String? ?? '',
      companyId   : json['company_id']   as String? ?? '',
      companyName : json['company_name'] as String? ?? '',
      createdAt   : DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      customer    : json['customer']     as String?,
      note        : json['note']         as String?,
      source      : json['source']       as String? ?? 'mobile_app',
      pendingSync : json['pending_sync'] as bool? ?? false,
      // Fiscalite
      isVatRegistered: json['is_vat_registered'] as bool? ?? true,
      // Société
      companyIfu     : json['company_ifu']     as String?,
      companyRc      : json['company_rc']      as String?,
      companyAddress : json['company_address'] as String?,
      companyPhone   : json['company_phone']   as String?,
      // Paiement
      paymentMethod  : json['payment_method']  as String? ?? 'Espece',
      amountPaid     : (json['amount_paid']    as num? ?? 0).toDouble(),
      // MECeF
      mecefCU        : json['mecef_cu']         as String?,
      mecefQrBase64  : json['mecef_qr_base64']  as String?,
      mecefDatetime  : json['mecef_datetime']   as String?,
      mecefStatus    : MecefStatusX.fromString(json['mecef_status'] as String?),
      mecefNim       : json['mecef_nim']        as String?,
      mecefCompteur  : json['mecef_compteur']   as String?,
      lines: rawLines.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return InvoiceLine(
          productId : map['product_id'] as String? ?? '',
          name      : map['name']       as String? ?? 'Produit',
          unitPrice : (map['unit_price'] as num? ?? 0).toDouble(),
          quantity  : (map['quantity']   as num? ?? 0).toInt(),
        );
      }).toList(),
    );
  }

  Invoice copyWith({
    String? id,
    String? reference,
    String? companyId,
    String? companyName,
    DateTime? createdAt,
    List<InvoiceLine>? lines,
    String? customer,
    String? note,
    String? source,
    bool? pendingSync,
    bool? isVatRegistered,
    String? companyIfu,
    String? companyRc,
    String? companyAddress,
    String? companyPhone,
    String? paymentMethod,
    double? amountPaid,
    String? mecefCU,
    String? mecefQrBase64,
    String? mecefDatetime,
    MecefStatus? mecefStatus,
    String? mecefNim,
    String? mecefCompteur,
  }) {
    return Invoice(
      id             : id             ?? this.id,
      reference      : reference      ?? this.reference,
      companyId      : companyId      ?? this.companyId,
      companyName    : companyName    ?? this.companyName,
      createdAt      : createdAt      ?? this.createdAt,
      lines          : lines          ?? this.lines,
      customer       : customer       ?? this.customer,
      note           : note           ?? this.note,
      source         : source         ?? this.source,
      pendingSync    : pendingSync    ?? this.pendingSync,
      isVatRegistered: isVatRegistered ?? this.isVatRegistered,
      companyIfu     : companyIfu     ?? this.companyIfu,
      companyRc      : companyRc      ?? this.companyRc,
      companyAddress : companyAddress ?? this.companyAddress,
      companyPhone   : companyPhone   ?? this.companyPhone,
      paymentMethod  : paymentMethod  ?? this.paymentMethod,
      amountPaid     : amountPaid     ?? this.amountPaid,
      mecefCU        : mecefCU        ?? this.mecefCU,
      mecefQrBase64  : mecefQrBase64  ?? this.mecefQrBase64,
      mecefDatetime  : mecefDatetime  ?? this.mecefDatetime,
      mecefStatus    : mecefStatus    ?? this.mecefStatus,
      mecefNim       : mecefNim       ?? this.mecefNim,
      mecefCompteur  : mecefCompteur  ?? this.mecefCompteur,
    );
  }
}
