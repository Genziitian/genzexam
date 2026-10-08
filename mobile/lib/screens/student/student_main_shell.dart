import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../legal/legal_documents.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../api/api.dart';
import '../../state/auth_state.dart';
import '../../state/theme_state.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/confirm_sign_out.dart';
import 'discussions_screen.dart';
import 'help_screens.dart';
import 'practice_screens.dart';
import 'progress_widgets.dart';

// -----------------------------------------------------------------------------
// AVATARS: ready-made pictures a student can pick. The choice is kept on this
// phone (per account); without one, the avatar shows the student's initials.
// -----------------------------------------------------------------------------
class _AvatarPreset {
  final String emoji;
  final Color from;
  final Color to;

  const _AvatarPreset(this.emoji, this.from, this.to);
}

const List<_AvatarPreset> _avatarPresets = [
  _AvatarPreset('🦊', Color(0xFFFDBA74), Color(0xFFEA580C)),
  _AvatarPreset('🐼', Color(0xFFE2E8F0), Color(0xFF64748B)),
  _AvatarPreset('🦁', Color(0xFFFDE68A), Color(0xFFD97706)),
  _AvatarPreset('🐯', Color(0xFFFED7AA), Color(0xFFC2410C)),
  _AvatarPreset('🐸', Color(0xFFBBF7D0), Color(0xFF16A34A)),
  _AvatarPreset('🦉', Color(0xFFDDD6FE), Color(0xFF6D28D9)),
  _AvatarPreset('🐙', Color(0xFFFBCFE8), Color(0xFFDB2777)),
  _AvatarPreset('🐬', Color(0xFFBAE6FD), Color(0xFF0284C7)),
  _AvatarPreset('🚀', Color(0xFFC7D2FE), Color(0xFF4338CA)),
  _AvatarPreset('⚡', Color(0xFFFEF08A), Color(0xFFCA8A04)),
  _AvatarPreset('🎯', Color(0xFFFECACA), Color(0xFFDC2626)),
  _AvatarPreset('🧠', Color(0xFFF5D0FE), Color(0xFFA21CAF)),
];

/// Index into [_avatarPresets], or null for the initials avatar.
final ValueNotifier<int?> _avatarChoice = ValueNotifier<int?>(null);
const _avatarStore = FlutterSecureStorage();

String _avatarKey(int? userId) => 'avatar_preset_${userId ?? 0}';

Future<void> _loadAvatarChoice(int? userId) async {
  try {
    final saved = int.tryParse(await _avatarStore.read(key: _avatarKey(userId)) ?? '');
    _avatarChoice.value = (saved != null && saved >= 0 && saved < _avatarPresets.length) ? saved : null;
  } catch (_) {
    _avatarChoice.value = null;
  }
}

Future<void> _saveAvatarChoice(int? userId, int? choice) async {
  _avatarChoice.value = choice;
  try {
    if (choice == null) {
      await _avatarStore.delete(key: _avatarKey(userId));
    } else {
      await _avatarStore.write(key: _avatarKey(userId), value: '$choice');
    }
  } catch (_) {
    // The choice still applies for this session.
  }
}

String _userInitials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'S';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// One avatar circle: a chosen preset, or the initials. [preset] overrides the saved choice (used by the picker).
Widget _avatarCircle({required String? name, required double size, int? preset, bool usePreset = true}) {
  final p = usePreset && preset != null && preset >= 0 && preset < _avatarPresets.length ? _avatarPresets[preset] : null;
  if (p == null) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFF86EFAC), width: 2),
      ),
      child: Text(
        _userInitials(name),
        style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A)),
      ),
    );
  }
  return KeepColors(
    child: Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.from, p.to]),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [BoxShadow(color: p.to.withValues(alpha: 0.35), blurRadius: size * 0.2, offset: Offset(0, size * 0.08))],
    ),
    child: Text(p.emoji, style: TextStyle(fontSize: size * 0.5, height: 1.1)),
    ),
  );
}

/// The signed-in student's avatar; redraws when they pick a different one.
class _UserAvatar extends StatelessWidget {
  final String? name;
  final double size;

