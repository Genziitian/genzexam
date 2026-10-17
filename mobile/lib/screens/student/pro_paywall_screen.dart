import 'package:flutter/material.dart';

import '../../widgets/app_ux_components.dart';
import '../../widgets/premium_widgets.dart';

/// Which plan the member picked on the paywall.
enum ProPlanChoice { trial, monthly }

/// "Get Pro" page: what Pro includes, then the plan choice. New members see a
/// free trial and the monthly plan; members who already had a trial see only
/// the monthly plan.
///
/// The buttons are not connected to billing yet. Pass [onStartTrial] and
/// [onSubscribe] to wire them; until then they tell the member it is not
/// available.
class ProPaywallScreen extends StatefulWidget {
  final bool trialAvailable;
  final int trialDays;
  final String price;
  final Future<void> Function()? onStartTrial;
  final Future<void> Function()? onSubscribe;

  const ProPaywallScreen({
    super.key,
    this.trialAvailable = true,
    this.trialDays = 7,
    this.price = '₹99',
    this.onStartTrial,
    this.onSubscribe,
  });

  @override
  State<ProPaywallScreen> createState() => _ProPaywallScreenState();
}

class _ProPaywallScreenState extends State<ProPaywallScreen> {
  late ProPlanChoice _choice = widget.trialAvailable
      ? ProPlanChoice.trial
      : ProPlanChoice.monthly;
  bool _busy = false;

  bool get _trial => _choice == ProPlanChoice.trial;

  Future<void> _continue() async {
    final handler = _trial ? widget.onStartTrial : widget.onSubscribe;
    if (handler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro checkout is not available yet.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await handler();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Get Pro'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: 150 + bottom),
            children: [
              _Hero(price: widget.price),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 250),
                      child: Text(
                        'Everything in Pro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Brand.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 320),
                      child: _Benefit(
                        icon: Icons.download_for_offline_rounded,
                        title: 'Practise offline',
                        detail:
                            'Download papers to your phone and attempt them anywhere, with no internet.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 400),
                      child: _Benefit(
                        icon: Icons.upload_file_rounded,
                        title: '5 paper uploads every week',
                        detail:
                            'Turn your own PDFs into private practice tests. Free accounts get 1 a week.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 480),
                      child: _Benefit(
                        icon: Icons.ondemand_video_rounded,
                        title: 'Video solutions',
                        detail:
                            'Step-by-step video answers for questions, as they roll out.',
                      ),
                    ),
                    const SizedBox(height: 22),
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 560),
                      child: _Compare(),
                    ),
                    const SizedBox(height: 26),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 640),
                      child: Text(
                        widget.trialAvailable
                            ? 'Choose how to start'
                            : 'Your plan',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Brand.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.trialAvailable) ...[
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 700),
                        child: _PlanCard(
                          selected: _trial,
                          recommended: true,
                          title: '${widget.trialDays}-day free trial',
                          subtitle:
                              'Then ${widget.price} / month. Try everything first.',
                          trailing: 'FREE',
                          onTap: () => setState(() => _choice = ProPlanChoice.trial),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 780),
                      child: _PlanCard(
                        selected: !_trial,
                        title: 'Pro monthly',
                        subtitle: widget.trialAvailable
                            ? 'Skip the trial and start Pro today.'
                            : 'Billed monthly. Cancel any time.',
                        trailing: '${widget.price}/mo',
                        onTap: () => setState(() => _choice = ProPlanChoice.monthly),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Center(
                      child: Text(
                        'Cancel any time from your subscription settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Brand.muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _trial
                          ? '${widget.trialDays} days free, then ${widget.price} a month'
                          : '${widget.price} a month, starting today',
                      key: ValueKey(_trial),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Brand.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PremiumButton(
                    gold: true,
                    busy: _busy,
                    icon: _trial
                        ? Icons.rocket_launch_rounded
                        : Icons.workspace_premium_rounded,
                    label: _trial
                        ? 'Start ${widget.trialDays}-day free trial'
                        : 'Subscribe for ${widget.price}/month',
                    onPressed: _continue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String price;
  const _Hero({required this.price});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      22,
      MediaQuery.paddingOf(context).top + 62,
      22,
      30,
    ),
    decoration: const BoxDecoration(
      gradient: Brand.darkGradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
    ),
    child: Column(
      children: [
        PulseRings(
          size: 100,
          color: Brand.gold,
          child: const Floating(child: ProEmblem(size: 100)),
        ),
        const FadeSlideIn(
          delay: Duration(milliseconds: 120),
          child: Text(
            'Go Pro. Practise without limits.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delay: const Duration(milliseconds: 220),
          child: Text(
            'Offline papers, more uploads and video solutions for $price a month.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.mint, height: 1.45),
          ),
        ),
      ],
    ),
  );
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _Benefit({required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 6)),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: Brand.gradient,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Colors.white, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Brand.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(color: Brand.muted, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Compare extends StatelessWidget {
  const _Compare();

  Widget _cell(String text, {bool bold = false, Color? color}) => Expanded(
    flex: 2,
    child: Center(
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? Brand.ink,
          fontSize: 13,
        ),
      ),
    ),
  );

  Widget _row(String label, String free, String pro, {bool last = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Brand.ink, fontSize: 13),
              ),
            ),
            _cell(free, color: Brand.muted),
            _cell(pro, bold: true, color: Brand.green),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(flex: 3, child: SizedBox()),
            _cell('Free', color: Brand.muted),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD36E), Color(0xFFF59E0B)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Brand.deep,
                      fontSize: 12,
                      letterSpacing: .6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _row('Paper uploads', '1 / week', '5 / week'),
        _row('Offline downloads', '—', 'Included'),
        _row('Video solutions', '—', 'Included'),
        _row('Practice papers', 'Included', 'Included', last: true),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  final bool selected;
  final bool recommended;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      AppHaptics.selection();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFECFDF3) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Brand.green : const Color(0xFFE2E8F0),
          width: selected ? 2 : 1.2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Brand.green.withValues(alpha: .2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? Brand.green : Colors.transparent,
              border: Border.all(
                color: selected ? Brand.green : const Color(0xFFCBD5E1),
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Brand.ink,
                        ),
                      ),
                    ),
                    if (recommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Brand.gold,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'BEST START',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Brand.deep,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Brand.muted, fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: selected ? Brand.green : Brand.ink,
            ),
          ),
        ],
      ),
    ),
  );
}
