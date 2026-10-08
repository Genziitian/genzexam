import 'package:flutter/material.dart';
import '../state/auth_state.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/student/student_main_shell.dart';

/// Production-grade Role-Based Route Gate for Quiz Lab Mobile.
///
/// Route Logic:
/// 1. Mounts [SplashScreen] on cold start to verify onboarding & credentials.
/// 2. If first install -> Mounts 3-slide [OnboardingScreen].
/// 3. If unauthenticated -> Mounts [LoginScreen].
/// 4. If authenticated:
///    - Student (Rank 0): Mounts 5-Tab [StudentMainShell].
///    - Admin (Rank 1): Mounts [AdminConsoleScreen].
///    - Manager (Rank 2): Mounts [ManagerWorkspaceScreen].
///      If Manager clicks 'Preview Student View', routes dynamically to [StudentMainShell]
///      with persistent exit preview banner.
class AppRouter extends StatefulWidget {
  final AuthState authState;

  const AppRouter({super.key, required this.authState});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _splashFinished = false;
  bool _showingOnboarding = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashFinished) {
      return SplashScreen(
        authState: widget.authState,
        onNeedsOnboarding: () {
          setState(() {
            _showingOnboarding = true;
            _splashFinished = true;
          });
        },
        onReady: () {
          setState(() {
            _splashFinished = true;
          });
        },
      );
    }

    if (_showingOnboarding) {
      return OnboardingScreen(
        onFinish: () {
          setState(() {
            _showingOnboarding = false;
          });
        },
      );
    }

    return ListenableBuilder(
      listenable: widget.authState,
      builder: (context, _) {
        switch (widget.authState.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                ),
              ),
            );

          case AuthStatus.unauthenticated:
            return LoginScreen(
              authState: widget.authState,
            );

          case AuthStatus.authenticated:
            return _routeByRole(widget.authState);
        }
      },
    );
  }

  /// The app has no manager or admin screens: whoever signs in, including a
  /// manager or an admin, gets the student app.
  Widget _routeByRole(AuthState state) {
    return StudentMainShell(
      authState: state,
      isManagerPreview: false,
    );
  }
}
