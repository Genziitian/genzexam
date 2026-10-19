import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/student/help_screens.dart';
import 'success_tick.dart';

const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _contactPage = 'https://quiz.genziitian.in/contact.html';

enum StatusKind { success, failure }

/// Opens Contact us where the user is: the in-app help sheet inside the app,
/// the website's contact page when running in a browser.
Future<void> openContactUs(BuildContext context) async {
  if (kIsWeb) {
    await launchUrl(Uri.parse(_contactPage), webOnlyWindowName: '_self');
    return;
  }
  showHelpSheet(
    context,
    onOpenFaq: () => Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => const FaqScreen())),
  );
}

/// Full-screen animated confirmation. Resolves when the user leaves it.
Future<void> showStatusScreen(
  BuildContext context, {
  required StatusKind kind,
  required String title,
  required String message,
  String? primaryLabel,
  String? secondaryLabel,
  VoidCallback? onSecondary,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => StatusScreen(
        kind: kind,
        title: title,
        message: message,
        primaryLabel:
            primaryLabel ?? (kind == StatusKind.success ? 'Continue' : 'Close'),
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    required this.primaryLabel,
    this.secondaryLabel,
    this.onSecondary,
  });
  final StatusKind kind;
  final String title;
  final String message;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final ok = kind == StatusKind.success;
    final accent = ok ? _green : _red;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [accent.withValues(alpha: .10), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ok)
                          const SuccessTick(size: 200, label: 'Success')
                        else
                          const FailureCross(
                            size: 200,
                            label: 'Something went wrong',
                          ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.5,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: _muted,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          primaryLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (secondaryLabel != null)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onSecondary?.call();
                        },
                        child: Text(secondaryLabel!),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Need help?',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                    TextButton.icon(
                      onPressed: () => openContactUs(context),
                      icon: const Icon(Icons.support_agent_rounded, size: 18),
                      label: const Text('Contact us'),
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
