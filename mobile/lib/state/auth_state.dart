import 'package:flutter/foundation.dart';
import '../api/api.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
}

/// Central state manager holding session identity, role, and rank.
///
/// Guaranteed:
/// - Authoritative server state from labapi.genziitian.in.
/// - Token zeroization on 401 Unauthorized or manual logout.
/// - Exact roles: 'student' (rank 0), 'admin' (rank 1), 'manager' (rank 2).
/// - Instant 'Preview Student View' context-switch for Managers.
class AuthState extends ChangeNotifier {
  final AuthService _authService;
  final ApiClient _apiClient;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _isPreviewingStudentView = false;

  AuthState({
    AuthService? authService,
    ApiClient? apiClient,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authService = authService ?? AuthService() {
    // Zeroize token if interceptor catches 401
    _apiClient.onUnauthorized = () {
      _zeroizeSession();
    };
  }

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isPreviewingStudentView => _isPreviewingStudentView;

  String get role => _user?.role ?? (_user?.isAdmin == true ? 'admin' : 'student');

  int get rank {
    switch (role) {
      case 'manager':
        return 2;
      case 'admin':
        return 1;
      case 'student':
      default:
        return 0;
    }
  }

  bool get isManager => role == 'manager';
  bool get isAdmin => role == 'admin' || role == 'manager';
  bool get isStudent => role == 'student';

  /// Cold-start initialization helper
  Future<void> init() async {
    await checkAuthStatus();
  }

  /// Initializes session check on app start.
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final hasToken = await _apiClient.hasAuthToken();
      if (!hasToken) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final profile = await _authService.getMe();
      _user = profile;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (e) {
      // Invalid/expired token or connection issue
      await _apiClient.deleteAuthToken();
      _user = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  /// Logs in via /api/auth/login directly without OTP.
  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _authService.login(email: email, password: password);
      _user = res.user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Invalid credentials or server connection issue.';
      notifyListeners();
      return false;
    }
  }

  /// Allows Manager to toggle previewing the 5-Tab Student View.
  void togglePreviewStudentView([bool? explicitValue]) {
    if (!isManager) return;
    _isPreviewingStudentView = explicitValue ?? !_isPreviewingStudentView;
    notifyListeners();
  }

  /// Logs out and purges token.
  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {
      await _apiClient.deleteAuthToken();
    } finally {
      _zeroizeSession();
    }
  }

  /// Permanently deletes account and zeroes session data (Google Play requirement)
  Future<bool> deleteAccount() async {
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      await _authService.deleteAccount();
      _zeroizeSession();
      return true;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = 'Failed to delete account. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void _zeroizeSession() {
    _user = null;
    _isPreviewingStudentView = false;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
}
