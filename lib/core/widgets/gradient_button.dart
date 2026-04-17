import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56,
    this.borderRadius = 20,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled
            ? const LinearGradient(
                colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
              )
            : const LinearGradient(
                colors: AppTheme.brandCardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: disabled
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x220F172A),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onPressed,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
