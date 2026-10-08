import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_ux_components.dart';

class LoginScreen extends StatefulWidget {
  final AuthState authState;

  const LoginScreen({
    super.key,
    required this.authState,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// One looping controller drives the backdrop, the logo glow and the Google border.
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    AppHaptics.light();
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await widget.authState.login(email, password);
  }

  Future<void> _handleGoogleSignIn() async {
    AppHaptics.light();
    FocusScope.of(context).unfocus();
    if (widget.authState.isGoogleSignInPending) return;
    await widget.authState.loginWithGoogle();
  }

  void _showLegalSheet(String title, String content) {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              Text(
                content,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _termsContent = '''
Terms & Conditions
Last Updated: April 2026

01 Service Description
QUIZ LAB provides access to premium digital educational courses designed specifically for students. Our services are delivered entirely online. Access to the courses is granted immediately upon successful completion of the payment process.

02 User Account & Security
To access our courses, users must sign in via their Google account. You are solely responsible for maintaining the confidentiality of your account information and for all activities that occur under your account. We reserve the right to terminate accounts that violate our security protocols.

03 Course Access & Usage
Access is granted exclusively to the email address used during the purchase.
Course access is non-transferable and intended for personal use only.
Sharing account credentials or course content with third parties is strictly prohibited.

04 Payment Terms
All prices are clearly displayed before the final checkout. By proceeding with the payment, you agree to the price and terms of the specific course. All payments are processed through secure third-party payment gateways (Razorpay, Stripe, or Cashfree).

05 Prohibited Use & Copyright
All content on this platform, including videos, documents, and code samples, is the intellectual property of QUIZ LAB. Any form of piracy, unauthorized redistribution, or commercial use of our content will result in legal action and immediate termination of access without notice.

06 Limitation of Liability
QUIZ LAB is an educational platform. While we strive for excellence, we do not guarantee specific academic results or career outcomes. The platform is not responsible for any misuse of the information provided or for any technical issues arising from the user's internet connection or device.
''';

  static const String _privacyContent = '''
1. Information We Collect:
Quiz Lab collects necessary academic information including your registered name, student email address (@iitm.ac.in), course enrollment selections, quiz attempt answers, scores, and weekly progress goals.

2. Authentication & Data Security:
We utilize Laravel Sanctum bearer tokens stored in hardware-backed Android Keystore using EncryptedSharedPreferences (AES-256-GCM). We do not store plain-text passwords or financial transaction information on the device.

3. Third-Party Payments:
Payment transactions for paper storefront purchases are securely processed by Razorpay. We do not process or retain credit card numbers or UPI PINs.

4. Account & Data Deletion:
In compliance with Google Play Store policies, users have the absolute right to delete their account and associated attempt records at any time directly through the app Settings menu or via our dedicated web portal at https://lab.genziitian.in/delete-account.html.

5. Contact:
For inquiries regarding our Privacy Policy or data rights, contact us at privacy@genziitian.in or support@genziitian.in.
''';

  @override
  Widget build(BuildContext context) {
    final authState = widget.authState;
    final isLoading = authState.status == AuthStatus.loading;
    final googlePending = authState.isGoogleSignInPending;
    final screenHeight = MediaQuery.of(context).size.height;
    final double backdropHeight = (screenHeight * 0.48).clamp(320.0, 460.0).toDouble();

    return AppKeyboardDismiss(
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Stack(
          children: [
            // Animated green backdrop behind the logo
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: backdropHeight,
              child: _AnimatedBackdrop(animation: _ambient),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // App Branding
                          _Entrance(
                            delayMs: 0,
                            offsetY: -24,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _ambient,
                                      builder: (context, child) {
                                        final pulse = 0.5 + 0.5 * math.sin(_ambient.value * 4 * math.pi);
                                        return Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF4ADE80).withValues(alpha: 0.22 + 0.28 * pulse),
                                                blurRadius: 18 + 16 * pulse,
                                                spreadRadius: 1 + 2 * pulse,
                                              ),
                                            ],
                                          ),
                                          child: child,
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.asset(
                                          'assets/logo.png',
                                          height: 68,
                                          width: 68,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Quiz Lab',
                                          style: TextStyle(
                                            fontSize: 32,
                                            height: 1.1,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.6,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'by GenZ IITian',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                            color: Color(0xFFA7F3D0),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Practice smarter. Score higher.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFD1FAE5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),

                          // Sign-in card
                          _Entrance(
                            delayMs: 180,
                            offsetY: 36,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                                    blurRadius: 32,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Welcome back',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Sign in to continue your preparation',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 18),

                                  // Error message banner
                                  if (authState.errorMessage != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              authState.errorMessage!,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFFB91C1C),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Google Sign-In Button
                                  _GoogleButton(
                                    animation: _ambient,
                                    pending: googlePending,
                                    onTap: isLoading ? null : _handleGoogleSignIn,
                                  ),

                                  const SizedBox(height: 18),
                                  const Row(
                                    children: [
                                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'or sign in with email',
                                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // Email Input
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: _fieldDecoration(
                                      label: 'Email Address',
                                      icon: Icons.mail_outline_rounded,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Email is required';
                                      if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Password Input
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    decoration: _fieldDecoration(
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          color: const Color(0xFF64748B),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Password is required';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Login Button
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          disabledBackgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Sign In',
                                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Terms of Service & Privacy Policy links (Play Store requirement)
                          _Entrance(
                            delayMs: 360,
                            offsetY: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => _showLegalSheet('Terms of Service', _termsContent),
                                  child: const Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Text(
                                  '   ·   ',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                                GestureDetector(
                                  onTap: () => _showLegalSheet('Privacy Policy', _privacyContent),
                                  child: const Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: border(const Color(0xFFE2E8F0)),
      enabledBorder: border(const Color(0xFFE2E8F0)),
      focusedBorder: border(const Color(0xFF16A34A), 2),
    );
  }
}

/// Dark green header with slowly drifting glows.
class _AnimatedBackdrop extends StatelessWidget {
  final Animation<double> animation;

  const _AnimatedBackdrop({required this.animation});

  static Widget _glow(Alignment alignment, double size, Color color, double opacity) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07200F), Color(0xFF14532D), Color(0xFF15803D)],
          ),
        ),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                _glow(Alignment(-0.9 + 0.3 * math.sin(t), -0.7 + 0.25 * math.cos(t)), 240, const Color(0xFF4ADE80), 0.30),
                _glow(Alignment(0.95 + 0.25 * math.cos(t), -0.1 + 0.35 * math.sin(t)), 280, const Color(0xFFA3E635), 0.18),
                _glow(Alignment(0.0 + 0.5 * math.sin(t + 2), 1.0 + 0.2 * math.cos(t)), 260, const Color(0xFF22D3EE), 0.16),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fades and slides its child in once, after an optional delay.
class _Entrance extends StatelessWidget {
  final int delayMs;
  final double offsetY;
  final Widget child;

  const _Entrance({required this.delayMs, required this.offsetY, required this.child});

  @override
  Widget build(BuildContext context) {
    const baseMs = 650;
    final totalMs = baseMs + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1.0, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * offsetY),
            child: child,
          ),
        );
      },
    );
  }
}

/// "Continue with Google" with a rotating Google-colour border and press feedback.
class _GoogleButton extends StatefulWidget {
  final Animation<double> animation;
  final bool pending;
  final VoidCallback? onTap;

  const _GoogleButton({required this.animation, required this.pending, required this.onTap});

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continue with Google',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedBuilder(
            animation: widget.animation,
            builder: (context, child) {
              // Whole turns per loop keep the rotation seamless; faster while waiting.
              final turns = widget.pending ? 8 : 2;
              final angle = widget.animation.value * 2 * math.pi * turns;
              return Container(
                height: 56,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: SweepGradient(
                    colors: const [_blue, _red, _yellow, _green, _blue],
                    transform: GradientRotation(angle),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.pending)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(_blue),
                      ),
                    )
                  else
                    const CustomPaint(size: Size(22, 22), painter: _GoogleLogoPainter()),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.pending ? 'Signing in with Google…' : 'Continue with Google',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
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
}

/// The four-colour Google "G", drawn so no image file is needed.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    double rad(double degrees) => degrees * math.pi / 180;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Angles run clockwise from the 3 o'clock position.
    paint.color = const Color(0xFFEA4335); // red, top
    canvas.drawArc(rect, rad(200), rad(115), false, paint);
    paint.color = const Color(0xFFFBBC05); // yellow, left
    canvas.drawArc(rect, rad(150), rad(52), false, paint);
    paint.color = const Color(0xFF34A853); // green, bottom
    canvas.drawArc(rect, rad(45), rad(107), false, paint);
    paint.color = const Color(0xFF4285F4); // blue, right
    canvas.drawArc(rect, rad(-2), rad(49), false, paint);

    // Blue crossbar
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2 - stroke * 0.05, stroke), bar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
