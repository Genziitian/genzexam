import 'api_client.dart';
import 'models/exam_platform_model.dart';

/// Real Exam Platform service communicating with backend/app/Http/Controllers/ExamPlatformController.php.
class ExamPlatformService {
  final ApiClient _client;

  ExamPlatformService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Checks server health probe.
  /// Endpoint: GET /api/exam-platform/health
  Future<ExamPlatformHealth> getHealth() async {
    final response = await _client.get<Map<String, dynamic>>('/exam-platform/health');
    return ExamPlatformHealth.fromJson(response.data!);
  }

  /// Fetches complete live exam state.
  /// Endpoint: GET /api/exam-platform/state
  Future<Map<String, dynamic>> getState() async {
    final response = await _client.get<Map<String, dynamic>>('/exam-platform/state');
    return response.data ?? {};
  }

  /// Syncs candidate session state (answers, time remaining, etc.) and pending reentry requests.
  /// Endpoint: POST /api/exam-platform/state
  Future<Map<String, dynamic>> syncState({
    required String email,
    required Map<String, dynamic> sessionUpdates,
    List<ReentryRequest>? reentryRequests,
  }) async {
    final payload = <String, dynamic>{
      'studentSessions': {
        email: sessionUpdates,
      },
    };
    if (reentryRequests != null) {
      payload['reentryRequests'] = reentryRequests.map((r) => r.toJson()).toList();
    }

    final response = await _client.post<Map<String, dynamic>>(
      '/exam-platform/state',
      data: payload,
    );

    return (response.data?['state'] as Map<String, dynamic>?) ?? {};
  }

  /// Fetches exam chat messages.
  /// Endpoint: GET /api/exam-platform/chat
  Future<List<ExamChatMessage>> getChat() async {
    final response = await _client.get<List<dynamic>>('/exam-platform/chat');
    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map((m) => ExamChatMessage.fromJson(m))
        .toList();
  }

  /// Sends a chat message to proctors/examiners during live exam.
  /// The server stamps the student's name, email, and role from their session.
  /// Endpoint: POST /api/exam-platform/chat
  Future<ExamChatMessage> sendChat(String text) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/exam-platform/chat',
      data: {
        'message': {
          'text': text.trim(),
        },
      },
    );

    final msgData = response.data!['message'] as Map<String, dynamic>;
    return ExamChatMessage.fromJson(msgData);
  }

  /// Fetches pending reentry requests.
  /// Endpoint: GET /api/exam-platform/reentry
  Future<List<ReentryRequest>> getReentry() async {
    final response = await _client.get<List<dynamic>>('/exam-platform/reentry');
    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map((r) => ReentryRequest.fromJson(r))
        .toList();
  }
}
