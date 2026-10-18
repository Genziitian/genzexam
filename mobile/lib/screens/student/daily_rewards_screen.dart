import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api.dart';
import '../../api/rewards_service.dart';

const _purple = Color(0xFF4F46E5);
const _labels = [
  '5% OFF',
  '30 DAYS PRO',
  '₹50 OFF',
  'TRY AGAIN',
  '25% OFF',
  'EXTRA SPIN',
  '₹100 OFF',
  '+50 XP',
  'FREE TEST',
  'FREE UPLOAD',
];

const _colors = [
  Color(0xFF4F46E5),
  Color(0xFFD97706),
  Color(0xFF059669),
  Color(0xFF64748B),
  Color(0xFF7C3AED),
  Color(0xFF0284C7),
  Color(0xFFDB2777),
  Color(0xFF2563EB),
  Color(0xFF0D9488),
  Color(0xFFEA580C),
];

IconData _getPrizeIcon(String type) {
  switch (type) {
    case 'free_pro':
      return Icons.workspace_premium_rounded;
    case 'coupon_pct':
    case 'coupon_flat':
      return Icons.confirmation_number_outlined;
    case 'bonus_xp':
      return Icons.bolt_rounded;
    case 'free_spin':
      return Icons.replay_circle_filled_rounded;
    case 'free_test':
      return Icons.assignment_outlined;
    case 'free_paper_upload':
      return Icons.cloud_upload_outlined;
    case 'try_again':
    default:
      return Icons.sentiment_satisfied_alt_rounded;
  }
}

class DailyRewardsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onAccountChanged;
  const DailyRewardsScreen({
    super.key,
    required this.apiClient,
    this.onAccountChanged,
  });
  @override
  State<DailyRewardsScreen> createState() => _DailyRewardsScreenState();
}

