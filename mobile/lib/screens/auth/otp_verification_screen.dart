import 'package:flutter/material.dart';
import '../../state/auth_state.dart';

class OtpVerificationScreen extends StatefulWidget {
  final AuthState authState;
  final VoidCallback onBackToLogin;

  const OtpVerificationScreen({
    super.key,
    required this.authState,
    required this.onBackToLogin,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isResending = false;
  String? _infoBanner;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final email = widget.authState.pendingVerificationEmail;
    final otp = _otpController.text.trim();

    if (email == null || email.isEmpty) {
      widget.onBackToLogin();
      return;
    }

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP code')),
      );
      return;
    }

    await widget.authState.verifyOtp(email, otp);
  }

  Future<void> _handleResend() async {
    final email = widget.authState.pendingVerificationEmail;
    if (email == null) return;

    setState(() {
      _isResending = true;
      _infoBanner = null;
    });

    final success = await widget.authState.resendOtp(email);
    setState(() {
      _isResending = false;
      if (success) {
        _infoBanner = 'A fresh 6-digit OTP was sent to $email';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.authState.pendingVerificationEmail ?? '';
    final isLoading = widget.authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: widget.onBackToLogin,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF16A34A), size: 30),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit verification code sent to\n$email',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Error banner
              if (widget.authState.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    widget.authState.errorMessage!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500),
                  ),
                ),

              // Info banner
              if (_infoBanner != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Text(
                    _infoBanner!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                  ),
                ),

              // 6-digit OTP field
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: const Color(0xFF94A3B8).withOpacity(0.5),
                    letterSpacing: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Verify Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text(
                          'Verify & Proceed',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive the OTP? ", style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  TextButton(
                    onPressed: _isResending ? null : _handleResend,
                    child: _isResending
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Resend Code', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
