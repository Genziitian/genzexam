import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_exceptions.dart';

class GeneratedPracticePaper {
  final int id;
  final String title;
  final int questionCount;
  final int timeLimitMinutes;
  final int? spinsRemaining;

  const GeneratedPracticePaper({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.timeLimitMinutes,
    this.spinsRemaining,
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
      spinsRemaining: ((json['quota'] as Map?)?['remaining'] as num?)?.toInt(),
    );
  }
}

class SpinPracticeQuota {
  final bool isPro;
  final int limit;
  final int used;
  final int remaining;

  const SpinPracticeQuota({
    required this.isPro,
    required this.limit,
    required this.used,
    required this.remaining,
  });

  factory SpinPracticeQuota.fromJson(Map<String, dynamic> json) {
    final limit = json['limit'];
    final used = json['used'];
    final remaining = json['remaining'];
    if (json['is_pro'] is! bool ||
        limit is! int ||
        limit < 1 ||
        used is! int ||
        used < 0 ||
        remaining is! int ||
        remaining < 0 ||
        remaining > limit) {
      throw const ApiException(
        message: 'Could not check your available spins. Please try again.',
      );
    }
    return SpinPracticeQuota(
      isPro: json['is_pro'] == true,
      limit: limit,
      used: used,
      remaining: remaining,
    );
  }
}

class SpinPracticeService {
  final ApiClient client;
  SpinPracticeService({required this.client});

  Future<SpinPracticeQuota> getQuota() async {
    final response = await client.get<Map<String, dynamic>>(
      '/student/spin-practice/quota',
      options: Options(extra: {'loadingBlocking': false}),
    );
    final raw = response.data?['quota'];
    if (raw is! Map) {
      throw const ApiException(
        message: 'Could not check your available spins. Please try again.',
      );
    }
    return SpinPracticeQuota.fromJson(Map<String, dynamic>.from(raw));
  }

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
