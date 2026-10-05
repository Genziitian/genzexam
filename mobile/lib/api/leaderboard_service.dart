import 'api_client.dart';
import 'models/leaderboard_model.dart';

/// Real Leaderboard service communicating with backend/app/Http/Controllers/LeaderboardController.php.
class LeaderboardService {
  final ApiClient _client;

  LeaderboardService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Fetches the global XP leaderboard (top 50 active non-admin students and current user rank).
  /// Endpoint: GET /api/leaderboard
  Future<LeaderboardData> getLeaderboard() async {
    final response = await _client.get<Map<String, dynamic>>('/leaderboard');
    return LeaderboardData.fromJson(response.data!);
  }
}
