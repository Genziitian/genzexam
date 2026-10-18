import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../api/spin_practice_service.dart';
import 'native_paper_room.dart';

class SpinPracticeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final UserModel? user;
  final VoidCallback onOpenMyPapers;

  const SpinPracticeScreen({
    super.key,
    required this.apiClient,
    this.user,
    required this.onOpenMyPapers,
  });

  @override
  State<SpinPracticeScreen> createState() => _SpinPracticeScreenState();
}

class _SpinPracticeScreenState extends State<SpinPracticeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _title = TextEditingController();
  final _scroll = ScrollController();
  List<CourseModel> _courses = [];
  int? _courseId;
  RangeValues _weeks = const RangeValues(1, 12);
  final Set<String> _types = {'all'};
  int _minutes = 20;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  String? _error;
  GeneratedPracticePaper? _paper;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _rotation.dispose();
    _title.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final courses = await CourseService(client: widget.apiClient)
          .getCourses();
      if (!mounted) return;
      setState(() => _courses = courses);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _loadError = error is ApiException
            ? error.message
            : 'Could not load courses. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _spin() async {
    if (_busy) return;
    if (_courseId == null) {
      setState(() => _error = 'Choose a course first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _paper = null;
    });
    if (!MediaQuery.disableAnimationsOf(context)) _rotation.repeat();
    try {
      final paper = await SpinPracticeService(client: widget.apiClient)
          .generate(
            courseId: _courseId!,
            weekMin: _weeks.start.round(),
            weekMax: _weeks.end.round(),
            paperTypes: _types.toList(),
            timeLimitMinutes: _minutes,
            title: _title.text,
          );
      if (!mounted) return;
      setState(() => _paper = paper);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is ApiException
            ? error.statusCode == 404
                  ? 'Practice generation is not available right now. Please try again later.'
                  : error.statusCode == null
                  ? '${error.message}\nCheck My Papers before trying again.'
                  : error.message
            : 'Could not create your paper. Please try again.',
      );
    } finally {
      if (mounted) {
        _rotation.stop();
        setState(() => _busy = false);
      }
    }
  }

  void _setType(String type, bool selected) {
    setState(() {
      if (type == 'all') {
        _types.clear();
        _types.add('all');
      } else {
        _types.remove('all');
        selected ? _types.add(type) : _types.remove(type);
        if (_types.isEmpty) _types.add('all');
      }
    });
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Try your practice')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null || _courses.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadError ?? 'No courses are available yet.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadCourses,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const Text(
                    'Spin a fresh paper.',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Up to 10 random questions from your selected papers.',
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox(
                      height: 228,
                      width: 228,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _rotation,
                            child: const CustomPaint(
                              size: Size.square(220),
                              painter: _PracticeWheelPainter(),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bolt_rounded,
                              size: 32,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: const Text(
                        'Creating your practice paper…',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (_paper case final paper?) ...[
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              paper.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${paper.questionCount} questions · ${paper.timeLimitMinutes} minutes',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PaperRoomScreen(
                                    quizId: paper.id,
                                    title: paper.title,
                                    apiClient: widget.apiClient,
                                    user: widget.user,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start practice'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onOpenMyPapers();
                              },
                              child: const Text('View in My Papers'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  _label('Course'),
                  DropdownButtonFormField<int>(
                    initialValue: _courseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Choose a course',
                      border: OutlineInputBorder(),
                    ),
                    items: _courses
                        .map(
                          (course) => DropdownMenuItem(
                            value: course.id,
                            child: Text(
                              course.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (id) => setState(() {
                            _courseId = id;
                            _error = null;
                          }),
                  ),
                  _label('Weeks ${_weeks.start.round()}–${_weeks.end.round()}'),
                  RangeSlider(
                    values: _weeks,
                    min: 1,
                    max: 12,
                    divisions: 11,
                    labels: RangeLabels(
                      '${_weeks.start.round()}',
                      '${_weeks.end.round()}',
                    ),
                    onChanged: _busy
                        ? null
                        : (weeks) => setState(() => _weeks = weeks),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in [
                        (1, 12, 'All weeks'),
                        (1, 4, 'Weeks 1–4'),
                        (5, 8, 'Weeks 5–8'),
                        (9, 12, 'Weeks 9–12'),
                      ])
                        ChoiceChip(
                          label: Text(preset.$3),
                          selected:
                              _weeks.start == preset.$1 &&
                              _weeks.end == preset.$2,
                          onSelected: _busy
                              ? null
                              : (_) => setState(
                                  () => _weeks = RangeValues(
                                    preset.$1.toDouble(),
                                    preset.$2.toDouble(),
                                  ),
                                ),
                        ),
                    ],
                  ),
                  _label('Paper types'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final type in {
                        'all': 'All types',
                        'pa': 'PA',
                        'ga': 'GA',
                        'quiz1': 'Quiz 1',
                        'quiz2': 'Quiz 2',
                        'endterm': 'End term',
                        'mock_test': 'Mock',
                      }.entries)
                        FilterChip(
                          label: Text(type.value),
                          selected: _types.contains(type.key),
                          onSelected: _busy
                              ? null
                              : (selected) => _setType(type.key, selected),
                        ),
                    ],
                  ),
                  _label('Time limit'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final minutes in [15, 20, 30, 45, 60])
                        ChoiceChip(
                          label: Text('$minutes min'),
                          selected: _minutes == minutes,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _minutes = minutes),
                        ),
                    ],
                  ),
                  _label('Paper name (optional)'),
                  TextField(
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      hintText: 'My practice paper',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _spin,
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(_busy ? 'Creating paper…' : 'Spin the wheel'),
                  ),
                  if (_error != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onOpenMyPapers();
                            },
                      child: const Text('Check My Papers'),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PracticeWheelPainter extends CustomPainter {
  const _PracticeWheelPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(
      center: center,
      radius: size.shortestSide / 2 - 4,
    );
    const colors = [
      Color(0xFF16A34A),
      Color(0xFF0284C7),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFFD97706),
      Color(0xFF059669),
      Color(0xFF2563EB),
      Color(0xFF4F46E5),
    ];
    for (var i = 0; i < colors.length; i++) {
      canvas.drawArc(
        rect,
        i * math.pi / 4,
        math.pi / 4,
        true,
        Paint()..color = colors[i],
      );
      canvas.drawArc(
        rect,
        i * math.pi / 4,
        math.pi / 4,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PracticeWheelPainter oldDelegate) => false;
}
