import 'api_client.dart';
import 'models/quiz_model.dart';

/// Real Quiz service communicating with:
/// - backend/app/Http/Controllers/QuizController.php
/// - backend/app/Http/Controllers/AttemptController.php
class QuizService {
  final ApiClient _client;

  QuizService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Fetches the quiz questions and options for an active quiz.
  /// Endpoint: GET /api/quizzes/{id}
  Future<QuizDetail> getQuiz(int quizId) async {
    final response = await _client.get<Map<String, dynamic>>('/quizzes/$quizId');
    return QuizDetail.fromJson(response.data!);
  }

  /// Offline copies are a Pro entitlement and use a dedicated server gate.
  Future<QuizDetail> downloadQuiz(int quizId) async {
    final response = await _client.get<Map<String, dynamic>>('/quizzes/$quizId/offline-download');
    return QuizDetail.fromJson(response.data!);
  }

  /// Starts or resumes an attempt for the specified quiz.
  /// If an in-progress attempt already exists, the server authoritatively returns it.
  /// Endpoint: POST /api/quizzes/{id}/attempts
  Future<StartAttemptResponse> startAttempt(int quizId) async {
    final response = await _client.post<Map<String, dynamic>>('/quizzes/$quizId/attempts');
    return StartAttemptResponse.fromJson(response.data!);
  }

  /// Submits the completed attempt answers for server auto-scoring.
  /// Endpoint: POST /api/attempts/{id}/submit
  Future<SubmitQuizResponse> submitAttempt(
    int attemptId,
    List<SubmitAnswerPayload> answers,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/attempts/$attemptId/submit',
      data: {
        'answers': answers.map((a) => a.toJson()).toList(),
      },
    );
    return SubmitQuizResponse.fromJson(response.data!);
  }

  /// Fetches the scored review of a submitted attempt.
  /// Includes correctness, marks awarded, explanations, and official acceptable answers.
  /// Endpoint: GET /api/attempts/{id}/result
  Future<QuizResultData> getResult(int attemptId) async {
    final response = await _client.get<Map<String, dynamic>>('/attempts/$attemptId/result');
    return QuizResultData.fromJson(response.data!);
  }

  /// Fetches the leaderboard for a specific quiz (top 10 + current user rank).
  /// Endpoint: GET /api/quizzes/{id}/leaderboard
  Future<QuizLeaderboard> getLeaderboard(int quizId) async {
    final response = await _client.get<Map<String, dynamic>>('/quizzes/$quizId/leaderboard');
    return QuizLeaderboard.fromJson(response.data!);
  }
}
