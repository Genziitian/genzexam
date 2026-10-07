import 'package:flutter/material.dart';
import '../state/auth_state.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/student/student_main_shell.dart';
import '../screens/admin/admin_console_screen.dart';
import '../screens/manager/manager_workspace_screen.dart';

/// Production-grade Role-Based Route Gate for GenZ IITian Mobile.
///
/// Route Logic:
/// 1. Inspects Sanctum Personal Access Token from FlutterSecureStorage on launch.
/// 2. If unauthenticated -> Mounts [LoginScreen].
/// 3. If needs OTP verification -> Mounts [OtpVerificationScreen].
/// 4. If authenticated:
///    - Student (Rank 0): Mounts 5-Tab [StudentMainShell].
///    - Admin (Rank 1): Mounts [AdminConsoleScreen].
///    - Manager (Rank 2): Mounts [ManagerWorkspaceScreen].
///      If Manager clicks 'Preview Student View', routes dynamically to [StudentMainShell]
///      with persistent exit preview banner.
class AppRouter extends StatelessWidget {
  final AuthState authState;

  const AppRouter({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authState,
      builder: (context, _) {
        switch (authState.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const _SplashScreen();

          case AuthStatus.unauthenticated:
            return LoginScreen(
              authState: authState,
              onNavigateToOtp: () {
                // Handled reactively via AuthStatus.needsVerification
              },
            );

          case AuthStatus.needsVerification:
            return OtpVerificationScreen(
              authState: authState,
              onBackToLogin: () {
                authState.checkAuthStatus();
              },
            );

          case AuthStatus.authenticated:
            return _routeByRole(authState);
        }
      },
    );
  }

  Widget _routeByRole(AuthState state) {
    final role = state.role;

    // Manager (Rank 2)
    if (role == 'manager') {
      if (state.isPreviewingStudentView) {
        return StudentMainShell(
          authState: state,
          isManagerPreview: true,
        );
      }
      return ManagerWorkspaceScreen(authState: state);
    }


    // Admin (Rank 1)
    if (role == 'admin') {
      return AdminConsoleScreen(authState: state);
    }

    // Student (Rank 0)
    return StudentMainShell(
      authState: state,
      isManagerPreview: false,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, color: Color(0xFF16A34A), size: 48),
            SizedBox(height: 16),
            Text(
              'QUIZ- LAB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'by GenZ IITian',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Verifying authoritative cloud credentials...',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
