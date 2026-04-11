import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/offline_sync_service.dart';
import '../auth/auth_provider.dart';
import '../billing/billing_screen.dart';
import '../inventory/inventory_screen.dart';
import '../pos/pos_entry_screen.dart';
import '../products/products_list_screen.dart';
import 'dart:async';
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
  // Sync au démarrage + toutes les 30 secondes
  _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.read(offlineSyncProvider).syncCurrentCompany();
  });
  // Sync immédiate au lancement
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
            title: const Text('Déconnexion'),
            content: const Text(
              'Voulez-vous vraiment vous déconnecter de cette boutique ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Se déconnecter'),
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

    final pages = [
      const ProductsListScreen(),
      const PosEntryScreen(),
      const InventoryScreen(),
      const BillingScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(company),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Produits'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Caisse'),
          NavigationDestination(icon: Icon(Icons.warehouse_outlined), selectedIcon: Icon(Icons.warehouse), label: 'Stocks'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Factures'),
        ],
      ),
    );
  }
}
