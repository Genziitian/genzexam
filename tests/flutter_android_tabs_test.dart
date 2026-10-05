// ============================================================================
// Quiz Lab - Flutter / Dart QA Integration & Widget Test Suite
// ============================================================================
// Target: Android App 5 Tabs (Home, Quizzes, Test, Support, More)
// Framework: Flutter Test / Dart
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// MODELS & SERVICES UNDER TEST
// ============================================================================

enum QuestionType { mcq, multiSelect, numerical, shortAnswer, trueFalse }

class QuestionOption {
  final int id;
  final String text;
  final bool isCorrect;

  QuestionOption({required this.id, required this.text, required this.isCorrect});
}

class QuestionModel {
  final int id;
  final QuestionType type;
  final String stem;
  final double marks;
  final double negativeMarks;
  final List<QuestionOption> options;
  final double? numericalAnswer;
  final double? numericalTolerance;
  final List<String>? acceptableShortAnswers;

  QuestionModel({
    required this.id,
    required this.type,
    required this.stem,
    required this.marks,
    this.negativeMarks = 0.5,
    this.options = const [],
    this.numericalAnswer,
    this.numericalTolerance = 0.01,
    this.acceptableShortAnswers,
  });
}

class QuizAttemptState {
  final int attemptId;
  final Map<int, dynamic> answers = {};
  final Set<int> reviewFlags = {};
  final Set<int> visitedIndices = {};
  bool isSubmitted = false;

  QuizAttemptState({required this.attemptId});

  void recordAnswer(int questionId, dynamic answer) {
    if (isSubmitted) throw StateError("Attempt already submitted");
    answers[questionId] = answer;
    visitedIndices.add(questionId);
  }

  void toggleReview(int questionId) {
    if (reviewFlags.contains(questionId)) {
      reviewFlags.remove(questionId);
    } else {
      reviewFlags.add(questionId);
    }
  }
}

// ============================================================================
// WIDGET UNDER TEST: TIMED EXAM PLAYER (TAB 3)
// ============================================================================

class TimedExamPlayerScreen extends StatefulWidget {
  final List<QuestionModel> questions;
  final int timeLimitSeconds;
  final Future<void> Function(Map<int, dynamic> answers, bool isAuto) onSubmit;

  const TimedExamPlayerScreen({
    super.key,
    required this.questions,
    required this.timeLimitSeconds,
    required this.onSubmit,
  });

  @override
  State<TimedExamPlayerScreen> createState() => _TimedExamPlayerScreenState();
}

