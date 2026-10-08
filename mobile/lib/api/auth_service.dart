import 'dart:math';

import 'api_client.dart';
import 'api_exceptions.dart';
import 'models/auth_model.dart';

/// Real authentication service communicating with backend/app/Http/Controllers/AuthController.php.
///
/// Handles:
/// - Email/Password login
/// - 6-digit OTP verification
/// - Registration & OTP resending
/// - Password recovery & password change
/// - Session inspection (GET /auth/me)
/// - Logout with Sanctum token deletion
class AuthService {
  final ApiClient _client;

  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  ApiClient get client => _client;

  /// Logs in a user with email and password.
  ///
  /// On success (200 OK):
  /// - Saves the returned Sanctum personal access token directly into FlutterSecureStorage.
  /// - Returns [AuthSuccessResponse] with token and user profile.
  ///
  /// Throws [ApiException] on:
  /// - 401: Invalid credentials.
  /// - 403: Email unverified (contains needsVerification: true, email: ...).
  /// - 403: Account deactivated.
  /// - 422: Validation error.
  Future<AuthSuccessResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
    );

    final authResponse = AuthSuccessResponse.fromJson(response.data!);
    // Authoritative Sanctum token storage
    await _client.saveAuthToken(authResponse.token);
    return authResponse;
  }

  // ---------------------------------------------------------------------------
  // Google sign-in (browser handoff)
  //
  // The app opens the backend's Google sign-in page in the browser with a random
  // one-time id. When Google finishes, the backend parks the session under that id
  // and the app collects it with [claimGoogleHandoff].
  // ---------------------------------------------------------------------------

  /// Random one-time id (48 chars) that links the browser sign-in to this app.
  static String newGoogleHandoffId() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(48, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }

  /// Address of the backend's Google sign-in page for the given handoff id.
  Uri googleSignInUri(String handoffId) {
    return Uri.parse('${ApiClient.defaultBaseUrl}/auth/google')
        .replace(queryParameters: {'handoff': handoffId});
  }

  /// Collects the session once the browser sign-in has finished.
  /// Returns null while the sign-in is still in progress.
  Future<AuthSuccessResponse?> claimGoogleHandoff(String handoffId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/google/handoff',
        data: {'handoff': handoffId},
      );
      final data = response.data;
      if (data == null || data['token'] == null || data['user'] == null) return null;
      final authResponse = AuthSuccessResponse.fromJson(data);
      await _client.saveAuthToken(authResponse.token);
      return authResponse;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null; // still waiting
      rethrow;
    }
  }

  /// Native Google sign-in: exchanges the ID token from Google's account card
  /// for a session. Endpoint: POST /api/auth/google/mobile
  Future<AuthSuccessResponse> loginWithGoogleIdToken(String idToken) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/google/mobile',
      data: {'id_token': idToken},
    );
    final authResponse = AuthSuccessResponse.fromJson(response.data!);
    await _client.saveAuthToken(authResponse.token);
    return authResponse;
  }

  /// Registers a new user account.
  Future<RegisterResponse> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    return RegisterResponse.fromJson(response.data!);
  }

  /// Sends a password reset OTP to the user's email.
  Future<String> forgotPassword({required String email}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/password/forgot',
      data: {'email': email.trim()},
    );

    return (response.data?['message'] ?? 'Password reset OTP sent successfully') as String;
  }

  /// Resets user password using the verified OTP.
  Future<String> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/password/reset',
      data: {
        'email': email.trim(),
        'otp': otp.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    return (response.data?['message'] ?? 'Password reset successfully.') as String;
  }

  /// Changes the authenticated student's password.
  Future<String> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/password/change',
      data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    return (response.data?['message'] ?? 'Password changed successfully') as String;
  }

  /// Fetches the authenticated user profile with XP, level progress, and badges.
  /// Endpoint: GET /api/auth/me
  Future<UserModel> getMe() async {
    final response = await _client.get<Map<String, dynamic>>('/auth/me');
    final userData = response.data!['user'] as Map<String, dynamic>;
    return UserModel.fromJson(userData);
  }

  /// Logs out the user by revoking the Sanctum token on the backend
  /// and deleting it from client-side secure storage.
  Future<void> logout() async {
    try {
      await _client.post<Map<String, dynamic>>('/auth/logout');
    } catch (_) {
      // Even if network fails or token was already invalidated on server,
      // client must clean up local secure token.
    } finally {
      await _client.deleteAuthToken();
    }
  }

  /// Permanently deletes the student account and all stored records.
  /// Complies with Google Play Store User Data Deletion requirements.
  Future<void> deleteAccount() async {
    try {
      await _client.delete<Map<String, dynamic>>('/auth/account');
    } catch (_) {
      // If server fails or is unreachable, ensure local credentials are eradicated
    } finally {
      await _client.deleteAuthToken();
    }
  }

  /// Checks if a valid Sanctum token exists in secure storage.
  Future<bool> isAuthenticated() async {
    return await _client.hasAuthToken();
  }
}
