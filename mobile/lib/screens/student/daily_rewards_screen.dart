import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

Color _prizeColor(String type) => switch (type) {
  'free_pro' => const Color(0xFFD97706),
  'coupon_pct' => const Color(0xFF7C3AED),
  'coupon_flat' => const Color(0xFF059669),
  'bonus_xp' => const Color(0xFF2563EB),
  'free_spin' => const Color(0xFF0284C7),
  'free_test' => const Color(0xFF0D9488),
  'free_paper_upload' => const Color(0xFFEA580C),
  _ => const Color(0xFF64748B),
};

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
  final VoidCallback? onOpenUploadPaper;
  final VoidCallback? onOpenTestYourself;
  const DailyRewardsScreen({
    super.key,
    required this.apiClient,
    this.onAccountChanged,
    this.onOpenUploadPaper,
    this.onOpenTestYourself,
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
  final Set<String> _expandedInstructions = {};

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
    final destination = result.reward == null
        ? null
        : _rewardDestination(result.reward!);
    final action = await showGeneralDialog<VoidCallback>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Result',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                _colors[result.segment].withValues(alpha: .16),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _gold.withValues(alpha: .6)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 28)],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _colors[result.segment],
                        Color.lerp(_colors[result.segment], Colors.black, .3)!,
                      ],
                    ),
                    border: Border.all(color: _gold, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _colors[result.segment].withValues(alpha: .4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getPrizeIcon(result.reward?.type ?? 'try_again'),
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  result.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  result.reward == null
                      ? (result.segment == 3
                            ? 'Better luck tomorrow! Free spin quota resets at midnight IST.'
                            : 'You won 1 Free Extra Spin! Spin again now.')
                      : _rewardDescription(result.reward!),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx, destination);
                      if (destination == null && result.reward != null)
                        setState(() => _history = true);
                    },
                    child: Text(
                      destination != null
                          ? result.reward!.type == 'free_paper_upload'
                                ? 'Upload paper now'
                                : 'Test yourself now'
                          : result.reward != null
                          ? 'My Rewards'
                          : 'Got It',
                    ),
                  ),
                ),
                if (destination != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _history = true);
                    },
                    child: const Text('My Rewards'),
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
    if (mounted) action?.call();
  }

  VoidCallback? _rewardDestination(RewardItem reward) => switch (reward.type) {
    'free_paper_upload' => widget.onOpenUploadPaper,
    'free_test' => widget.onOpenTestYourself,
    _ => null,
  };

  String _rewardDescription(RewardItem reward) => switch (reward.type) {
    'free_paper_upload' => '1 bonus upload has been added to your account. Open Upload Paper to use it. No coupon code needed.',
    'free_test' => '1 bonus practice test has been added to your account. Open Test Yourself to use it. No coupon code needed.',
    'free_pro' => 'Open My Rewards and activate your 30 days of free Pro. No card or recurring charge.',
    'free_spin' =>
      'Your extra spin is ready. Return to the wheel to spin again.',
    'bonus_xp' =>
      '50 Study XP has been added to your account. No code or claim needed.',
    _ => 'Saved in My Rewards. Reveal and copy your coupon, then apply it at Genziitian.in/courses checkout.',
  };

  void _showPrizesSheet() {
    final shuffledPrizes = List<WheelPrizeDef>.from(wheelPrizes)..shuffle();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: _goldLight),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Wheel Prizes',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                itemCount: shuffledPrizes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final p = shuffledPrizes[i];
                  final c = _colors[p.segment];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE0E7FF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _getPrizeIcon(p.type),
                            color: c,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.sub,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rewardAction(RewardItem reward) async {
    if (_busy || reward.isExpired) return;
    final destination = _rewardDestination(reward);
    if (destination != null) {
      destination();
      return;
    }
    if (reward.type == 'free_spin') {
      setState(() => _history = false);
      return;
    }
    setState(() => _busy = true);
    try {
      if (!reward.scratched) {
        await _service.reveal(reward.id);
        await _load();
        if (mounted && reward.code != null) {
          await Clipboard.setData(ClipboardData(text: reward.code!));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Coupon code ${reward.code} revealed & copied!'),
            ),
          );
        }
      } else if (reward.type == 'free_pro' && !reward.claimed) {
        final message = await _service.claimPro(reward.id);
        widget.onAccountChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
        await _load();
      } else if (reward.code != null) {
        await Clipboard.setData(ClipboardData(text: reward.code!));
        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Coupon code copied!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Could not complete action.',
            ),
          ),
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
        color: Colors.white,
        elevation: 1.5,
        shadowColor: const Color(0x1A1E1B4B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0E7FF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: _purple,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: _purple,
                size: 20,
              ),
            ),
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
              _ruleItem(
                'Daily Free Spin Allowance',
                'Every registered account receives 1 free spin every calendar day. No payment required. Resets at midnight IST.',
              ),
              _ruleItem(
                '7-Day Automatic Expiry',
                'All discount coupons and feature passes auto-disable exactly 7 days from the moment spun or scratched.',
              ),
              _ruleItem(
                'Redemption Venue',
                'Course discount coupons are valid exclusively at Genziitian.in/courses checkout.',
              ),
              _ruleItem(
                'Order Value & Max Cap',
                'Minimum purchase requirement is ₹350. Maximum discount on percentage coupons capped at ₹100.',
              ),
              _ruleItem(
                '30 Days Free Pro',
                'Provides 30 consecutive calendar days of full Pro access with zero recurring billing.',
              ),
              _ruleItem(
                'Platform Rules Agreement',
                'By participating you accept all Quiz LAB terms and promotional rules.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 10),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _gold,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardCard(RewardItem reward) {
    final expired = reward.isExpired;
    final revealed = reward.scratched;
    final label = expired
        ? 'Expired'
        : _rewardDestination(reward) != null
        ? reward.type == 'free_paper_upload'
              ? 'Upload paper now'
              : 'Test yourself now'
        : reward.type == 'free_spin'
        ? 'Spin again'
        : !revealed
        ? 'Reveal reward'
        : reward.type == 'free_pro' && !reward.claimed
        ? 'Activate Pro'
        : reward.code != null
        ? 'Copy code'
        : reward.claimed
        ? 'Applied'
        : 'Revealed';
    final accent = expired ? const Color(0xFF9CA3AF) : _prizeColor(reward.type);
    final actionDisabled =
        _busy ||
        expired ||
        (_rewardDestination(reward) == null &&
            reward.type != 'free_spin' &&
            revealed &&
            reward.code == null &&
            (reward.type != 'free_pro' || reward.claimed));
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141E1B4B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent, accent.withValues(alpha: .55)],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            expired
                                ? Icons.timer_off_outlined
                                : _getPrizeIcon(reward.type),
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                revealed || expired
                                    ? reward.title
                                    : 'Your reward is ready',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                              if (reward.expiresAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        expired
                                            ? 'Expired after 7 days'
                                            : 'Expires in 7 days',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: expired
                                ? Colors.grey.shade100
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            expired ? 'Outdated' : 'Active',
                            style: TextStyle(
                              color: expired
                                  ? Colors.grey
                                  : const Color(0xFF15803D),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (revealed && !expired && reward.code != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF7EA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _gold.withValues(alpha: .7),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.confirmation_number_outlined,
                              color: _goldDeep,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SelectableText(
                                reward.code!,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() {
                            if (!_expandedInstructions.remove(reward.id))
                              _expandedInstructions.add(reward.id);
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                          ),
                          icon: Icon(
                            _expandedInstructions.contains(reward.id)
                                ? Icons.expand_less_rounded
                                : Icons.info_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _expandedInstructions.contains(reward.id)
                                ? 'Hide instructions'
                                : 'Instructions',
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: actionDisabled
                              ? null
                              : () => _rewardAction(reward),
                          style: FilledButton.styleFrom(
                            backgroundColor: _purple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(label),
                        ),
                      ],
                    ),
                    if (_expandedInstructions.contains(reward.id)) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _rewardInstructions(reward),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rewardInstructions(RewardItem reward) {
    if (reward.isExpired)
      return [
        _ruleItem(
          'Expired',
          'This reward is no longer available. Expired coupon codes cannot be copied or redeemed.',
        ),
      ];
    switch (reward.type) {
      case 'coupon_pct':
      case 'coupon_flat':
        return [
          _ruleItem(
            '1. Visit',
            'Open Genziitian.in/courses and choose a course. This coupon is for that website checkout.',
          ),
          _ruleItem(
            '2. Apply code',
            'Reveal the reward, tap Copy code, then paste it into the coupon field at checkout before paying.',
          ),
          _ruleItem(
            'Same email',
            'This coupon is locked to your account email. Log in on GenZ IITian with the same email to use it.',
          ),
          _ruleItem(
            'Minimum order',
            '₹350. Receiving this coupon is free; buying a course requires payment.',
          ),
          if (reward.type == 'coupon_pct')
            _ruleItem(
              'Discount limit',
              reward.title.startsWith('5%')
                  ? 'Up to ₹50, as shown on this coupon.'
                  : 'Up to ₹100 per purchase.',
            ),
          _ruleItem(
            'Expiry',
            'Valid for 7 days from winning the coupon. Revealing it later does not restart its validity.',
          ),
          TextButton(
            onPressed: () =>
                _openRewardLink(Uri.https('genziitian.in', '/courses')),
            child: const Text('Visit courses'),
          ),
          TextButton(
            onPressed: () => _openRewardLink(
              Uri.parse(
                'https://quiz.genziitian.in/terms.html#rewards-promotions',
              ),
            ),
            child: const Text('Promotional terms'),
          ),
        ];
      case 'free_paper_upload':
        return [
          _ruleItem(
            'Added to your account',
            '1 bonus paper upload was credited automatically. Tap Upload paper now, choose your PDF or JSON, and turn it into a test. No coupon code or payment needed.',
          ),
        ];
      case 'free_test':
        return [
          _ruleItem(
            'Added to your account',
            '1 bonus practice test was credited automatically. Tap Test yourself now and choose your course to create a paper. No coupon code or payment needed.',
          ),
        ];
      case 'free_pro':
        return [
          _ruleItem(
            reward.claimed ? 'Pro activated' : 'Activate your reward',
            reward.claimed
                ? 'Your 30-day Pro reward has been activated. No card or recurring charge applies to this reward.'
                : 'Reveal your reward, then tap Activate Pro for 30 consecutive days of Pro access. No card, payment or recurring charge.',
          ),
        ];
      case 'bonus_xp':
        return [
          _ruleItem(
            'Added to your account',
            '50 Study XP was credited automatically. No code or claim needed.',
          ),
        ];
      case 'free_spin':
        return [
          _ruleItem(
            'Extra spin ready',
            'Tap Spin again to return to the wheel and use your extra Daily Rewards spin. No code or payment needed.',
          ),
        ];
      default:
        return [_ruleItem('My Rewards', _rewardDescription(reward))];
    }
  }

  Future<void> _openRewardLink(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep the instructions visible if the device cannot open a browser.
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the link. Visit $uri in your browser.'),
        ),
      );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) => Material(
    color: filled ? _purple : Colors.white,
    elevation: filled ? 4 : 1,
    shadowColor: filled ? const Color(0x664F46E5) : const Color(0x1A1E1B4B),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: filled ? Colors.transparent : const Color(0xFFE0E7FF),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: filled ? _goldLight : _purple),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: filled ? Colors.white : const Color(0xFF1E1B4B),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _spinButton() {
    final disabled = _busy || _needsRefresh || (_data?.remaining ?? 0) <= 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: disabled
            ? null
            : const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
              ),
        color: disabled ? const Color(0xFFE5E7EB) : null,
        boxShadow: disabled
            ? null
            : const [
                BoxShadow(
                  color: Color(0x663730A3),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: _goldLight,
          disabledForegroundColor: const Color(0xFF6B7280),
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: disabled ? Colors.transparent : _gold,
              width: 1.2,
            ),
          ),
        ),
        onPressed: disabled ? null : _spin,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.casino_outlined, size: 22),
        label: Text(
          _busy
              ? 'Spinning…'
              : _needsRefresh
              ? 'Rewards unavailable · Try again'
              : (_data?.remaining ?? 0) <= 0
              ? '✓ Spun Today · Come Back Tomorrow'
              : 'Spin now · Free daily spin',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15.5,
            color: disabled ? const Color(0xFF6B7280) : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text(
        'Daily Rewards',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
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
                Row(
                  children: [
                    Expanded(
                      child: _actionTile(
                        icon: Icons.emoji_events_outlined,
                        label: 'View Prizes',
                        onTap: _showPrizesSheet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionTile(
                        icon: _history
                            ? Icons.casino_outlined
                            : Icons.card_giftcard_rounded,
                        label: _history
                            ? 'Back to Wheel'
                            : (_data?.rewards.isEmpty ?? true)
                            ? 'My Rewards'
                            : 'My Rewards (${_data?.rewards.length ?? 0})',
                        filled: true,
                        onTap: _busy
                            ? null
                            : () => setState(() => _history = !_history),
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
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error is ApiException
                                ? (_error as ApiException).message
                                : 'Temporary server failure. Please try again.',
                            style: const TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFEEF2FF), Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE0E7FF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A4F46E5),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
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
                                    child: RepaintBoundary(
                                      child: AnimatedBuilder(
                                        animation: _turns,
                                        builder: (_, _) => CustomPaint(
                                          painter: _RewardWheelPainter(
                                            _turns.value,
                                            _busy,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 66,
                                    height: 66,
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [_goldLight, _gold, _goldDeep],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x66000000),
                                          blurRadius: 12,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset('assets/logo.png'),
                                    ),
                                  ),
                                  Positioned(
                                    top: -2,
                                    child: AnimatedBuilder(
                                      animation: _turns,
                                      builder: (_, child) {
                                        final phase = (_turns.value * 10) % 1;
                                        final flick = _busy
                                            ? -.5 * math.max(0.0, 1 - phase * 5)
                                            : 0.0;
                                        return Transform.rotate(
                                          angle: flick,
                                          alignment: Alignment.topCenter,
                                          child: child,
                                        );
                                      },
                                      child: CustomPaint(
                                        size: const Size(26, 36),
                                        painter: _PinPainter(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _spinButton(),
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
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFEEF2FF),
                                    Color(0xFFE0E7FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: _gold.withValues(alpha: .6),
                                ),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: _purple,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No rewards yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Spin the wheel daily to collect coupons and Free Pro.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
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

const _gold = Color(0xFFD9B04A);
const _goldLight = Color(0xFFF6E7B4);
const _goldDeep = Color(0xFF9A7418);

class _RewardWheelPainter extends CustomPainter {
  final double turns;
  final bool busy;
  _RewardWheelPainter(this.turns, this.busy);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 6;
    final discR = outer - 17;
    final disc = Rect.fromCircle(center: centre, radius: discR);
    final rim = Rect.fromCircle(center: centre, radius: outer);

    if (busy) {
      final pulse = .5 + .5 * math.sin(turns * math.pi * 2 * 3);
      canvas.drawCircle(
        centre,
        outer + 4,
        Paint()
          ..color = _gold.withValues(alpha: .25 + .2 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawCircle(
      centre + const Offset(0, 6),
      outer,
      Paint()
        ..color = const Color(0x401E1B4B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Fixed metal rim.
    canvas.drawCircle(
      centre,
      outer,
      Paint()
        ..shader = const SweepGradient(
          colors: [_goldLight, _gold, _goldDeep, _gold, _goldLight],
          stops: [0, .3, .55, .8, 1],
        ).createShader(rim),
    );
    canvas.drawCircle(
      centre,
      outer - 3,
      Paint()..color = const Color(0xFF2B2670),
    );
    // Rim bulbs; while spinning a light chases around the rim.
    const bulbs = 24;
    for (var i = 0; i < bulbs; i++) {
      final a = i * math.pi * 2 / bulbs - math.pi / 2;
      final pos = centre + Offset(math.cos(a), math.sin(a)) * (outer - 8.5);
      var glow = .55;
      if (busy) {
        final d = ((i / bulbs) - (turns * 2)) % 1;
        glow = .3 + .7 * math.pow(1 - d, 3).toDouble();
      }
      canvas.drawCircle(
        pos,
        4.5,
        Paint()
          ..color = _goldLight.withValues(alpha: glow * .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        pos,
        2.2,
        Paint()..color = _goldLight.withValues(alpha: .35 + glow * .65),
      );
    }

    // Rotating disc.
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(turns * math.pi * 2);
    canvas.translate(-centre.dx, -centre.dy);
    const sweep = math.pi * 2 / 10;
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * sweep;
      final base = _colors[i];
      canvas.drawArc(
        disc,
        angle,
        sweep,
        true,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(base, Colors.black, .28)!,
              base,
              Color.lerp(base, Colors.white, .16)!,
            ],
            stops: const [.12, .62, 1],
          ).createShader(disc),
      );
      final edge = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + edge * 34,
        centre + edge * discR,
        Paint()
          ..color = Colors.white.withValues(alpha: .55)
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
        centre + edge * (discR - 5),
        2.4,
        Paint()..color = _goldLight,
      );
      final text = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: discR < 125 ? 9 : 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(angle + sweep / 2);
      canvas.translate(discR * .66, 0);
      canvas.rotate(math.pi / 2);
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      canvas.restore();
    }
    canvas.restore();

    // Fixed finishing: inner rings and glass reflection.
    canvas.drawCircle(
      centre,
      discR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _gold,
    );
    canvas.drawCircle(
      centre,
      40,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _goldLight.withValues(alpha: .7),
    );
    canvas.drawCircle(
      centre,
      discR - 1,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x30FFFFFF), Color(0x00FFFFFF), Color(0x18000000)],
          stops: [0, .45, 1],
        ).createShader(disc),
    );
  }

  @override
  bool shouldRepaint(_RewardWheelPainter old) =>
      old.turns != turns || old.busy != busy;
}

/// Gold-and-red pin that flicks as each segment edge passes under it.
class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width - 1, size.height * .32)
      ..arcToPoint(
        Offset(1, size.height * .32),
        radius: Radius.circular(size.width / 2),
        clockwise: false,
      )
      ..close();
    canvas.drawShadow(path, const Color(0x99000000), 3, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFC62828)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _goldLight,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * .32),
      3.2,
      Paint()..color = _goldLight,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => false;
}
