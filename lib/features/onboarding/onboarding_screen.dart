import 'package:flutter/material.dart';

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

  static const _slides = [
    _OnboardingSlideData(
      title: 'Vendez plus vite',
      description:
          'Gerez vos produits, vos prix et vos partages WhatsApp depuis une seule application.',
      icon: Icons.rocket_launch_rounded,
      colors: [Color(0xFF0F172A), Color(0xFF1565D8)],
    ),
    _OnboardingSlideData(
      title: 'Une caisse moderne',
      description:
          'Scannez, facturez et suivez votre activite avec une interface simple pour la boutique.',
      icon: Icons.point_of_sale_rounded,
      colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
    ),
    _OnboardingSlideData(
      title: 'Pret pour demarrer',
      description:
          'Creez votre compte ou connectez-vous pour commencer a vendre en quelques minutes.',
      icon: Icons.storefront_rounded,
      colors: [Color(0xFF0EA5A4), Color(0xFFF59E0B)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    child: TextButton(
                      onPressed: _loading ? null : _finish,
                      child: const Text('Passer'),
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
                              isLastPage ? 'Commencer' : 'Suivant',
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

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.slide});

  final _OnboardingSlideData slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: slide.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(42),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0F172A),
                    blurRadius: 36,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Icon(
                slide.icon,
                size: 110,
                color: Colors.white,
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
    required this.icon,
    required this.colors,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
}
