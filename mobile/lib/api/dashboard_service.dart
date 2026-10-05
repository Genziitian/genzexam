import 'api_client.dart';
import 'models/dashboard_model.dart';

/// Real Dashboard service communicating with backend/app/Http/Controllers/DashboardController.php.
///
/// Fetches authoritative server state:
/// - Dynamic time greeting
/// - 28-day activity streak
/// - 12-week accuracy & study hours metrics
/// - Global relative ranking & movement
/// - 12-week performance analytics (accuracy, speed, score, attempts)
/// - Today's smart next quiz challenge
/// - Active student headcount in last 15 mins
/// - Live community completion feed
class DashboardService {
  final ApiClient _client;

  DashboardService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Fetches the live student dashboard data.
  /// Endpoint: GET /api/student/dashboard
  Future<DashboardData> getDashboard() async {
    final response = await _client.get<Map<String, dynamic>>('/student/dashboard');
    return DashboardData.fromJson(response.data!);
  }
}
