import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/erp_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/exit_guard.dart';
import '../../data/offline_sync_service.dart';
import '../auth/auth_provider.dart';
import '../billing/billing_screen.dart';
import '../pos/pos_entry_screen.dart';
import '../products/products_list_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;
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
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Deconnexion'),
            content: const Text(
              'Voulez-vous vraiment vous deconnecter de cette boutique ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Se deconnecter'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldLogout || !mounted) return;
    await ref.read(authProvider.notifier).signOut();
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

    final pages = const [
      ProductsListScreen(),
      PosEntryScreen(),
      BillingScreen(),
    ];

    return ExitGuard(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            foregroundImage:
                absoluteLogoUrl != null ? NetworkImage(absoluteLogoUrl) : null,
            child: absoluteLogoUrl == null
                ? Text(
                    initials.isEmpty ? 'BT' : initials,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  )
                : null,
          ),
        ),
        title: Column(
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
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: SizedBox(
        height: 102,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x160F172A),
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DockItem(
                        label: 'Produits',
                        icon: Icons.home_rounded,
                        selected: currentIndex == 0,
                        onTap: () => onChanged(0),
                      ),
                    ),
                    const SizedBox(width: 76),
                    Expanded(
                      child: _DockItem(
                        label: 'Factures',
                        icon: Icons.receipt_long_rounded,
                        selected: currentIndex == 2,
                        onTap: () => onChanged(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () => onChanged(1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: currentIndex == 1 ? 74 : 68,
                  height: currentIndex == 1 ? 74 : 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFC24B),
                        Color(0xFFFF9F1C),
                        Color(0xFFFF7A18),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FF9F1C),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF143A52),
                    size: 30,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: currentIndex == 1 ? 1 : 0.78,
                  child: Text(
                    'Caisse',
                    style: TextStyle(
                      color: currentIndex == 1
                          ? const Color(0xFF143A52)
                          : const Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
    final color = selected ? const Color(0xFF1565D8) : const Color(0xFF7C8DA6);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
