import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loader pleine page aux couleurs de l'app.
///
/// Logo centré avec effet de pulse + anneau dégradé bleu/teal rotatif,
/// inspiré du style Fada Pay.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    // Pulse doux du logo (0.90 → 1.00 → 0.90 en boucle)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    )..repeat(reverse: true);

    // Rotation continue de l'anneau
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _scale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ringSize = 96.0;
    const logoSize = 60.0;

    return Center(
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [

            // ── Halo de fond statique ────────────────────────────────────
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1565D8).withOpacity(0.06),
              ),
            ),

            // ── Anneau gradient rotatif ──────────────────────────────────
            AnimatedBuilder(
              animation: _rotCtrl,
              builder: (_, __) => CustomPaint(
                size: const Size(ringSize, ringSize),
                painter: _GradientRingPainter(_rotCtrl.value),
              ),
            ),

            // ── Logo pulsant ─────────────────────────────────────────────
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565D8).withOpacity(0.20),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/branding/app-logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Peintre de l'anneau gradient ─────────────────────────────────────────────

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter(this.t);

  /// Progression de la rotation (0.0 → 1.0).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Anneau complet, mais le dégradé crée une zone transparente
    // qui simule l'arc ouvert qui tourne.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [
          Colors.transparent,
          Color(0xFF1565D8),
          Color(0xFF22C1C3),
          Color(0xFF1565D8),
          Colors.transparent,
        ],
        stops: const [0.0, 0.12, 0.52, 0.88, 1.0],
        transform: GradientRotation(t * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // départ en haut
      math.pi * 2,  // cercle complet (le gradient gère la transparence)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => old.t != t;
}
