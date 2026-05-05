import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitGuard extends StatefulWidget {
  const ExitGuard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _lastBackPressAt;

  Future<bool> _handleWillPop() async {
    final now = DateTime.now();
    final shouldConfirm = _lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) < const Duration(seconds: 2);

    if (!shouldConfirm) {
      _lastBackPressAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Appuyez encore sur retour pour quitter.'),
            duration: Duration(seconds: 2),
          ),
        );
      return false;
    }

    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quitter l application'),
            content: const Text(
              'Voulez-vous vraiment quitter l application ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Quitter'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      await SystemNavigator.pop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: widget.child,
    );
  }
}
