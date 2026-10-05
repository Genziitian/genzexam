import 'api_client.dart';
import 'models/admin_model.dart';

/// Real Admin service communicating with backend/app/Http/Controllers/Admin/ controllers.
///
/// Role rank permissions enforced on server:
/// - Managers (rank 2): Total control, can set roles, delete users, manage all below.
/// - Admins (rank 1): Can view users, toggle active/pro for students only.
class AdminService {
  final ApiClient _client;

  AdminService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Fetches platform statistics (total students, quizzes, questions, courses, attempts today).
  /// Endpoint: GET /api/admin/stats
  Future<AdminStatsResponse> getStats() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/stats');
    return AdminStatsResponse.fromJson(response.data!);
  }

  /// Lists platform users with filter, search, and pagination.
  /// Endpoint: GET /api/admin/users
  Future<AdminUserListResponse> getUsers({
    String? search,
    String filter = 'all', // 'all', 'managers', 'admins', 'students', 'pro', 'inactive', 'active'
    int page = 1,
    int perPage = 25,
  }) async {
    final query = <String, dynamic>{
      'filter': filter,
      'page': page,
      'per_page': perPage,
    };
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/users',
      queryParameters: query,
    );
    return AdminUserListResponse.fromJson(response.data!);
  }

  /// Toggles active status of an account. Admins may only toggle students.
  /// Endpoint: PATCH /api/admin/users/{userId}/toggle-active
  Future<Map<String, dynamic>> toggleActive(int userId) async {
    final response = await _client.patch<Map<String, dynamic>>('/admin/users/$userId/toggle-active');
    return response.data ?? {};
  }

  /// Toggles Pro membership of an account. Admins may only toggle students.
  /// Endpoint: PATCH /api/admin/users/{userId}/toggle-pro
  Future<Map<String, dynamic>> togglePro(int userId) async {
    final response = await _client.patch<Map<String, dynamic>>('/admin/users/$userId/toggle-pro');
    return response.data ?? {};
  }

  /// Sets user role ('student', 'admin', 'manager'). Manager only.
  /// Endpoint: PATCH /api/admin/users/{userId}/role
  Future<Map<String, dynamic>> setRole(int userId, String role) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/users/$userId/role',
      data: {'role': role},
    );
    return response.data ?? {};
  }

  /// Permanently deletes a user account. Manager only.
  /// Endpoint: DELETE /api/admin/users/{userId}
  Future<bool> deleteUser(int userId) async {
    final response = await _client.delete<Map<String, dynamic>>('/admin/users/$userId');
    return response.statusCode == 200;
  }
}
