import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/widgets/exit_guard.dart';

// ─── Données de slide ─────────────────────────────────────────────────────────

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.accentColor,
    required this.icon,
  });

  final String title;
  final String description;
  final String imagePath;
  final Color accentColor;
  final IconData icon;
}

// ─── Écran principal ──────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onCompleted,
  });

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _loading = false;
  bool _showLaunchVideo = true;

  static const _slides = [
    _OnboardingSlideData(
      title: 'Scannez pour vendre',
      description:
          'Scannez le QR du produit, vérifiez l\'article et validez la vente en quelques secondes.',
      imagePath: 'assets/onboarding/onboarding_scan_real.png',
      accentColor: Color(0xFF1565D8),
      icon: Icons.qr_code_scanner_rounded,
    ),
    _OnboardingSlideData(
      title: 'Stock mis à jour',
      description:
          'Chaque vente ajuste automatiquement les quantités, les prix et l\'historique de votre boutique.',
      imagePath: 'assets/onboarding/onboarding_inventory_real.png',
      accentColor: Color(0xFF22C1C3),
      icon: Icons.inventory_2_rounded,
    ),
    _OnboardingSlideData(
      title: 'Reçus et paiements',
      description:
          'Retrouvez les reçus, suivez les encaissements et gardez une trace claire de chaque opération.',
      imagePath: 'assets/onboarding/onboarding_growth_real.png',
      accentColor: Color(0xFF7C3AED),
      icon: Icons.receipt_long_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showLaunchVideo) {
      return _LaunchVideoIntro(
        onFinished: () {
          if (!mounted) return;
          setState(() => _showLaunchVideo = false);
        },
      );
    }

    final isLastPage = _currentPage == _slides.length - 1;
    final currentSlide = _slides[_currentPage];

    return ExitGuard(
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF061F54),
                currentSlide.accentColor.withOpacity(0.85),
                const Color(0xFF0D1B3E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: [

                  // ── Barre supérieure ────────────────────────────────────
                  Row(
                    children: [
                      // Logo app
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.20),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/branding/app-logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Bouton Passer
                      AnimatedOpacity(
                        opacity: isLastPage ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          onTap: (_loading || isLastPage) ? null : _finish,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.22),
                              ),
                            ),
                            child: const Text(
                              'Passer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Slides ───────────────────────────────────────────────
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (value) =>
                          setState(() => _currentPage = value),
                      itemCount: _slides.length,
                      itemBuilder: (context, index) {
                        return _OnboardingSlide(slide: _slides[index]);
                      },
                    ),
                  ),

                  // ── Indicateurs ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        width: index == _currentPage ? 28 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? Colors.white
                              : Colors.white.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Bouton CTA gradient ──────────────────────────────────
                  GestureDetector(
                    onTap: _loading
                        ? null
                        : () async {
                            if (isLastPage) {
                              await _finish();
                              return;
                            }
                            await _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLastPage
                              ? const [Color(0xFF7C3AED), Color(0xFF1565D8)]
                              : const [
                                  Color(0xFF0D47A1),
                                  Color(0xFF1565D8),
                                  Color(0xFF22C1C3),
                                ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: currentSlide.accentColor.withOpacity(0.45),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isLastPage
                                        ? 'Créer mon compte'
                                        : 'Continuer',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isLastPage
                                        ? Icons.rocket_launch_rounded
                                        : Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      await widget.onCompleted();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

// ─── Slide individuelle ───────────────────────────────────────────────────────

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.slide});

  final _OnboardingSlideData slide;

  @override
  Widget build(BuildContext context) {
    final imageSize =
        MediaQuery.sizeOf(context).shortestSide < 380 ? 240.0 : 275.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // ── Carte image + halo coloré ───────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Halo radial derrière la carte
                  Container(
                    width: imageSize + 60,
                    height: imageSize + 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          slide.accentColor.withOpacity(0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Carte principale
                  Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: slide.accentColor.withOpacity(0.32),
                          blurRadius: 44,
                          offset: const Offset(0, 18),
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Image.asset(
                        slide.imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Badge icône flottant en haut à droite de la carte
                  Positioned(
                    top: (imageSize + 60) / 2 - imageSize / 2 + 4,
                    right: (imageSize + 60) / 2 - imageSize / 2 + 4,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: slide.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: slide.accentColor.withOpacity(0.50),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(slide.icon, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 42),

              // ── Titre ────────────────────────────────────────────────────
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 14),

              // ── Description ──────────────────────────────────────────────
              Text(
                slide.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 15,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Intro vidéo de lancement ─────────────────────────────────────────────────

class _LaunchVideoIntro extends StatefulWidget {
  const _LaunchVideoIntro({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_LaunchVideoIntro> createState() => _LaunchVideoIntroState();
}

class _LaunchVideoIntroState extends State<_LaunchVideoIntro> {
  late final VideoPlayerController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/onboarding/launch_video.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(false)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      }).catchError((_) {
        _finish();
      });
    _controller.addListener(_handleVideoTick);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleVideoTick)
      ..dispose();
    super.dispose();
  }

  void _handleVideoTick() {
    if (!_controller.value.isInitialized) return;
    final position = _controller.value.position;
    final duration = _controller.value.duration;
    if (duration > Duration.zero && position >= duration) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      child: Scaffold(
        backgroundColor: const Color(0xFF061F54),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              right: 16,
              child: GestureDetector(
                onTap: _finish,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.40),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.20),
                    ),
                  ),
                  child: const Text(
                    'Passer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