  const _UserAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: _avatarChoice,
      builder: (context, choice, _) => _avatarCircle(name: name, size: size, preset: choice),
    );
  }
}

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
  void initState() {
    super.initState();
    _loadAvatarChoice(widget.authState.user?.id);
  }

  @override
  Widget build(BuildContext context) {
    return AppKeyboardDismiss(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        // Pages run right down to the floating bar, so there is no empty band beside the raised button.
        extendBody: true,
        body: SafeArea(
          bottom: false,
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
                child: Padding(
                  // Height of the bar's white pill plus its bottom margin and the system inset.
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + 76),
                  child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _HomeTab(
                      dashboardService: _dashboardService,
                      leaderboardService: _leaderboardService,
                      user: widget.authState.user,
                      onNavigateToQuizzes: () => setState(() => _currentIndex = 1),
                      onOpenProfile: () => setState(() => _currentIndex = 4),
                    ),
                    _MyPapersTab(
                      storefrontService: _storefrontService,
                      courseService: _courseService,
                      user: widget.authState.user,
                      isActive: _currentIndex == 1,
                      onBrowsePractice: () => setState(() => _currentIndex = 2),
                    ),
                    PracticeTab(courseService: _courseService, user: widget.authState.user),
                    _RanksTab(
                      leaderboardService: _leaderboardService,
                      user: widget.authState.user,
                      isActive: _currentIndex == 3,
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
          height: 106,
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
// TAB: RANKS (Global XP leaderboard with podium, celebration and pinned "you" row)
// -----------------------------------------------------------------------------
class _RanksTab extends StatefulWidget {
  final LeaderboardService leaderboardService;
  final UserModel? user;

  /// True while this tab is the one on screen; each time it becomes true the
  /// podium pops in again and the confetti plays.
  final bool isActive;

  const _RanksTab({required this.leaderboardService, this.user, required this.isActive});

  @override
  State<_RanksTab> createState() => _RanksTabState();
}

class _RanksTabState extends State<_RanksTab> with TickerProviderStateMixin {
  static const _rowHeight = 62.0;

  late Future<LeaderboardData> _future;
  late final AnimationController _party; // confetti, ~3.2s
  late final AnimationController _pop; // podium cards popping in
  late final AnimationController _idle; // gentle loop: gold glow and bobbing medals
  int _plays = 0; // bumps each time the tab opens, so one-shot animations replay

  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _myRowKey = GlobalKey();
  bool _pinMyRow = false;

  @override
  void initState() {
    super.initState();
    _future = widget.leaderboardService.getLeaderboard();
    _party = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _scroll.addListener(_updatePin);
    if (widget.isActive) _celebrate();
  }

  @override
  void didUpdateWidget(covariant _RanksTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _celebrate();
  }

  @override
  void dispose() {
    _scroll.removeListener(_updatePin);
    _scroll.dispose();
    _party.dispose();
    _pop.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _celebrate() {
    _plays++;
    _pop.forward(from: 0);
    _party.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePin());
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

  /// Pin the "you" row to the bottom while your real row is still below the screen.
  void _updatePin() {
    if (!mounted) return;
    final rowBox = _myRowKey.currentContext?.findRenderObject();
    final viewBox = _viewportKey.currentContext?.findRenderObject();
    var pin = false;
    if (rowBox is RenderBox && viewBox is RenderBox && rowBox.attached && viewBox.attached) {
      final top = rowBox.localToGlobal(Offset.zero, ancestor: viewBox).dy;
      pin = top > viewBox.size.height - _rowHeight - 8;
    }
    if (pin != _pinMyRow) setState(() => _pinMyRow = pin);
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static const _avatarColors = [
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0284C7),
    Color(0xFFDB2777),
  ];

  Uri? _avatarUri(String? avatar) {
    final value = avatar?.trim();
    if (value == null || value.isEmpty) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;
    final apiOrigin = Uri.parse(ApiClient.defaultBaseUrl);
    return apiOrigin.replace(
      path: parsed.path.startsWith('/') ? parsed.path : '/${parsed.path}',
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    );
  }

  Widget _avatar(String name, double size, {String? avatar, Color? color}) {
    final c = color ?? _avatarColors[name.hashCode.abs() % _avatarColors.length];
    final imageUri = _avatarUri(avatar);
    final initials = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(c.withValues(alpha: 0.10), Colors.white),
      ),
      child: Text(
        _initialsOf(name),
        style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, color: c),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(c.withValues(alpha: 0.10), Colors.white),
        border: Border.all(color: c.withValues(alpha: 0.30), width: 1.5),
      ),
      child: ClipOval(
        child: imageUri == null
            ? initials
            : Image.network(
                imageUri.toString(),
                width: size,
                height: size,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    wasSynchronouslyLoaded || frame != null ? child : initials,
                errorBuilder: (context, error, stackTrace) => initials,
              ),
      ),
    );
  }

  // ---- Podium ---------------------------------------------------------------

  Widget _podiumCard(GlobalLeaderboardEntry entry, int place) {
    // place: 1 gold (tallest), 2 silver, 3 bronze. Feet line up at the bottom.
    final double height = place == 1 ? 262 : (place == 2 ? 244 : 228);
    final List<Color> fill = place == 1
        ? const [Color(0xFFFFF4B8), Color(0xFFFCD34D), Color(0xFFF5B92E)] // polished gold
        : place == 2
            ? const [Color(0xFFFFFFFF), Color(0xFFE2E8F0)]
            : const [Color(0xFFFFF7ED), Color(0xFFFCD9B6)];
    final Color edge = place == 1
        ? const Color(0xFFF59E0B)
        : place == 2
            ? const Color(0xFF94A3B8)
            : const Color(0xFFC2773A);
    final Color strong = place == 1
        ? const Color(0xFF92400E)
        : place == 2
            ? const Color(0xFF475569)
            : const Color(0xFF9A4D16);
    final medal = place == 1 ? '🥇' : (place == 2 ? '🥈' : '🥉');
    final label = place == 1 ? 'TOP' : (place == 2 ? '2ND' : '3RD');

    // Pop order: silver, gold, bronze.
    final order = place == 2 ? 0 : (place == 1 ? 1 : 2);
    final start = 0.12 * order;

    return AnimatedBuilder(
      animation: _pop,
      builder: (context, child) {
        final t = ((_pop.value - start) / 0.6).clamp(0.0, 1.0).toDouble();
        final scale = Curves.elasticOut.transform(t);
        return Opacity(
          opacity: (t * 3).clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: 0.6 + 0.4 * scale, alignment: Alignment.bottomCenter, child: child),
        );
      },
      child: SizedBox(
        height: height + 12,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            if (place == 1)
              // Breathing golden glow behind the winner.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: height,
                child: AnimatedBuilder(
                  animation: _idle,
                  builder: (context, _) {
                    final pulse = 0.5 + 0.5 * math.sin(_idle.value * 2 * math.pi);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.25 + 0.35 * pulse),
                            blurRadius: 18 + 22 * pulse,
                            spreadRadius: 1 + 4 * pulse,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Container(
              height: height,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: fill),
                border: Border.all(color: edge, width: place == 1 ? 2.5 : 1.5),
                boxShadow: [
                  BoxShadow(color: edge.withValues(alpha: place == 1 ? 0.35 : 0.2), blurRadius: place == 1 ? 24 : 14, offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(
                children: [
                  if (place == 1) ...[
                    // Soft gloss along the top edge, like polished metal.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 70,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                    // A narrow glint that glides across once, then rests. It sits under
                    // the text, so the name and XP always stay crisp.
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final bandWidth = box.maxWidth * 0.42;
                          return AnimatedBuilder(
                            animation: _idle,
                            builder: (context, child) {
                              final t = ((_idle.value - 0.08) / 0.38).clamp(0.0, 1.0).toDouble();
                              final eased = Curves.easeInOut.transform(t);
                              // The band is centred in the card; slide it from fully off the left to fully off the right.
                              final travel = box.maxWidth / 2 + bandWidth * 1.2;
                              final dx = -travel + 2 * travel * eased;
                              return Transform.translate(offset: Offset(dx, 0), child: child);
                            },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Transform.rotate(
                                angle: 0.32,
                                child: OverflowBox(
                                  maxHeight: box.maxHeight * 1.8,
                                  minHeight: box.maxHeight * 1.8,
                                  maxWidth: bandWidth,
                                  minWidth: bandWidth,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0),
                                          Colors.white.withValues(alpha: 0.38),
                                          Colors.white.withValues(alpha: 0.62),
                                          Colors.white.withValues(alpha: 0.38),
                                          Colors.white.withValues(alpha: 0),
                                        ],
                                        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                      ),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 22, 6, 12),
                    child: Column(
                children: [
                  _avatar(entry.name, place == 1 ? 62 : 52, avatar: entry.avatar, color: strong),
                  const SizedBox(height: 8),
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _idle,
                    builder: (context, child) {
                      final wave = math.sin((_idle.value + place * 0.22) * 2 * math.pi);
                      return Transform.translate(
                        offset: Offset(0, -2.5 * wave),
                        child: Transform.rotate(angle: 0.10 * wave, child: child),
                      );
                    },
                    child: Text(medal, style: const TextStyle(fontSize: 22, height: 1.1)),
                  ),
                  const SizedBox(height: 2),
                  TweenAnimationBuilder<double>(
                    key: ValueKey<String>('xp-$_plays-${entry.userId}'),
                    tween: Tween<double>(begin: 0.0, end: entry.xp.toDouble()),
                    duration: Duration(milliseconds: 1100 + 150 * order),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      '${value.round()}',
                      style: TextStyle(fontSize: place == 1 ? 24 : 20, height: 1.1, fontWeight: FontWeight.w800, color: strong),
                    ),
                  ),
                  const Text('XP', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '⚡ LVL ${entry.level}',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: strong),
                    ),
                  ),
                ],
              ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: edge, borderRadius: BorderRadius.circular(10)),
                child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _podium(List<GlobalLeaderboardEntry> top) {
    // Left silver (#2), middle gold (#1), right bronze (#3).
    final first = top.isNotEmpty ? top[0] : null;
    final second = top.length > 1 ? top[1] : null;
    final third = top.length > 2 ? top[2] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(flex: 10, child: second == null ? const SizedBox() : _podiumCard(second, 2)),
        const SizedBox(width: 8),
        Expanded(flex: 11, child: first == null ? const SizedBox() : _podiumCard(first, 1)),
        const SizedBox(width: 8),
        Expanded(flex: 10, child: third == null ? const SizedBox() : _podiumCard(third, 3)),
      ],
    );
  }

  // ---- Rows -----------------------------------------------------------------

  Widget _row({required String rank, required String name, required int xp, String? avatar, bool isMe = false, bool compact = false, Key? key}) {
    return Container(
      key: key,
      height: compact ? 50 : _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isMe ? const Color(0xFFF0FDF4) : null,
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              rank,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isMe ? const Color(0xFF15803D) : const Color(0xFF475569)),
            ),
          ),
          _avatar(name, 34, avatar: avatar, color: isMe ? const Color(0xFF16A34A) : null),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(6)),
                    child: const Text('YOU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          Text('$xp', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  /// "More people in between" marker.
  Widget _gapRow({double height = 34}) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle),
            ),
        ],
      ),
    );
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
        final myId = widget.user?.id;
        final myName = widget.user?.name ?? 'You';
        final myRank = data.myRank;
        final myIndex = entries.indexWhere((e) => e.userId == myId);
        final rest = entries.length > 3 ? entries.sublist(3) : <GlobalLeaderboardEntry>[];
        // You are below everyone listed: show a gap marker, then your row at the end.
        final appendMe = myIndex < 0 && myRank != null;
        final hasMyRow = myIndex >= 3 || appendMe;

        WidgetsBinding.instance.addPostFrameCallback((_) => _updatePin());

        return Stack(
          key: _viewportKey,
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF16A34A),
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Leaderboard',
                      style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: 'Top students by total XP',
                        children: [
                          if (myRank != null)
                            TextSpan(
                              text: '  · Your rank: #$myRank',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                            ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 18),

                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('No rankings yet. Finish a quiz to get on the board.', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                      )
                    else ...[
                      _podium(entries),
                      const SizedBox(height: 20),

                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 54,
                                    child: Text('RANK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: Color(0xFF64748B))),
                                  ),
                                  Expanded(
                                    child: Text('STUDENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: Color(0xFF64748B))),
                                  ),
                                  Text('XP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            for (var i = 0; i < rest.length; i++) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _FadeUp(
                                key: ValueKey<String>('row-$_plays-$i'),
                                delayMs: 350 + (i < 12 ? i * 55 : 660),
                                child: _row(
                                  key: rest[i].userId == myId ? _myRowKey : null,
                                  rank: '#${rest[i].rank}',
                                  name: rest[i].name,
                                  xp: rest[i].xp,
                                  avatar: rest[i].avatar,
                                  isMe: rest[i].userId == myId,
                                ),
                              ),
                            ],
                            if (appendMe) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _gapRow(),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _row(key: _myRowKey, rank: '#$myRank', name: myName, xp: data.me.xp, avatar: widget.user?.avatar, isMe: true),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Your row, pinned to the bottom until your real place scrolls into view.
            if (hasMyRow)
              Positioned(
                left: 16,
                right: 16,
                bottom: 6,
                child: IgnorePointer(
                  ignoring: !_pinMyRow,
                  child: AnimatedSlide(
                    offset: _pinMyRow ? Offset.zero : const Offset(0, 0.4),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _pinMyRow ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Three dots: there are more students between the rows above and you.
                            Container(color: const Color(0xFFF0FDF4), child: _gapRow(height: 14)),
                            _row(
                              compact: true,
                              rank: myRank != null ? '#$myRank' : '—',
                              name: myName,
                              xp: myIndex >= 0 ? entries[myIndex].xp : data.me.xp,
                              avatar: myIndex >= 0 ? entries[myIndex].avatar : widget.user?.avatar,
                              isMe: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Celebration
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _party,
                  builder: (context, _) {
                    if (_party.value <= 0 || _party.value >= 1) return const SizedBox.shrink();
                    return CustomPaint(painter: _ConfettiPainter(progress: _party.value));
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Confetti: two bursts popping up from the lower corners, then falling.
class _ConfettiPainter extends CustomPainter {
  final double progress; // 0..1 over the whole celebration

  const _ConfettiPainter({required this.progress});

  static const _colors = [
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFFA855F7),
    Color(0xFFFACC15),
    Color(0xFFEF4444),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint();
    const seconds = 3.2;
    final time = progress * seconds;
    final fadeOut = ((1 - progress) / 0.25).clamp(0.0, 1.0).toDouble();

    for (var i = 0; i < 130; i++) {
      final fromLeft = i.isEven;
      final delay = random.nextDouble() * 0.5; // staggered pops
      final angle = (fromLeft ? -math.pi / 3 : -2 * math.pi / 3) + (random.nextDouble() - 0.5) * 0.9;
      final speed = size.height * (0.75 + random.nextDouble() * 0.75);
      final w = 5.0 + random.nextDouble() * 6;
      final h = 3.0 + random.nextDouble() * 5;
      final spin = (random.nextDouble() - 0.5) * 14;
      final color = _colors[random.nextInt(_colors.length)];
      final round = random.nextInt(4) == 0;

      final t = time - delay;
      if (t <= 0) continue;

      // Launch, slow down with drag, fall with gravity.
      final drag = 1 - math.exp(-2.2 * t);
      final gravity = size.height * 0.55;
      final x = (fromLeft ? 0.0 : size.width) + math.cos(angle) * speed * drag / 2.2 + math.sin(t * 3 + i) * 6;
      final y = size.height * 0.62 + math.sin(angle) * speed * drag / 2.2 + 0.5 * gravity * t * t;
      if (y > size.height + 20) continue;

      paint.color = color.withValues(alpha: fadeOut);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * t);
      if (round) {
        canvas.drawCircle(Offset.zero, w / 2, paint);
      } else {
        // Squash the width over time so pieces look like they flutter.
        final flutter = 0.35 + 0.65 * math.cos(t * 9 + i).abs();
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w * flutter, height: h), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

// -----------------------------------------------------------------------------
// TAB 1: HOME (Dashboard & Weekly Goal Tracker)
// -----------------------------------------------------------------------------
class _HomeTab extends StatefulWidget {
  final DashboardService dashboardService;
  final LeaderboardService leaderboardService;
  final UserModel? user;
  final VoidCallback onNavigateToQuizzes;
  final VoidCallback onOpenProfile;

  const _HomeTab({
    required this.dashboardService,
    required this.leaderboardService,
    this.user,
    required this.onNavigateToQuizzes,
    required this.onOpenProfile,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with SingleTickerProviderStateMixin {
  late Future<DashboardData> _dashboardFuture;
  late Future<LeaderboardData> _leaderboardFuture;

  /// Gentle loop: logo glow, flickering flame, shimmer on the name.
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.dashboardService.getDashboard();
    _leaderboardFuture = widget.leaderboardService.getLeaderboard();
    _ambient = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  static String _firstName(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    final first = parts.isEmpty ? '' : parts.first;
    if (first.isEmpty) return 'Student';
    return first[0].toUpperCase() + first.substring(1).toLowerCase();
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
      _leaderboardFuture = widget.leaderboardService.getLeaderboard();
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
                    AnimatedBuilder(
                      animation: _ambient,
                      builder: (context, child) {
                        final pulse = 0.5 + 0.5 * math.sin(_ambient.value * 2 * math.pi);
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.15 + 0.30 * pulse),
                                blurRadius: 8 + 12 * pulse,
                                spreadRadius: 1.5 * pulse,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: KeepColors(child: Image.asset('assets/logo.png', width: 44, height: 44, fit: BoxFit.cover)),
                      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _ambient,
                            builder: (context, child) {
                              final a = _ambient.value * 2 * math.pi;
                              final flicker = 1 + 0.10 * math.sin(a * 5) + 0.06 * math.sin(a * 9);
                              return Transform.rotate(
                                angle: 0.10 * math.sin(a * 3),
                                child: Transform.scale(scale: flicker, alignment: Alignment.bottomCenter, child: child),
                              );
                            },
                            child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF59E0B), size: 15),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${data.streak.days}-day streak',
                            style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Open profile',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          AppHaptics.selection();
                          widget.onOpenProfile();
                        },
                        child: _UserAvatar(name: widget.user?.name, size: 40),
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        const Text(
                          'Welcome back, ',
                          style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF0F172A)),
                        ),
                        AnimatedBuilder(
                          animation: _ambient,
                          builder: (context, child) {
                            // A light band crosses the name during the first half of each loop.
                            final t = (_ambient.value / 0.5).clamp(0.0, 1.0).toDouble();
                            final x = -2.0 + 4.0 * t;
                            return ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (rect) => LinearGradient(
                                begin: Alignment(x - 0.6, 0),
                                end: Alignment(x + 0.6, 0),
                                colors: const [Color(0xFF16A34A), Color(0xFF86EFAC), Color(0xFF16A34A)],
                              ).createShader(rect),
                              child: child,
                            );
                          },
                          child: Text(
                            '${_firstName(widget.user?.name)}.',
                            style: const TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF16A34A)),
                          ),
                        ),
                      ],
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
                          child: FutureBuilder<LeaderboardData>(
                            future: _leaderboardFuture,
                            builder: (context, rankSnapshot) {
                              final myRank = rankSnapshot.data?.myRank;
                              return _MetricCard(
                                title: 'RANK',
                                value: myRank == null
                                    ? (rankSnapshot.connectionState == ConnectionState.waiting ? '…' : 'New')
                                    : '#$myRank',
                                unit: myRank == null ? 'unranked' : 'XP rank',
                                color: const Color(0xFF8B5CF6),
                                titleColor: const Color(0xFF6D28D9),
                                history: [0, (myRank ?? 0).toDouble()],
                              );
                            },
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
                  weekScore: data.performance.isEmpty
                      ? 0.0
                      : (data.performance.last.score != 0 ? data.performance.last.score : data.performance.last.accuracy),
                  lastSevenDays: data.streak.history.length > 7
                      ? data.streak.history.sublist(data.streak.history.length - 7)
                      : data.streak.history,
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

  /// Average score (0-100) for this week.
  final double weekScore;

  /// Activity flags for the last seven days (1 = active), as the website shows them.
  final List<int> lastSevenDays;

  const _WeeklyGoalCard({required this.completed, required this.weekScore, required this.lastSevenDays});

  @override
  State<_WeeklyGoalCard> createState() => _WeeklyGoalCardState();
}

class _WeeklyGoalCardState extends State<_WeeklyGoalCard> with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  int _targetGoal = 5;

  /// Breathing pulse for today's chip.
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _loadGoal();
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
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
    // Same numbers as the website's Weekly Goal card.
    final completed = math.min(widget.completed, _targetGoal);
    final progress = (completed / _targetGoal).clamp(0.0, 1.0).toDouble();
    final remaining = math.max(0, _targetGoal - completed);
    final todayIndex = DateTime.now().weekday - 1; // Monday = 0
    final daysLeft = 6 - todayIndex;
    final perDay = daysLeft > 0 ? (remaining / daysLeft).toStringAsFixed(1) : '—';
    final score = widget.weekScore.round();
    final scoreColor = score >= 70
        ? const Color(0xFF16A34A)
        : score >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFF43F5E);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: completed >= _targetGoal ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Ring
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
                    Text.rich(
                      TextSpan(
                        text: '$completed',
                        children: [
                          TextSpan(
                            text: '/$_targetGoal',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Color(0xFFCBD5E1)),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 3),
                    const Text('quizzes', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Message
          if (remaining > 0) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$remaining more',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const TextSpan(text: ' to hit your weekly goal.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 3),
            Text(
              '$daysLeft day${daysLeft == 1 ? '' : 's'} remaining · ~$perDay/day',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            ),
          ] else
            const Text(
              'Weekly goal complete!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
            ),
          const SizedBox(height: 12),

          // Change goal
          GestureDetector(
            onTap: _showChangeGoalDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
              ),
              child: const Text(
                'Change goal',
                style: TextStyle(color: Color(0xFF15803D), fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Week days
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(child: _dayChip(dayLetters[i], i, todayIndex)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${dayLetters[todayIndex]} — today',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // This week avg score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('This week avg score', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('$score%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: (score / 100).clamp(0.0, 1.0).toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                return LinearProgressIndicator(
                  value: t,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayChip(String letter, int index, int todayIndex) {
    final done = index < widget.lastSevenDays.length && widget.lastSevenDays[index] == 1;
    final isToday = index == todayIndex;
    final Color background = done
        ? const Color(0xFF16A34A)
        : isToday
            ? const Color(0xFF16A34A).withValues(alpha: 0.10)
            : const Color(0xFFF8FAFC);
    final Color foreground = done
        ? Colors.white
        : isToday
            ? const Color(0xFF15803D)
            : index < todayIndex
                ? const Color(0xFFCBD5E1)
                : const Color(0xFF94A3B8);
    final chip = Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isToday && !done ? const Color(0xFF16A34A).withValues(alpha: 0.45) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(letter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: foreground)),
    );
    if (!isToday) return chip;
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_breath.value);
        return Transform.scale(
          scale: 1 + 0.07 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.30 * t), blurRadius: 10 * t, spreadRadius: 1.5 * t),
              ],
            ),
            child: child,
          ),
        );
      },
      child: chip,
    );
  }
}

