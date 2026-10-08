import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../state/theme_state.dart';
import '../../widgets/app_ux_components.dart';

const _green = Color(0xFF16A34A);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// Icon and colour for each badge. Unknown badges fall back to a star.
class _BadgeLook {
  final String glyph;
  final Color color;

  const _BadgeLook(this.glyph, this.color);
}

const Map<String, _BadgeLook> _badgeLooks = {
  'newcomer': _BadgeLook('🌱', Color(0xFF22C55E)),
  'spark': _BadgeLook('✨', Color(0xFFF59E0B)),
  'explorer': _BadgeLook('🧭', Color(0xFF0EA5E9)),
  'challenger': _BadgeLook('🥊', Color(0xFFF43F5E)),
  'apprentice': _BadgeLook('📘', Color(0xFF0EA5E9)),
  'trailblazer': _BadgeLook('🚀', Color(0xFF6366F1)),
  'scholar': _BadgeLook('🎓', Color(0xFF6366F1)),
  'strategist': _BadgeLook('♟️', Color(0xFF14B8A6)),
  'adept': _BadgeLook('⚡', Color(0xFF06B6D4)),
  'specialist': _BadgeLook('🔬', Color(0xFF06B6D4)),
  'achiever': _BadgeLook('🎯', Color(0xFF14B8A6)),
  'prodigy': _BadgeLook('💡', Color(0xFFF59E0B)),
  'veteran': _BadgeLook('🛡️', Color(0xFF10B981)),
  'virtuoso': _BadgeLook('🎻', Color(0xFFEC4899)),
  'expert': _BadgeLook('🧠', Color(0xFF8B5CF6)),
  'sage': _BadgeLook('🦉', Color(0xFF8B5CF6)),
  'master': _BadgeLook('🏅', Color(0xFFF43F5E)),
  'titan': _BadgeLook('🗿', Color(0xFF10B981)),
  'grandmaster': _BadgeLook('⚔️', Color(0xFFEC4899)),
  'mythic': _BadgeLook('🐉', Color(0xFFF43F5E)),
  'legend': _BadgeLook('🔥', Color(0xFFF59E0B)),
  'immortal': _BadgeLook('💎', Color(0xFF0EA5E9)),
  'iit-champion': _BadgeLook('👑', Color(0xFFF97316)),
};

class _Badge {
  final String slug;
  final String label;
  final String description;
  final int level;
  final bool earned;

  const _Badge({required this.slug, required this.label, required this.description, required this.level, required this.earned});

  factory _Badge.fromJson(Map<String, dynamic> json) {
    return _Badge(
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      earned: json['earned'] == true,
    );
  }
}

/// Everything the profile endpoint returns about progress.
class _ProgressData {
  final int xp;
  final int level;
  final bool isMax;
  final int xpToNext;
  final int nextLevelTotal;
  final int thisLevelTotal;
  final List<_Badge> badges;
  final _Badge? nextBadge;
  final int? nextBadgeLevelsAway;
  final int attempts;
  final double avgScore;
  final double bestScore;
  final int ideSolved;

  const _ProgressData({
    required this.xp,
    required this.level,
    required this.isMax,
    required this.xpToNext,
    required this.nextLevelTotal,
    required this.thisLevelTotal,
    required this.badges,
    required this.nextBadge,
    required this.nextBadgeLevelsAway,
    required this.attempts,
    required this.avgScore,
    required this.bestScore,
    required this.ideSolved,
  });

  static double _d(dynamic v) => v == null ? 0 : (double.tryParse(v.toString()) ?? 0);
  static int _i(dynamic v) => _d(v).round();

  factory _ProgressData.fromJson(Map<String, dynamic> json) {
    final xp = (json['xp'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final progress = (xp['progress'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final next = (xp['next_badge'] as Map?)?.cast<String, dynamic>();
    return _ProgressData(
      xp: _i(xp['xp']),
      level: _i(xp['level']) < 1 ? 1 : _i(xp['level']),
      isMax: progress['is_max'] == true,
      xpToNext: _i(progress['xp_to_next']),
      nextLevelTotal: _i(progress['next_level_xp_total']),
      thisLevelTotal: _i(progress['this_level_xp_total']),
      badges: ((xp['badges'] as List?) ?? const [])
          .whereType<Map>()
          .map((b) => _Badge.fromJson(b.cast<String, dynamic>()))
          .toList(),
      nextBadge: next == null ? null : _Badge.fromJson({...next, 'earned': false}),
      nextBadgeLevelsAway: next == null ? null : _i(next['levels_remaining']),
      attempts: _i(stats['completed_attempts']),
      avgScore: _d(stats['avg_percentage']),
      bestScore: _d(stats['best_percentage']),
      ideSolved: _i(stats['ide_solved']),
    );
  }
}

/// XP needed to reach a level. Same rule as the server: 50 x level x level (level 1 starts at 0).
int _xpForLevel(int level) => level <= 1 ? 0 : 50 * level * level;

String _thousands(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

Widget _badgeIcon(_Badge badge, double size) {
  final look = _badgeLooks[badge.slug] ?? const _BadgeLook('⭐', Color(0xFF64748B));
  final glyph = Text(look.glyph, style: TextStyle(fontSize: size * 0.46, height: 1.1));
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: badge.earned
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [look.color.withValues(alpha: 0.30), look.color.withValues(alpha: 0.10)],
                  )
                : null,
            color: badge.earned ? null : const Color(0xFFF8FAFC),
            border: Border.all(color: badge.earned ? look.color.withValues(alpha: 0.45) : const Color(0xFFE2E8F0), width: 2),
          ),
          // Emoji keep their real colours in dark mode; locked ones are greyed out.
          child: KeepColors(
            child: badge.earned
                ? glyph
                : Opacity(
                    opacity: 0.45,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: glyph,
                    ),
                  ),
          ),
        ),
        if (!badge.earned)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.lock_rounded, size: size * 0.16, color: Colors.white),
            ),
          ),
      ],
    ),
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [BoxShadow(color: _ink.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
  );
}

