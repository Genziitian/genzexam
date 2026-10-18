import 'package:flutter/material.dart';

import '../../api/pro_play_offer.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/premium_widgets.dart';

enum ProPlanChoice { monthly, yearly }

/// Prices and eligibility come from the authenticated server and Play catalog.
class ProPaywallScreen extends StatefulWidget {
  final ProPlayOffer? monthly;
  final ProPlayOffer? yearly;
  final bool disabled;
  final bool busy;
  final String? message;
  final Future<void> Function(ProPlayOffer) onSubscribe;
  final VoidCallback onRestore;
  final VoidCallback onRetry;
  const ProPaywallScreen({
    super.key,
    this.monthly,
    this.yearly,
    required this.onSubscribe,
    required this.onRestore,
    required this.onRetry,
    this.disabled = false,
    this.busy = false,
    this.message,
  });

  @override
  State<ProPaywallScreen> createState() => _ProPaywallScreenState();
}

class _ProPaywallScreenState extends State<ProPaywallScreen> {
  ProPlanChoice _choice = ProPlanChoice.monthly;
  ProPlayOffer? get _offer =>
      _choice == ProPlanChoice.yearly ? widget.yearly : widget.monthly;
  bool get _trial => _offer?.isTrial == true;
  String _date(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Brand.deep,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Get Pro'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: 230 + bottom),
            children: [
              const _Hero(),
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
                      delay: Duration(milliseconds: 560),
                      child: _Compare(),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Choose your plan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      selected: _choice == ProPlanChoice.monthly,
                      title: 'Monthly',
                      recommended: widget.monthly?.isTrial == true,
                      subtitle: widget.monthly?.isTrial == true
                          ? 'Try for free · ${widget.monthly!.trialDays} days, then ${widget.monthly!.price}/month'
                          : 'Billed monthly. Cancel renewal any time.',
                      trailing: widget.monthly?.price ?? 'Unavailable',
                      onTap: widget.busy
                          ? () {}
                          : () =>
                                setState(() => _choice = ProPlanChoice.monthly),
                    ),
                    const SizedBox(height: 10),
                    _PlanCard(
                      selected: _choice == ProPlanChoice.yearly,
                      title: 'Yearly',
                      subtitle: 'Billed yearly. No free trial.',
                      trailing: widget.yearly?.price ?? 'Unavailable',
                      onTap: widget.busy
                          ? () {}
                          : () =>
                                setState(() => _choice = ProPlanChoice.yearly),
                    ),
                    if (_trial) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_offer!.price} − ${_offer!.price} trial discount = FREE today',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pro starts today. First charge: ${_date(DateUtils.addDaysToDate(DateTime.now(), _offer!.trialDays))}, then ${_offer!.price}/month.',
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Cancel before the trial ends to avoid the subscription charge. Google Play confirms the exact billing date at checkout.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Brand.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(widget.message!),
                      ),
                    if (widget.disabled && widget.message == null)
                      const Text(
                        'New Pro subscriptions are unavailable right now.',
                      ),
                    TextButton(
                      onPressed: widget.onRestore,
                      child: const Text('Restore purchases'),
                    ),
                    if (widget.monthly == null || widget.yearly == null)
                      TextButton(
                        onPressed: widget.onRetry,
                        child: const Text('Reload available plans'),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _trial
                          ? '${_offer!.trialDays} days free, then ${_offer!.price}/month'
                          : _offer?.terms ?? 'Plan unavailable in Google Play',
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
                    busy: widget.busy,
                    icon: _trial
                        ? Icons.rocket_launch_rounded
                        : Icons.workspace_premium_rounded,
                    label: _trial
                        ? 'Try for free'
                        : _choice == ProPlanChoice.yearly
                        ? 'Subscribe yearly'
                        : 'Subscribe monthly',
                    onPressed: _offer == null || widget.disabled || widget.busy
                        ? null
                        : () => widget.onSubscribe(_offer!),
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
  const _Hero();

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
            'Go Pro. Make practice yours.',
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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Brand.ink,
                  fontSize: 13,
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                  style: const TextStyle(
                    color: Brand.muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
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
