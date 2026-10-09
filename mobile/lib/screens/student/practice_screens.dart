import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../api/api.dart';
import '../../api/offline_paper_store.dart';
import '../../state/theme_state.dart';
import '../../widgets/app_ux_components.dart';
import 'native_paper_room.dart' as native;

const _green = Color(0xFF16A34A);
const _ink = Color(0xFF0F172A);
const _webOrigin = 'https://quiz.genziitian.in';

// -----------------------------------------------------------------------------
// PRACTICE TAB: enrolled courses, as on the website's Practice page
// -----------------------------------------------------------------------------
class PracticeTab extends StatefulWidget {
  final CourseService courseService;
  final UserModel? user;

  const PracticeTab({super.key, required this.courseService, this.user});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  bool _loading = true;
  String? _error;
  List<CourseModel> _courses = [];
  Map<String, double> _completion = {}; // course slug -> percent
  bool _activeOnly = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Search box hint that types course names letter by letter, like the website.
  Timer? _typeTimer;
  int _typeWord = 0;
  int _typeChars = 0;
  int _typeHold = 0; // ticks to wait before the next move
  bool _typeDeleting = false;
  bool _cursorOn = true;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _typeTimer = Timer.periodic(
      const Duration(milliseconds: 90),
      (_) => _typeStep(),
    );
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _typeWords {
    final names = _courses
        .map((c) => c.name)
        .where((n) => n.isNotEmpty)
        .toList();
    return names.isEmpty
        ? const ['Mathematics', 'Statistics', 'Python']
        : names;
  }

  void _typeStep() {
    if (!mounted || _query.isNotEmpty)
      return; // the hint is hidden while the user types
    final words = _typeWords;
    final word = words[_typeWord % words.length];
    _tick++;
    final cursor = (_tick ~/ 5).isEven;
    var changed = cursor != _cursorOn;
    _cursorOn = cursor;

    if (_typeHold > 0) {
      _typeHold--;
    } else if (!_typeDeleting) {
      if (_typeChars < word.length) {
        _typeChars++;
        changed = true;
        if (_typeChars == word.length) _typeHold = 14; // pause on the full word
      } else {
        _typeDeleting = true;
      }
    } else {
      if (_typeChars > 0) {
        _typeChars -= 1;
        changed = true;
      } else {
        _typeDeleting = false;
        _typeWord = (_typeWord + 1) % words.length;
        _typeHold = 4;
      }
    }
    if (changed) setState(() {});
  }

