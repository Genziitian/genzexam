import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/premium_widgets.dart';

/// 3-Slide First-Time Onboarding Walkthrough for Quiz Lab Mobile.
///
/// Features:
/// - Persisted `has_seen_onboarding` flag via FlutterSecureStorage.
/// - Smooth page indicator dots with haptic feedback.
/// - "Skip" and "Get Started" buttons.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.auto_stories_rounded,
      'title': 'Master Past Term Papers',
      'subtitle': 'Comprehensive Past Quizzes & Mocks',
      'description':
          'Access official past term papers, graded practice sets, and mock assessments for Mathematics, Python, and Statistics.',
    },
    {
      'icon': Icons.calculate_rounded,
      'title': 'Pro Scientific Calculators',
      'subtitle': 'Exam-Ready Arithmetic & Functions',
      'description':
          'Evaluate complex equations, matrix determinants, logarithms, and trigonometry on-screen with zero distractions and instant feedback.',
    },
    {
      'icon': Icons.cloud_sync_rounded,
      'title': 'Real-Time Cloud Progress',
      'subtitle': 'Weekly Goals & Community Help',
      'description':
          'Track your weekly quiz goals, earn XP milestones, and resolve doubts with verified teaching assistants in real-time forums.',
    },
  ];

  Future<void> _completeOnboarding() async {
    AppHaptics.light();
    await _storage.write(key: 'has_seen_onboarding', value: 'true');
    widget.onFinish();
  }

  void _nextPage() {
    AppHaptics.selection();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    opacity: isLast ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: TextButton(
                      onPressed: isLast ? null : _completeOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Brand.muted,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) {
                    AppHaptics.selection();
                    setState(() => _currentPage = i);
                  },
                  itemBuilder: (context, i) {
                    final slide = _slides[i];
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        var delta = 0.0;
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          delta = ((_pageController.page ?? _currentPage.toDouble()) - i)
                              .clamp(-1.0, 1.0);
                        }
                        return Opacity(
                          opacity: (1 - delta.abs() * .8).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(delta * -40, 0),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FadeSlideIn(
                              dy: 30,
                              child: PulseRings(
                                size: 112,
                                child: Floating(
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      gradient: Brand.gradient,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Brand.green.withValues(alpha: 0.38),
                                          blurRadius: 30,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      slide['icon'] as IconData,
                                      size: 56,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 160),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Brand.green.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  (slide['subtitle'] as String).toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: Brand.green,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 260),
                              child: Text(
                                slide['title'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  color: Brand.ink,
                                  letterSpacing: -0.6,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 360),
                              child: Text(
                                slide['description'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: Brand.muted,
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (idx) => AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == idx ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == idx
                                ? Brand.green
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    PremiumButton(
                      label: isLast ? 'Get Started' : 'Continue',
                      icon: isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                      onPressed: _nextPage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
