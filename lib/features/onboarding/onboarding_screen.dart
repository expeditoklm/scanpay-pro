import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/widgets/exit_guard.dart';

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
          'Scannez le QR du produit, vérifiez l’article et validez la vente en quelques secondes.',
      imagePath: 'assets/onboarding/onboarding_scan_real.png',
    ),
    _OnboardingSlideData(
      title: 'Stock mis à jour',
      description:
          'Chaque vente ajuste automatiquement les quantités, les prix et l’historique de votre boutique.',
      imagePath: 'assets/onboarding/onboarding_inventory_real.png',
    ),
    _OnboardingSlideData(
      title: 'Reçus et paiements',
      description:
          'Retrouvez les reçus, suivez les encaissements et gardez une trace claire de chaque opération.',
      imagePath: 'assets/onboarding/onboarding_growth_real.png',
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

    final theme = Theme.of(context);
    final isLastPage = _currentPage == _slides.length - 1;

    return ExitGuard(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF4F8FD), Color(0xFFEAF3FF), Color(0xFFF7FBFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Opacity(
                      opacity: isLastPage ? 0.0 : 1.0,
                      child: TextButton(
                        onPressed: (_loading || isLastPage) ? null : _finish,
                        child: const Text('Passer'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (value) =>
                          setState(() => _currentPage = value),
                      itemCount: _slides.length,
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return _OnboardingSlide(slide: slide);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: index == _currentPage ? 28 : 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? const Color(0xFF1565D8)
                              : const Color(0xFFD3E1F4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              if (isLastPage) {
                                await _finish();
                                return;
                              }
                              await _pageController.nextPage(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                              );
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isLastPage ? 'Créer mon compte' : 'Continuer',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
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
              child: TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0x66000000),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Passer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.slide});

  final _OnboardingSlideData slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageSize = MediaQuery.sizeOf(context).shortestSide < 380 ? 260.0 : 300.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(42),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0F172A),
                    blurRadius: 36,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(42),
                child: Image.asset(
                  slide.imagePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              slide.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF475569),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.title,
    required this.description,
    required this.imagePath,
  });

  final String title;
  final String description;
  final String imagePath;
}
