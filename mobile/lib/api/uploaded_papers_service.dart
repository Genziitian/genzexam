import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'api_client.dart';
import 'api_exceptions.dart';
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

  factory UploadedPaper.fromJson(Map<String, dynamic> json) {
    final id = _integer(json['id'], minimum: 1);
    final count = _integer(json['question_count']);
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Missing paper title.');
    }
    return UploadedPaper(id: id, title: title, questionCount: count);
  }
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

  factory UploadQuota.fromJson(Map<String, dynamic> json) {
    final isPro = json['is_pro'];
    final limit = _integer(json['limit'], minimum: 1);
    final used = _integer(json['used']);
    final remaining = _integer(json['remaining']);
    final rawReset = json['resets_at'];
    final reset = rawReset is String ? DateTime.tryParse(rawReset) : null;
    if (isPro is! bool ||
        used + remaining != limit ||
        (rawReset != null && reset == null)) {
      throw const FormatException('Invalid upload allowance.');
    }
    return UploadQuota(
      isPro: isPro,
      limit: limit,
      proLimit: _integer(json['pro_limit'] ?? 5, minimum: 1),
      used: used,
      remaining: remaining,
      windowDays: _integer(json['window_days'] ?? 7, minimum: 1),
      resetsAt: reset?.toLocal(),
    );
  }
}

int _integer(dynamic value, {int minimum = 0}) {
  if (value is! num ||
      !value.isFinite ||
      value < minimum ||
      value != value.toInt()) {
    throw const FormatException('Invalid number in upload response.');
  }
  return value.toInt();
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
    final response = await _client.get<dynamic>('/student/uploaded-papers');
    try {
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['papers'] is! List ||
          data['quota'] is! Map<String, dynamic>) {
        throw const FormatException('Missing upload data.');
      }
      final papers = (data['papers'] as List).map((paper) {
        if (paper is! Map<String, dynamic>) {
          throw const FormatException('Invalid paper.');
        }
        return UploadedPaper.fromJson(paper);
      }).toList();
      return UploadedPapersData(
        papers,
        UploadQuota.fromJson(data['quota'] as Map<String, dynamic>),
      );
    } on FormatException {
      throw const ApiException(
        message: 'Could not confirm your papers and upload allowance. Please try again.',
      );
    }
  }

  Future<UploadedPaper> upload(
    PlatformFile file,
  ) => AppActivity.run('Uploading and preparing your paper…', () async {
    const maxBytes = 10 * 1024 * 1024;
    if (!const ['pdf', 'json'].contains(file.extension?.toLowerCase())) {
      throw const ApiException(message: 'Choose a PDF or JSON paper.');
    }
    final bytes = BytesBuilder(copy: false);
    try {
      if ((file.lengthSync() ?? 0) > maxBytes) {
        throw const ApiException(message: 'Choose a paper smaller than 10 MB.');
      }
      // Read through the picker API: selected files need not have a local
      // path. Bound the actual bytes even when picker size metadata is absent.
      await for (final chunk in file.readAsByteStream()) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const ApiException(
            message: 'Choose a paper smaller than 10 MB.',
          );
        }
        bytes.add(chunk);
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Could not read this file. Choose it again or save it on your device first.',
      );
    }
    if (bytes.isEmpty) {
      throw const ApiException(
        message: 'This file is empty. Choose another paper.',
      );
    }
    final form = FormData.fromMap({
      'paper': MultipartFile.fromBytes(bytes.takeBytes(), filename: file.name),
    });
    final response = await _client.post<dynamic>(
      '/student/uploaded-papers',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 6),
        receiveTimeout: const Duration(minutes: 6),
      ),
    );
    try {
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Missing uploaded paper.');
      }
      final paper = UploadedPaper.fromJson(data);
      if (paper.questionCount == 0) {
        throw const FormatException('No converted questions.');
      }
      return paper;
    } on FormatException {
      throw const ApiException(
        message: 'The server did not confirm a usable test. Refresh your papers before uploading again.',
      );
    }
  });
}
