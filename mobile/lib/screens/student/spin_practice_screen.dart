import 'dart:async';

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
  int? _remaining;
  int? _limit;
  bool _isPro = false;
  String? _loadError;
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
    final quota = await SpinPracticeService(client: widget.apiClient).getQuota();
    if (!mounted || quota == null) return;
    setState(() {
      _isPro = quota.isPro;
      _remaining = quota.remaining;
      _limit = quota.limit;
    });
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
    if (_busy || _restoring || _remaining == 0) return;
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
      ]);
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
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.rawData is Map) {
        final quota = (error.rawData as Map)['quota'];
        if (quota is Map) {
          _remaining = (quota['remaining'] as num?)?.toInt();
          _limit = (quota['limit'] as num?)?.toInt();
          if (quota['is_pro'] is bool) _isPro = quota['is_pro'] as bool;
        }
      }
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Could not create your paper. Please try again.',
      );
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
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: _dialogTitle(dialog, 'How it works'),
      content: const Text(
        '1. Choose your course and week range.\n\n2. Pick one, several, or all paper types. Naming the paper is optional.\n\n3. Spin for up to 10 random questions from matching papers.\n\n4. Choose your time when you open it. The paper stays in My Papers.\n\n1 free spin daily, up to 7 with Pro. Resets at midnight IST. Papers auto-delete after 30 days. No upload tokens used. Papers are private and cannot be shared.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Widget _dialogTitle(BuildContext dialog, String title) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset('assets/logo.png', width: 32, height: 32),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        tooltip: 'Close',
        onPressed: () => Navigator.pop(dialog),
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );

  Future<void> _showPaperReady(GeneratedPracticePaper paper) async {
    final selected = _courses.firstWhere((course) => course.id == _courseId);
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: _dialogTitle(dialog, 'Your paper is ready'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              paper.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _paperDetail('Course', selected.name),
            _paperDetail('Questions', '${paper.questionCount}'),
            _paperDetail(
              'Weeks',
              '${_weeks.start.round()}–${_weeks.end.round()}',
            ),
            _paperDetail(
              'Paper types',
              _types.contains('all')
                  ? 'All types'
                  : _types.map((type) => _paperTypes[type]!).join(', '),
            ),
            if (_remaining != null)
              _paperDetail('Spins left today', '$_remaining'),
            const SizedBox(height: 16),
            const Text(
              'Private test, saved in My Papers. Kept for 30 days. Only you can open it. Choose your time when you start.',
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: _remaining == 0
                ? null
                : () => Navigator.pop(dialog, 'again'),
            child: const Text('Spin again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, 'try'),
            child: const Text('Try now'),
          ),
        ],
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

  Widget _paperDetail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
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
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
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
      showDragHandle: true,
      useSafeArea: true,
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
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.viewInsetsOf(sheet).bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheet).height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose a course',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search courses',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => update(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: courses.isEmpty
                          ? const Center(child: Text('No matching courses'))
                          : ListView.builder(
                              itemCount: courses.length,
                              itemBuilder: (_, index) {
                                final course = courses[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(course.name),
                                  trailing: course.id == _courseId
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF059669),
                                        )
                                      : const Icon(
                                          Icons.circle_outlined,
                                          color: Color(0xFFCBD5E1),
                                        ),
                                  onTap: () => Navigator.pop(sheet, course.id),
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
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Paper types',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 6, 8, 12),
                  child: Text('Choose more than one, or include all types.'),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('All types'),
                          value: selected.contains('all'),
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged: (_) => update(() {
                            selected.clear();
                            selected.add('all');
                          }),
                        ),
                        const Divider(height: 16),
                        for (final type in _paperTypes.entries)
                          CheckboxListTile(
                            title: Text(type.value),
                            value: selected.contains(type.key),
                            controlAffinity: ListTileControlAffinity.trailing,
                            onChanged: (checked) => update(() {
                              selected.remove('all');
                              checked == true
                                  ? selected.add(type.key)
                                  : selected.remove(type.key);
                              if (selected.isEmpty) selected.add('all');
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(sheet, selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Apply selection'),
                ),
              ],
            ),
          ),
        ),
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
    final isUpgrade = !_isPro && _remaining == 0;
    final isProExhausted = _isPro && _remaining == 0;
    final isDisabled = _busy || _restoring || isProExhausted;

    String label;
    if (_busy) {
      label = 'Creating paper…';
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
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
                    : const Color(0xFF064E3B),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: isDisabled
                  ? null
                  : isUpgrade
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProMembershipScreen(
                                apiClient: widget.apiClient,
                              ),
                            ),
                          );
                        }
                      : _spin,
              icon: _busy
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Test yourself',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                onPressed: _busy ? null : _showHelp,
                                child: const Text('How it works'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Generate 10 random question',
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          PracticeWheel(
                            turns: _rotation,
                            busy: _busy,
                            complete: _paper != null,
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
                                  style: TextStyle(fontWeight: FontWeight.w700),
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
                              activeTrackColor: const Color(0xFF059669),
                              inactiveTrackColor: scheme.outlineVariant
                                  .withValues(alpha: 0.6),
                              rangeThumbShape: const RoundRangeSliderThumbShape(
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
                              fillColor: scheme.surfaceContainerLow,
                              contentPadding: const EdgeInsets.all(16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
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
                  child: ColoredBox(
                    color: scheme.surface.withValues(alpha: .25),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PracticeWheel(
                            turns: _rotation,
                            busy: _busy,
                            complete: false,
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
        ],
      ),
    );
  }
}