/// Fades and lifts its child in once, after an optional delay.
class _FadeUp extends StatelessWidget {
  final int delayMs;
  final Widget child;

  const _FadeUp({super.key, required this.delayMs, required this.child});

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

  static const _valueStyle = TextStyle(fontSize: 28, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF0F172A));

  /// The number counts up from zero when the card appears ("#167", "13", "0.5").
  Widget _animatedValue() {
    final match = RegExp(r'^(\D*)(\d+(?:\.\d+)?)$').firstMatch(value);
    if (match == null) {
      return Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _valueStyle);
    }
    final prefix = match.group(1) ?? '';
    final digits = match.group(2)!;
    final decimals = digits.contains('.') ? digits.split('.').last.length : 0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: double.parse(digits)),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '$prefix${v.toStringAsFixed(decimals)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _valueStyle,
      ),
    );
  }

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
                    Flexible(child: _animatedValue()),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 54,
                      height: 26,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeInOutCubic,
                        builder: (context, t, _) =>
                            CustomPaint(painter: _TrendPainter(values: history, color: color, progress: t, dense: true)),
                      ),
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
// TAB 2: MY PAPERS (papers you bought or attempted, as on the website)
// -----------------------------------------------------------------------------
class _MyPapersTab extends StatefulWidget {
  final StorefrontService storefrontService;
  final CourseService courseService;
  final UserModel? user;
  final VoidCallback onBrowsePractice;

