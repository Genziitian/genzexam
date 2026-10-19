import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../api/spin_practice_service.dart';
import 'native_paper_room.dart';
import 'premium_practice_wheel.dart';
import 'pro_membership_card.dart';

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
  late final AnimationController _rotation = AnimationController.unbounded(
    vsync: this,
  );
  final _title = TextEditingController();
  final _scroll = ScrollController();
  List<CourseModel> _courses = [];
  int? _courseId;
  RangeValues _weeks = const RangeValues(1, 12);
  final Set<String> _types = {'all'};
  bool _loading = true;
  bool _busy = false;
  bool _restoring = false;
  bool _quotaLoading = false;
  int? _remaining;
  int? _limit;
  bool _isPro = false;
  String? _loadError;
  String? _quotaError;
  String? _error;
  GeneratedPracticePaper? _paper;

  @override
  void initState() {
    super.initState();
    _isPro = widget.user?.isPro == true;
    _loadCourses();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    if (_quotaLoading) return;
    setState(() {
      _quotaLoading = true;
      _quotaError = null;
    });
    try {
      final quota = await SpinPracticeService(client: widget.apiClient)
          .getQuota();
      if (!mounted) return;
      setState(() {
        _isPro = quota.isPro;
        _remaining = quota.remaining;
        _limit = quota.limit;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _remaining = null;
        _limit = null;
        _quotaError = error is ApiException
            ? error.message
            : 'Could not check your available spins. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _quotaLoading = false);
    }
  }

  Future<void> _reload() async {
    await Future.wait<void>([_loadCourses(), _loadQuota()]);
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
      setState(() {
        _courses = courses;
        if (!courses.any((course) => course.id == _courseId)) {
          _courseId = null;
        }
      });
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
    if (_busy ||
        _restoring ||
        _quotaLoading ||
        _remaining == null ||
        _remaining == 0)
      return;
    if (_courseId == null) {
      setState(() => _error = 'Choose a course first.');
      return;
    }
    FocusScope.of(context).unfocus();
    final reduced = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _busy = true;
      _error = null;
      _paper = null;
    });
    if (!reduced)
      _rotation.repeat(
        min: 0,
        max: 1,
        period: const Duration(milliseconds: 1100),
      );
    GeneratedPracticePaper? ready;
    try {
      final results = await Future.wait<Object?>([
        SpinPracticeService(client: widget.apiClient).generate(
          courseId: _courseId!,
          weekMin: _weeks.start.round(),
          weekMax: _weeks.end.round(),
          paperTypes: _types.toList(),
          title: _title.text,
        ),
        if (!reduced) Future<void>.delayed(const Duration(seconds: 4)),
      ], eagerError: true);
      if (!mounted) return;
      _rotation.stop(canceled: false);
      if (!reduced)
        await _rotation
            .animateTo(
              _rotation.value + .37,
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
            )
            .orCancel;
      if (!mounted) return;
      ready = results.first as GeneratedPracticePaper;
      setState(() {
        _paper = ready;
        _remaining = ready!.spinsRemaining;
      });
      if (_remaining == null) await _loadQuota();
    } catch (error) {
      if (!mounted) return;
      var receivedQuota = false;
      if (error is ApiException && error.rawData is Map) {
        final quota = (error.rawData as Map)['quota'];
        if (quota is Map) {
          try {
            final parsed = SpinPracticeQuota.fromJson(
              Map<String, dynamic>.from(quota),
            );
            _remaining = parsed.remaining;
            _limit = parsed.limit;
            _isPro = parsed.isPro;
            receivedQuota = true;
          } on ApiException {
            // Keep the original generation error; reload an incomplete quota.
          }
        }
      }
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Could not create your paper. Please try again.',
      );
      if (error is! ApiException ||
          error.statusCode == null ||
          error.statusCode! >= 500 ||
          (error.statusCode == 429 && !receivedQuota)) {
        await _loadQuota();
      }
    } finally {
      if (mounted) {
        _rotation.stop(canceled: false);
        setState(() {
          _busy = false;
          _restoring = true;
        });
      }
    }
    if (!mounted) return;
    if (!reduced) await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _restoring = false);
    if (ready != null) await _showPaperReady(ready);
  }

  Future<void> _showHelp() => showDialog<void>(
    context: context,
    builder: (dialog) {
      const steps = [
        'Choose your course and week range.',
        'Pick one, several, or all paper types. Naming the paper is optional.',
        'Spin for up to 10 random questions from matching papers.',
        'Choose your time when you open it. The paper stays in My Papers.',
      ];
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHeader(dialog, 'How it works'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF312E81),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFC9A961),
                                ),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Color(0xFFF1E1B6),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  steps[i],
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    height: 1.4,
                                    color: Color(0xFF1E1B4B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F4EA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '1 free spin daily, up to 7 with Pro. Resets at midnight IST. Papers auto-delete after 30 days. No upload tokens used. Papers are private and cannot be shared.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF5B4A1F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFF312E81),
                    foregroundColor: const Color(0xFFF1E1B6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// Gradient header shared by the dialogs and sheets of this screen.
  Widget _sheetHeader(
    BuildContext context,
    String title, {
    String? subtitle,
    bool close = true,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 8, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF312E81), Color(0xFF4338CA)],
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFC9A961)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset('assets/logo.png', width: 30, height: 30),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFF1E1B6),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (close)
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            color: Colors.white,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    ),
  );

  Future<void> _showPaperReady(GeneratedPracticePaper paper) async {
    final selected = _courses.firstWhere((course) => course.id == _courseId);
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 14, 8, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF312E81), Color(0xFF4338CA)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: const Color(0xFFC9A961)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 28,
                              height: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Your paper is ready',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF1E1B6),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialog),
                          color: Colors.white,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      paper.title.replaceAll('-', '\u2011'),
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  children: [
                    _paperDetail(
                      Icons.school_outlined,
                      'Course',
                      selected.name,
                    ),
                    _paperDetail(
                      Icons.help_outline_rounded,
                      'Questions',
                      '${paper.questionCount}',
                    ),
                    _paperDetail(
                      Icons.date_range_rounded,
                      'Weeks',
                      '${_weeks.start.round()}–${_weeks.end.round()}',
                    ),
                    _paperDetail(
                      Icons.layers_outlined,
                      'Paper types',
                      _types.contains('all')
                          ? 'All types'
                          : _types.map((type) => _paperTypes[type]!).join(', '),
                    ),
                    if (_remaining != null)
                      _paperDetail(
                        Icons.rotate_right_rounded,
                        'Spins left today',
                        '$_remaining',
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: const Color(0xFF312E81),
                          side: const BorderSide(color: Color(0xFFC9A961)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _remaining == null || _remaining == 0
                            ? null
                            : () => Navigator.pop(dialog, 'again'),
                        child: const Text('Spin again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFF312E81),
                          foregroundColor: const Color(0xFFF1E1B6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialog, 'try'),
                        child: const Text('Try now'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'again') {
      unawaited(_spin());
    }
    if (action == 'try') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaperRoomScreen(
            quizId: paper.id,
            title: paper.title,
            apiClient: widget.apiClient,
            user: widget.user,
          ),
        ),
      );
    }
  }

  Widget _paperDetail(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F4EA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF8E7234)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 104,
          child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF312E81),
            ),
          ),
        ),
      ],
    ),
  );

  static const _paperTypes = {
    'pa': 'PA',
    'ga': 'GA',
    'quiz1': 'Quiz 1',
    'quiz2': 'Quiz 2',
    'endterm': 'End term',
    'mock_test': 'Mock',
  };

  Widget _selectionField({
    required Key key,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool placeholder = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: const Color(0x1A312E81),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF312E81),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFFF1E1B6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: placeholder
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseCourse() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) {
        var query = '';
        return StatefulBuilder(
          builder: (sheet, update) {
            final courses = _courses
                .where(
                  (course) =>
                      course.name.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheet).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheet).height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sheetHeader(sheet, 'Choose a course'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search courses',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF8F4EA),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) => update(() => query = value),
                      ),
                    ),
                    Expanded(
                      child: courses.isEmpty
                          ? const Center(child: Text('No matching courses'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: courses.length,
                              itemBuilder: (_, index) {
                                final course = courses[index];
                                final on = course.id == _courseId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: on
                                        ? const Color(0xFFEEF2FF)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: on
                                            ? const Color(0xFF4338CA)
                                            : const Color(0xFFE5E7EB),
                                        width: on ? 1.4 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListTile(
                                      title: Text(
                                        course.name,
                                        style: TextStyle(
                                          fontWeight: on
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: const Color(0xFF1E1B4B),
                                        ),
                                      ),
                                      trailing: on
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFF4338CA),
                                            )
                                          : const Icon(
                                              Icons.circle_outlined,
                                              color: Color(0xFFCBD5E1),
                                            ),
                                      onTap: () =>
                                          Navigator.pop(sheet, course.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted)
      setState(() {
        _courseId = selected;
        _error = null;
      });
  }

  Future<void> _chooseTypes() async {
    final selected = Set<String>.of(_types);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) {
          Widget option(String key, String label, ValueChanged<bool> onTap) {
            final on = selected.contains(key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: on ? const Color(0xFFEEF2FF) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: on
                        ? const Color(0xFF4338CA)
                        : const Color(0xFFE5E7EB),
                    width: on ? 1.4 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      color: const Color(0xFF1E1B4B),
                    ),
                  ),
                  trailing: Icon(
                    on
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: on
                        ? const Color(0xFF4338CA)
                        : const Color(0xFFCBD5E1),
                  ),
                  onTap: () => onTap(!on),
                ),
              ),
            );
          }

          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetHeader(
                  sheet,
                  'Paper types',
                  subtitle: 'Choose more than one, or include all types.',
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      children: [
                        option(
                          'all',
                          'All types',
                          (_) => update(() {
                            selected.clear();
                            selected.add('all');
                          }),
                        ),
                        for (final type in _paperTypes.entries)
                          option(
                            type.key,
                            type.value,
                            (checked) => update(() {
                              selected.remove('all');
                              checked
                                  ? selected.add(type.key)
                                  : selected.remove(type.key);
                              if (selected.isEmpty) selected.add('all');
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheet, selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF312E81),
                      foregroundColor: const Color(0xFFF1E1B6),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Color(0xFFC9A961)),
                      ),
                    ),
                    child: const Text('Apply selection'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result != null && mounted)
      setState(() {
        _types.clear();
        _types.addAll(result);
      });
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  Widget _footer(ColorScheme scheme) {
    final isUpgrade = !_isPro && _remaining == 0 && !_quotaLoading;
    final isProExhausted = _isPro && _remaining == 0 && !_quotaLoading;
    final isDisabled = _busy || _restoring || _quotaLoading || isProExhausted;
    final error = _error ?? _quotaError;

    String label;
    if (_busy) {
      label = 'Creating paper…';
    } else if (_quotaLoading) {
      label = 'Checking available spins…';
    } else if (_quotaError != null) {
      label = 'Retry spin allowance';
    } else if (_remaining == null) {
      label = 'Spin the wheel';
    } else if (!_isPro) {
      if (_remaining! > 0) {
        label = 'Spin the wheel · 1 free spin left';
      } else {
        label = 'Unlock 7 spins/day with Pro';
      }
    } else {
      if (_remaining! > 0) {
        label = 'Spin the wheel · $_remaining/${_limit ?? 7} spins left';
      } else {
        label = '0/${_limit ?? 7} spins left today';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                ),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isUpgrade
                    ? const Color(0xFFD97706)
                    : const Color(0xFF312E81),
                foregroundColor: isUpgrade
                    ? Colors.white
                    : const Color(0xFFF1E1B6),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                minimumSize: const Size.fromHeight(58),
                elevation: 6,
                shadowColor: const Color(0x66312E81),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isUpgrade
                        ? Colors.transparent
                        : const Color(0xFFC9A961),
                    width: 1.2,
                  ),
                ),
              ),
              onPressed: isDisabled
                  ? null
                  : isUpgrade
                  ? () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ProMembershipScreen(apiClient: widget.apiClient),
                        ),
                      );
                      if (mounted) await _loadQuota();
                    }
                  : _quotaError != null
                  ? _loadQuota
                  : _spin,
              icon: _busy || _quotaLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isUpgrade
                          ? Icons.stars_rounded
                          : Icons.rotate_right_rounded,
                    ),
              label: Text(label),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: _busy || _restoring,
            child: AnimatedOpacity(
              key: const Key('spin-background-dim'),
              opacity: _busy ? .18 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 650),
              curve: Curves.easeInOut,
              child: Scaffold(
                appBar: AppBar(
                  actions: [
                    IconButton(
                      tooltip: 'How it works',
                      onPressed: _busy ? null : _showHelp,
                      icon: const Icon(Icons.help_outline_rounded),
                    ),
                  ],
                  title: Row(
                    children: [
                      const Flexible(child: Text('Test yourself')),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD36E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            color: Color(0xFF714308),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar:
                    !_loading && _loadError == null && _courses.isNotEmpty
                    ? _footer(scheme)
                    : null,
                body: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null || _courses.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.red.shade600,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _loadError ?? 'No courses are available yet.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _reload,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          children: [
                            Text(
                              'Generate up to 10 random questions.',
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Opacity(
                              opacity: _busy ? 0 : 1,
                              child: PracticeWheel(
                                turns: _rotation,
                                busy: false,
                                complete: _paper != null,
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
                            _label('Course'),
                            _selectionField(
                              key: const Key('spin-course'),
                              icon: Icons.school_outlined,
                              text: _courseId == null
                                  ? 'Choose a course'
                                  : _courses
                                        .firstWhere((c) => c.id == _courseId)
                                        .name,
                              placeholder: _courseId == null,
                              onTap: _chooseCourse,
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Week range',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_weeks.start.round().toString().padLeft(2, '0')} — ${_weeks.end.round().toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: const Color(0xFF312E81),
                                thumbColor: const Color(0xFFC9A961),
                                inactiveTrackColor: scheme.outlineVariant
                                    .withValues(alpha: 0.6),
                                rangeThumbShape:
                                    const RoundRangeSliderThumbShape(
                                      enabledThumbRadius: 8,
                                    ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 18,
                                ),
                                showValueIndicator: ShowValueIndicator.onDrag,
                              ),
                              child: RangeSlider(
                                key: const Key('spin-weeks'),
                                values: _weeks,
                                min: 1,
                                max: 12,
                                labels: RangeLabels(
                                  'Week ${_weeks.start.round()}',
                                  'Week ${_weeks.end.round()}',
                                ),
                                onChanged: _busy
                                    ? null
                                    : (weeks) => setState(() => _weeks = weeks),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Week 1',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  'Week 12',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            _label('Paper types'),
                            _selectionField(
                              key: const Key('spin-types'),
                              icon: Icons.layers_outlined,
                              text: _types.contains('all')
                                  ? 'All types'
                                  : _types
                                        .map((type) => _paperTypes[type]!)
                                        .join(', '),
                              onTap: _chooseTypes,
                            ),
                            _label('Paper name (optional)'),
                            TextField(
                              controller: _title,
                              enabled: !_busy,
                              maxLength: 150,
                              decoration: InputDecoration(
                                hintText: 'My practice paper',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_busy,
              child: AnimatedOpacity(
                opacity: _busy ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 650),
                curve: Curves.easeInOut,
                child: ExcludeSemantics(
                  excluding: !_busy,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: ColoredBox(
                      color: scheme.surface.withValues(alpha: .55),
                      child: Center(
                        child: AnimatedScale(
                          scale: _busy ? 1 : .8,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 450),
                          curve: Curves.easeOutBack,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  if (_busy) const WheelSparks(),
                                  PracticeWheel(
                                    turns: _rotation,
                                    busy: _busy,
                                    complete: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Creating your private test…',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurface,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