class _DailyRewardsScreenState extends State<DailyRewardsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _service = RewardsService(widget.apiClient);
  late final _turns = AnimationController.unbounded(vsync: this);
  RewardsSnapshot? _data;
  Object? _error;
  bool _loading = true, _busy = false, _history = false;
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _turns.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _needsRefresh = false;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _needsRefresh = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _spin() async {
    if (_busy || _needsRefresh || (_data?.remaining ?? 0) <= 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!reduced) {
      _turns.repeat(
        min: _turns.value,
        max: _turns.value + 1,
        period: const Duration(seconds: 1),
      );
    }
    try {
      HapticFeedback.mediumImpact();
      final result = await _service.spin();
      if (!mounted) return;
      _turns.stop();
      // Sectors start at twelve o'clock. Land their centre under the pointer.
      final fraction = (1 - (result.segment + .5) / 10) % 1;
      await _turns.animateTo(
        _turns.value.ceilToDouble() + (reduced ? 0 : 3) + fraction,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 3400),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(
        () => _data = RewardsSnapshot(
          remaining: result.remaining,
          rewards: [
            if (result.reward != null) result.reward!,
            ...(_data?.rewards ?? []),
          ],
        ),
      );
      widget.onAccountChanged?.call();
      await _showResultModal(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _needsRefresh = true;
        });
      }
    } finally {
      if (mounted) {
        _turns.stop();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showResultModal(RewardSpinResult result) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Result',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _colors[result.segment].withValues(alpha: .15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(_getPrizeIcon(result.reward?.type ?? 'try_again'), color: _colors[result.segment], size: 34),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  result.title,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  result.reward == null
                      ? (result.segment == 3
                          ? 'Better luck tomorrow! Free spin quota resets at midnight IST.'
                          : 'You won 1 Free Extra Spin! Spin again now.')
                      : 'Saved to your My Rewards list. Tap below to view your code.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (result.reward != null) setState(() => _history = true);
                    },
                    child: Text(result.reward != null ? 'My Rewards' : 'Got It'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: child,
      ),
    );
  }

  void _showPrizesSheet() {
    final shuffledPrizes = List<WheelPrizeDef>.from(wheelPrizes)..shuffle();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: _purple),
                  SizedBox(width: 8),
                  Text(
                    'Wheel Prizes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: shuffledPrizes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = shuffledPrizes[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _colors[p.segment].withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(_getPrizeIcon(p.type), color: _colors[p.segment], size: 20),
                        ),
                      ),
                      title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(p.sub, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rewardAction(RewardItem reward) async {
    if (_busy || reward.isExpired) return;
    setState(() => _busy = true);
    try {
      if (!reward.scratched) {
        await _service.reveal(reward.id);
        await _load();
        if (mounted && reward.code != null) {
          await Clipboard.setData(ClipboardData(text: reward.code!));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Coupon code ${reward.code} revealed & copied!')),
          );
        }
      } else if (reward.type == 'free_pro' && !reward.claimed) {
        final message = await _service.claimPro(reward.id);
        widget.onAccountChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
        await _load();
      } else if (reward.code != null) {
        await Clipboard.setData(ClipboardData(text: reward.code!));
        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon code copied!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not complete action.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildRulesDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: Material(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(Icons.shield_outlined, color: _purple, size: 20),
            title: const Text(
              'Rules and Conditions',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ruleItem('Daily Free Spin Allowance', 'Every registered account receives 1 free spin every calendar day. No payment required. Resets at midnight IST.'),
              _ruleItem('7-Day Automatic Expiry', 'All discount coupons and feature passes auto-disable exactly 7 days from the moment spun or scratched.'),
              _ruleItem('Redemption Venue', 'Course discount coupons are valid exclusively at Genziitian.in/courses checkout.'),
              _ruleItem('Order Value & Max Cap', 'Minimum purchase requirement is ₹350. Maximum discount on percentage coupons capped at ₹100.'),
              _ruleItem('30 Days Free Pro', 'Provides 30 consecutive calendar days of full Pro access with zero recurring billing.'),
              _ruleItem('Platform Rules Agreement', 'By participating you accept all Quiz LAB terms and promotional rules.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45),
          children: [
            TextSpan(text: '• $title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            TextSpan(text: desc),
          ],
        ),
      ),
    );
  }

  Widget _rewardCard(RewardItem reward) {
    final expired = reward.isExpired;
    final revealed = reward.scratched;
    final label = expired
        ? 'Expired'
        : !revealed
        ? 'Reveal reward'
        : reward.type == 'free_pro' && !reward.claimed
        ? 'Activate Pro'
        : reward.code != null
        ? 'Copy code'
        : reward.claimed
        ? 'Applied'
        : 'Revealed';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: expired ? Colors.grey.shade100 : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      expired ? Icons.timer_off_outlined : _getPrizeIcon(reward.type),
                      color: expired ? Colors.grey : _purple,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        revealed || expired ? reward.title : 'Your reward is ready',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (reward.expiresAt != null)
                        Text(
                          expired ? 'Expired after 7 days' : 'Expires in 7 days',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: expired ? Colors.grey.shade100 : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    expired ? 'Outdated' : 'Active',
                    style: TextStyle(
                      color: expired ? Colors.grey : const Color(0xFF15803D),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (revealed && !expired && reward.code != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SelectableText(
                      reward.code!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                    InkWell(
                      onTap: () => _rewardAction(reward),
                      child: const Text('Copy', style: TextStyle(color: _purple, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy || expired || (revealed && reward.code == null && (reward.type != 'free_pro' || reward.claimed))
                    ? null
                    : () => _rewardAction(reward),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: expired ? Colors.grey.shade100 : const Color(0xFFEEF2FF),
                  foregroundColor: expired ? Colors.grey.shade500 : _purple,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text('Daily Rewards', style: TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _busy ? () async {} : _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // Top header bar
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Spin & Win',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _showPrizesSheet,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('View Prizes'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: _busy ? null : () => setState(() => _history = !_history),
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _history
                            ? 'Back to Wheel'
                            : (_data?.rewards.isEmpty ?? true)
                            ? 'My Rewards'
                            : 'My Rewards (${_data?.rewards.length ?? 0})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_error != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error is ApiException
                                ? (_error as ApiException).message
                                : 'Temporary server failure. Please try again.',
                            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _error = null;
                              _loading = true;
                            });
                            _load();
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ],

                // View 1: Lucky Wheel
                if (!_history) ...[
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Semantics(
                            image: true,
                            label: 'Reward wheel with ten prizes',
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _turns,
                                      builder: (_, _) => CustomPaint(
                                        painter: _RewardWheelPainter(
                                          _turns.value,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFFEAB308),
                                        width: 4,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset('assets/logo.png'),
                                    ),
                                  ),
                                  const Positioned(
                                    top: 0,
                                    child: Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 46,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _purple,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _busy || _needsRefresh || (_data?.remaining ?? 0) <= 0
                                  ? null
                                  : _spin,
                              icon: const Icon(Icons.casino_outlined, size: 20),
                              label: Text(
                                _busy
                                    ? 'Spinning…'
                                    : _needsRefresh
                                    ? 'Rewards unavailable · Try again'
                                    : (_data?.remaining ?? 0) <= 0
                                    ? '✓ Spun Today · Come Back Tomorrow'
                                    : 'Spin now · Free daily spin',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildRulesDropdown(),
                ],

                // View 2: My Rewards List
                if (_history) ...[
                  if (_data?.rewards.isEmpty ?? true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.card_giftcard_rounded, color: _purple, size: 28),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No rewards yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Spin the wheel daily to collect coupons and Free Pro.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final reward in _data!.rewards) _rewardCard(reward),
                  _buildRulesDropdown(),
                ],
              ],
            ),
          ),
  );
}

class _RewardWheelPainter extends CustomPainter {
  final double turns;
  _RewardWheelPainter(this.turns);
  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero),
        radius = size.shortestSide / 2 - 14;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(turns * math.pi * 2);
    canvas.translate(-centre.dx, -centre.dy);
    const sweep = math.pi * 2 / 10;
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * sweep;
      canvas.drawArc(rect, angle, sweep, true, Paint()..color = _colors[i]);
      canvas.drawArc(
        rect,
        angle,
        sweep,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final text = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: radius < 125 ? 8 : 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(angle + sweep / 2);
      canvas.translate(radius * .67, 0);
      canvas.rotate(math.pi / 2);
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = const Color(0xFFEAB308)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RewardWheelPainter oldDelegate) =>
      oldDelegate.turns != turns;
}