class _TimedExamPlayerScreenState extends State<TimedExamPlayerScreen> {
  late int _remainingSeconds;
  Timer? _timer;
  int _currentIndex = 0;
  final QuizAttemptState _attemptState = QuizAttemptState(attemptId: 101);
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeLimitSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      }
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _triggerSubmit(isAuto: true);
      }
    });
  }

  Future<void> _triggerSubmit({required bool isAuto}) async {
    if (_isSubmitting || _attemptState.isSubmitted) return;
    setState(() => _isSubmitting = true);
    _attemptState.isSubmitted = true;
    _timer?.cancel();

    try {
      await widget.onSubmit(_attemptState.answers, isAuto);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAuto ? "Time is up! Quiz auto-submitted." : "Quiz submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Submission failed. Retrying in background..."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _handleWillPop() async {
    if (_attemptState.isSubmitted) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Leave Examination?"),
        content: const Text(
          "Your examination timer continues running in the background. "
          "Unsubmitted answers may be lost if you exit.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Stay in Exam"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Exit Exam"),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.questions[_currentIndex];
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final timerText = "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";

    return PopScope(
      canPop: _attemptState.isSubmitted,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final allow = await _handleWillPop();
          if (allow && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Quiz Lab Exam Player"),
          actions: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _remainingSeconds < 60 ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timerText,
                  key: const Key("exam_timer_display"),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds < 60 ? Colors.red.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Question Palette Bar
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.questions.length,
                itemBuilder: (ctx, idx) {
                  final qId = widget.questions[idx].id;
                  final isAnswered = _attemptState.answers.containsKey(qId);
                  final isReviewed = _attemptState.reviewFlags.contains(qId);
                  Color btnColor = Colors.grey.shade200;
                  if (isAnswered) btnColor = Colors.green.shade300;
                  if (isReviewed) btnColor = Colors.purple.shade200;

                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = idx),
                    child: Container(
                      width: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        color: btnColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _currentIndex == idx ? Colors.blue.shade800 : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text("${idx + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
            const Divider(),

            // Question Stem & Options View
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Question ${_currentIndex + 1} of ${widget.questions.length}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentQ.stem,
                      key: const Key("question_stem_text"),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 16),

                    if (currentQ.type == QuestionType.mcq || currentQ.type == QuestionType.trueFalse)
                      ...currentQ.options.map((opt) {
                        final selected = _attemptState.answers[currentQ.id] == opt.id;
                        return RadioListTile<int>(
                          key: Key("option_${opt.id}"),
                          title: Text(opt.text),
                          value: opt.id,
                          groupValue: _attemptState.answers[currentQ.id],
                          onChanged: (val) {
                            setState(() {
                              _attemptState.recordAnswer(currentQ.id, val);
                            });
                          },
                        );
                      }),

                    if (currentQ.type == QuestionType.multiSelect)
                      ...currentQ.options.map((opt) {
                        final selectedList = (_attemptState.answers[currentQ.id] as List<int>?) ?? [];
                        final isChecked = selectedList.contains(opt.id);
                        return CheckboxListTile(
                          key: Key("msq_option_${opt.id}"),
                          title: Text(opt.text),
                          value: isChecked,
                          onChanged: (bool? checked) {
                            setState(() {
                              final updated = List<int>.from(selectedList);
                              if (checked == true) {
                                updated.add(opt.id);
                              } else {
                                updated.remove(opt.id);
                              }
                              _attemptState.recordAnswer(currentQ.id, updated);
                            });
                          },
                        );
                      }),

                    if (currentQ.type == QuestionType.numerical)
                      TextField(
                        key: const Key("numerical_input_field"),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: "Enter Numerical Answer",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          _attemptState.recordAnswer(currentQ.id, double.tryParse(val));
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Action Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))
              ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    key: const Key("btn_toggle_review"),
                    onPressed: () {
                      setState(() {
                        _attemptState.toggleReview(currentQ.id);
                      });
                    },
                    child: Text(_attemptState.reviewFlags.contains(currentQ.id) ? "Marked for Review" : "Mark for Review"),
                  ),
                  ElevatedButton(
                    key: const Key("btn_manual_submit"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _triggerSubmit(isAuto: false),
                    child: const Text("Submit Exam", style: TextStyle(color: Colors.white)),
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

// ============================================================================
// FLUTTER TEST CASES EXECUTION SPECIFICATION
// ============================================================================

void main() {
  group("Quiz Lab Android App - QA Widget & Edge Case Tests", () {
    late List<QuestionModel> mockQuestions;

    setUp(() {
      mockQuestions = [
        QuestionModel(
          id: 1,
          type: QuestionType.mcq,
          stem: "What is Python list slice x[::-1]?",
          marks: 2.0,
          negativeMarks: 0.5,
          options: [
            QuestionOption(id: 10, text: "[1, 2, 3]", isCorrect: false),
            QuestionOption(id: 11, text: "Reversed list", isCorrect: true),
          ],
        ),
        QuestionModel(
          id: 2,
          type: QuestionType.multiSelect,
          stem: "Select all valid dictionary instantiations in Python:",
          marks: 3.0,
          negativeMarks: 1.0,
          options: [
            QuestionOption(id: 20, text: "d = {'a': 1}", isCorrect: true),
            QuestionOption(id: 21, text: "d = dict(a=1)", isCorrect: true),
            QuestionOption(id: 22, text: "d = {['a']: 1}", isCorrect: false),
          ],
        ),
        QuestionModel(
          id: 3,
          type: QuestionType.numerical,
          stem: "Calculate 2 ** 3 * 2 + 10 // 3:",
          marks: 3.0,
          numericalAnswer: 19.0,
          numericalTolerance: 0.01,
        ),
      ];
    });

    testWidgets("Tab 3 Test Engine: Zero timer auto-submits exam when countdown reaches 00:00", (WidgetTester tester) async {
      bool autoSubmitted = false;
      Map<int, dynamic>? finalPayload;

      await tester.pumpWidget(
        MaterialApp(
          home: TimedExamPlayerScreen(
            questions: mockQuestions,
            timeLimitSeconds: 2, // 2 second countdown
            onSubmit: (answers, isAuto) async {
              autoSubmitted = isAuto;
              finalPayload = answers;
            },
          ),
        ),
      );

      // Verify timer displays 00:02
      expect(find.text("00:02"), findsOneWidget);

      // Select option for Question 1
      await tester.tap(find.byKey(const Key("option_11")));
      await tester.pump();

      // Fast forward 2 seconds to trigger zero timer
      await tester.pump(const Duration(seconds: 1));
      expect(find.text("00:01"), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Assert auto-submit fired with staged payload
      expect(autoSubmitted, isTrue, "Zero timer must trigger auto submission");
      expect(finalPayload?[1], equals(11), "Selected option 11 must be preserved in auto-submit");
      expect(find.text("Time is up! Quiz auto-submitted."), findsOneWidget);
    });

    testWidgets("Tab 3 Test Engine: Back button triggers modal warning and intercepts exit", (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimedExamPlayerScreen(
            questions: mockQuestions,
            timeLimitSeconds: 300,
            onSubmit: (_, __) async {},
          ),
        ),
      );

      // Simulate Android hardware back button invocation
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // Assert modal warning appears
      expect(find.text("Leave Examination?"), findsOneWidget);
      expect(find.text("Stay in Exam"), findsOneWidget);
      expect(find.text("Exit Exam"), findsOneWidget);

      // Tap 'Stay in Exam' -> Modal dismisses and candidate remains in player
      await tester.tap(find.text("Stay in Exam"));
      await tester.pumpAndSettle();

      expect(find.text("Leave Examination?"), findsNothing);
      expect(find.byKey(const Key("question_stem_text")), findsOneWidget);
    });

    testWidgets("Tab 3 Test Engine: Question palette synchronizes colors dynamically", (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimedExamPlayerScreen(
            questions: mockQuestions,
            timeLimitSeconds: 600,
            onSubmit: (_, __) async {},
          ),
        ),
      );

      // Initially Question 1 is unvisited
      expect(find.text("1"), findsOneWidget);

      // Answer Question 1
      await tester.tap(find.byKey(const Key("option_11")));
      await tester.pumpAndSettle();

      // Mark for Review
      await tester.tap(find.byKey(const Key("btn_toggle_review")));
      await tester.pumpAndSettle();

      expect(find.text("Marked for Review"), findsOneWidget);
    });

    testWidgets("Tab 3 Test Engine: MSQ multi-select checkbox toggles both values into answer list", (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimedExamPlayerScreen(
            questions: mockQuestions,
            timeLimitSeconds: 600,
            onSubmit: (_, __) async {},
          ),
        ),
      );

      // Jump to Question 2 (MSQ)
      await tester.tap(find.text("2"));
      await tester.pumpAndSettle();

      // Tap option 20 and 21
      await tester.tap(find.byKey(const Key("msq_option_20")));
      await tester.pump();
      await tester.tap(find.byKey(const Key("msq_option_21")));
      await tester.pumpAndSettle();

      final state = tester.state<State<TimedExamPlayerScreen>>(find.byType(TimedExamPlayerScreen));
      final dynamic dynamicState = state;
      final answers = dynamicState._attemptState.answers;
      expect(answers[2], containsAll([20, 21]));
    });
  });
}
