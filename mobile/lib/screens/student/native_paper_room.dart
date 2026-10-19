import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../api/api.dart';
import '../../api/offline_paper_store.dart';
import '../../api/paper_content.dart';
import '../../api/pro_access_guard.dart';
import 'pro_locked_view.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/success_tick.dart';

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
  ProAccess? _locked;
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
    var cached = _userId > 0
        ? await OfflinePaperStore.readQuiz(_userId, widget.quizId)
        : null;
    // A downloaded copy opens only while Pro is active, online or offline.
    ProAccess? lockedBy;
    if (cached != null) {
      final access = await ProAccessGuard.check(widget.apiClient, _userId);
      if (!mounted) return;
      if (access != ProAccess.active) {
        lockedBy = access;
        cached = null;
        if (widget.preferOffline) {
          setState(() {
            _loading = false;
            _locked = access;
          });
          return;
        }
      }
    }
    final saved = cached;
    if (saved != null) {
      if (!mounted) return;
      setState(() {
        _quiz = saved;
        _offline = true;
        _loading = false;
        _selectedMinutes = saved.timeLimitMinutes;
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
    if (quiz == null && lockedBy != null) {
      setState(() {
        _loading = false;
        _locked = lockedBy;
      });
      return;
    }
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
      final answeredNow = _questions.where(_hasAnswer).length;
      final totalNow = _questions.length;
      final confirm = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 320),
        transitionBuilder: (context, anim, _, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        ),
        pageBuilder: (context, _, _) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRing(
                    value: totalNow == 0 ? 0 : answeredNow / totalNow,
                    size: 92,
                    child: Text(
                      '$answeredNow/$totalNow',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _paperInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Submit this paper?',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: _paperInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    answeredNow < totalNow
                        ? '${totalNow - answeredNow} question${totalNow - answeredNow == 1 ? '' : 's'} still unanswered. Your answers will be saved and the paper will close.'
                        : 'All questions answered. Your answers will be saved and the paper will close.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PremiumButton(
                    label: 'Submit',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Keep working',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _paperGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            : _locked != null
            ? ProLockedView(
                access: _locked!,
                apiClient: widget.apiClient,
                paperCount: 1,
                onRecheck: () async {
                  final access = await ProAccessGuard.check(
                    widget.apiClient,
                    _userId,
                  );
                  if (access == ProAccess.active && mounted) {
                    setState(() {
                      _locked = null;
                      _loading = true;
                    });
                    unawaited(_loadPaper());
                  } else if (mounted) {
                    setState(() => _locked = access);
                  }
                  return access;
                },
              )
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
      FadeSlideIn(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F5132), Color(0xFF16A34A)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Color(0xFFFDE68A),
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'READY WHEN YOU ARE',
                              style: TextStyle(
                                color: Colors.white,
                                letterSpacing: 1.3,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _quiz?.title ?? widget.title,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metaPill(
                          Icons.help_outline_rounded,
                          '${_questions.length} questions',
                        ),
                        _metaPill(
                          Icons.menu_book_outlined,
                          _quiz?.course?.name ?? 'Practice paper',
                        ),
                      ],
                    ),
                    if (_offline)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text(
                          'Downloaded paper. Answers will sync when you are back online.',
                          style: TextStyle(color: Color(0xFFD1FAE5)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 20,
                          color: _paperGreen,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Choose your time',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _paperInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, box) {
                        final third = (box.maxWidth - 20) / 3;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _timeTile(
                              'Untimed',
                              0,
                              third,
                              Icons.all_inclusive_rounded,
                            ),
                            if ((_quiz?.timeLimitMinutes ?? 0) > 0)
                              _timeTile(
                                'Paper default · ${_quiz!.timeLimitMinutes} min',
                                _quiz!.timeLimitMinutes,
                                box.maxWidth,
                                Icons.verified_outlined,
                              ),
                            for (final minutes in [15, 30, 45, 60])
                              _timeTile('$minutes min', minutes, third, null),
                            _customTile(third),
                          ],
                        );
                      },
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 24),
                    PremiumButton(
                      label: 'Start paper',
                      icon: Icons.play_arrow_rounded,
                      onPressed: _begin,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _metaPill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _tile({
    required double width,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) => SizedBox(
    width: width,
    height: 56,
    child: Material(
      color: selected ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? _paperGreen : const Color(0xFFE2E8F0),
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(child: child),
      ),
    ),
  );

  Widget _timeTile(String label, int minutes, double width, IconData? icon) {
    final selected = _selectedMinutes == minutes;
    return _tile(
      width: width,
      selected: selected,
      onTap: () {
        AppHaptics.selection();
        setState(() => _selectedMinutes = minutes);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected || icon != null) ...[
            Icon(
              selected ? Icons.check_circle_rounded : icon,
              size: 17,
              color: selected ? _paperGreen : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? const Color(0xFF14532D) : _paperInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customTile(double width) {
    const presets = {0, 15, 30, 45, 60};
    final custom =
        !presets.contains(_selectedMinutes) &&
        _selectedMinutes != (_quiz?.timeLimitMinutes ?? -1);
    return _tile(
      width: width,
      selected: custom,
      onTap: _customTime,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tune_rounded, size: 17, color: _paperGreen),
          const SizedBox(width: 6),
          Text(
            custom ? '$_selectedMinutes min' : 'Custom',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _paperGreen,
            ),
          ),
        ],
      ),
    );
  }

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

  static const _reportReasons = <String, String>{
    'wrong_question': 'This question is wrong',
    'wrong_answer': 'The correct answer is wrong',
    'wrong_format': 'The format is wrong',
    'typo': 'Typo or unclear wording',
    'missing_info': 'Image, table or data is missing',
    'options_wrong': 'Options are wrong or missing',
    'other': 'Something else is wrong',
  };

  Future<void> _reportQuestion(int questionId, int number) async {
    final picked = <String>{};
    final comment = TextEditingController();
    var sending = false;
    var sent = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: sent
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 18),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, v, child) =>
                                Transform.scale(scale: v, child: child),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                gradient: Brand.gradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Thanks, report sent',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _paperInk,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Our team will check question $number and fix it if needed.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          PremiumButton(
                            label: 'Back to the paper',
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Report question $number',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _paperInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'What is wrong? Pick everything that applies.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final entry
                                          in _reportReasons.entries)
                                        FilterChip(
                                          label: Text(entry.value),
                                          selected: picked.contains(entry.key),
                                          showCheckmark: false,
                                          avatar: picked.contains(entry.key)
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 16,
                                                  color: _paperGreen,
                                                )
                                              : null,
                                          selectedColor: const Color(
                                            0xFFDCFCE7,
                                          ),
                                          onSelected: (on) => setSheet(() {
                                            on
                                                ? picked.add(entry.key)
                                                : picked.remove(entry.key);
                                            error = null;
                                          }),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: comment,
                                    maxLines: 3,
                                    maxLength: 1000,
                                    decoration: InputDecoration(
                                      labelText: 'Tell us more (optional)',
                                      hintText:
                                          'e.g. The answer should be 4, not 5',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                  if (error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        error!,
                                        style: const TextStyle(
                                          color: Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          PremiumButton(
                            label: 'Submit report',
                            icon: Icons.flag_rounded,
                            busy: sending,
                            onPressed: () async {
                              if (picked.isEmpty) {
                                setSheet(
                                  () => error = 'Pick at least one reason.',
                                );
                                return;
                              }
                              setSheet(() {
                                sending = true;
                                error = null;
                              });
                              try {
                                await widget.apiClient
                                    .post<Map<String, dynamic>>(
                                      '/question-reports',
                                      data: {
                                        'question_id': questionId,
                                        'question_number': number,
                                        'reasons': picked.toList(),
                                        'comment': comment.text.trim().isEmpty
                                            ? null
                                            : comment.text.trim(),
                                      },
                                    );
                                setSheet(() {
                                  sending = false;
                                  sent = true;
                                });
                              } catch (e) {
                                setSheet(() {
                                  sending = false;
                                  error = e is ApiException ? e.message : 'Could not send the report. Check your connection and try again.';
                                });
                              }
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    comment.dispose();
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
          height: 60,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _questions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _questionPaletteItem(index),
          ),
        ),
        Container(height: 1, color: const Color(0xFFE2E8F0)),
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
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDCFCE7),
                foregroundColor: const Color(0xFF047857),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showCalculator,
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text(
                'Calculator',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              _headerPill(
                constraints.maxWidth < 440
                    ? '$answeredCount/${_questions.length}'
                    : 'Answered:  $answeredCount/${_questions.length}',
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
              if (_current != null)
                _ReportButton(
                  compact: constraints.maxWidth < 340,
                  onTap: () =>
                      _reportQuestion(_current!.id, _questionIndex + 1),
                ),
              const SizedBox(width: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: _submitting
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF0F7A3D)],
                        ),
                  color: _submitting ? const Color(0xFFE5E7EB) : null,
                  boxShadow: _submitting
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x4016A34A),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submitting ? null : () => _submit(),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text(
                    'Submit & Exit',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
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
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
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
    const purple = Color(0xFF7C3AED);
    final Color fill = isCurrent
        ? _paperGreen
        : review
        ? const Color(0xFFF3E8FF)
        : answered
        ? const Color(0xFFDCFCE7)
        : Colors.white;
    final Color text = isCurrent
        ? Colors.white
        : review
        ? purple
        : answered
        ? const Color(0xFF166534)
        : const Color(0xFF64748B);
    final Color border = isCurrent
        ? _paperGreen
        : review
        ? purple
        : answered
        ? const Color(0xFF86EFAC)
        : const Color(0xFFCBD5E1);
    return Semantics(
      button: true,
      selected: isCurrent,
      label:
          'Question ${index + 1}${answered ? ', answered' : ''}${review ? ', marked for review' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          AppHaptics.selection();
          setState(() => _questionIndex = index);
          await _saveDraft();
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: isCurrent ? 0 : 1.4),
              boxShadow: isCurrent
                  ? const [
                      BoxShadow(
                        color: Color(0x5516A34A),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (review)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: purple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flag,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

  Widget _paperImage(String source, {String alt = 'Question image'}) {
    Widget unavailable(BuildContext context, Object error, StackTrace? stack) =>
        const Text(
          'This image is unavailable. Download the paper again while online.',
        );
    final resolved = paperImageUri(
      source,
      apiBaseUrl: widget.apiClient.dio.options.baseUrl,
      allowEmbedded: true,
    );
    if (resolved == null) return const Text('Image unavailable.');
    Widget image;
    if (resolved.startsWith('data:image/')) {
      try {
        image = Image.memory(
          base64Decode(resolved.substring(resolved.indexOf(',') + 1)),
          semanticLabel: alt,
          errorBuilder: unavailable,
        );
      } catch (_) {
        return const Text('Saved image could not be read.');
      }
    } else {
      image = Image.network(
        resolved,
        semanticLabel: alt,
        errorBuilder: unavailable,
      );
    }
    return Tooltip(
      message: 'Enlarge image',
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close image',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Flexible(child: InteractiveViewer(maxScale: 8, child: image)),
              ],
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: image,
        ),
      ),
    );
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
          final uri = paperImageUri(
            (content['url'] ??
                    content['asset'] ??
                    content['src'] ??
                    content['value'] ??
                    '')
                .toString(),
            apiBaseUrl: widget.apiClient.dio.options.baseUrl,
            allowEmbedded: true,
          );
          return [
            if (uri != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _paperImage(
                  uri,
                  alt: content['alt']?.toString() ?? 'Question image',
                ),
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
    final widgets = <Widget>[];
    var cursor = 0;
    for (final match in paperContentPattern.allMatches(text)) {
      if (match.start > cursor) {
        widgets.addAll(_plainRichText(text.substring(cursor, match.start)));
      }
      final image = match.group(5) ?? match.group(6);
      if (match.group(1) != null) {
        widgets.add(_codeBlock(match.group(3)!.trimRight()));
      } else if (image != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _paperImage(image, alt: match.group(4) ?? 'Question image'),
          ),
        );
      } else {
        widgets.addAll(_plainRichText(match.group(0)!));
      }
      cursor = match.end;
    }
    widgets.addAll(_plainRichText(text.substring(cursor)));
    return widgets;
  }

  List<Widget> _plainRichText(String text) {
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
    final pct = (result?.percentage ?? 0).toDouble();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FadeSlideIn(
          child: _panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SuccessTick(
                  size: 120,
                  label: 'Paper submitted successfully',
                ),
                const SizedBox(height: 14),
                const Text(
                  'Paper submitted',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _paperInk,
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 18),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => AnimatedRing(
                      value: pct / 100,
                      size: 128,
                      stroke: 11,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${v.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: _paperInk,
                            ),
                          ),
                          Text(
                            '${result.score} / ${result.totalMarks}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                PremiumButton(
                  label: 'Back to papers',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
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

class _ReportButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _ReportButton({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Report question',
    child: Semantics(
      button: true,
      label: 'Report question',
      child: Material(
        color: const Color(0xFFFEF2F2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFECACA)),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 12,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 17,
                  color: Color(0xFFB91C1C),
                ),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  const Text(
                    'Report',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
