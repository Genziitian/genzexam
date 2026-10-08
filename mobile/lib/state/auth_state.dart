import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _isGoogleSignInPending = false;
  int _googleAttempt = 0;

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

  /// True while the browser is open for Google sign-in and the app is waiting for it.
  bool get isGoogleSignInPending => _isGoogleSignInPending;

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

  /// OAuth "Web application" client id of the Google Cloud project (the same one the
  /// backend uses). The Android client (package + SHA-1) lives in that same project.
  static const String _googleServerClientId =
      '990282572765-bn1ls79tuhpa589eiici5r9mr6c98c8h.apps.googleusercontent.com';

  bool _googleReady = false;

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);
    _googleReady = true;
  }

  /// Signs in with Google's own account card (no browser): one tap on an account,
  /// then the backend turns Google's ID token into a session.
  Future<bool> loginWithGoogle() async {
    if (_isGoogleSignInPending) return false;

    final attempt = ++_googleAttempt;
    _isGoogleSignInPending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ensureGoogleReady();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return _endGoogleAttempt(attempt, 'Google did not return a sign-in token. Please try again.');
      }

      final res = await _authService.loginWithGoogleIdToken(idToken);
      UserModel profile = res.user;
      try {
        profile = await _authService.getMe();
      } catch (_) {
        // Fall back to the profile that came with the session.
      }

      _user = profile;
      _isGoogleSignInPending = false;
      _errorMessage = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // Closed the card without choosing an account.
        _isGoogleSignInPending = false;
        notifyListeners();
        return false;
      }
      final detail = (e.description ?? '').trim();
      return _endGoogleAttempt(
        attempt,
        'Google sign-in failed (${e.code.name})${detail.isEmpty ? '' : ': $detail'}',
      );
    } on ApiException catch (e) {
      return _endGoogleAttempt(attempt, e.message);
    } catch (_) {
      return _endGoogleAttempt(attempt, 'Google sign-in could not be completed. Please try again.');
    }
  }

  /// Stops waiting for a Google sign-in that the user abandoned.
  void cancelGoogleLogin() {
    if (!_isGoogleSignInPending) return;
    _googleAttempt++;
    _isGoogleSignInPending = false;
    notifyListeners();
  }

  bool _endGoogleAttempt(int attempt, String message) {
    if (attempt != _googleAttempt) return false;
    _isGoogleSignInPending = false;
    _errorMessage = message;
    notifyListeners();
    return false;
  }

  /// Changes the signed-in user's display name. Returns null on success,
  /// or a message to show if it could not be saved.
  Future<String?> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name cannot be empty.';
    try {
      await _apiClient.patch<dynamic>('/student/profile', data: {'name': trimmed});
      _user = await _authService.getMe();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save your name. Please try again.';
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
      await _forgetGoogleAccount();
      await _authService.logout();
    } catch (_) {
      await _apiClient.deleteAuthToken();
    } finally {
      _zeroizeSession();
    }
  }

  /// Sends an account deletion request without deleting the signed-in account.
  Future<bool> requestAccountDeletion({required String reason, String? details}) async {
    try {
      await _authService.requestAccountDeletion(reason: reason, details: details);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _forgetGoogleAccount() async {
    try {
      await _ensureGoogleReady();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google, or Google services unavailable.
    }
  }

  void _zeroizeSession() {
    _user = null;
    _isPreviewingStudentView = false;
    _googleAttempt++;
    _isGoogleSignInPending = false;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
}
