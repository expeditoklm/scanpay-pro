import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitGuard extends StatefulWidget {
  const ExitGuard({super.key, required this.child});
  final Widget child;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _lastBackPressAt;

  Future<bool> _handleWillPop() async {
    final now = DateTime.now();
    final isSecondPress = _lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) < const Duration(seconds: 2);

    if (isSecondPress) {
      await SystemNavigator.pop();
      return false;
    }

    _lastBackPressAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Appuyez encore sur retour pour quitter.',
              textAlign: TextAlign.center),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