  /// True while this tab is on screen; the list reloads each time it is opened.
  final bool isActive;

  const _MyPapersTab({
    required this.storefrontService,
    required this.courseService,
    required this.onBrowsePractice,
    required this.isActive,
    this.user,
  });

  @override
  State<_MyPapersTab> createState() => _MyPapersTabState();
}

class _MyPapersTabState extends State<_MyPapersTab> {
  static const _sectionLabels = {
    'quiz1': 'Quiz 1',
    'quiz2': 'Quiz 2',
    'endterm': 'End Term',
    'mock_test': 'Mock test',
    'practice': 'Practice',
    'practice_graded': 'Graded practice',
  };

  bool _loading = true;
  String? _error;
  List<MyPaperItem> _papers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MyPapersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final papers = await widget.storefrontService.getMyPapers();
      if (!mounted) return;
      setState(() {
        _papers = papers;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (quiet && _papers.isNotEmpty) return; // keep what is on screen
      setState(() {
        _error = e is ApiException && e.statusCode == 403
            ? 'My Papers is for student accounts. Managers handle papers and sales from the manager console.'
            : 'Your papers could not load. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  static String _num(double value) => value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

  Future<void> _openPaper(MyPaperItem paper) async {
    AppHaptics.light();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaperRoomScreen(
          quizId: paper.id,
          title: paper.title,
          apiClient: widget.courseService.client,
          user: widget.user,
        ),
      ),
    );
    if (mounted) _load(quiet: true);
  }

  void _openCatalogue() {
    AppHaptics.light();
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                title: const Text('All papers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                surfaceTintColor: Colors.white,
                elevation: 0,
              ),
              body: SafeArea(
                child: _QuizzesTab(
                  courseService: widget.courseService,
                  storefrontService: widget.storefrontService,
                  user: widget.user,
                ),
              ),
            ),
          ),
        )
        .then((_) {
      if (mounted) _load(quiet: true);
    });
  }

  void _showDetails(MyPaperItem paper, String state, String progressText) {
    AppHaptics.selection();
    final attempts = paper.attemptCount;
    final total = paper.lastTotalMarks ?? 0;
    final score = paper.lastScore ?? 0;
    final hasScore = attempts > 0 && total > 0 && !paper.inProgress;
    final fraction = hasScore ? (score / total).clamp(0.0, 1.0).toDouble() : 0.0;
    final percent = (fraction * 100).round();
    final Color scoreColor = percent >= 70
        ? const Color(0xFF16A34A)
        : percent >= 40
            ? const Color(0xFFF59E0B)
            : const Color(0xFFF43F5E);
    final timed = (paper.timeLimitMinutes ?? 0) > 0;
    final actionLabel = paper.inProgress ? 'Continue' : (attempts > 0 ? 'Attempt again' : 'Start');
    final sub = [paper.course?.name, paper.year?.toString(), _sectionLabels[paper.section]]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    Widget tile(IconData icon, String value, String label, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 1),
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),

                // Header: icon, title, course line, access tag
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                        ),
                      ),
                      child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paper.title,
                            style: const TextStyle(fontSize: 17, height: 1.25, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(sub, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                      child: Text(state, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick facts
                Row(
                  children: [
                    tile(Icons.quiz_outlined, '${paper.questionCount}', 'Questions', const Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    tile(Icons.timer_outlined, timed ? '${paper.timeLimitMinutes} min' : 'Untimed', 'Time', const Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    tile(Icons.replay_rounded, '$attempts', attempts == 1 ? 'Attempt' : 'Attempts', const Color(0xFFD97706)),
                  ],
                ),
                const SizedBox(height: 14),

                // Last score
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: hasScore
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'LAST SCORE',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    text: _num(score),
                                    children: [
                                      TextSpan(
                                        text: ' / ${_num(total)}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(fontSize: 22, height: 1.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scoreColor)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: fraction),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, _) => LinearProgressIndicator(
                                  value: t,
                                  minHeight: 7,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(
                              paper.inProgress ? Icons.hourglass_top_rounded : Icons.flag_outlined,
                              size: 20,
                              color: paper.inProgress ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                paper.inProgress
                                    ? 'You have an attempt in progress. Pick up where you left off.'
                                    : 'Not started yet. Your score will show here after your first attempt.',
                                style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                ),

                // About
                if ((paper.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'ABOUT THIS PAPER',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 5),
                  Text(paper.description!.trim(), style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF475569))),
                ],
                const SizedBox(height: 18),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: _button('Close', filled: false, onTap: () => Navigator.of(ctx).pop()),
                    ),
                    if (paper.available && paper.hasAccess) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _button(
                          actionLabel,
                          filled: true,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _openPaper(paper);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
    );
  }

  Widget _button(String text, {required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF16A34A) : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: filled ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
          boxShadow: filled
              ? [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 5))]
              : const [],
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: filled ? Colors.white : const Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _card(MyPaperItem paper) {
    // Same rules as the website's My Papers cards.
    final paid = paper.pricePaise > 0;
    final purchased = paper.purchased || paper.source == 'purchase';
    final usable = paper.available && paper.hasAccess;
    final attempts = paper.attemptCount;
    final state = !paper.available
        ? 'Unavailable'
        : purchased
            ? 'Purchased ✓'
            : paid
                ? 'Paid'
                : 'Free';
    final total = paper.lastTotalMarks ?? 0;
    final score = paper.lastScore ?? 0;
    final progressText = paper.inProgress
        ? 'In progress'
        : attempts > 0
            ? '${paper.lastTotalMarks != null ? 'Last score ${_num(score)}/${_num(total)} · ' : ''}$attempts attempt${attempts == 1 ? '' : 's'}'
            : 'Not started';
    final showBar = attempts > 0 && total > 0 && !paper.inProgress;
    final pct = showBar ? (score / total).clamp(0.0, 1.0).toDouble() : 0.0;
    final sub = [paper.course?.name, paper.year?.toString(), _sectionLabels[paper.section]]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    final Color tagBg = !paper.available
        ? const Color(0xFFF1F5F9)
        : purchased
            ? const Color(0xFFDCFCE7)
            : paid
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFECFDF5);
    final Color tagFg = !paper.available
        ? const Color(0xFF64748B)
        : purchased
            ? const Color(0xFF15803D)
            : paid
                ? const Color(0xFFB45309)
                : const Color(0xFF15803D);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.45, 1.0],
          colors: [Colors.white, Color(0xFFF0F9F2)],
        ),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF166534).withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF86EFAC), Color(0x0086EFAC)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: title, course and score. Right: Free tag, time and question count stacked.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paper.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            progressText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: paper.inProgress
                                  ? const Color(0xFFB45309)
                                  : attempts > 0
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
                          child: Text(state, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tagFg)),
                        ),
                        const SizedBox(height: 6),
                        _chip((paper.timeLimitMinutes ?? 0) > 0 ? '${paper.timeLimitMinutes} min' : 'Untimed'),
                        const SizedBox(height: 6),
                        _chip('${paper.questionCount} questions'),
                      ],
                    ),
                  ],
                ),
                if (showBar) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE2E8E4),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                    ),
                  ),
                ],
                if (paper.available) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (usable) ...[
                        Expanded(
                          child: _button('View details', filled: false, onTap: () => _showDetails(paper, state, progressText)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: usable
                            ? _button(
                                paper.inProgress ? 'Continue' : (attempts > 0 ? 'Attempt again' : 'Start'),
                                filled: true,
                                onTap: () => _openPaper(paper),
                              )
                            : _button('Buy paper', filled: false, onTap: _openCatalogue),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _papers.isEmpty) {
      return AppShimmerCard.list(count: 4);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF16A34A),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your papers.',
                  style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF0F172A)),
                ),
              ),
              GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  widget.onBrowsePractice();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('Browse practice', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Papers you bought or attempted, with your progress.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          if (_error != null && _papers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('Try again', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold))),
                ],
              ),
            )
          else if (_papers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40, horizontal: 12),
              child: Text(
                'Nothing here yet. Start any free paper from Practice, or buy a paper, and it shows up here with your score.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
              ),
            )
          else
            for (final paper in _papers)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(paper)),

          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _openCatalogue,
              child: const Text('Browse all papers', style: TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ALL PAPERS (catalogue, opened from My Papers): PAPERS & STOREFRONT (Past Papers, Pricing & Claims)
// -----------------------------------------------------------------------------
class _QuizzesTab extends StatefulWidget {
  final CourseService courseService;
  final StorefrontService storefrontService;
  final UserModel? user;

  const _QuizzesTab({
    required this.courseService,
    required this.storefrontService,
    this.user,
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
                        builder: (_) => PaperRoomScreen(
                          quizId: paper.id,
                          title: paper.title,
                          apiClient: widget.courseService.client,
                          user: widget.user,
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

  Future<void> _refresh() async {
    AppHaptics.light();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Appearance: three cards with a small preview each. Picking one applies it at once.
  void _showThemeSelector() {
    AppHaptics.selection();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (ctx, mode, _) {
          Widget option(ThemeMode value, String label, String hint, IconData icon, List<Color> preview) {
            final selected = mode == value;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  setAppThemeMode(value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFF0FDF4) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0), width: selected ? 2 : 1),
                  ),
                  child: Column(
                    children: [
                      // Tiny screen preview; keeps its real colours in dark mode.
                      KeepColors(
                        child: Container(
                          height: 62,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, stops: const [0.5, 0.5], colors: preview),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                            child: Icon(icon, size: 17, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 20,
                        color: selected ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  const Text('Choose how Quiz Lab looks on this phone.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      option(ThemeMode.system, 'System', 'Follows your phone', Icons.phone_android_rounded, const [Color(0xFFF8FAFC), Color(0xFF0E131E)]),
                      const SizedBox(width: 8),
                      option(ThemeMode.light, 'Light', 'Bright and clear', Icons.light_mode_rounded, const [Color(0xFFF8FAFC), Color(0xFFF8FAFC)]),
                      const SizedBox(width: 8),
                      option(ThemeMode.dark, 'Dark', 'Easy at night', Icons.dark_mode_rounded, const [Color(0xFF0E131E), Color(0xFF0E131E)]),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Edit profile: change the display name and pick one of the ready-made avatars.
  void _showEditProfile() {
    AppHaptics.light();
    final user = widget.user;
    final nameController = TextEditingController(text: user?.name ?? '');
    int? picked = _avatarChoice.value;
    var saving = false;
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> save() async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              setSheet(() => error = 'Name cannot be empty.');
              return;
            }
            setSheet(() {
              saving = true;
              error = null;
            });
            String? problem;
            if (name != (user?.name ?? '')) {
              problem = await widget.authState.updateName(name);
            }
            await _saveAvatarChoice(user?.id, picked);
            if (!ctx.mounted) return;
            if (problem != null) {
              setSheet(() {
                saving = false;
                error = problem;
              });
              return;
            }
            Navigator.of(ctx).pop();
          }

          Widget option(int? index) {
            final selected = picked == index;
            return GestureDetector(
              onTap: () {
                AppHaptics.selection();
                setSheet(() => picked = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? const Color(0xFF16A34A) : Colors.transparent, width: 2.5),
                ),
                child: AnimatedScale(
                  scale: selected ? 1.0 : 0.92,
                  duration: const Duration(milliseconds: 160),
                  child: _avatarCircle(name: nameController.text, size: 52, preset: index, usePreset: index != null),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Edit profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 16),

                    // Live preview
                    Center(child: _avatarCircle(name: nameController.text, size: 84, preset: picked, usePreset: picked != null)),
                    const SizedBox(height: 18),

                    const Text(
                      'CHOOSE AN AVATAR',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      children: [
                        option(null), // initials
                        for (var i = 0; i < _avatarPresets.length; i++) option(i),
                      ],
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'YOUR NAME',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 120,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Your name',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2)),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: saving ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : const Text('Save changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openDiscussions() {
    AppHaptics.light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DiscussionsScreen(discussionService: widget.discussionService)),
    );
  }

  /// Opens a page of the website inside the app, signed in with this session.
  void _openInApp(String path, String title) {
    AppHaptics.light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebPageScreen(
          path: path,
          title: title,
          apiClient: widget.discussionService.client,
          user: widget.user,
        ),
      ),
    );
  }

  Widget _exploreTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Material(type: MaterialType.transparency, child: ListTile(
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
    ));
  }

  void _openFaqs() {
    AppHaptics.light();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FaqScreen()));
  }

  void _showHelpSupportDialog() {
    showHelpSheet(context, onOpenFaq: _openFaqs);
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
              if (title == 'Refund & Cancellation') ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => callSupport(ctx),
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Call support'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => emailSupport(ctx),
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Email support'),
                    )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    AppHaptics.heavy();
    String? selectedReason;
    bool sending = false;
    final detailsController = TextEditingController();
    showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 8),
              Flexible(child: Text('Request Account Deletion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a reason and send your request. Our manager will review it before your account and its data are deleted.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text('Name: ${widget.user?.name ?? '—'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Email: ${widget.user?.email ?? '—'}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedReason),
                    initialValue: selectedReason,
                    decoration: const InputDecoration(labelText: 'Reason for leaving', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'no_longer_needed', child: Text('I no longer need the account')),
                      DropdownMenuItem(value: 'privacy_concerns', child: Text('Privacy concerns')),
                      DropdownMenuItem(value: 'another_account', child: Text('I am using another account')),
                      DropdownMenuItem(value: 'app_issue', child: Text('I had an issue with the app')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: sending ? null : (value) => setDialogState(() => selectedReason = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    enabled: !sending,
                    maxLength: 1200,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Anything else you want us to know (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Text(
                    'Your name, email, account ID, reason, and any note above will be emailed to admin@genziitian.org and shown in the web manager dashboard.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: sending || selectedReason == null
                  ? null
                  : () async {
                      AppHaptics.heavy();
                      setDialogState(() => sending = true);
                      final submitted = await widget.authState.requestAccountDeletion(
                        reason: selectedReason!,
                        details: detailsController.text,
                      );
                      if (!ctx.mounted) return;
                      if (submitted) {
                        Navigator.pop(ctx, true);
                      } else {
                        setDialogState(() => sending = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not send your request. Please try again.'), backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(sending ? 'Sending…' : 'Send Deletion Request'),
            ),
          ],
        ),
      ),
    ).then((submitted) {
      detailsController.dispose();
      if (submitted != true || !mounted) return;
      showDialog<void>(
        context: context,
        builder: (doneContext) => AlertDialog(
          title: const Text('Request sent'),
          content: const Text('Your deletion request was sent to our manager for review. Your account is still active until the request is processed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(doneContext), child: const Text('Done')),
          ],
        ),
      );
    });
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
          // Profile Summary (tap to edit name and avatar)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showEditProfile,
            child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _UserAvatar(name: user?.name, size: 56),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 11, color: Colors.white),
                      ),
                    ),
                  ],
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
                const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),

          // Level, badges and stats (as on the website's profile page)
          ProgressSection(apiClient: widget.discussionService.client),
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
                  icon: Icons.forum_outlined,
                  color: const Color(0xFF0284C7),
                  title: 'Discussions',
                  subtitle: 'Doubts, answers and peer questions',
                  onTap: _openDiscussions,
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _exploreTile(
                  icon: Icons.play_circle_outline_rounded,
                  color: const Color(0xFF7C3AED),
                  title: 'Video Solutions',
                  badge: 'PRO',
                  subtitle: 'Step-by-step video answers',
                  onTap: () => _openInApp('/video-solutions', 'Video Solutions'),
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
                Material(type: MaterialType.transparency, child: ListTile(
                  leading: const Icon(Icons.palette_outlined, color: Color(0xFF64748B), size: 20),
                  title: const Text('Theme / Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: appThemeMode,
                        builder: (context, mode, _) => Text(
                          _themeLabel(mode),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  onTap: _showThemeSelector,
                )),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Material(type: MaterialType.transparency, child: ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF0284C7), size: 20),
                  title: const Text('Help & Support Desk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: _showHelpSupportDialog,
                )),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Material(type: MaterialType.transparency, child: ListTile(
                  leading: const Icon(Icons.quiz_outlined, color: Color(0xFF7C3AED), size: 20),
                  title: const Text('FAQs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Quick answers to common questions', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: _openFaqs,
                )),
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
                Material(type: MaterialType.transparency, child: ListTile(
                  leading: const Icon(Icons.description_outlined, color: Color(0xFF64748B), size: 20),
                  title: const Text('Terms & Conditions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () => _showLegalSheet('Terms & Conditions', LegalDocuments.terms),
                )),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Material(type: MaterialType.transparency, child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF64748B), size: 20),
                  title: const Text('Refund & Cancellation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () => _showLegalSheet('Refund & Cancellation', LegalDocuments.refunds),
                )),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Material(type: MaterialType.transparency, child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF64748B), size: 20),
                  title: const Text('Privacy Policy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () => _showLegalSheet('Privacy Policy', LegalDocuments.privacy),
                )),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Material(type: MaterialType.transparency, child: ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20),
                  title: const Text('Delete Account & Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFFCA5A5)),
                  onTap: _showDeleteAccountDialog,
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Logout
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                AppHaptics.medium();
                confirmSignOut(context, widget.authState);
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
