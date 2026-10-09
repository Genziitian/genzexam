import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../api/api.dart';
import '../../api/offline_paper_store.dart';

const _paperGreen = Color(0xFF16A34A);
const _paperInk = Color(0xFF0F172A);

/// Flutter-native paper player. Safe question content is cached locally and
/// answer drafts are durably written after every change.
class PaperRoomScreen extends StatefulWidget {
  final int quizId;
  final String title;
  final ApiClient apiClient;
  final UserModel? user;
  final bool preferOffline;

  const PaperRoomScreen({
    super.key,
    required this.quizId,
    required this.title,
    required this.apiClient,
    this.user,
    this.preferOffline = false,
  });

  @override
  State<PaperRoomScreen> createState() => _PaperRoomScreenState();
}

class _PaperRoomScreenState extends State<PaperRoomScreen>
    with WidgetsBindingObserver {
  late final QuizService _quizService = QuizService(client: widget.apiClient);
  QuizDetail? _quiz;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  int _seconds = 0;
  int _selectedMinutes = 0;
  int _questionIndex = 0;
  int? _attemptId;
  bool _started = false;
  bool _starting = false;
  bool _submitting = false;
  bool _submitted = false;
  bool _pendingSubmit = false;
  bool _pendingSaved = false;
  final Set<int> _markedForReview = {};
  String? _startedAt;
  Future<void> _draftWrite = Future<void>.value();
  SubmitQuizResponse? _result;
  Timer? _clock;
  Timer? _syncRetry;
  final Map<int, Map<String, dynamic>> _answers = {};
  final Map<int, TextEditingController> _answerControllers = {};

  int get _userId => widget.user?.id ?? 0;
  List<QuestionModel> get _questions => _quiz?.questions ?? const [];
  QuestionModel? get _current =>
      _questions.isEmpty ? null : _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OfflinePaperStore.holdPaper(_userId, widget.quizId);
    _loadPaper();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _syncRetry?.cancel();
    // Keep the sync worker out until any final local write/network submit ends.
    if (!_submitting) {
      unawaited(
        _draftWrite.catchError((_) {}).whenComplete(() {
          OfflinePaperStore.releasePaper(_userId, widget.quizId);
        }),
      );
    }
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_started && !_submitted) unawaited(_submit(force: true));
    } else if (state == AppLifecycleState.resumed &&
        _pendingSubmit &&
        !_submitted) {
      unawaited(_submit(force: true));
    }
  }

  Future<void> _loadPaper() async {
    final cached = _userId > 0
        ? await OfflinePaperStore.readQuiz(_userId, widget.quizId)
        : null;
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _quiz = cached;
        _offline = true;
        _loading = false;
        _selectedMinutes = cached.timeLimitMinutes;
      });
      final draft = await OfflinePaperStore.readDraft(_userId, widget.quizId);
      if (draft != null && draft['started_at'] != null) {
        _restoreDraft(draft);
        if (_pendingSubmit) unawaited(_submit(force: true));
      }
      if (!widget.preferOffline) unawaited(_refreshCachedPaper());
      return;
    }

    if (widget.preferOffline) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'This download could not be read. Download it again from Practice while online.';
        });
      return;
    }

    QuizDetail? quiz;
    var offline = false;
    try {
      quiz = await _quizService.getQuiz(widget.quizId);
      // Only the Pro-protected download endpoint creates offline copies.
    } catch (_) {
      quiz = null;
    }
    if (!mounted) return;
    if (quiz == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load this paper. Connect to the internet once to download it for offline practice.';
      });
      return;
    }
    final draft = _userId > 0
        ? await OfflinePaperStore.readDraft(_userId, widget.quizId)
        : null;
    setState(() {
      _quiz = quiz;
      _offline = offline;
      _loading = false;
      _selectedMinutes = quiz!.timeLimitMinutes;
    });
    if (draft != null && draft['started_at'] != null) {
      _restoreDraft(draft);
      // Reopening after an OS/process kill finishes the interrupted attempt.
      if (_pendingSubmit) unawaited(_submit(force: true));
    }
  }

  Future<void> _refreshCachedPaper() async {
    try {
      final latest = await _quizService.getQuiz(widget.quizId);
      // Keep the explicit download, including its embedded images, intact.
      if (!mounted) return;
      setState(() {
        _offline = false;
        // Do not replace the paper while a student is answering it.
        if (!_started) {
          _quiz = latest;
          _selectedMinutes = latest.timeLimitMinutes;
        }
      });
    } catch (_) {
      // The cached copy is already available; continue without blocking.
    }
  }

  void _restoreDraft(Map<String, dynamic> draft) {
    final rawAnswers = draft['answers'];
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final questionId = int.tryParse(entry.key.toString());
        if (questionId != null && entry.value is Map) {
          _answers[questionId] = Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }
    _attemptId = (draft['attempt_id'] as num?)?.toInt();
    _selectedMinutes =
        (draft['duration_minutes'] as num?)?.toInt() ?? _selectedMinutes;
    // A previous screen/process has ended: finish that saved attempt, never
    // silently resume it or overwrite it with a new one.
    _pendingSubmit = true;
    _pendingSaved = draft['pending_submit'] == true;
    final reviewIds = draft['marked_for_review'];
    if (reviewIds is List) {
      _markedForReview
        ..clear()
        ..addAll(reviewIds.whereType<num>().map((id) => id.toInt()));
    }
    _started = true;
    _startedAt = draft['started_at']?.toString();
    final index = (draft['question_index'] as num?)?.toInt() ?? 0;
    _questionIndex = index.clamp(0, (_questions.length - 1).clamp(0, 100000));
    final startedAt = DateTime.tryParse(draft['started_at'].toString());
    if (_selectedMinutes > 0 && startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      _seconds = (_selectedMinutes * 60 - elapsed).clamp(
        0,
        _selectedMinutes * 60,
      );
    }
    if (mounted) setState(() {});
    if (_pendingSubmit) {
      _scheduleSyncRetry();
      return;
    }
    _startClock();
  }

  Future<void> _saveDraft({bool pending = false}) {
    if (_userId <= 0 || !_started || _submitted) return Future<void>.value();
    _pendingSubmit = _pendingSubmit || pending;
    _startedAt ??= DateTime.now().toIso8601String();
    final snapshot = {
      'attempt_id': _attemptId,
      'started_at': _startedAt,
      'duration_minutes': _selectedMinutes,
      'question_index': _questionIndex,
      'marked_for_review': _markedForReview.toList(),
      'answers': _answers.map((key, value) => MapEntry(key.toString(), value)),
      'pending_submit': _pendingSubmit,
    };
    _draftWrite = _draftWrite
        .catchError((_) {})
        .then(
          (_) => OfflinePaperStore.writeDraft(_userId, widget.quizId, snapshot),
        );
    return _draftWrite;
  }

  Future<void> _begin() async {
    if (_quiz == null || _starting || _started) return;
    if (_questions.isEmpty) {
      setState(() => _error = 'This paper does not have any questions yet.');
      return;
    }
    _starting = true;
    int? attemptId;
    try {
      if (!_offline) {
        attemptId = (await _quizService.startAttempt(widget.quizId)).attemptId;
      }
    } catch (error) {
      // An already downloaded paper can be attempted offline. The attempt is
      // created and scored by the server when the student reconnects.
      final hasLocalCopy =
          _userId > 0 &&
          await OfflinePaperStore.readQuiz(_userId, widget.quizId) != null;
      final connectionFailure =
          error is ApiException &&
          (error.statusCode == null || (error.statusCode ?? 0) >= 500);
      if (!hasLocalCopy || !connectionFailure) {
        _starting = false;
        if (!mounted) return;
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not start this paper. Please try again.',
        );
        return;
      }
      _offline = true;
    }
    if (!mounted) return;
    setState(() {
      _starting = false;
      _error = null;
      _attemptId = attemptId;
      _started = true;
      _startedAt = DateTime.now().toIso8601String();
      _seconds = _selectedMinutes * 60;
      _questionIndex = 0;
    });
    try {
      await _saveDraft();
      _startClock();
    } catch (_) {
      if (mounted)
        setState(() {
          _started = false;
          _error = 'This device could not save a paper draft. Please free some storage and try again.';
        });
    }
  }

  void _startClock() {
    _clock?.cancel();
    if (_seconds <= 0) return;
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _submitted) return timer.cancel();
      if (_seconds <= 1) {
        setState(() => _seconds = 0);
        timer.cancel();
        unawaited(_submit(force: true));
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _setAnswer(int questionId, Map<String, dynamic> answer) async {
    _answers[questionId] = answer;
    await _saveDraft();
    if (mounted) setState(() {});
  }

  Future<void> _submit({bool force = false, bool tryNetwork = false}) async {
    if (_submitting || _submitted || !_started) return;
    if (!force) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit this paper?'),
          content: const Text(
            'Your answers will be saved and the paper will close.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep working'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    setState(() {
      _submitting = true;
      _pendingSubmit = true;
      _error = null;
    });
    _clock?.cancel();
    try {
      try {
        await _saveDraft(pending: true);
        if (mounted) setState(() => _pendingSaved = true);
      } catch (_) {
        if (mounted)
          setState(() {
            _pendingSubmit = false;
            _error = 'Could not save your answers on this device. Keep this paper open and try again.';
          });
        return;
      }
      if (_offline && !tryNetwork) {
        _scheduleSyncRetry();
        return;
      }
      var attemptId = _attemptId;
      attemptId ??= (await _quizService.startAttempt(widget.quizId)).attemptId;
      _attemptId = attemptId;
      // Persist the server ID before submitting so reconnect/restart can check
      // whether the server already accepted this same attempt.
      await _saveDraft(pending: true);
      final payload = _questions.map((question) {
        final answer = _answers[question.id] ?? const <String, dynamic>{};
        return SubmitAnswerPayload(
          questionId: question.id,
          selectedOptionIds: (answer['selected_option_ids'] as List?)
              ?.map((id) => (id as num).toInt())
              .toList(),
          textAnswer: answer['text_answer']?.toString(),
          numericalAnswer: answer['numerical_answer'] as num?,
        );
      }).toList();
      final response = await _quizService.submitAttempt(attemptId, payload);
      await OfflinePaperStore.clearDraft(_userId, widget.quizId);
      _syncRetry?.cancel();
      _syncRetry = null;
      if (!mounted) return;
      setState(() {
        _result = response;
        _submitted = true;
        _pendingSubmit = false;
      });
    } catch (_) {
      // If the request reached the server but the response did not, ask the
      // authoritative result endpoint before retrying a potentially completed
      // submission. If not complete, retain the encrypted local sync queue.
      final attemptId = _attemptId;
      if (attemptId != null) {
        try {
          final result = await _quizService.getResult(attemptId);
          await OfflinePaperStore.clearDraft(_userId, widget.quizId);
          if (mounted) {
            setState(() {
              _submitted = true;
              _pendingSubmit = false;
              _result = SubmitQuizResponse(
                attemptId: result.attempt.id,
                score: result.attempt.score,
                totalMarks: result.attempt.totalMarks,
                percentage: result.attempt.percentage,
                xpAward: const XpAwardEnvelope(
                  xpBefore: 0,
                  xpAfter: 0,
                  xpGained: 0,
                  levelBefore: 1,
                  levelAfter: 1,
                  leveledUp: false,
                  newBadges: [],
                  reason: '',
                ),
              );
            });
          }
          return;
        } catch (_) {}
      }
      await _saveDraft(pending: true);
      _scheduleSyncRetry();
      if (mounted) {
        setState(
          () => _error = 'Your answers are saved on this device. We will submit them when the connection returns.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
      if (!mounted) OfflinePaperStore.releasePaper(_userId, widget.quizId);
    }
  }

  void _scheduleSyncRetry() {
    _syncRetry ??= Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _pendingSubmit && !_submitting && !_submitted) {
        unawaited(_submit(force: true, tryNetwork: true));
      }
    });
  }

  String get _clockLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_started || _submitted || _pendingSaved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _started && !_submitted) unawaited(_submit(force: true));
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: _started && !_submitted
            ? null
            : AppBar(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: _paperInk,
                title: Text(
                  _quiz?.title ?? widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [
                  if (_offline)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: Text(
                          'OFFLINE',
                          style: TextStyle(
                            color: _paperGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _paperGreen))
            : _error != null && _quiz == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : _submitted
            ? _resultView()
            : _pendingSubmit
            ? _pendingView()
            : !_started
            ? _startView()
            : SafeArea(child: _paperView()),
      ),
    );
  }

  Widget _startView() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
    children: [
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'READY WHEN YOU ARE',
              style: TextStyle(
                color: _paperGreen,
                letterSpacing: 1.5,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _quiz?.title ?? widget.title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: _paperInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_questions.length} questions · ${_quiz?.course?.name ?? 'Practice paper'}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (_offline)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Downloaded paper. Answers will sync when you are back online.',
                  style: TextStyle(color: _paperGreen),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Choose your time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'You can set a custom clock before this attempt starts.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _timeChip('Untimed', 0),
                if ((_quiz?.timeLimitMinutes ?? 0) > 0)
                  _timeChip(
                    'Paper default · ${_quiz!.timeLimitMinutes} min',
                    _quiz!.timeLimitMinutes,
                  ),
                for (final minutes in [15, 30])
                  _timeChip('$minutes min', minutes),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _timeChip('45 min', 45),
                    const SizedBox(width: 8),
                    _timeChip('60 min', 60),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _customTime,
                      icon: const Icon(Icons.timer_outlined, size: 16),
                      label: const Text('Custom'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _begin,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start paper'),
                style: FilledButton.styleFrom(
                  backgroundColor: _paperGreen,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _timeChip(String label, int minutes) => ChoiceChip(
    label: Text(label),
    selected: _selectedMinutes == minutes,
    selectedColor: const Color(0xFFDCFCE7),
    onSelected: (_) => setState(() => _selectedMinutes = minutes),
  );

  Future<void> _customTime() async {
    final controller = TextEditingController(
      text: _selectedMinutes > 0 ? '$_selectedMinutes' : '90',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom time limit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'For example, 75',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Use time'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (value < 1 || value > 600) {
      setState(() => _error = 'Choose between 1 and 600 minutes.');
    } else {
      setState(() {
        _selectedMinutes = value;
        _error = null;
      });
    }
  }

  Widget _paperView() {
    final question = _current;
    if (question == null)
      return const Center(child: Text('This paper has no questions.'));
    final selected =
        ((_answers[question.id]?['selected_option_ids'] as List?) ?? [])
            .map((id) => (id as num).toInt())
            .toSet();
    final isMulti =
        question.type == 'multi_select' || question.type == 'mcq_multi';
    final answeredCount = _questions.where(_hasAnswer).length;
    final questionType = isMulti
        ? 'MCQ MULTI'
        : question.type == 'numerical'
        ? 'NUMERICAL'
        : question.options.isEmpty
        ? 'WRITTEN ANSWER'
        : 'MCQ';
    return Column(
      children: [
        _runnerHeader(answeredCount),
        Container(height: 1, color: const Color(0xFFE2E8F0)),
        SizedBox(
          height: 76,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: _questions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _questionPaletteItem(index),
          ),
        ),
        Container(height: 3, color: const Color(0xFF1E293B)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Question ${_questionIndex + 1} of ${_questions.length}',
                        style: const TextStyle(
                          color: _paperInk,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        questionType,
                        style: const TextStyle(
                          color: Color(0xFF0369A1),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '+${question.marks} Marks',
                      style: const TextStyle(
                        color: _paperGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: const Color(0xFFE2E8F0)),
              const SizedBox(height: 20),
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMulti)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'SELECT ALL THAT APPLY',
                          style: TextStyle(
                            color: _paperGreen,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ..._richWidgets(question.stem),
                    if (question.stemImage != null &&
                        question.stemImage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _paperImage(question.stemImage!),
                      ),
                    if (question.stemCode != null &&
                        question.stemCode!.isNotEmpty)
                      _codeBlock(question.stemCode!),
                    if (question.stemTable != null) _table(question.stemTable),
                    if (question.options.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      for (final option in question.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              final next = Set<int>.from(selected);
                              if (isMulti) {
                                if (!next.add(option.id))
                                  next.remove(option.id);
                              } else {
                                next
                                  ..clear()
                                  ..add(option.id);
                              }
                              _setAnswer(question.id, {
                                'selected_option_ids': next.toList(),
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: selected.contains(option.id)
                                    ? const Color(0xFFF0FDF4)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected.contains(option.id)
                                      ? _paperGreen
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isMulti
                                        ? (selected.contains(option.id)
                                              ? Icons.check_box
                                              : Icons.check_box_outline_blank)
                                        : (selected.contains(option.id)
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off),
                                    color: selected.contains(option.id)
                                        ? _paperGreen
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: option.optionType == 'code'
                                          ? [
                                              _codeBlock(
                                                option.optionText.toString(),
                                              ),
                                            ]
                                          : _richWidgets(option.optionText),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ] else if (question.type == 'numerical') ...[
                      const SizedBox(height: 18),
                      TextField(
                        key: ValueKey('num_${question.id}'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Your answer',
                          border: OutlineInputBorder(),
                        ),
                        controller: _controller(
                          question.id,
                          'numerical_answer',
                        ),
                        onChanged: (v) => _setAnswer(question.id, {
                          'numerical_answer': num.tryParse(v),
                        }),
                      ),
                    ] else ...[
                      const SizedBox(height: 18),
                      TextField(
                        key: ValueKey('text_${question.id}'),
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Your answer',
                          border: OutlineInputBorder(),
                        ),
                        controller: _controller(question.id, 'text_answer'),
                        onChanged: (v) =>
                            _setAnswer(question.id, {'text_answer': v}),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(top: false, child: _runnerBottomBar()),
      ],
    );
  }

  bool _hasAnswer(QuestionModel question) {
    final answer = _answers[question.id];
    if (answer == null) return false;
    final selected = answer['selected_option_ids'];
    if (selected is List && selected.isNotEmpty) return true;
    final numerical = answer['numerical_answer'];
    if (numerical != null && numerical.toString().isNotEmpty) return true;
    return (answer['text_answer'] ?? '').toString().trim().isNotEmpty;
  }

  Widget _runnerHeader(int answeredCount) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => unawaited(_submit()),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Submit and exit',
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _quiz?.title ?? widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _paperInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _quiz?.course?.name ??
                        _quiz?.section ??
                        'Quiz LAB · Practice',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF047857),
                side: const BorderSide(color: Color(0xFF86EFAC)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              onPressed: _showCalculator,
              child: const Text(
                'Calculator',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
        if (_offline)
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'OFFLINE PAPER',
                style: TextStyle(
                  color: _paperGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            _headerPill(
              'Answered:  $answeredCount/${_questions.length}',
              const Color(0xFFF1F5F9),
              const Color(0xFF475569),
            ),
            const SizedBox(width: 8),
            _headerPill(
              _selectedMinutes > 0 ? _clockLabel : 'Untimed',
              _seconds < 60 && _selectedMinutes > 0
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFF1F5F9),
              _seconds < 60 && _selectedMinutes > 0
                  ? Colors.red
                  : const Color(0xFF0F172A),
              leading: _selectedMinutes == 0 ? Icons.circle : null,
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 11,
                ),
              ),
              onPressed: _submitting ? null : () => _submit(),
              icon: const Icon(Icons.check, size: 17),
              label: const Text(
                'Submit & Exit',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _headerPill(
    String label,
    Color background,
    Color foreground, {
    IconData? leading,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFCBD5E1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          Icon(leading, size: 10, color: _paperGreen),
          const SizedBox(width: 7),
        ],
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Widget _questionPaletteItem(int index) {
    final question = _questions[index];
    final isCurrent = index == _questionIndex;
    final answered = _hasAnswer(question);
    final review = _markedForReview.contains(question.id);
    final color = review
        ? const Color(0xFF7C3AED)
        : answered
        ? _paperGreen
        : const Color(0xFF64748B);
    return InkWell(
      onTap: () async {
        setState(() => _questionIndex = index);
        await _saveDraft();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: answered && !review ? const Color(0xFFDCFCE7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? _paperGreen : const Color(0xFFCBD5E1),
            width: isCurrent ? 3 : 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${index + 1}',
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (review)
              const Positioned(
                right: 3,
                top: 3,
                child: Icon(Icons.flag, size: 12, color: Color(0xFF7C3AED)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _runnerBottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
    ),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: _compactRunnerButtonStyle(),
            onPressed: _questionIndex > 0
                ? () => _goToQuestion(_questionIndex - 1)
                : null,
            icon: const Icon(Icons.arrow_back, size: 14),
            label: const Text('Prev'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton(
            style: _compactRunnerButtonStyle(),
            onPressed: _hasAnswer(_current!)
                ? () async {
                    _answers.remove(_current!.id);
                    _answerControllers[_current!.id]?.clear();
                    await _saveDraft();
                    if (mounted) setState(() {});
                  }
                : null,
            child: const Text('Clear'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton(
            style: _compactRunnerButtonStyle().copyWith(
              foregroundColor: WidgetStatePropertyAll(
                _markedForReview.contains(_current!.id)
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF475569),
              ),
            ),
            onPressed: () async {
              setState(() {
                if (!_markedForReview.add(_current!.id))
                  _markedForReview.remove(_current!.id);
              });
              await _saveDraft();
            },
            child: Text(
              _markedForReview.contains(_current!.id) ? 'Marked' : 'Review',
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            style: _compactRunnerButtonStyle(
              backgroundColor: _paperGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: _questionIndex + 1 < _questions.length
                ? () => _goToQuestion(_questionIndex + 1)
                : () => _submit(),
            icon: Icon(
              _questionIndex + 1 < _questions.length
                  ? Icons.arrow_forward
                  : Icons.check,
              size: 14,
            ),
            label: Text(
              _questionIndex + 1 < _questions.length ? 'Save & Next' : 'Finish',
            ),
          ),
        ),
      ],
    ),
  );

  ButtonStyle _compactRunnerButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
  }) => OutlinedButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor ?? const Color(0xFF475569),
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    side: BorderSide(
      color: backgroundColor == null
          ? const Color(0xFFCBD5E1)
          : backgroundColor,
    ),
  );

  Future<void> _goToQuestion(int index) async {
    setState(() => _questionIndex = index.clamp(0, _questions.length - 1));
    await _saveDraft();
  }

  void _showCalculator() {
    final controller = TextEditingController();
    String result = '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calculator'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Expression',
                  hintText: 'e.g. 12 * 4',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  result,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.clear();
                setDialogState(() => result = '');
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () {
                final expression = controller.text.trim();
                final match = RegExp(
                  r'^(-?\d+(?:\.\d+)?)\s*([+*/-])\s*(-?\d+(?:\.\d+)?)$',
                ).firstMatch(expression);
                if (match == null) {
                  setDialogState(() => result = 'Enter a simple calculation');
                  return;
                }
                final a = double.parse(match.group(1)!);
                final b = double.parse(match.group(3)!);
                final value = switch (match.group(2)) {
                  '+' => a + b,
                  '-' => a - b,
                  '*' => a * b,
                  '/' => b == 0 ? double.nan : a / b,
                  _ => double.nan,
                };
                setDialogState(
                  () => result = value.isFinite
                      ? (value == value.roundToDouble()
                            ? value.toInt().toString()
                            : value.toString())
                      : 'Cannot divide by zero',
                );
              },
              child: const Text('Calculate'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  TextEditingController _controller(int questionId, String key) =>
      _answerControllers.putIfAbsent(
        questionId,
        () => TextEditingController(
          text: (_answers[questionId]?[key] ?? '').toString(),
        ),
      );

  Widget _paperImage(String source) {
    Widget unavailable(BuildContext context, Object error, StackTrace? stack) =>
        const Text(
          'This image is unavailable. Download the paper again while online.',
        );
    if (source.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(source.substring(source.indexOf(',') + 1)),
          errorBuilder: unavailable,
        );
      } catch (_) {
        return const Text('Saved image could not be read.');
      }
    }
    return Image.network(source, errorBuilder: unavailable);
  }

  List<Widget> _richWidgets(dynamic content) {
    if (content is List) return content.expand(_richWidgets).toList();
    if (content is Map) {
      final kind = (content['kind'] ?? content['type'] ?? 'text')
          .toString()
          .toLowerCase();
      final value = (content['value'] ?? '').toString();
      switch (kind) {
        case 'math':
          return [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _math(value, display: true),
            ),
          ];
        case 'code':
          return [_codeBlock(value)];
        case 'image':
          final uri = _safeImageUri(
            (content['url'] ?? content['asset'] ?? content['src'] ?? content['value'] ?? '').toString(),
          );
          return [
            if (uri != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _paperImage(uri),
              )
            else
              const Text('Image unavailable.'),
          ];
        case 'table':
          return [_table(content)];
        case 'text':
          return _richWidgets(value);
        default:
          return [
            SelectableText(
              content.toString(),
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: _paperInk,
              ),
            ),
          ];
      }
    }
    final text = content?.toString() ?? '';
    final plain = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(p|div|li|h[1-6])\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
    return _textWithMath(plain);
  }

  Widget _math(String source, {required bool display}) => Math.tex(
    source.trim(),
    mathStyle: display ? MathStyle.display : MathStyle.text,
    textStyle: const TextStyle(fontSize: 18, color: _paperInk),
    onErrorFallback: (error) => SelectableText(
      source,
      style: const TextStyle(fontSize: 16, color: _paperInk),
    ),
  );

  List<Widget> _textWithMath(String text) {
    final pattern = RegExp(
      r'\\\[(.+?)\\\]|\\\((.+?)\\\)|\$\$(.+?)\$\$|\$(.+?)\$',
      dotAll: true,
    );
    final widgets = <Widget>[];
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        widgets.add(
          SelectableText(
            text.substring(cursor, match.start),
            style: const TextStyle(fontSize: 16, height: 1.5, color: _paperInk),
          ),
        );
      }
      final display = match.group(1) != null || match.group(3) != null;
      final expression =
          match.group(1) ??
          match.group(2) ??
          match.group(3) ??
          match.group(4) ??
          '';
      widgets.add(
        display
            ? SizedBox(
                width: double.infinity,
                child: _math(expression, display: true),
              )
            : _math(expression, display: false),
      );
      cursor = match.end;
    }
    if (cursor < text.length || widgets.isEmpty) {
      widgets.add(
        SelectableText(
          text.substring(cursor),
          style: const TextStyle(fontSize: 16, height: 1.5, color: _paperInk),
        ),
      );
    }
    return [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: widgets),
    ];
  }

  String? _safeImageUri(String value) {
    if (value.startsWith('data:image/')) return value;
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null) return null;
    if (parsed.scheme == 'https') return parsed.toString();
    if (value.startsWith('/')) return 'https://labapi.genziitian.in$value';
    return null;
  }

  Widget _codeBlock(String code) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(12),
    ),
    child: SelectableText(
      code,
      style: const TextStyle(color: Color(0xFFE2E8F0), fontFamily: 'monospace'),
    ),
  );

  Widget _table(dynamic raw) {
    List<dynamic> rows;
    List<dynamic> headers = [];
    if (raw is Map) {
      headers = raw['headers'] is List ? raw['headers'] as List : [];
      rows = raw['rows'] is List ? raw['rows'] as List : [];
    } else {
      rows = raw is List ? raw : [];
    }
    if (rows.isEmpty && headers.isEmpty) return const SizedBox.shrink();
    final normalized = rows
        .map(
          (row) => row is List
              ? row
              : row is Map
              ? row.values.toList()
              : [row],
        )
        .toList();
    final count = headers.isNotEmpty
        ? headers.length
        : normalized.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: List.generate(
          count,
          (i) => DataColumn(
            label: Text(i < headers.length ? headers[i].toString() : ''),
          ),
        ),
        rows: normalized
            .map(
              (row) => DataRow(
                cells: List.generate(
                  count,
                  (i) =>
                      DataCell(Text(i < row.length ? row[i].toString() : '')),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _resultView() {
    final result = _result;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: _paperGreen, size: 52),
              const SizedBox(height: 12),
              const Text(
                'Paper submitted',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _paperInk,
                ),
              ),
              if (result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    '${result.score} / ${result.totalMarks} · ${result.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 17,
                      color: _paperGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(backgroundColor: _paperGreen),
                  child: const Text('Back to papers'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: _panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              color: _paperGreen,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Paper finished',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _paperInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Your answers are saved on this device. We will submit them when the connection returns.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.45),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _submit(force: true, tryNetwork: true),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(_submitting ? 'Submitting…' : 'Try submitting now'),
                style: FilledButton.styleFrom(backgroundColor: _paperGreen),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to papers'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C0F172A),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}
