import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/erp_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/exit_guard.dart';
import '../../data/offline_sync_service.dart';
import '../auth/auth_provider.dart';
import '../billing/billing_screen.dart';
import '../pos/pos_scan_screen.dart';
import '../products/products_list_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 1;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(offlineSyncProvider).syncCurrentCompany();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(offlineSyncProvider).syncCurrentCompany();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(offlineSyncProvider).syncCurrentCompany();
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E2F2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFE11D48),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Se deconnecter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voulez-vous vraiment quitter cette boutique ?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: const BorderSide(color: Color(0xFFD7E2F2)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Deconnecter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ) ?? false;
    if (!shouldLogout || !mounted) return;
    await ref.read(authProvider.notifier).signOut();
  }

  void _showCompanyProfile() {
    final auth = ref.read(authProvider);
    if (auth == null) return;
    final company = auth.companyName;
    final logoUrl = auth.companyLogoUrl;
    final absoluteLogoUrl = (logoUrl != null && logoUrl.isNotEmpty)
        ? (logoUrl.startsWith('http') ? logoUrl : '$kErpBaseUrl$logoUrl')
        : null;
    final initials = company.trim().isEmpty
        ? 'BT'
        : company.trim().split(RegExp(r'\s+')).take(2)
            .map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ProfileSheet(
        companyName: company,
        plan: auth.plan,
        role: auth.role,
        companyId: auth.companyId,
        absoluteLogoUrl: absoluteLogoUrl,
        initials: initials,
        onCopyId: () async {
          await Clipboard.setData(ClipboardData(text: auth.companyId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Matricule copié dans le presse-papiers'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final company = auth?.companyName ?? '';
    final logoUrl = auth?.companyLogoUrl;
    final absoluteLogoUrl = (logoUrl != null && logoUrl.isNotEmpty)
        ? (logoUrl.startsWith('http') ? logoUrl : '$kErpBaseUrl$logoUrl')
        : null;
    final initials = company.trim().isEmpty
        ? 'BT'
        : company
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
            .join();

    final pages = [
      const ProductsListScreen(),
      PosScanScreen(embedded: true, active: _index == 1),
      const BillingScreen(),
    ];

    return ExitGuard(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          titleSpacing: 0,
          leadingWidth: 76,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: _showCompanyProfile,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundImage: absoluteLogoUrl != null
                      ? NetworkImage(absoluteLogoUrl)
                      : null,
                  child: absoluteLogoUrl == null
                      ? Text(
                          initials.isEmpty ? 'BT' : initials,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF1565D8),
                                fontWeight: FontWeight.w700,
                              ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          title: GestureDetector(
            onTap: _showCompanyProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(company),
                Text(
                  (auth?.plan.isNotEmpty ?? false)
                      ? 'Plan ${auth!.plan.toUpperCase()}'
                      : 'Tableau de bord',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Deconnexion',
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppTheme.brandShellGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: IndexedStack(index: _index, children: pages),
        ),
        bottomNavigationBar: _HomeBottomBar(
          currentIndex: _index,
          onChanged: (value) => setState(() => _index = value),
        ),
      ),
    );
  }
}

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 108,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // ── Barre principale ───────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x441565D8),
                      blurRadius: 28,
                      offset: Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DockItem(
                        label: 'Produits',
                        icon: Icons.inventory_2_rounded,
                        selected: currentIndex == 0,
                        onTap: () => onChanged(0),
                      ),
                    ),
                    const SizedBox(width: 72),
                    Expanded(
                      child: _DockItem(
                        label: 'Ventes',
                        icon: Icons.receipt_long_rounded,
                        selected: currentIndex == 2,
                        onTap: () => onChanged(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bouton orange Caisse ───────────────────────────────────
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () => onChanged(1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: currentIndex == 1 ? 72 : 66,
                  height: currentIndex == 1 ? 72 : 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFC24B), Color(0xFFFF9F1C), Color(0xFFFF6B00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9F1C).withValues(
                          alpha: currentIndex == 1 ? 0.55 : 0.3,
                        ),
                        blurRadius: currentIndex == 1 ? 28 : 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 4,
                    ),
                  ),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: currentIndex == 1 ? 0.0 : 0.0,
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF0F172A),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

            // ── Label "Caisse" ─────────────────────────────────────────
            Positioned(
              bottom: 8,
              child: IgnorePointer(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: currentIndex == 1
                        ? const Color(0xFFFF9F1C)
                        : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: currentIndex == 1
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                  child: const Text('Caisse'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item de dock ─────────────────────────────────────────────────────────────

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          const Icon(
            Icons.copy_rounded,
            size: 14,
            color: Color(0xFF94A3B8),
          ),
        ],
      ],
    );

    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Spacer(),
        onTap != null
            ? GestureDetector(
                onTap: onTap,
                child: valueWidget,
              )
            : valueWidget,
      ],
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
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
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 44 : 36,
              height: selected ? 34 : 28,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1565D8).withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF22C1C3)
                    : const Color(0xFF475569),
                size: selected ? 22 : 20,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: selected
                    ? const Color(0xFF22C1C3)
                    : const Color(0xFF475569),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile bottom sheet avec animation slide-from-top ───────────────────────
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({
    required this.companyName,
    required this.plan,
    required this.role,
    required this.companyId,
    required this.absoluteLogoUrl,
    required this.initials,
    required this.onCopyId,
  });

  final String companyName;
  final String plan;
  final String role;
  final String companyId;
  final String? absoluteLogoUrl;
  final String initials;
  final VoidCallback onCopyId;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;
  late final Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    // Avatar : apparaît en glissant depuis le haut + agrandissement
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _translateY = Tween<double>(begin: -56.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    // Texte / infos : fade-in légèrement décalé
    _contentOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOut),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E2F2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // En-tête : avatar animé + infos
          Row(
            children: [
              // Avatar — glisse depuis le haut et grossit
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _translateY.value),
                  child: Transform.scale(
                    scale: _scale.value,
                    alignment: Alignment.topLeft,
                    child: Opacity(opacity: _opacity.value, child: child),
                  ),
                ),
                child: Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFEFF6FF),
                    foregroundImage: widget.absoluteLogoUrl != null
                        ? NetworkImage(widget.absoluteLogoUrl!)
                        : null,
                    child: widget.absoluteLogoUrl == null
                        ? Text(
                            widget.initials,
                            style: const TextStyle(
                              color: Color(0xFF1565D8),
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Nom + badge plan — fade-in après l'avatar
              Expanded(
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.companyName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Plan ${widget.plan.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Infos détaillées — fade-in après l'avatar
          FadeTransition(
            opacity: _contentOpacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                _ProfileInfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: widget.role,
                ),
                const SizedBox(height: 10),
                _ProfileInfoRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Matricule',
                  value: widget.companyId.length > 12
                      ? '${widget.companyId.substring(0, 12)}...'
                      : widget.companyId,
                  onTap: widget.onCopyId,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
