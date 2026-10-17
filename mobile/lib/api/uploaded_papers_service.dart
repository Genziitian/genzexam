import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'api_client.dart';
import '../state/app_activity.dart';

class UploadedPaper {
  final int id;
  final String title;
  final int questionCount;

  const UploadedPaper({
    required this.id,
    required this.title,
    required this.questionCount,
  });

  factory UploadedPaper.fromJson(Map<String, dynamic> json) => UploadedPaper(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String? ?? 'My paper',
    questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
  );
}

/// The student's rolling upload allowance, as reported by the server.
class UploadQuota {
  final bool isPro;
  final int limit;
  final int proLimit;
  final int used;
  final int remaining;
  final int windowDays;
  final DateTime? resetsAt;

  const UploadQuota({
    required this.isPro,
    required this.limit,
    required this.proLimit,
    required this.used,
    required this.remaining,
    required this.windowDays,
    this.resetsAt,
  });

  factory UploadQuota.fromJson(Map<String, dynamic> json) => UploadQuota(
    isPro: json['is_pro'] as bool? ?? false,
    limit: (json['limit'] as num?)?.toInt() ?? 0,
    proLimit: (json['pro_limit'] as num?)?.toInt() ?? 5,
    used: (json['used'] as num?)?.toInt() ?? 0,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    windowDays: (json['window_days'] as num?)?.toInt() ?? 7,
    resetsAt: DateTime.tryParse(json['resets_at'] as String? ?? '')?.toLocal(),
  );
}

class UploadedPapersData {
  final List<UploadedPaper> papers;
  final UploadQuota? quota;
  const UploadedPapersData(this.papers, this.quota);
}

class UploadedPapersService {
  final ApiClient _client;
  UploadedPapersService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<UploadedPapersData> list() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/student/uploaded-papers',
    );
    final papers = (response.data?['papers'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UploadedPaper.fromJson)
        .toList();
    final quota = response.data?['quota'];
    return UploadedPapersData(
      papers,
      quota is Map<String, dynamic> ? UploadQuota.fromJson(quota) : null,
    );
  }

  Future<UploadedPaper> upload(PlatformFile file) =>
      AppActivity.run('Uploading and preparing your paper…', () async {
        final path = file.path;
        if (path == null) throw Exception('Could not read the selected file.');
        final form = FormData.fromMap({
          'paper': await MultipartFile.fromFile(path, filename: file.name),
        });
        final response = await _client.post<Map<String, dynamic>>(
          '/student/uploaded-papers',
          data: form,
          options: Options(
            contentType: 'multipart/form-data',
            sendTimeout: const Duration(minutes: 6),
            receiveTimeout: const Duration(minutes: 6),
          ),
        );
        return UploadedPaper.fromJson(response.data ?? const {});
      });
}
