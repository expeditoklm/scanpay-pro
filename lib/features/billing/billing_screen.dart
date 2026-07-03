import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/app_loader.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/models/invoice.dart';
import '../../core/services/xprinter_service.dart';
import '../../core/utils/price_formatter.dart';
import '../pos/invoice_pdf.dart';
import 'billing_providers.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
final _compactReceiptPreviewFormat = PdfPageFormat(
  72 * PdfPageFormat.mm,
  220 * PdfPageFormat.mm,
  marginAll: 6 * PdfPageFormat.mm,
);

enum _Period { all, today, week, month }

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _sortAsc = false;
  _Period _period = _Period.all;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Invoice> _filtered(List<Invoice> invoices) {
    // ── Filtre par période ───────────────────────────────────────────────
    var list = invoices;
    if (_period != _Period.all) {
      final now = DateTime.now();
      list = list.where((inv) {
        final d = inv.createdAt;
        switch (_period) {
          case _Period.today:
            return d.year == now.year && d.month == now.month && d.day == now.day;
          case _Period.week:
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
            return d.isAfter(start.subtract(const Duration(seconds: 1)));
          case _Period.month:
            return d.year == now.year && d.month == now.month;
          case _Period.all:
            return true;
        }
      }).toList();
    }
    // ── Filtre texte : numéro, produit, montant, mode de paiement ────────
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((inv) {
        if (inv.reference.toLowerCase().contains(q)) return true;
        if (inv.id.toLowerCase().contains(q)) return true;
        if (formatPriceEuro(inv.total).toLowerCase().contains(q)) return true;
        if (inv.paymentMethod.toLowerCase().contains(q)) return true;
        if (inv.lines.any((l) => l.name.toLowerCase().contains(q))) return true;
        return false;
      }).toList();
    }
    return list;
  }

  List<Invoice> _sorted(List<Invoice> invoices) {
    final list = List<Invoice>.from(invoices);
    list.sort((a, b) => _sortAsc
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt));
    return list;
  }

  double _totalFor(List<Invoice> invoices) =>
      invoices.fold(0, (sum, inv) => sum + inv.total);

  @override
  Widget build(BuildContext context) {
    final asyncInvoices = ref.watch(invoicesListProvider);

    return asyncInvoices.when(
      loading: () => const AppLoader(),
      error: (error, _) => Center(child: Text('Erreur: $error')),
      data: (invoices) {
        if (invoices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Aucune vente pour le moment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Validez une vente depuis la caisse pour voir vos factures ici.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final filtered = _filtered(invoices);
        final sorted = _sorted(filtered);
        final periodTotal = _totalFor(filtered);

        return ListView(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            16, 14, 16,
            MediaQuery.of(context).padding.bottom + 88,
          ),
          children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1565D8), Color(0xFF22C1C3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x221565D8),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Historique ventes',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${filtered.length} / ${invoices.length} facture${invoices.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _sortAsc = !_sortAsc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortAsc
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Date',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ── Total for period ──────────────────────────────────
                  if (_period != _Period.all) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total ${_periodLabel(_period)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            formatPriceEuro(periodTotal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // ── Filter chips ──────────────────────────────────────
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _PeriodChip(
                          label: 'Tout',
                          icon: Icons.list_rounded,
                          selected: _period == _Period.all,
                          onTap: () => setState(() => _period = _Period.all),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: "Aujourd'hui",
                          icon: Icons.today_rounded,
                          selected: _period == _Period.today,
                          onTap: () => setState(() => _period = _Period.today),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: 'Semaine',
                          icon: Icons.view_week_rounded,
                          selected: _period == _Period.week,
                          onTap: () => setState(() => _period = _Period.week),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: 'Mois',
                          icon: Icons.calendar_month_rounded,
                          selected: _period == _Period.month,
                          onTap: () => setState(() => _period = _Period.month),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Barre de recherche ────────────────────────────────────────
            _SalesSearchBar(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: 12),
            // ── Empty state ───────────────────────────────────────────────
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFD7E2F2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _query.isNotEmpty
                              ? 'Aucun résultat pour "$_query"'
                              : 'Aucune vente ${_periodLabel(_period)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _query.isNotEmpty
                              ? 'Essayez un autre numéro, produit ou montant.'
                              : 'Aucune transaction sur cette période.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // ── Invoice cards ─────────────────────────────────────────
              ...sorted.map((invoice) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InvoiceCard(invoice: invoice),
                  )),
              // ── Pied de liste : total CA + retour en haut ─────────────
              _SalesListFooter(
                totalCount: invoices.length,
                displayedCount: sorted.length,
                periodTotal: periodTotal,
                onScrollTop: () => _scrollCtrl.animateTo(
                  0,
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _periodLabel(_Period p) {
    switch (p) {
      case _Period.all:
        return 'tout';
      case _Period.today:
        return "aujourd'hui";
      case _Period.week:
        return 'cette semaine';
      case _Period.month:
        return 'ce mois';
    }
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? const Color(0xFF1565D8) : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF1565D8) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final Invoice invoice;

  Future<void> _share(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareTicketSheet(invoice: invoice),
    );
  }

  Future<void> _reprint(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Impression du recu en cours...',
              textAlign: TextAlign.center)),
    );
    final result = await const XPrinterService().printSavedInvoice(invoice);
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message,
              textAlign: TextAlign.center),
        backgroundColor:
            result.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Apercu ticket')),
                body: PdfPreview(
                  initialPageFormat: _compactReceiptPreviewFormat,
                  canChangePageFormat: false,
                  canDebug: false,
                  build: (format) => buildInvoicePdf(invoice, format),
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: invoice.pendingSync
                  ? const Color(0xFFFFC37A)
                  : const Color(0xFFD7E2F2),
              width: invoice.pendingSync ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E0F172A),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: invoice.pendingSync
                        ? const [Color(0xFFF59E0B), Color(0xFFF97316)]
                        : const [Color(0xFF1565D8), Color(0xFF22C1C3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  invoice.pendingSync
                      ? Icons.cloud_upload_outlined
                      : Icons.receipt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.reference.isNotEmpty
                          ? invoice.reference
                          : 'Facture ${invoice.id.substring(0, 8)}...',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_dateFmt.format(invoice.createdAt)}  ·  ${invoice.lines.length} ligne${invoice.lines.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (invoice.pendingSync) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1DC),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Sync en attente',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPriceEuro(invoice.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF1565D8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reimprimer le recu',
                        onPressed: () => _reprint(context),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        icon: const Icon(
                          Icons.print_rounded,
                          color: Color(0xFF1565D8),
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Partager le ticket',
                        onPressed: () => _share(context),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Color(0xFF22C1C3),
                          size: 20,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Texte du reçu (partage SMS / WhatsApp) ──────────────────────────────────

String _buildTextReceipt(Invoice invoice) {
  final buf = StringBuffer();
  buf.writeln('✅ QuickSellPay — Reçu de vente');
  buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
  if (invoice.reference.isNotEmpty) {
    buf.writeln('📋 Réf : ${invoice.reference}');
  }
  buf.writeln('📅 ${_dateFmt.format(invoice.createdAt)}');
  buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
  buf.writeln('🛍️ Articles :');
  for (final l in invoice.lines) {
    buf.writeln('  • ${l.name} x${l.quantity} — ${formatPriceEuro(l.lineTotal)}');
  }
  buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
  buf.writeln('💰 Total : ${formatPriceEuro(invoice.total)}');
  buf.writeln('💳 Paiement : ${invoice.paymentMethod}');
  if (invoice.amountPaid > 0) {
    buf.writeln('   Reçu    : ${formatPriceEuro(invoice.amountPaid)}');
    if (invoice.change > 0) {
      buf.writeln('   Rendu   : ${formatPriceEuro(invoice.change)}');
    }
  }
  buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
  buf.writeln('Merci pour votre confiance ! 🙏');
  return buf.toString();
}

// ─── Barre de recherche des ventes ────────────────────────────────────────────

class _SalesSearchBar extends StatelessWidget {
  const _SalesSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7E2F2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Numéro, produit, montant, mode de paiement...',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sheet de partage du ticket ───────────────────────────────────────────────

class _ShareTicketSheet extends StatefulWidget {
  const _ShareTicketSheet({required this.invoice});
  final Invoice invoice;

  @override
  State<_ShareTicketSheet> createState() => _ShareTicketSheetState();
}

class _ShareTicketSheetState extends State<_ShareTicketSheet> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Header dégradé ─────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1565D8), Color(0xFF22C1C3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.share_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.invoice.reference.isNotEmpty
                                    ? widget.invoice.reference
                                    : 'Ticket ${widget.invoice.id.substring(0, 8)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                formatPriceEuro(widget.invoice.total),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Options ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Column(
                  children: [
                    _ShareOption(
                      icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xFF1565D8),
                      title: 'Partager le ticket PDF',
                      subtitle: 'WhatsApp, Email, Drive...',
                      loading: _generating,
                      onTap: _sharePdf,
                    ),
                    const SizedBox(height: 10),
                    _ShareOption(
                      icon: Icons.copy_rounded,
                      color: const Color(0xFF22C1C3),
                      title: 'Copier le résumé texte',
                      subtitle: 'Coller dans un message ou SMS',
                      onTap: _copyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final bytes = await buildInvoicePdf(
        widget.invoice,
        _compactReceiptPreviewFormat,
      );
      if (!mounted) return;
      final safeRef = widget.invoice.reference.isNotEmpty
          ? widget.invoice.reference.replaceAll(RegExp(r'[^\w\-]'), '_')
          : widget.invoice.id.substring(0, 8);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'ticket_$safeRef.pdf',
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _buildTextReceipt(widget.invoice)));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Résumé copié dans le presse-papier',
          textAlign: TextAlign.center,
        ),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: loading ? Colors.transparent : const Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pied de liste des ventes ─────────────────────────────────────────────────

class _SalesListFooter extends StatelessWidget {
  const _SalesListFooter({
    required this.totalCount,
    required this.displayedCount,
    required this.periodTotal,
    required this.onScrollTop,
  });

  final int totalCount;
  final int displayedCount;
  final double periodTotal;
  final VoidCallback onScrollTop;

  @override
  Widget build(BuildContext context) {
    final isFiltered = displayedCount < totalCount;
    final countLabel = isFiltered
        ? '$displayedCount sur $totalCount vente${totalCount > 1 ? 's' : ''}'
        : '$totalCount vente${totalCount > 1 ? 's' : ''} au total';

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Column(
        children: [
          // ── Séparateur dégradé ─────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0xFFD7E2F2),
                  Color(0xFFD7E2F2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Compteur + CA ──────────────────────────────────────────────
          Text(
            countLabel,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 4),
            Text(
              'Total affiché : ${formatPriceEuro(periodTotal)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1565D8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),

          // ── Bouton retour en haut ──────────────────────────────────────
          GestureDetector(
            onTap: onScrollTop,
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD7E2F2)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565D8).withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Color(0xFF1565D8),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Retour en haut',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
