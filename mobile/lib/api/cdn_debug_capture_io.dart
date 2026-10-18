import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

Future<void> saveCdnDebugCapture({
  required String body,
  required String requestId,
  required String method,
  required String path,
  required String url,
}) async {
  if (!kDebugMode) return;
  try {
    final directory = Directory(
      '${Directory.systemTemp.path}/quizlab-cdn-evidence',
    );
    await directory.create(recursive: true);
    final safeId = requestId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final stem = '${directory.path}/$safeId';
    await File('$stem.html').writeAsString(body, flush: true);
    final client = HttpClient();
    final userAgent = client.userAgent;
    client.close(force: true);
    final utc = DateTime.now().toUtc();
    await File('$stem.json').writeAsString(
      jsonEncode({
        'timeUtc': utc.toIso8601String(),
        'timeIST':
            '${utc.add(const Duration(hours: 5, minutes: 30)).toIso8601String().replaceAll('Z', '')}+05:30',
        'source': 'Flutter app HTML 403 response',
        'method': method,
        'path': path,
        'url': url,
        'firstBodyLine': body.split('\n').first,
        'status': 403,
        'contentType': 'text/html',
        'requestId': requestId,
        'defaultUserAgent': userAgent,
      }),
      flush: true,
    );
    debugPrint('Quiz LAB CDN capture: $stem');
  } catch (_) {
    // Diagnostics must never change request handling or expose account data.
    debugPrint('Quiz LAB CDN capture: could not save diagnostic');
  }
}
