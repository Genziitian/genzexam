import 'api_client.dart';
import 'models/exam_platform_model.dart';

/// Real Exam Platform service communicating with backend/app/Http/Controllers/ExamPlatformController.php.
///
/// Supports candidate session synchronization and proctor/manager live exam control actions:
/// - State retrieval & candidate progress syncing
/// - Proctor live exam actions (start, pause, resume, end, extend_time, lock_session, approve_reentry)
/// - Full exam state reset (Manager only)
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

  /// Dispatches a proctor or manager action to control the live exam.
  /// Supported actions: 'start_exam', 'pause_exam', 'resume_exam', 'end_exam',
  /// 'extend_time', 'toggle_type', 'publish_results', 'add_whitelist',
  /// 'remove_whitelist', 'approve_reentry', 'reject_reentry', 'lock_session'.
  /// Endpoint: POST /api/exam-platform/action (Admin & Manager only)
  Future<Map<String, dynamic>> dispatchAction(
    String action, [
    Map<String, dynamic>? parameters,
  ]) async {
    final data = <String, dynamic>{'action': action};
    if (parameters != null) {
      data.addAll(parameters);
    }

    final response = await _client.post<Map<String, dynamic>>(
      '/exam-platform/action',
      data: data,
    );

    return response.data ?? {};
  }

  /// Resets the live exam state back to defaults.
  /// Endpoint: POST /api/exam-platform/reset (Manager only)
  Future<Map<String, dynamic>> resetState() async {
    final response = await _client.post<Map<String, dynamic>>('/exam-platform/reset');
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
