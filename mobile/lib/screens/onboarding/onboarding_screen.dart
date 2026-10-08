import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/app_ux_components.dart';

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isLast)
            TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Hero Container
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF16A34A), Color(0xFF1F3D22)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            slide['icon'] as IconData,
                            size: 54,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 36),

                        Text(
                          slide['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          slide['description'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots & Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (idx) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == idx ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == idx
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isLast ? 'Get Started' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
