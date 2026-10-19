import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/pro_access_guard.dart';
import '../../widgets/premium_widgets.dart';
import 'pro_membership_card.dart';

/// Shown in place of downloaded papers once Pro has ended (or cannot be
/// confirmed). Nothing downloaded opens until the member renews.
class ProLockedView extends StatefulWidget {
  final ProAccess access;
  final ApiClient apiClient;
  final int paperCount;

  /// Runs the access check again; returns the new answer.
  final Future<ProAccess> Function() onRecheck;

  const ProLockedView({
    super.key,
    required this.access,
    required this.apiClient,
    required this.onRecheck,
    this.paperCount = 0,
  });

  @override
  State<ProLockedView> createState() => _ProLockedViewState();
}

class _ProLockedViewState extends State<ProLockedView> {
  bool _checking = false;

  Future<void> _recheck() async {
    setState(() => _checking = true);
    await widget.onRecheck();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _resubscribe() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProMembershipScreen(apiClient: widget.apiClient),
      ),
    );
    if (mounted) await _recheck();
  }

  @override
  Widget build(BuildContext context) {
    final expired = widget.access == ProAccess.expired;
    final n = widget.paperCount;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          Center(
            child: PulseRings(
              size: 96,
              color: Brand.gold,
              child: Floating(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        .4, .4, .2, 0, 0, //
                        .4, .4, .2, 0, 0,
                        .4, .4, .2, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: const ProEmblem(size: 96, glow: false),
                    ),
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Brand.gold,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Brand.deep,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: Text(
              expired
                  ? 'Your Pro membership has ended'
                  : 'Verify your Pro membership',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Brand.ink,
                letterSpacing: -.4,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FadeSlideIn(
            delay: const Duration(milliseconds: 250),
            child: Text(
              expired
                  ? 'Please resubscribe or purchase Pro again to open your downloaded papers. They stay locked, online or offline, until Pro is active.'
                  : 'We could not confirm your Pro membership. Connect to the internet once so we can check it. Your downloads unlock as soon as Pro is confirmed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.muted, height: 1.5),
            ),
          ),
          if (n > 0) ...[
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      color: Color(0xFF9A5B00),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$n downloaded ${n == 1 ? 'paper is' : 'papers are'} waiting for you. Nothing is deleted. Renew and they open again.',
                        style: const TextStyle(
                          color: Color(0xFF7A4A00),
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          FadeSlideIn(
            delay: const Duration(milliseconds: 450),
            child: PremiumButton(
              gold: true,
              icon: Icons.workspace_premium_rounded,
              label: expired ? 'Resubscribe to Pro' : 'See Pro membership',
              onPressed: _resubscribe,
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 520),
            child: TextButton.icon(
              onPressed: _checking ? null : _recheck,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                _checking ? 'Checking…' : 'I have already renewed. Check again',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
