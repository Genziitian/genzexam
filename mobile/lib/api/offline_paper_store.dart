import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'quiz_service.dart';
import 'models/quiz_model.dart';

/// Encrypted on-device copies explicitly downloaded through the Pro endpoint.
/// Answers are saved after every edit so an OS process kill cannot erase work.
class OfflinePaperStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final Set<String> _openPapers = {};

  static void holdPaper(int userId, int quizId) =>
      _openPapers.add(_key(userId, quizId));

  static void releasePaper(int userId, int quizId) =>
      _openPapers.remove(_key(userId, quizId));

  static String _key(int userId, int quizId) => 'paper_cache_${userId}_$quizId';

  static Future<void> cacheQuiz(int userId, QuizDetail quiz) async {
    // Embed diagrams too: a saved URL alone cannot work in airplane mode.
    // A separate client avoids sending the account token to image hosts.
    final media = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.bytes,
      ),
    );
    final images = <String, String>{};
    var totalBytes = 0;
    Future<String> saveImage(String source) async {
      if (source.isEmpty || source.startsWith('data:image/')) return source;
      if (images.containsKey(source)) return images[source]!;
      final uri = Uri.parse(ApiClient.defaultBaseUrl).resolve(source);
      if (uri.scheme != 'https')
        throw const FormatException('Image must use HTTPS.');
      final cancel = CancelToken();
      final response = await media.get<List<int>>(
        uri.toString(),
        cancelToken: cancel,
        onReceiveProgress: (received, _) {
          if (received > 5 * 1024 * 1024) cancel.cancel('Image is too large.');
        },
      );
      final bytes = response.data!;
      totalBytes += bytes.length;
      final mime =
          response.headers.value('content-type')?.split(';').first ?? '';
      if (!mime.startsWith('image/') || totalBytes > 20 * 1024 * 1024) {
        throw const FormatException('Paper images could not be saved.');
      }
      return images[source] = 'data:$mime;base64,${base64Encode(bytes)}';
    }

    Future<dynamic> embed(dynamic value) async {
      if (value is List) {
        final result = <dynamic>[];
        for (final item in value) {
          result.add(await embed(item));
        }
        return result;
      }
      if (value is Map) {
        final copy = <String, dynamic>{};
        final image = (value['kind'] ?? value['type']) == 'image';
        for (final entry in value.entries) {
          final key = entry.key.toString();
          copy[key] =
              entry.value is String &&
                  (key == 'stem_image' ||
                      (image && ['url', 'src', 'asset', 'value'].contains(key)))
              ? await saveImage(entry.value as String)
              : await embed(entry.value);
        }
        return copy;
      }
      return value;
    }

    dynamic saved;
    try {
      saved = await embed(quiz.toJson());
    } finally {
      media.close(force: true);
    }
    await _storage.write(
      key: _key(userId, quiz.id),
      value: jsonEncode({'quiz': saved}),
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
    QuizService service, {
    bool Function()? canSync,
  }) async {
    final all = await _storage.readAll();
    final prefix = 'paper_cache_${userId}_';
    for (final entry in all.entries) {
      if (canSync != null && !canSync()) return;
      if (!entry.key.startsWith(prefix) || !entry.key.endsWith('_draft'))
        continue;
      final idPart = entry.key.substring(
        prefix.length,
        entry.key.length - '_draft'.length,
      );
      final quizId = int.tryParse(idPart);
      if (quizId == null) continue;
      // The background worker must never finish a paper still on screen.
      if (_openPapers.contains(_key(userId, quizId))) continue;
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
          if (canSync != null && !canSync()) return;
          if (_openPapers.contains(_key(userId, quizId))) continue;
          await clearDraft(userId, quizId);
          continue;
        } catch (_) {
          // It was not submitted yet. Continue with the saved answers.
        }
      }

      try {
        if (_openPapers.contains(_key(userId, quizId))) continue;
        if (canSync != null && !canSync()) return;
        attemptId ??= (await service.startAttempt(quizId)).attemptId;
        if (canSync != null && !canSync()) return;
        if (_openPapers.contains(_key(userId, quizId))) continue;
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
        if (canSync != null && !canSync()) return;
        if (_openPapers.contains(_key(userId, quizId))) continue;
        await service.submitAttempt(attemptId, payload);
        await clearDraft(userId, quizId);
      } catch (_) {
        // Keep the draft; the next launch/reconnection can retry it.
      }
    }
  }
}