const _labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Color(0xFF94A3B8));

// -----------------------------------------------------------------------------
// LEVEL, BADGES AND STATS (shown on the More tab, same content as the web profile)
// -----------------------------------------------------------------------------
class ProgressSection extends StatefulWidget {
  final ApiClient apiClient;

  const ProgressSection({super.key, required this.apiClient});

  @override
  State<ProgressSection> createState() => ProgressSectionState();
}

class ProgressSectionState extends State<ProgressSection> {
  _ProgressData? _data;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final res = await widget.apiClient.get<Map<String, dynamic>>('/student/profile');
      if (!mounted) return;
      setState(() {
        _data = _ProgressData.fromJson(res.data ?? const <String, dynamic>{});
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = _data == null);
    }
  }

  void _openRuleBook() {
    AppHaptics.light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RuleBookScreen(badges: _data?.badges ?? const [], level: _data?.level ?? 1, xp: _data?.xp ?? 0)),
    );
  }

  void _showBadge(_Badge badge) {
    AppHaptics.selection();
    final need = _xpForLevel(badge.level);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _badgeIcon(badge, 92),
              const SizedBox(height: 14),
              Text(badge.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 4),
              Text(
                badge.earned ? 'Earned · ${badge.description}' : 'Locked · reach Level ${badge.level} (${_thousands(need)} XP)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF3FAF5)]),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _labelStyle),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: _ink)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) {
      if (_failed) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              const Expanded(child: Text('Could not load your level and badges.', style: TextStyle(fontSize: 13, color: _muted))),
              TextButton(onPressed: reload, child: const Text('Retry', style: TextStyle(color: _green, fontWeight: FontWeight.bold))),
            ],
          ),
        );
      }
      return AppShimmerCard.list(count: 2);
    }

    final span = d.nextLevelTotal - d.thisLevelTotal;
    final fraction = d.isMax || span <= 0 ? 1.0 : ((d.xp - d.thisLevelTotal) / span).clamp(0.0, 1.0).toDouble();
    final earned = d.badges.where((b) => b.earned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Level
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('LEVEL', style: _labelStyle),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 14, color: _green),
                        const SizedBox(width: 2),
                        Text('LVL ${d.level}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openRuleBook,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 15, color: _green),
                        SizedBox(width: 4),
                        Text('Rule book', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _green)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: d.xp.toDouble()),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      _thousands(v.round()),
                      style: const TextStyle(fontSize: 40, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1.4, color: _ink),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text('XP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('XP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: _muted)),
                  Text(
                    d.isMax ? 'Max level' : '${_thousands(d.xp)} / ${_thousands(d.nextLevelTotal)} XP',
                    style: const TextStyle(fontSize: 12.5, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: fraction),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => LinearProgressIndicator(
                    value: t,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                d.isMax ? 'You have reached the top level.' : '${_thousands(d.xpToNext)} XP to Level ${d.level + 1}',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
              if (d.nextBadge != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECF7EF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBE5C8)),
                  ),
                  child: Row(
                    children: [
                      _badgeIcon(d.nextBadge!, 50),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEXT BADGE', style: _labelStyle),
                            const SizedBox(height: 3),
                            Text(d.nextBadge!.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                            Text(
                              '${d.nextBadgeLevelsAway ?? 0} level${d.nextBadgeLevelsAway == 1 ? '' : 's'} away · L${d.nextBadge!.level}',
                              style: const TextStyle(fontSize: 12.5, color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---- Badges
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              InkWell(
                onTap: _openRuleBook,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Badges', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$earned of ${d.badges.length} earned', style: const TextStyle(fontSize: 12.5, color: _muted)),
                              const Text('View all', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _green)),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: _green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final badge in d.badges.take(3))
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showBadge(badge),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _badgeIcon(badge, 54),
                            const SizedBox(height: 5),
                            Text(
                              badge.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: badge.earned ? _ink : const Color(0xFF94A3B8),
                              ),
                            ),
                            Text('L${badge.level}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _openRuleBook,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: const Text('How do XP, levels and badges work?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 14, bottom: 10),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('YOUR STATS', style: _labelStyle),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _stat('AVG SCORE', '${d.avgScore.toStringAsFixed(1)}%'),
                  const SizedBox(width: 10),
                  _stat('BEST SCORE', '${d.bestScore.toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _stat('QUIZ ATTEMPTS', '${d.attempts}'),
                  const SizedBox(width: 10),
                  _stat('IDE SOLVED', '${d.ideSolved}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// RULE BOOK: how XP is earned, when levels change, and who gets which badge
// -----------------------------------------------------------------------------
class RuleBookScreen extends StatelessWidget {
  final List<_Badge> badges;
  final int level;
  final int xp;

  const RuleBookScreen({super.key, required this.badges, required this.level, required this.xp});

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: _green),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink))),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _para(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF334155))),
      );

  Widget _rule(String what, String points, {String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(what, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink)),
                if (note != null) Text(note, style: const TextStyle(fontSize: 12, height: 1.4, color: _muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
            child: Text(points, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
          ),
        ],
      ),
    );
  }

  Widget _levelRow(int lvl) {
    final reached = level >= lvl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text('Level $lvl', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: reached ? _green : _ink)),
          ),
          Expanded(child: Text('${_thousands(_xpForLevel(lvl))} XP', style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)))),
          if (reached) const Icon(Icons.check_circle_rounded, size: 16, color: _green),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F5F9),
        surfaceTintColor: const Color(0xFFF1F5F9),
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('Rule book', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Text.rich(
              TextSpan(
                text: 'How XP, levels and ',
                children: [TextSpan(text: 'badges work.', style: TextStyle(color: _green))],
              ),
              style: TextStyle(fontSize: 26, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: _ink),
            ),
            const SizedBox(height: 6),
            Text(
              'You are on Level $level with ${_thousands(xp)} XP.',
              style: const TextStyle(fontSize: 13.5, color: _muted),
            ),
            const SizedBox(height: 16),

            _section('The short version', Icons.flash_on_rounded, [
              _para('Everything you do earns XP (experience points). XP only ever adds up into one total.'),
              _para('Your total XP decides your level. Your level decides your badges. Nobody hands out badges by hand, and you cannot buy them.'),
            ]),

            _section('How you earn XP', Icons.add_circle_outline_rounded, [
              _rule('Finish a paper for the first time', '5 to 25 XP', note: '5 XP for finishing, plus 1 XP for every 5% you score. 0% gives 5, 50% gives 15, 100% gives 25.'),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _rule('Attempt the same paper again', 'Half', note: 'A repeat attempt earns half of what that score would earn the first time (at least 1 XP).'),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _rule('Daily bonus', '+10 XP', note: 'Once a day, on your first finished paper or solved coding problem of the day.'),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _rule('Solve a coding (IDE) problem', '20 / 40 / 80', note: 'Easy 20, Medium 40, Hard 80. Counted the first time your solution is accepted.'),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _rule('Your reply is accepted as the answer', '+50 XP', note: 'In Discussions, when the person who asked marks your reply as the answer.'),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _rule('Someone upvotes your doubt or reply', '+2 XP', note: 'Each upvote you receive in Discussions.'),
            ]),

            _section('When XP is taken back', Icons.remove_circle_outline_rounded, [
              _para('If someone removes their upvote, the 2 XP goes with it.'),
              _para('If the asker picks a different accepted answer, or un-accepts yours, the 50 XP moves away from you.'),
              _para('XP from papers and coding problems is never taken back.'),
            ]),

            _section('How levels work', Icons.trending_up_rounded, [
              _para('There are 50 levels. To reach a level you need 50 x level x level XP in total. So each level is a bigger step than the one before.'),
              for (final lvl in const [2, 3, 4, 5, 7, 10, 15, 20, 25, 30, 40, 50]) _levelRow(lvl),
              const SizedBox(height: 6),
              _para('Level 50 is the top. XP stops counting once you reach it.'),
            ]),

            _section('Badges: who gets what', Icons.military_tech_rounded, [
              _para('A badge unlocks the moment you reach its level, and it is yours for good. Everyone starts with Newcomer.'),
              if (badges.isEmpty)
                _para('Open this page again when you are online to see the full badge list.')
              else
                for (final badge in badges)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        _badgeIcon(badge, 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(badge.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: badge.earned ? _ink : const Color(0xFF64748B))),
                              Text(
                                'Level ${badge.level} · ${_thousands(_xpForLevel(badge.level))} XP',
                                style: const TextStyle(fontSize: 12, color: _muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          badge.earned ? 'Earned' : 'Locked',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badge.earned ? _green : const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
            ]),

            _section('Leaderboard', Icons.emoji_events_outlined, [
              _para('The Ranks tab orders students by total XP. More XP means a higher place. The top three stand on the podium.'),
            ]),
          ],
        ),
      ),
    );
  }
}
