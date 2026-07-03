import 'package:flutter/material.dart';

/// Placeholder animé style shimmer pour les images en cours de chargement.
///
/// Utilisation typique :
/// ```dart
/// Image.network(
///   url,
///   loadingBuilder: (_, child, progress) =>
///       progress == null ? child : const ShimmerBox(),
/// )
/// ```
/// Le widget remplit son parent — il suffit de le placer dans un conteneur
/// aux dimensions souhaitées.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadiusGeometry? borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    // La valeur passe de -2 à +2 → le reflet traverse le widget de gauche à droite
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              // Le reflet lumineux se déplace horizontalement
              begin: Alignment(v - 0.8, 0),
              end: Alignment(v + 0.8, 0),
              colors: const [
                Color(0xFFE2E8F0), // gris de base
                Color(0xFFF1F5F9), // gris clair
                Color(0xFFFFFFFF), // reflet blanc
                Color(0xFFF1F5F9), // gris clair
                Color(0xFFE2E8F0), // gris de base
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }
}
