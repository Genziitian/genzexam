import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'quiz_service.dart';
import 'models/quiz_model.dart';

/// Small encrypted on-device cache for papers the signed-in student has opened.
/// Answers are saved after every edit so an OS process kill cannot erase work.
class OfflinePaperStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _key(int userId, int quizId) => 'paper_cache_${userId}_$quizId';

  static Future<void> cacheQuiz(int userId, QuizDetail quiz) async {
    await _storage.write(
      key: _key(userId, quiz.id),
      value: jsonEncode({'quiz': quiz.toJson()}),
    );
  }

  static Future<QuizDetail?> readQuiz(int userId, int quizId) async {
    try {
      final raw = await _storage.read(key: _key(userId, quizId));
      if (raw == null) return null;
      return QuizDetail.fromJson(
        jsonDecode(raw)['quiz'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<QuizDetail>> listDownloadedPapers(int userId) async {
    final all = await _storage.readAll();
    final prefix = 'paper_cache_${userId}_';
    final papers = <QuizDetail>[];
    for (final entry in all.entries) {
      if (!entry.key.startsWith(prefix) || entry.key.endsWith('_draft')) {
        continue;
      }
      try {
        final value = jsonDecode(entry.value) as Map<String, dynamic>;
        final quiz = QuizDetail.fromJson(value['quiz'] as Map<String, dynamic>);
        papers.add(quiz);
      } catch (_) {
        // Ignore damaged or older cache entries instead of breaking the list.
      }
    }
    papers.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return papers;
  }

  static Future<Map<String, dynamic>?> readDraft(int userId, int quizId) async {
    try {
      final raw = await _storage.read(key: '${_key(userId, quizId)}_draft');
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeDraft(
    int userId,
    int quizId,
    Map<String, dynamic> draft,
  ) => _storage.write(
    key: '${_key(userId, quizId)}_draft',
    value: jsonEncode(draft),
  );

  static Future<void> clearDraft(int userId, int quizId) =>
      _storage.delete(key: '${_key(userId, quizId)}_draft');

  /// After a process restart the previous screen cannot finish its network
  /// request. Submit each saved attempt once the account is authenticated.
  static Future<void> syncInterruptedDrafts(
    int userId,
    QuizService service,
  ) async {
    final all = await _storage.readAll();
    final prefix = 'paper_cache_${userId}_';
    for (final entry in all.entries) {
      if (!entry.key.startsWith(prefix) || !entry.key.endsWith('_draft'))
        continue;
      final idPart = entry.key.substring(
        prefix.length,
        entry.key.length - '_draft'.length,
      );
      final quizId = int.tryParse(idPart);
      if (quizId == null) continue;
      Map<String, dynamic> draft;
      try {
        draft = jsonDecode(entry.value) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      int? attemptId = (draft['attempt_id'] as num?)?.toInt();
      if (attemptId != null) {
        try {
          await service.getResult(attemptId);
          await clearDraft(userId, quizId);
          continue;
        } catch (_) {
          // It was not submitted yet. Continue with the saved answers.
        }
      }

      try {
        attemptId ??= (await service.startAttempt(quizId)).attemptId;
        final rawAnswers = draft['answers'];
        final payload = <SubmitAnswerPayload>[];
        if (rawAnswers is Map) {
          for (final item in rawAnswers.entries) {
            final questionId = int.tryParse(item.key.toString());
            if (questionId == null || item.value is! Map) continue;
            final answer = Map<String, dynamic>.from(item.value as Map);
            payload.add(
              SubmitAnswerPayload(
                questionId: questionId,
                selectedOptionIds: (answer['selected_option_ids'] as List?)
                    ?.map((id) => (id as num).toInt())
                    .toList(),
                textAnswer: answer['text_answer']?.toString(),
                numericalAnswer: answer['numerical_answer'] as num?,
              ),
            );
          }
        }
        await _storage.write(
          key: entry.key,
          value: jsonEncode({
            ...draft,
            'attempt_id': attemptId,
            'pending_submit': true,
          }),
        );
        await service.submitAttempt(attemptId, payload);
        await clearDraft(userId, quizId);
      } catch (_) {
        // Keep the draft; the next launch/reconnection can retry it.
      }
    }
  }
}
