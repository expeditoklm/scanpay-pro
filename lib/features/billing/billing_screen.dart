import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/models/invoice.dart';
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
  bool _sortAsc = false;
  _Period _period = _Period.all;

  List<Invoice> _filtered(List<Invoice> invoices) {
    if (_period == _Period.all) return invoices;
    final now = DateTime.now();
    return invoices.where((inv) {
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
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
            const SizedBox(height: 16),
            // ── Empty state for period ────────────────────────────────────
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
                          'Aucune vente ${_periodLabel(_period)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Aucune transaction sur cette période.',
                          style: TextStyle(
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
            else
              // ── Invoice cards ───────────────────────────────────────────
              ...sorted.map((invoice) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InvoiceCard(invoice: invoice),
                  )),
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
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 18,
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
