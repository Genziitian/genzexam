import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'api_client.dart';

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

class UploadedPapersService {
  final ApiClient _client;
  UploadedPapersService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<List<UploadedPaper>> list() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/student/uploaded-papers',
    );
    return (response.data?['papers'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UploadedPaper.fromJson)
        .toList();
  }

  Future<UploadedPaper> upload(PlatformFile file) async {
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
  }
}