  String get _typedHint {
    final words = _typeWords;
    final word = words[_typeWord % words.length];
    final shown = word.substring(0, _typeChars.clamp(0, word.length).toInt());
    return 'Search “$shown${_cursorOn ? '|' : ' '}”';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await widget.courseService.getCourses();
      final completion = <String, double>{};
      try {
        final res = await widget.courseService.client.get<Map<String, dynamic>>(
          '/student/progress',
        );
        final rows = res.data?['course_progress'];
        if (rows is List) {
          for (final row in rows) {
            if (row is Map && row['course_slug'] != null) {
              completion[row['course_slug'].toString()] =
                  (row['completion_percent'] as num?)?.toDouble() ?? 0;
            }
          }
        }
      } catch (_) {
        // Progress is a nice-to-have: the course list still shows without it.
      }
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _completion = completion;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load your courses.';
        _loading = false;
      });
    }
  }

  double _percentOf(CourseModel course) => _completion[course.slug] ?? 0;

  void _open(CourseModel course) {
    AppHaptics.light();
    _searchController.clear();
    _query = '';
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => CoursePapersScreen(
              course: course,
              courseService: widget.courseService,
              user: widget.user,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
          _load();
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _courses.isEmpty) {
      return AppShimmerCard.list(count: 3);
    }
    if (_error != null && _courses.isEmpty) {
      return AppErrorCard(
        title: 'Unable to Load Practice',
        message: _error!,
        onRetry: _load,
      );
    }

    final query = _query.trim().toLowerCase();
    final shown = _courses.where((c) {
      final pct = _percentOf(c);
      if (_activeOnly && !(pct > 0 && pct < 100)) return false;
      if (query.isNotEmpty && !c.name.toLowerCase().contains(query))
        return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: _green,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        children: [
          // Small label, then the headline with the last words in green.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, size: 14, color: _green),
              ),
              const SizedBox(width: 7),
              const Text(
                'PRACTICE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text.rich(
            TextSpan(
              text: 'Brush up at ',
              children: [
                TextSpan(
                  text: 'your own pace.',
                  style: TextStyle(color: _green),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick a course and practise any paper, any time.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Search
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBE5C8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _typedHint,
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: _green),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Count + filter
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${shown.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      TextSpan(
                        text:
                            ' ${_activeOnly ? 'active' : 'enrolled'} course${shown.length == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _activeOnly = !_activeOnly);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _activeOnly
                        ? _green.withValues(alpha: 0.10)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _activeOnly ? _green : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    'Active only',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _activeOnly ? _green : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  _courses.isEmpty
                      ? 'Your enrolled courses will appear here once they are published.'
                      : 'No courses match.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            for (final course in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CourseCard(
                  course: course,
                  percent: _percentOf(course),
                  onTap: () => _open(course),
                ),
              ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final double percent;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.percent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = percent.round().clamp(0, 100);
    final status = pct == 0
        ? 'Not started'
        : (pct >= 100 ? 'Completed' : 'In progress');
    final sections =
        '${course.hasIde ? 'PA · GA · IDE' : 'PA · GA'} · Quiz 1 · Quiz 2 · End Term · Mock';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.35, 1.0],
            colors: [Colors.white, Color(0xFFECF7EF)],
          ),
          border: Border.all(color: _green.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF166534).withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF3E3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: Color(0xFF15803D),
                    size: 22,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: '$pct',
                        children: const [
                          TextSpan(
                            text: '%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'COMPLETE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.6,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              course.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sections,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFDBE7DF),
                valueColor: const AlwaysStoppedAnimation<Color>(_green),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                _GoPill(
                  label: pct == 0
                      ? 'Start'
                      : (pct >= 100 ? 'Review' : 'Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Green pill with an arrow that nudges forward every couple of seconds.
class _GoPill extends StatefulWidget {
  final String label;

  const _GoPill({required this.label});

  @override
  State<_GoPill> createState() => _GoPillState();
}

class _GoPillState extends State<_GoPill> with SingleTickerProviderStateMixin {
  late final AnimationController _nudge;

  @override
  void initState() {
    super.initState();
    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF15803D)],
        ),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: AnimatedBuilder(
              animation: _nudge,
              builder: (context, child) {
                // Two quick nudges at the start of each loop, then still.
                final t = (_nudge.value / 0.35).clamp(0.0, 1.0).toDouble();
                final dx = 3.0 * math.sin(t * 2 * math.pi).abs();
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COURSE PAGE: paper types as chips, compact paper rows, To do / Done filter
// -----------------------------------------------------------------------------
class CoursePapersScreen extends StatefulWidget {
  final CourseModel course;
  final CourseService courseService;
  final UserModel? user;

  const CoursePapersScreen({
    super.key,
    required this.course,
    required this.courseService,
    this.user,
  });

  @override
  State<CoursePapersScreen> createState() => _CoursePapersScreenState();
}

class _CoursePapersScreenState extends State<CoursePapersScreen> {
  static const _typeNames = [
    'Practice Assignment',
    'Graded Assignment',
    'Quiz 1',
    'Quiz 2',
    'End Term',
    'Mock Test',
  ];
  static const _typeShort = [
    'Practice',
    'Graded',
    'Quiz 1',
    'Quiz 2',
    'End Term',
    'Mock',
  ];
  static const _filters = ['All', 'To do', 'Done'];

  bool _loading = true;
  String? _error;
  List<List<CourseQuizListItem>> _lists = List.generate(
    6,
    (_) => <CourseQuizListItem>[],
  );
  final ScrollController _scrollController = ScrollController();
  int _type = 0; // index into _typeNames
  int _filter = 0; // index into _filters

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final slug = widget.course.slug;
      final practiceFuture = widget.courseService.getPractice(slug);
      final examFuture = widget.courseService.getExamPrep(slug);
      final practice = await practiceFuture;
      final exam = await examFuture;
      if (!mounted) return;
      final lists = [
        practice.practice,
        practice.graded,
        exam.quiz1,
        exam.quiz2,
        exam.endterm,
        exam.mockTest,
      ];
      setState(() {
        _lists = lists;
        _loading = false;
        _error = null;
        // Land on the first type that has papers.
        if (lists[_type].isEmpty) {
          final firstWithPapers = lists.indexWhere((l) => l.isNotEmpty);
          if (firstWithPapers >= 0) _type = firstWithPapers;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (quiet) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Could not load the papers for this course.';
        _loading = false;
      });
    }
  }

  Future<void> _openPaper(CourseQuizListItem paper) async {
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
    if (mounted) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _load(quiet: true); // attempt counts may have changed
    }
  }

  Future<void> _downloadPaper(CourseQuizListItem paper) async {
    final userId = widget.user?.id;
    if (userId == null) return;
    try {
      final quiz = await QuizService(
        client: widget.courseService.client,
      ).downloadQuiz(paper.id);
      await OfflinePaperStore.cacheQuiz(userId, quiz);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paper saved on this device for offline practice.'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Could not download this paper.',
            ),
          ),
        );
    }
  }

  static int _doneIn(List<CourseQuizListItem> list) =>
      list.where((p) => p.userHasAttempted).length;

  // ---- Header: course name and overall progress -----------------------------

  Widget _header() {
    final all = _lists.expand((l) => l).toList();
    final done = _doneIn(all);
    final total = all.length;
    final fraction = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14532D), Color(0xFF16A34A)],
        ),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.course.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0 ? 'No papers yet' : '$done of $total papers done',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFD1FAE5),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: fraction),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => LinearProgressIndicator(
                      value: t,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFBBF7D0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${(fraction * 100).round()}%',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Paper type chips (only the types that have papers) -------------------

  Widget _typeChips() {
    final chips = <Widget>[];
    for (var i = 0; i < _typeNames.length; i++) {
      final list = _lists[i];
      if (list.isEmpty) continue;
      final selected = i == _type;
      chips.add(
        GestureDetector(
          onTap: () {
            AppHaptics.selection();
            setState(() => _type = i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _green : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _green : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _typeShort[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_doneIn(list)}/${list.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  Widget _filterBar(int shownCount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_typeNames[_type]} · $shownCount paper${shownCount == 1 ? '' : 's'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _filters.length; i++)
                GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _filter = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _filter == i ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _filter == i
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _filter == i ? _ink : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- One compact row per paper --------------------------------------------

  Widget _paperRow(CourseQuizListItem paper) {
    final done = paper.userHasAttempted;
    final meta = <String>[
      if (paper.weekNumber != null) 'Week ${paper.weekNumber}',
      '${paper.questionCount} Q',
      paper.timeLimitMinutes > 0 ? '${paper.timeLimitMinutes} min' : 'Untimed',
      if (done)
        paper.attemptCount > 1 ? '${paper.attemptCount} attempts' : '1 attempt',
    ].join(' · ');

    return GestureDetector(
      onTap: () => _openPaper(paper),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: done ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Download for offline practice',
              visualDensity: VisualDensity.compact,
              onPressed: () => _downloadPaper(paper),
              icon: const Icon(
                Icons.download_for_offline_outlined,
                color: _green,
                size: 21,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: done ? Colors.white : _green,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _green, width: 1.2),
              ),
              child: Text(
                done ? 'Retake' : 'Start',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: done ? _green : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = _lists.any((l) => l.isNotEmpty);
    final current = _lists[_type];
    final shown = current.where((p) {
      if (_filter == 1) return !p.userHasAttempted;
      if (_filter == 2) return p.userHasAttempted;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F5F9),
        surfaceTintColor: const Color(0xFFF1F5F9),
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'All practice courses',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ),
      body: _loading
          ? AppShimmerCard.list(count: 4)
          : _error != null
          ? AppErrorCard(
              title: 'Unable to Load Papers',
              message: _error!,
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: () => _load(quiet: true),
              color: _green,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _header(),
                  const SizedBox(height: 14),
                  if (!hasAny)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'No papers in this course yet.',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    _typeChips(),
                    const SizedBox(height: 12),
                    _filterBar(shown.length),
                    const SizedBox(height: 10),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            _filter == 1
                                ? 'All done here. Nice work.'
                                : 'Nothing attempted here yet.',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final paper in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _paperRow(paper),
                        ),
                  ],
                ],
              ),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// PAPER ROOM: the website's real paper player, signed in with this app's session
// -----------------------------------------------------------------------------
class PaperRoomScreen extends StatelessWidget {
  final int quizId;
  final String title;
  final ApiClient apiClient;
  final UserModel? user;

  const PaperRoomScreen({
    super.key,
    required this.quizId,
    required this.title,
    required this.apiClient,
    this.user,
  });

  @override
  Widget build(BuildContext context) => native.PaperRoomScreen(
    quizId: quizId,
    title: title,
    apiClient: apiClient,
    user: user,
  );
}

// -----------------------------------------------------------------------------
// WEB PAGE: any page of the website shown inside the app, signed in with this
// app's session (used for Video Solutions). The site's own top bar and bottom
// bar are hidden, because the app provides the title bar and navigation.
// -----------------------------------------------------------------------------
class WebPageScreen extends StatefulWidget {
  final String path;
  final String title;
  final ApiClient apiClient;
  final UserModel? user;

  const WebPageScreen({
    super.key,
    required this.path,
    required this.title,
    required this.apiClient,
    this.user,
  });

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  static const String _chromeCss = '''
header.lg\\:hidden{display:none!important}
div.fixed.inset-x-0.bottom-0.z-40.lg\\:hidden{display:none!important}
''';

  late final WebViewController _web;
  bool _signedIn = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (_signedIn) _hideSiteBars();
          },
          onPageFinished: _onPageFinished,
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(
                () => _error =
                    'Could not open this page. Check your connection and try again.',
              );
            }
          },
        ),
      );
    _start();
  }

  void _start() {
    setState(() {
      _signedIn = false;
      _ready = false;
      _error = null;
    });
    _web.loadRequest(Uri.parse('$_webOrigin/terms-and-conditions'));
  }

  Future<void> _hideSiteBars() async {
    try {
      await _web.runJavaScript(
        '(function f(){var d=document;if(!d.head){setTimeout(f,30);return;}'
        'if(d.getElementById("ql-app-bars"))return;'
        'var s=d.createElement("style");s.id="ql-app-bars";s.textContent=${jsonEncode(_chromeCss)};d.head.appendChild(s);})();',
      );
    } catch (_) {
      // Cosmetic only.
    }
  }

  Future<void> _onPageFinished(String url) async {
    if (!mounted) return;
    if (_signedIn) {
      await _hideSiteBars();
      if (mounted) setState(() => _ready = true);
      return;
    }
    final token = await widget.apiClient.getAuthToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Your session has ended. Please sign in again.');
      return;
    }
    final user = widget.user;
    final userJson = jsonEncode({
      'id': user?.id,
      'name': user?.name,
      'email': user?.email,
      'role': user?.role,
      'is_admin': user?.isAdmin ?? false,
      'avatar': user?.avatar,
    });
    try {
      await _web.runJavaScript(
        'try{localStorage.setItem("lab_token",${jsonEncode(token)});'
        'localStorage.setItem("lab_user",${jsonEncode(userJson)});'
        'localStorage.setItem("ql_theme",${jsonEncode(isAppDark(context) ? 'dark' : 'light')});}catch(e){}',
      );
    } catch (_) {
      // The page shows its own sign-in if storage is unavailable.
    }
    if (!mounted) return;
    _signedIn = true;
    await _web.loadRequest(Uri.parse('$_webOrigin${widget.path}'));
  }

  Future<void> _onBack() async {
    // Step back inside the page first (for example out of a video), then leave.
    try {
      if (_ready && await _web.canGoBack()) {
        final url = await _web.currentUrl();
        if (url != null && Uri.tryParse(url)?.path != widget.path) {
          await _web.goBack();
          return;
        }
      }
    } catch (_) {
      // Fall through to leaving the screen.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _onBack,
          ),
          titleSpacing: 0,
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: _error != null
              ? AppErrorCard(
                  title: 'Unable to Open Page',
                  message: _error!,
                  onRetry: _start,
                )
              : Stack(
                  children: [
                    KeepColors(child: WebViewWidget(controller: _web)),
                    if (!_ready)
                      const ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(_green),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
