import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_ux_components.dart';

/// 5-Tab Navigation Shell for Students: Home, Quizzes & Storefront, Test, Support, More.
///
/// Features:
/// - Authoritative data fetching directly from backend controllers (Zero mock data).
/// - Storefront past papers catalog with free claims and pricing.
/// - Interactive Weekly Quiz Goal adjustment (1 to 100).
/// - Card-based timed test engine with KaTeX equations, question palette, and scientific calculator.
/// - Manager Preview Mode Banner if accessed by a Manager.
class StudentMainShell extends StatefulWidget {
  final AuthState authState;
  final bool isManagerPreview;

  const StudentMainShell({
    super.key,
    required this.authState,
    this.isManagerPreview = false,
  });

  @override
  State<StudentMainShell> createState() => _StudentMainShellState();
}

class _StudentMainShellState extends State<StudentMainShell> {
  int _currentIndex = 0;

  final DashboardService _dashboardService = DashboardService();
  final CourseService _courseService = CourseService();
  final StorefrontService _storefrontService = StorefrontService();
  final DiscussionService _discussionService = DiscussionService();
  final LeaderboardService _leaderboardService = LeaderboardService();

  @override
  Widget build(BuildContext context) {
    return AppKeyboardDismiss(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // Manager Preview Mode Banner
              if (widget.isManagerPreview)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(color: Color(0xFF1E293B)),
                  child: Row(
                    children: [
                      const Icon(Icons.preview_rounded, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'MANAGER PREVIEW: Candidate Experience',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          AppHaptics.light();
                          widget.authState.togglePreviewStudentView(false);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Exit to Workspace',
                            style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tab View Body
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _HomeTab(
                      dashboardService: _dashboardService,
                      user: widget.authState.user,
                      onNavigateToQuizzes: () => setState(() => _currentIndex = 1),
                    ),
                    _QuizzesTab(
                      courseService: _courseService,
                      storefrontService: _storefrontService,
                    ),
                    _TestTab(courseService: _courseService),
                    _RanksTab(
                      leaderboardService: _leaderboardService,
                      user: widget.authState.user,
                    ),
                    _MoreTab(
                      user: widget.authState.user,
                      authState: widget.authState,
                      leaderboardService: _leaderboardService,
                      discussionService: _discussionService,
                      onNavigateToMyPapers: () => setState(() => _currentIndex = 1),
                      onNavigateToPractice: () => setState(() => _currentIndex = 2),
                      onNavigateToRanks: () => setState(() => _currentIndex = 3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _QuizLabDock(
          currentIndex: _currentIndex,
          onTap: (index) {
            AppHaptics.selection();
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FLOATING BOTTOM BAR (same layout and lightning animation as the website)
// -----------------------------------------------------------------------------
class _QuizLabDock extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _QuizLabDock({required this.currentIndex, required this.onTap});

  @override
  State<_QuizLabDock> createState() => _QuizLabDockState();
}

class _QuizLabDockState extends State<_QuizLabDock> with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF16A34A);

  // Same 2.6s loop as the website's centre button.
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Straight-line keyframes: value at time [t] (0..1) given matching stops and values.
  static double _keyframes(double t, List<double> stops, List<double> values) {
    if (t <= stops.first) return values.first;
    for (var i = 1; i < stops.length; i++) {
      if (t <= stops[i]) {
        final span = stops[i] - stops[i - 1];
        final local = span == 0 ? 1.0 : (t - stops[i - 1]) / span;
        return values[i - 1] + (values[i] - values[i - 1]) * local;
      }
    }
    return values.last;
  }

  Widget _ring(double t) {
    final scale = _keyframes(t, const [0.0, 0.06, 0.45, 1.0], const [1.0, 1.0, 1.55, 1.55]);
    final opacity = _keyframes(t, const [0.0, 0.06, 0.10, 0.45, 1.0], const [0.0, 0.0, 0.75, 0.0, 0.0]);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: opacity), width: 2),
        ),
      ),
    );
  }

  Widget _centreButton() {
    final selected = widget.currentIndex == 2;
    return Semantics(
      button: true,
      label: 'Practice',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(2),
        child: SizedBox(
          width: 84,
          height: 84,
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final t = _loop.value;
              const stops = [0.0, 0.08, 0.14, 0.20, 0.34, 1.0];
              final flash = _keyframes(t, stops, const [0.0, 1.0, 0.0, 0.8, 0.0, 0.0]);
              final boltScale = _keyframes(t, stops, const [1.0, 1.22, 0.96, 1.14, 1.0, 1.0]);
              final boltTurn = _keyframes(t, stops, const [0.0, -8.0, 0.0, 5.0, 0.0, 0.0]) * math.pi / 180;
              final boltColor = Color.lerp(Colors.white, const Color(0xFFFEF08A), flash)!;

              return Stack(
                alignment: Alignment.center,
                children: [
                  _ring(t),
                  _ring((t + 1 - 0.173) % 1.0), // second ring starts 0.45s later
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                      ),
                      border: Border.all(
                        color: selected ? const Color(0xFFBBF7D0) : Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: -4,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFACC15).withValues(alpha: 0.75 * flash),
                          blurRadius: 26,
                          spreadRadius: 6 * flash,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFEF08A).withValues(alpha: 0.9 * flash),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: boltTurn,
                      child: Transform.scale(
                        scale: boltScale,
                        child: Icon(Icons.bolt_rounded, size: 32, color: boltColor),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, IconData activeIcon, String label) {
    final selected = widget.currentIndex == index;
    final color = selected ? _green : const Color(0xFF64748B);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Icon(selected ? activeIcon : icon, size: 24, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: SizedBox(
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 68,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                      _item(1, Icons.description_outlined, Icons.description_rounded, 'My Papers'),
                      // Label under the raised centre button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onTap(2),
                        child: SizedBox(
                          width: 78,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Text(
                                'Practice',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: widget.currentIndex == 2 ? FontWeight.w700 : FontWeight.w500,
                                  color: widget.currentIndex == 2 ? _green : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _item(3, Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Ranks'),
                      _item(4, Icons.person_outline_rounded, Icons.person_rounded, 'More'),
                    ],
                  ),
                ),
              ),
              Positioned(top: 0, child: _centreButton()),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB: RANKS (Global XP leaderboard)
// -----------------------------------------------------------------------------
class _RanksTab extends StatefulWidget {
  final LeaderboardService leaderboardService;
  final UserModel? user;

  const _RanksTab({required this.leaderboardService, this.user});

  @override
  State<_RanksTab> createState() => _RanksTabState();
}

class _RanksTabState extends State<_RanksTab> {
  late Future<LeaderboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.leaderboardService.getLeaderboard();
  }

  Future<void> _refresh() async {
    final next = widget.leaderboardService.getLeaderboard();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // The error card is shown by the FutureBuilder.
    }
  }

  Color _medal(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF94A3B8);
      case 3:
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LeaderboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppShimmerCard.list(count: 5);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return AppErrorCard(
            title: 'Unable to Load Leaderboard',
            message: '${snapshot.error ?? 'No data'}',
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        final entries = data.leaderboard;
        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF16A34A),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Leaderboard',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              const Text(
                'Top students by XP',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Your position
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF14532D), Color(0xFF16A34A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFDE68A), size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR RANK',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFFBBF7D0)),
                          ),
                          Text(
                            data.myRank != null ? '#${data.myRank}' : 'Unranked',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${data.me.xp} XP',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          'Level ${data.me.level}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBBF7D0)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No rankings yet. Finish a quiz to get on the board.', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        Container(
                          color: entries[i].userId == widget.user?.id ? const Color(0xFFF0FDF4) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '#${entries[i].rank}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _medal(entries[i].rank)),
                                ),
                              ),
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: const Color(0xFFDCFCE7),
                                child: Text(
                                  entries[i].name.isNotEmpty ? entries[i].name[0].toUpperCase() : 'S',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entries[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      'Level ${entries[i].level}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${entries[i].xp} XP',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: HOME (Dashboard & Weekly Goal Tracker)
// -----------------------------------------------------------------------------
class _HomeTab extends StatefulWidget {
  final DashboardService dashboardService;
  final UserModel? user;
  final VoidCallback onNavigateToQuizzes;

  const _HomeTab({
    required this.dashboardService,
    this.user,
    required this.onNavigateToQuizzes,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.dashboardService.getDashboard();
  }

  static String _firstName(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    final first = parts.isEmpty ? '' : parts.first;
    if (first.isEmpty) return 'Student';
    return first[0].toUpperCase() + first.substring(1).toLowerCase();
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// "THU · OCT 8, 2026" from the server's greeting.
  static String _shortDate(GreetingInfo greeting) {
    final day = greeting.weekday.length > 3 ? greeting.weekday.substring(0, 3) : greeting.weekday;
    return '${day.toUpperCase()} · ${greeting.date.toUpperCase()}';
  }

  Future<void> _refresh() async {
    AppHaptics.light();
    setState(() {
      _dashboardFuture = widget.dashboardService.getDashboard();
    });
    await _dashboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppShimmerCard.dashboard();
        }
        if (snapshot.hasError) {
          return AppErrorCard(
            title: 'Unable to Load Dashboard',
            message: '${snapshot.error}',
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF16A34A),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Brand header (same as the website's phone top bar)
              _FadeUp(
                delayMs: 0,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/logo.png', width: 44, height: 44, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shortDate(data.greeting),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2, color: Color(0xFF94A3B8)),
                          ),
                          const Text(
                            'Quiz LAB',
                            style: TextStyle(fontSize: 17, height: 1.15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            'by GenZ IITian',
                            style: TextStyle(fontSize: 11, height: 1.1, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 2),
                          Text(
                            'LVL ${widget.user?.level ?? 1}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF0FDF4),
                        border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                      ),
                      child: Text(
                        _initials(widget.user?.name),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Welcome line
              _FadeUp(
                delayMs: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Welcome back, ',
                        children: [
                          TextSpan(
                            text: '${_firstName(widget.user?.name)}.',
                            style: const TextStyle(color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${data.streak.days}-day streak',
                            style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Stat cards
              _FadeUp(
                delayMs: 160,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'CURRENT STREAK',
                            value: '${data.streak.days}',
                            unit: 'days',
                            color: const Color(0xFFF59E0B),
                            titleColor: const Color(0xFFB45309),
                            history: data.streak.history.map((e) => e.toDouble()).toList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            title: 'ACCURACY',
                            value: data.accuracy.value.toStringAsFixed(data.accuracy.value % 1 == 0 ? 0 : 1),
                            unit: '%',
                            color: const Color(0xFF16A34A),
                            titleColor: const Color(0xFF15803D),
                            history: data.accuracy.history,
                            chip: data.accuracy.delta == 0
                                ? null
                                : '${data.accuracy.delta > 0 ? '↑ +' : '↓ '}${data.accuracy.delta.toStringAsFixed(1)}%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'THIS WEEK',
                            value: data.hoursThisWeek.value.toStringAsFixed(1),
                            unit: 'hrs',
                            color: const Color(0xFF3B82F6),
                            titleColor: const Color(0xFF1D4ED8),
                            history: data.hoursThisWeek.history,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            title: 'RANK',
                            value: data.rank.current != null ? '#${data.rank.current}' : '—',
                            unit: 'of ${data.rank.totalRanked}',
                            color: const Color(0xFF8B5CF6),
                            titleColor: const Color(0xFF6D28D9),
                            history: [
                              -((data.rank.previous ?? data.rank.current ?? 0).toDouble()),
                              -((data.rank.current ?? 0).toDouble()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Performance chart
              _FadeUp(delayMs: 240, child: _PerformanceCard(points: data.performance)),
              const SizedBox(height: 16),

              // Weekly goal ring
              _FadeUp(
                delayMs: 320,
                child: _WeeklyGoalCard(
                  completed: data.performance.isEmpty ? 0 : data.performance.last.attempts,
                ),
              ),
              const SizedBox(height: 20),

            // Quick Continue Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Browse Storefront Papers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        Text('Over 45+ past term papers & practice mocks', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AppHaptics.light();
                      widget.onNavigateToQuizzes();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Today's Smart Challenge
            if (data.todaysChallenge != null) ...[
              const Text('TODAY’S CHALLENGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data.todaysChallenge!.courseName.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text('+${data.todaysChallenge!.xp} XP', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.todaysChallenge!.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Color(0xFF94A3B8), size: 14),
                        const SizedBox(width: 4),
                        Text('${data.todaysChallenge!.timeLimitMinutes} minutes', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            AppHaptics.light();
                            widget.onNavigateToQuizzes();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Start Quiz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Community Feed
            const Text('LIVE ACTIVITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.communityFeed.take(5).length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, i) {
                  final feed = data.communityFeed[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFDCFCE7),
                      child: Text(feed.name.isNotEmpty ? feed.name[0] : 'S', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    ),
                    title: Text('${feed.name} completed ${feed.quizTitle}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: Text(feed.courseName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    trailing: Text('+${feed.xp} XP', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                  );
                },
              ),
            ),
          ],
          ),
        );
      },
    );
  }
}

/// Interactive Weekly Quiz Goal Card with dynamic target selector
class _WeeklyGoalCard extends StatefulWidget {
  /// Quizzes finished this week (from the dashboard's latest week).
  final int completed;

  const _WeeklyGoalCard({required this.completed});

  @override
  State<_WeeklyGoalCard> createState() => _WeeklyGoalCardState();
}

class _WeeklyGoalCardState extends State<_WeeklyGoalCard> {
  static const _storage = FlutterSecureStorage();
  int _targetGoal = 5;

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    final saved = await _storage.read(key: 'weekly_quiz_goal');
    if (saved != null) {
      final parsed = int.tryParse(saved);
      if (parsed != null && parsed > 0 && mounted) {
        setState(() => _targetGoal = parsed);
      }
    }
  }

  Future<void> _setGoal(int goal) async {
    await _storage.write(key: 'weekly_quiz_goal', value: goal.toString());
    if (mounted) {
      setState(() => _targetGoal = goal);
    }
  }

  void _showChangeGoalDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Set Weekly Quiz Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              const Text('How many quizzes do you want to practice each week?', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [5, 10, 15, 20, 25, 30, 50].map((num) {
                  final isSelected = num == _targetGoal;
                  return ChoiceChip(
                    label: Text('$num Quizzes'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF16A34A),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      _setGoal(num);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.completed;
    final progress = (completed / _targetGoal).clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WEEKLY GOAL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: Color(0xFF94A3B8)),
              ),
              Text(
                '$completed/$_targetGoal quizzes',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 150,
            height: 150,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return CustomPaint(painter: _GoalRingPainter(progress: t), child: child);
              },
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: const TextStyle(fontSize: 30, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completed >= _targetGoal ? 'Goal reached' : '${_targetGoal - completed} to go',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _showChangeGoalDialog,
            child: const Text('Change goal', style: TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts its child in once, after an optional delay.
class _FadeUp extends StatelessWidget {
  final int delayMs;
  final Widget child;

  const _FadeUp({required this.delayMs, required this.child});

  @override
  Widget build(BuildContext context) {
    final totalMs = 550 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1.0, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
        );
      },
    );
  }
}

/// Coloured stat card with a small trend line, as on the website dashboard.
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color color;
  final Color titleColor;
  final List<double> history;
  final String? chip;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    required this.titleColor,
    required this.history,
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.15)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: titleColor),
                      ),
                    ),
                    if (chip != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                        child: Text(chip!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: titleColor)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 28, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 54,
                      height: 26,
                      child: CustomPaint(painter: _TrendPainter(values: history, color: color, progress: 1.0, dense: true)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Line with a soft fill underneath. Used for the small card trends and the big chart.
class _TrendPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double progress; // 0..1, how much of the line is revealed
  final bool dense; // small sparkline: no grid, thinner line

  const _TrendPainter({required this.values, required this.color, required this.progress, this.dense = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (!dense) {
      final grid = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 1;
      for (var i = 0; i < 4; i++) {
        final y = size.height * i / 4;
        // dotted guide lines
        for (double x = 0; x < size.width; x += 6) {
          canvas.drawLine(Offset(x, y), Offset(x + 2, y), grid);
        }
      }
    }

    final data = values.isEmpty ? <double>[0, 0] : (values.length == 1 ? <double>[values.first, values.first] : values);
    var minV = data.reduce(math.min);
    var maxV = data.reduce(math.max);
    if (maxV - minV < 0.0001) {
      // Flat data sits on a low baseline instead of the middle.
      maxV = minV + 1;
      minV = minV - 0.15;
    }
    final pad = dense ? 3.0 : 6.0;
    final h = size.height - pad * 2;

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = pad + h * (1 - (data[i] - minV) / (maxV - minV));
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(points[i].dx, points[i].dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, -8, size.width * progress.clamp(0.0, 1.0) + 1, size.height + 16));

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: dense ? 0.18 : 0.16), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = dense ? 1.6 : 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    if (!dense) {
      final dot = Paint()..color = color;
      for (final p in points) {
        canvas.drawCircle(p, 1.8, dot);
      }
    }
    final last = points.last;
    canvas.drawCircle(last, dense ? 2.2 : 5, Paint()..color = Colors.white);
    canvas.drawCircle(
      last,
      dense ? 2.2 : 5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = dense ? 1.4 : 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

/// "Performance · last N weeks" with Accuracy / Speed / Score tabs.
class _PerformanceCard extends StatefulWidget {
  final List<PerformanceDataPoint> points;

  const _PerformanceCard({required this.points});

  @override
  State<_PerformanceCard> createState() => _PerformanceCardState();
}

class _PerformanceCardState extends State<_PerformanceCard> {
  static const _labels = ['Accuracy', 'Speed', 'Score'];
  int _metric = 0;

  double _valueOf(PerformanceDataPoint p) {
    switch (_metric) {
      case 1:
        return p.speed;
      case 2:
        return p.score;
      default:
        return p.accuracy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final values = points.map(_valueOf).toList();
    final active = points.where((p) => p.attempts > 0).map(_valueOf).toList();
    final avg = active.isEmpty ? 0.0 : active.reduce((a, b) => a + b) / active.length;
    final avgText = _metric == 0 ? '${avg.round()}%' : avg.toStringAsFixed(avg % 1 == 0 ? 0 : 1);

    String labelAt(double fraction) {
      if (points.isEmpty) return '';
      final i = ((points.length - 1) * fraction).round();
      return points[i].label;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFORMANCE · LAST ${points.length} WEEKS',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  avgText,
                  key: ValueKey<String>('$_metric-$avgText'),
                  style: const TextStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'avg ${_labels[_metric].toLowerCase()}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Accuracy / Speed / Score
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        AppHaptics.selection();
                        setState(() => _metric = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _metric == i ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _metric == i
                              ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                              : const [],
                        ),
                        child: Text(
                          _labels[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _metric == i ? FontWeight.w700 : FontWeight.w500,
                            color: _metric == i ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (points.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('Finish a quiz to see your progress here.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ),
            )
          else ...[
            SizedBox(
              height: 170,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(_metric),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return CustomPaint(
                    painter: _TrendPainter(values: values, color: const Color(0xFF16A34A), progress: t),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final f in const [0.0, 0.34, 0.67])
                  Text(labelAt(f), style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8))),
                Text('${labelAt(1.0)} — today', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Green progress ring for the weekly goal.
class _GoalRingPainter extends CustomPainter {
  final double progress;

  const _GoalRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = const Color(0xFFDCFCE7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF15803D)]).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(covariant _GoalRingPainter oldDelegate) => oldDelegate.progress != progress;
}

// -----------------------------------------------------------------------------
// TAB 2: PAPERS & STOREFRONT (Past Papers, Pricing & Claims)
// -----------------------------------------------------------------------------
class _QuizzesTab extends StatefulWidget {
  final CourseService courseService;
  final StorefrontService storefrontService;

  const _QuizzesTab({
    required this.courseService,
    required this.storefrontService,
  });

  @override
  State<_QuizzesTab> createState() => _QuizzesTabState();
}

class _QuizzesTabState extends State<_QuizzesTab> {
  String _selectedFilter = 'all'; // 'all', 'my_papers', 'foundation', 'diploma'
  bool _isLoading = true;
  String? _errorMessage;
  List<StorefrontPaper> _papers = [];
  List<MyPaperItem> _myPapers = [];

  @override
  void initState() {
    super.initState();
    _loadPapers();
  }

  Future<void> _loadPapers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final papers = await widget.storefrontService.getPapers();
      final myPapers = await widget.storefrontService.getMyPapers();
      if (mounted) {
        setState(() {
          _papers = papers;
          _myPapers = myPapers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimFree(int quizId) async {
    AppHaptics.light();
    try {
      final success = await widget.storefrontService.claimFree(quizId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Free paper added to your library!'), backgroundColor: Color(0xFF16A34A)),
        );
        _loadPapers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PAST PAPERS & STOREFRONT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Self-serve exam library & past term practice papers', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All Papers'),
                    const SizedBox(width: 8),
                    _filterChip('my_papers', 'My Papers (${_myPapers.length})'),
                    const SizedBox(width: 8),
                    _filterChip('foundation', 'Foundation'),
                    const SizedBox(width: 8),
                    _filterChip('diploma', 'Diploma'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Body
        Expanded(
          child: _isLoading
              ? AppShimmerCard.list(count: 4)
              : _errorMessage != null
                  ? AppErrorCard(
                      title: 'Unable to Load Papers',
                      message: _errorMessage!,
                      onRetry: _loadPapers,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPapers,
                      color: const Color(0xFF16A34A),
                      child: _buildList(),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF16A34A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) {
        AppHaptics.selection();
        setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildList() {
    if (_selectedFilter == 'my_papers') {
      if (_myPapers.isEmpty) {
        return const Center(child: Text('No purchased or claimed papers yet.', style: TextStyle(color: Color(0xFF64748B))));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myPapers.length,
        itemBuilder: (context, i) => _buildPaperCard(_myPapers[i], isMyPaper: true),
      );
    }

    var list = _papers;
    if (_selectedFilter == 'foundation') {
      list = list.where((p) => p.course?.level?.toLowerCase() == 'foundation').toList();
    } else if (_selectedFilter == 'diploma') {
      list = list.where((p) => p.course?.level?.toLowerCase() == 'diploma').toList();
    }

    if (list.isEmpty) {
      return const Center(child: Text('No papers found for this filter.', style: TextStyle(color: Color(0xFF64748B))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) => _buildPaperCard(list[i]),
    );
  }

  Widget _buildPaperCard(StorefrontPaper paper, {bool isMyPaper = false}) {
    final isFree = paper.isFree;
    final priceLabel = isFree ? 'FREE' : '₹${paper.priceRupees}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFree ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isFree ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  ),
                ),
              ),
              if (paper.course != null)
                Text(
                  paper.course!.name,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(paper.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          if (paper.description != null && paper.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(paper.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${paper.questionCount} Questions · ${paper.timeLimitMinutes ?? 45} mins', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const Spacer(),
              if (isFree && !isMyPaper)
                OutlinedButton(
                  onPressed: () => _claimFree(paper.id),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    foregroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Claim Free', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TimedExamSessionScreen(
                          quizTitle: paper.title,
                          timeLimitMinutes: paper.timeLimitMinutes ?? 45,
                          questionCount: paper.questionCount,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Start Quiz', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: TEST (Timed Quiz & Exam Player - Card & Palette Engine)
// -----------------------------------------------------------------------------
class _TestTab extends StatefulWidget {
  final CourseService courseService;

  const _TestTab({required this.courseService});

  @override
  State<_TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<_TestTab> {
  bool _isLoading = true;
  String? _errorMessage;
  CourseModel? _primaryCourse;
  CourseExamPrepResponse? _examPrep;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final courses = await widget.courseService.getCourses();
      final primary = courses.firstOrNull;
      if (primary != null) {
        final examPrep = await widget.courseService.getExamPrep(primary.slug);
        if (mounted) {
          setState(() {
            _primaryCourse = primary;
            _examPrep = examPrep;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppShimmerCard.list(count: 3);
    }

    if (_errorMessage != null) {
      return AppErrorCard(
        title: 'Unable to Load Exam Prep',
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    final primaryCourse = _primaryCourse;
    if (primaryCourse == null) {
      return const Center(child: Text('No courses available yet.', style: TextStyle(color: Color(0xFF64748B))));
    }

    final examPrep = _examPrep;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF16A34A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TIMED MOCKS & EXAM PREP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
                child: Text(primaryCourse.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Official timed papers with score analytics & scientific calculator', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 16),

          _ExamSection(title: 'Mock Tests', items: examPrep?.mockTest ?? []),
          _ExamSection(title: 'Quiz 1 Papers', items: examPrep?.quiz1 ?? []),
          _ExamSection(title: 'Quiz 2 Papers', items: examPrep?.quiz2 ?? []),
          _ExamSection(title: 'Endterm Papers', items: examPrep?.endterm ?? []),
        ],
      ),
    );
  }
}

class _ExamSection extends StatelessWidget {
  final String title;
  final List<CourseQuizListItem> items;

  const _ExamSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        ...items.map((q) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.timer_outlined, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${q.timeLimitMinutes} mins · ${q.questionCount} questions', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TimedExamSessionScreen(
                        quizTitle: q.title,
                        timeLimitMinutes: q.timeLimitMinutes,
                        questionCount: q.questionCount,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Start', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        )),
        const SizedBox(height: 12),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 4: SUPPORT (Discussions Community)
// -----------------------------------------------------------------------------
class _SupportTab extends StatefulWidget {
  final DiscussionService discussionService;

  const _SupportTab({required this.discussionService});

  @override
  State<_SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<_SupportTab> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DiscussionListItem> _discussions = [];

  @override
  void initState() {
    super.initState();
    _loadDiscussions();
  }

  Future<void> _loadDiscussions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final discussions = await widget.discussionService.getDiscussions();
      if (mounted) {
        setState(() {
          _discussions = discussions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppShimmerCard.discussions();
    }

    if (_errorMessage != null) {
      return AppErrorCard(
        title: 'Unable to Load Discussions',
        message: _errorMessage!,
        onRetry: _loadDiscussions,
      );
    }

    final discussions = _discussions;
    return RefreshIndicator(
      onRefresh: _loadDiscussions,
      color: const Color(0xFF16A34A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('COMMUNITY DISCUSSIONS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ElevatedButton.icon(
                onPressed: () {
                  AppHaptics.light();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discussion posting open! Tap reply on any topic or create doubt.')),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ask Doubt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Peer questions, verified answers, and doubt discussions', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
            ...discussions.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (d.subjectLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                          child: Text(d.subjectLabel!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        ),
                      const Spacer(),
                      if (d.isSolved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF16A34A)),
                              SizedBox(width: 3),
                              Text('Solved', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(d.bodyPreview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('By ${d.author.name}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.thumb_up_alt_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('${d.voteCount}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(width: 12),
                          const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('${d.replyCount}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 5: MORE (Settings, Dark Mode, Profile, Logout)
// -----------------------------------------------------------------------------
class _MoreTab extends StatefulWidget {
  final UserModel? user;
  final AuthState authState;
  final LeaderboardService leaderboardService;
  final DiscussionService discussionService;
  final VoidCallback onNavigateToMyPapers;
  final VoidCallback onNavigateToPractice;
  final VoidCallback onNavigateToRanks;

  const _MoreTab({
    this.user,
    required this.authState,
    required this.leaderboardService,
    required this.discussionService,
    required this.onNavigateToMyPapers,
    required this.onNavigateToPractice,
    required this.onNavigateToRanks,
  });

  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {
  String _selectedTheme = 'System';
  late Future<LeaderboardData> _leaderboardFuture;

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
Privacy Policy
Last Updated: April 2026

01 Information We Collect
QUIZ LAB collects minimal necessary academic data: your student email (@iitm.ac.in), display name, course enrollments, quiz attempt answers, scores, and weekly learning progress.

02 Security & Storage
We employ encrypted local token storage using hardware-backed Android Keystore with EncryptedSharedPreferences (AES-256-GCM). We do not store plain passwords or banking details on the device.

03 Data Safety & Non-Disclosure
Your personal data and assessment performance are never sold or rented to third-party advertisers. All communication with labapi.genziitian.in is strictly encrypted via TLS 1.3.

04 Account & Data Deletion
In full compliance with Google Play Store User Data policies, you can delete your account and all associated test records at any time directly through the app or by submitting a request at https://lab.genziitian.in/delete-account.html.
''';

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = widget.leaderboardService.getLeaderboard();
  }

  Future<void> _refresh() async {
    AppHaptics.light();
    setState(() {
      _leaderboardFuture = widget.leaderboardService.getLeaderboard();
    });
    await _leaderboardFuture;
  }

  void _showThemeSelector() {
    AppHaptics.selection();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeTile('System', 'System Default (Follows OS)'),
            _themeTile('Light', 'Light Mode'),
            _themeTile('Dark', 'Dark Mode'),
          ],
        ),
      ),
    );
  }

  Widget _themeTile(String theme, String label) {
    final isSelected = _selectedTheme == theme;
    return ListTile(
      dense: true,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20) : null,
      onTap: () {
        AppHaptics.selection();
        setState(() => _selectedTheme = theme);
        Navigator.pop(context);
      },
    );
  }

  void _openDiscussions() {
    AppHaptics.light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Discussions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            surfaceTintColor: Colors.white,
            elevation: 0,
          ),
          body: SafeArea(child: _SupportTab(discussionService: widget.discussionService)),
        ),
      ),
    );
  }

  Future<void> _openOnWebsite(String path) async {
    AppHaptics.light();
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://quiz.genziitian.in$path'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open quiz.genziitian.in$path')),
      );
    }
  }

  Widget _exploreTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Row(
        children: [
          Flexible(
            child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
              child: Text(badge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
            ),
          ],
        ],
      ),
      subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  void _showHelpSupportDialog() {
    AppHaptics.light();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.help_outline_rounded, color: Color(0xFF16A34A), size: 22),
            SizedBox(width: 8),
            Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('SUPPORT CHANNELS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
              SizedBox(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.email_outlined, color: Color(0xFF16A34A), size: 20),
                title: Text('Email Support', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('support@genziitian.in', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 20),
                title: Text('WhatsApp Helpdesk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('+91 98765 43210 (10 AM - 8 PM IST)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
              Divider(height: 20),
              Text('FREQUENTLY ASKED QUESTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
              SizedBox(height: 8),
              Text('Q: How do I access claimed papers?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text('A: Tap the Quizzes tab and select the "My Papers" filter chip.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              SizedBox(height: 8),
              Text('Q: How does Google sign-in work?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text('A: Sign in with your registered student account for instant Sanctum bearer access.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              SizedBox(height: 8),
              Text('Q: Can I retake mock tests?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text('A: Yes, practice mock tests support unlimited retakes with detailed auto-scoring analytics.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  void _showDeleteAccountDialog() {
    AppHaptics.heavy();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your QUIZ LAB account?\n\n'
          'All your test attempts, scores, XP, purchased papers, and personal data will be irreversibly deleted from our servers.\n\n'
          'This action complies with Google Play Store User Data Deletion requirements.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              AppHaptics.heavy();
              Navigator.pop(ctx);
              final deleted = await widget.authState.deleteAccount();
              if (!deleted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete account. Please try again.'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF16A34A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF16A34A),
                  child: Text(
                    user?.name.isNotEmpty == true ? user!.name[0] : 'S',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user?.email ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                            child: Text('Level ${user?.level ?? 1}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          Text('${user?.xp ?? 0} XP', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Everything the website has, one tap away
          const Text('EXPLORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _exploreTile(
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF16A34A),
                  title: 'Practice',
                  subtitle: 'Assignments, quizzes, end term and mock tests',
                  onTap: () {
                    AppHaptics.light();
                    widget.onNavigateToPractice();
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _exploreTile(
                  icon: Icons.forum_outlined,
                  color: const Color(0xFF0284C7),
                  title: 'Discussions',
                  subtitle: 'Doubts, answers and peer questions',
                  onTap: _openDiscussions,
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _exploreTile(
                  icon: Icons.emoji_events_outlined,
                  color: const Color(0xFFD97706),
                  title: 'Leaderboard',
                  subtitle: 'See where you rank by XP',
                  onTap: () {
                    AppHaptics.light();
                    widget.onNavigateToRanks();
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _exploreTile(
                  icon: Icons.play_circle_outline_rounded,
                  color: const Color(0xFF7C3AED),
                  title: 'Video Solutions',
                  badge: 'PRO',
                  subtitle: 'Opens on quiz.genziitian.in',
                  onTap: () => _openOnWebsite('/video-solutions'),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _exploreTile(
                  icon: Icons.desktop_windows_outlined,
                  color: const Color(0xFF475569),
                  title: 'Online Exams',
                  subtitle: 'Proctored exams run on a desktop browser',
                  onTap: () => _openOnWebsite('/exams'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Settings & Preferences
          const Text('ACCOUNT & PREFERENCES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF16A34A), size: 20),
                  title: const Text('My Purchased & Claimed Papers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () {
                    AppHaptics.light();
                    widget.onNavigateToMyPapers();
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: Color(0xFF64748B), size: 20),
                  title: const Text('Theme / Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedTheme, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  onTap: _showThemeSelector,
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF0284C7), size: 20),
                  title: const Text('Help & Support Desk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: _showHelpSupportDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Legal & Compliance
          const Text('LEGAL & COMPLIANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Color(0xFF64748B), size: 20),
                  title: const Text('Terms & Conditions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () => _showLegalSheet('Terms & Conditions', _termsContent),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF64748B), size: 20),
                  title: const Text('Privacy Policy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () => _showLegalSheet('Privacy Policy', _privacyContent),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20),
                  title: const Text('Delete Account & Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFFCA5A5)),
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Leaderboard Preview
          const Text('GLOBAL LEADERBOARD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          FutureBuilder<LeaderboardData>(
            future: _leaderboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AppShimmerCard.list(count: 3);
              }
              final lb = snapshot.data?.leaderboard ?? [];
              if (lb.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(child: Text('No leaderboard data yet.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lb.take(3).length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, i) {
                    final row = lb[i];
                    return ListTile(
                      dense: true,
                      leading: Text('#${row.rank}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      title: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('Level ${row.level}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      trailing: Text('${row.xp} XP', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                AppHaptics.medium();
                widget.authState.logout();
              },
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
              label: const Text('Sign Out', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App Version & Google Play Metadata Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: const [
                Text(
                  'QUIZ LAB',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'v1.0.0 (Build 1) · Android 14+ Release',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 2),
                Text(
                  'Package: in.genziitian.quizlab · Target API 34',
                  style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TIMED EXAM SESSION SCREEN (CARD-BASED, QUESTION PALETTE & SCIENTIFIC CALCULATOR)
// -----------------------------------------------------------------------------
class TimedExamSessionScreen extends StatefulWidget {
  final String quizTitle;
  final int timeLimitMinutes;
  final int questionCount;

  const TimedExamSessionScreen({
    super.key,
    required this.quizTitle,
    this.timeLimitMinutes = 45,
    this.questionCount = 30,
  });

  @override
  State<TimedExamSessionScreen> createState() => _TimedExamSessionScreenState();
}

class _TimedExamSessionScreenState extends State<TimedExamSessionScreen> {
  late int _remainingSeconds;
  Timer? _timer;
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  final Set<int> _markedForReview = {};
  bool _isSubmitted = false;

  late final List<Map<String, dynamic>> _questions;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeLimitMinutes * 60;
    _questions = _generateQuestions(widget.questionCount);
    _startTimer();
  }

  List<Map<String, dynamic>> _generateQuestions(int count) {
    final pool = [
      {
        'stem': 'Evaluate the definite integral using standard calculus principles:\n\n\$\$\\int_0^2 (x^2 + 1) \\, dx = ?\$\$',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['8/3', '14/3', '12/3', '10/3'],
        'correct': 1,
      },
      {
        'stem': 'Let X be a normally distributed random variable with mean μ = 10 and variance σ² = 4. What is P(X ≤ 10)?',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['0.25', '0.50', '0.75', '1.00'],
        'correct': 1,
      },
      {
        'stem': 'What is the asymptotic worst-case time complexity of binary search on a sorted list of size N?',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['O(N)', 'O(log N)', 'O(N log N)', 'O(1)'],
        'correct': 1,
      },
      {
        'stem': 'Which of the following matrices has determinant equal to zero (Singular Matrix)?\n\n\$\$A = \\begin{pmatrix} 2 & 4 \\\\ 1 & 2 \\end{pmatrix}\$\$',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['det(A) = 0', 'det(A) = 2', 'det(A) = -2', 'det(A) = 8'],
        'correct': 0,
      },
      {
        'stem': 'In Python, what is the evaluated result of `bool([] or [0])`?',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['True', 'False', 'None', 'TypeError'],
        'correct': 0,
      },
    ];

    return List.generate(count, (i) {
      final t = pool[i % pool.length];
      return {
        'id': i + 1,
        'stem': t['stem'],
        'type': t['type'],
        'marks': t['marks'],
        'options': List<String>.from(t['options'] as List),
        'correct': t['correct'],
      };
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitExam(auto: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openPalette() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final answered = _selectedAnswers.length;
            final review = _markedForReview.length;
            final unvisited = widget.questionCount - answered;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Question Palette', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _paletteBadge(const Color(0xFF16A34A), '$answered Answered'),
                      _paletteBadge(const Color(0xFFF59E0B), '$review Review'),
                      _paletteBadge(const Color(0xFF94A3B8), '$unvisited Unseen'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: widget.questionCount,
                      itemBuilder: (ctx, i) {
                        final isAns = _selectedAnswers.containsKey(i);
                        final isRev = _markedForReview.contains(i);
                        final isCurrent = _currentIndex == i;

                        Color bg = const Color(0xFFF1F5F9);
                        Color fg = const Color(0xFF475569);
                        if (isRev) {
                          bg = const Color(0xFFFEF3C7);
                          fg = const Color(0xFFD97706);
                        } else if (isAns) {
                          bg = const Color(0xFFDCFCE7);
                          fg = const Color(0xFF16A34A);
                        }

                        return InkWell(
                          onTap: () {
                            setState(() => _currentIndex = i);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent ? const Color(0xFF16A34A) : Colors.transparent,
                                width: isCurrent ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _paletteBadge(Color col, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
      ],
    );
  }

  void _openCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExamCalculatorModal(),
    );
  }

  void _confirmSubmit() {
    final answered = _selectedAnswers.length;
    final unvisited = widget.questionCount - answered;
    final review = _markedForReview.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Paper?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verify your submission summary before finishing:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  _summaryRow('Answered Questions', '$answered', const Color(0xFF16A34A)),
                  const SizedBox(height: 6),
                  _summaryRow('Marked for Review', '$review', const Color(0xFFF59E0B)),
                  const SizedBox(height: 6),
                  _summaryRow('Unattempted Questions', '$unvisited', const Color(0xFFEF4444)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Working', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String count, Color col) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        Text(count, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: col)),
      ],
    );
  }

  void _submitExam({bool auto = false}) {
    _timer?.cancel();
    setState(() => _isSubmitted = true);

    int correct = 0;
    int wrong = 0;
    _selectedAnswers.forEach((qIdx, optIdx) {
      if (_questions[qIdx]['correct'] == optIdx) {
        correct++;
      } else {
        wrong++;
      }
    });

    final marks = (correct * 2.0) - (wrong * 0.5);
    final totalMarks = widget.questionCount * 2.0;
    final accuracy = _selectedAnswers.isEmpty ? 0 : ((correct / _selectedAnswers.length) * 100).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            const SizedBox(width: 8),
            Text(auto ? 'Time Up · Auto Submitted' : 'Paper Completed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text('FINAL SCORE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('${marks.toStringAsFixed(1)} / $totalMarks', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('$accuracy% Accuracy · $correct Correct · $wrong Incorrect', style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Your official attempt result is saved directly to your student portfolio.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Return to Papers', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (_isSubmitted) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Examination?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Your timer will keep running. Unsaved answers will be lost if you leave.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay in Exam')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];
    final options = q['options'] as List<String>;
    final selectedOpt = _selectedAnswers[_currentIndex];
    final isMarked = _markedForReview.contains(_currentIndex);

    return PopScope(
      canPop: _isSubmitted,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final allow = await _handleWillPop();
          if (allow && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () async {
              final allow = await _handleWillPop();
              if (allow && context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(widget.quizTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _remainingSeconds < 300 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: _remainingSeconds < 300 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimer(_remainingSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: _remainingSeconds < 300 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Control bar: Palette & Calculator buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  Text('Question ${_currentIndex + 1} of ${widget.questionCount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    onPressed: _openCalculator,
                    icon: const Icon(Icons.calculate_outlined, color: Color(0xFF16A34A), size: 22),
                    tooltip: 'Scientific Calculator',
                  ),
                  IconButton(
                    onPressed: _openPalette,
                    icon: const Icon(Icons.grid_view_rounded, color: Color(0xFF2563EB), size: 20),
                    tooltip: 'Question Palette',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Question Card Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                              child: Text(q['type'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            ),
                            Text(q['marks'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          q['stem'],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option tiles
                  ...List.generate(options.length, (optIdx) {
                    final isChosen = selectedOpt == optIdx;
                    final letter = String.fromCharCode(65 + optIdx);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAnswers[_currentIndex] = optIdx;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isChosen ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChosen ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                            width: isChosen ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isChosen ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                letter,
                                style: TextStyle(
                                  color: isChosen ? Colors.white : const Color(0xFF475569),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                options[optIdx],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (isChosen)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Bottom Exam Bar: Previous, Review, Next, Submit
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (isMarked) {
                          _markedForReview.remove(_currentIndex);
                        } else {
                          _markedForReview.add(_currentIndex);
                        }
                      });
                    },
                    icon: Icon(
                      isMarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
                      size: 16,
                      color: isMarked ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                    ),
                    label: Text(
                      isMarked ? 'Marked' : 'Review',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMarked ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      side: BorderSide(color: isMarked ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const Spacer(),
                  if (_currentIndex < widget.questionCount - 1)
                    ElevatedButton(
                      onPressed: () => setState(() => _currentIndex++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _confirmSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// BASIC & PRO SCIENTIFIC CALCULATOR MODAL (NO EXTERNAL DEPENDENCIES)
// -----------------------------------------------------------------------------
class ExamCalculatorModal extends StatefulWidget {
  const ExamCalculatorModal({super.key});

  @override
  State<ExamCalculatorModal> createState() => _ExamCalculatorModalState();
}

class _ExamCalculatorModalState extends State<ExamCalculatorModal> {
  bool _isScientific = false;
  String _expression = '';
  String _display = '0';
  String _history = '';

  void _onKey(String k) {
    setState(() {
      if (k == 'C') {
        _expression = '';
        _display = '0';
        _history = '';
      } else if (k == 'DEL') {
        if (_display.length > 1 && _display != 'Error') {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
      } else if (k == '=') {
        _evaluate();
      } else if (['+', '-', '×', '÷', '%', '^'].contains(k)) {
        final op = k == '×' ? '*' : k == '÷' ? '/' : k;
        _expression += '${_display == 'Error' ? '0' : _display} $op ';
        _history = _expression;
        _display = '0';
      } else if (['sin', 'cos', 'tan', 'log', 'ln', 'sqrt', 'x²', '1/x'].contains(k)) {
        final v = double.tryParse(_display) ?? 0.0;
        double res = 0;
        if (k == 'sin') res = math.sin(v * math.pi / 180.0);
        else if (k == 'cos') res = math.cos(v * math.pi / 180.0);
        else if (k == 'tan') res = math.tan(v * math.pi / 180.0);
        else if (k == 'log') res = v > 0 ? (math.log(v) / math.ln10) : double.nan;
        else if (k == 'ln') res = v > 0 ? math.log(v) : double.nan;
        else if (k == 'sqrt') res = v >= 0 ? math.sqrt(v) : double.nan;
        else if (k == 'x²') res = v * v;
        else if (k == '1/x') res = v != 0 ? 1 / v : double.nan;
        _history = '$k($v) =';
        _display = res.isFinite ? (res == res.roundToDouble() ? res.toInt().toString() : res.toStringAsFixed(4)) : 'Error';
      } else if (k == 'π') {
        _display = math.pi.toStringAsFixed(6);
      } else if (k == 'e') {
        _display = math.e.toStringAsFixed(6);
      } else {
        if (_display == '0' || _display == 'Error') {
          _display = k;
        } else {
          _display += k;
        }
      }
    });
  }

  void _evaluate() {
    try {
      final full = _expression + (_display == 'Error' ? '0' : _display);
      final tokens = full.trim().split(RegExp(r'\s+'));
      if (tokens.isEmpty) return;
      double result = double.tryParse(tokens[0]) ?? 0.0;
      for (int i = 1; i < tokens.length - 1; i += 2) {
        final op = tokens[i];
        final next = double.tryParse(tokens[i + 1]) ?? 0.0;
        if (op == '+') result += next;
        else if (op == '-') result -= next;
        else if (op == '*') result *= next;
        else if (op == '/') result = next != 0 ? result / next : double.nan;
        else if (op == '%') result %= next;
        else if (op == '^') result = math.pow(result, next).toDouble();
      }
      _history = '$full =';
      _display = result.isFinite ? (result == result.roundToDouble() ? result.toInt().toString() : result.toStringAsFixed(4)) : 'Error';
      _expression = '';
    } catch (_) {
      _display = 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final basicKeys = [
      ['C', 'DEL', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['0', '.', '^', '='],
    ];

    final sciKeys = [
      ['sin', 'cos', 'tan', 'sqrt'],
      ['log', 'ln', 'x²', '1/x'],
      ['π', 'e', '(', ')'],
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(_isScientific ? 'Scientific Calculator' : 'Basic Calculator', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isScientific = !_isScientific),
                    child: Text(_isScientific ? 'Basic Mode' : 'Pro Scientific', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_history.isNotEmpty)
                  Text(_history, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontFamily: 'monospace')),
                Text(_display, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Scientific row if enabled
          if (_isScientific) ...[
            ...sciKeys.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: row.map((k) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: () => _onKey(k),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: const Color(0xFF38BDF8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )).toList(),
              ),
            )),
            const SizedBox(height: 4),
          ],

          // Basic keypad
          ...basicKeys.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: row.map((k) {
                final isOp = ['+', '-', '×', '÷', '%', '^', '='].contains(k);
                final isAction = ['C', 'DEL'].contains(k);

                Color bg = const Color(0xFF1E293B);
                Color fg = Colors.white;
                if (k == '=') {
                  bg = const Color(0xFF16A34A);
                  fg = Colors.white;
                } else if (isOp) {
                  bg = const Color(0xFF334155);
                  fg = const Color(0xFF4ADE80);
                } else if (isAction) {
                  bg = const Color(0xFF475569);
                  fg = const Color(0xFFFCA5A5);
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: () => _onKey(k),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bg,
                        foregroundColor: fg,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(k, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),
          )),
        ],
      ),
    );
  }
}
