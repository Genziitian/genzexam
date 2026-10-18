import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_exceptions.dart';

class GeneratedPracticePaper {
  final int id;
  final String title;
  final int questionCount;
  final int timeLimitMinutes;

  const GeneratedPracticePaper({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.timeLimitMinutes,
  });

  factory GeneratedPracticePaper.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final count = (json['question_count'] as num?)?.toInt() ?? 0;
    final minutes = (json['time_limit_minutes'] as num?)?.toInt() ?? 0;
    if (id <= 0 || count <= 0 || minutes <= 0) {
      throw const ApiException(
        message: 'The server returned an incomplete paper. Check My Papers before spinning again.',
      );
    }
    return GeneratedPracticePaper(
      id: id,
      title: json['title'] as String? ?? 'Practice paper',
      questionCount: count,
      timeLimitMinutes: minutes,
    );
  }
}

class SpinPracticeService {
  final ApiClient client;
  SpinPracticeService({required this.client});

  Future<GeneratedPracticePaper> generate({
    required int courseId,
    required int weekMin,
    required int weekMax,
    required List<String> paperTypes,
    String title = '',
  }) async {
    final response = await client.post<Map<String, dynamic>>(
      '/student/spin-practice',
      options: Options(extra: {'loadingBlocking': false}),
      data: {
        'course_id': courseId,
        'week_min': weekMin,
        'week_max': weekMax,
        'paper_types': paperTypes,
        'title': title.trim(),
      },
    );
    return GeneratedPracticePaper.fromJson(response.data ?? {});
  }
}
