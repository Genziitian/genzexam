import 'package:flutter/material.dart';

import '../../legal/legal_documents.dart';

import '../../api/pro_play_offer.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/feature_load_error_card.dart';
import 'help_screens.dart';

enum ProPlanChoice { monthly, yearly }

/// Prices and eligibility come from the authenticated server and Play catalog.
class ProPaywallScreen extends StatefulWidget {
  final ProPlayOffer? monthly;
  final ProPlayOffer? yearly;
  final bool disabled;
  final bool busy;
  final String? message;
  final Object? membershipError;
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
    this.membershipError,
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
            padding: EdgeInsets.only(
              bottom:
                  (MediaQuery.textScalerOf(context).scale(14) > 20
                      ? 240
                      : 150) +
                  bottom,
            ),
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
                    if (widget.membershipError != null) ...[
                      const SizedBox(height: 20),
                      FeatureLoadErrorCard(
                        error: widget.membershipError!,
                        feature: 'Membership',
                        onRetry: () async => widget.onRetry(),
                        onSupport: () => emailSupport(context),
                      ),
                    ] else ...[
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
                            : () => setState(
                                () => _choice = ProPlanChoice.monthly,
                              ),
                      ),
                      const SizedBox(height: 10),
                      _PlanCard(
                        selected: _choice == ProPlanChoice.yearly,
                        title: 'Yearly',
                        subtitle: 'Billed yearly. No free trial.',
                        trailing: widget.yearly?.price ?? 'Unavailable',
                        onTap: widget.busy
                            ? () {}
                            : () => setState(
                                () => _choice = ProPlanChoice.yearly,
                              ),
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
                              _ReceiptRow(
                                label: 'Monthly plan',
                                amount: _offer!.price,
                              ),
                              const SizedBox(height: 8),
                              _ReceiptRow(
                                label:
                                    '${_offer!.trialDays}-day trial discount',
                                amount: '− ${_offer!.price}',
                              ),
                              const Divider(height: 24),
                              const _ReceiptRow(
                                label: 'Due today',
                                amount: 'FREE',
                                total: true,
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    if (widget.membershipError == null &&
                        (widget.monthly == null || widget.yearly == null))
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
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Terms & Conditions'),
                              ),
                              body: const SingleChildScrollView(
                                padding: EdgeInsets.all(20),
                                child: SelectableText(LegalDocuments.terms),
                              ),
                            ),
                          ),
                        ),
                        child: const Text.rich(
                          TextSpan(
                            text: 'By continuing, you agree to our ',
                            style: TextStyle(fontSize: 11, color: Brand.muted),
                            children: [
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: Brand.green,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (_trial) ...[
                      const SizedBox(height: 18),
                      Text(
                        'First charge: ${_date(DateUtils.addDaysToDate(DateTime.now(), _offer!.trialDays))} — ${_offer!.price}, then every month.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Cancel before this date to avoid the subscription charge. The date assumes you start today; Google Play confirms the exact billing time at checkout.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Brand.muted),
                      ),
                    ],
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
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottom),
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
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _trial
                                ? '${_offer!.trialDays} days free, then ${_offer!.price}/month'
                                : widget.membershipError != null
                                ? 'Membership unavailable'
                                : _offer?.terms ??
                                      'Plan unavailable in Google Play',
                            key: ValueKey(
                              '${_choice.name}-${_trial}-${_offer?.price}',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Brand.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Brand.gold,
                            foregroundColor: Brand.deep,
                            minimumSize: const Size(110, 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                              _offer == null ||
                                  widget.disabled ||
                                  widget.busy ||
                                  widget.membershipError != null
                              ? null
                              : () => widget.onSubscribe(_offer!),
                          child: widget.busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _trial
                                      ? 'Try for free'
                                      : _choice == ProPlanChoice.yearly
                                      ? 'Subscribe yearly'
                                      : 'Subscribe monthly',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
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

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.amount,
    this.total = false,
  });
  final String label;
  final String amount;
  final bool total;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: total ? 17 : 14,
            fontWeight: total ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 16),
      Flexible(
        child: Text(
          amount,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: total ? 22 : 16,
            fontWeight: FontWeight.w800,
            color: total ? Brand.green : Brand.ink,
          ),
        ),
      ),
    ],
  );
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
        _row('Daily spins', '1 / day', '7 / day'),
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
