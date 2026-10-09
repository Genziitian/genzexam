import 'dart:convert';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api.dart';
import '../api/offline_paper_store.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  connectionUnavailable,
}

/// Central state manager holding session identity, role, and rank.
///
/// Guaranteed:
/// - Authoritative server state from labapi.genziitian.in.
/// - Token zeroization on 401 Unauthorized or manual logout.
/// - Exact roles: 'student' (rank 0), 'admin' (rank 1), 'manager' (rank 2).
/// - Instant 'Preview Student View' context-switch for Managers.
class AuthState extends ChangeNotifier with WidgetsBindingObserver {
  late final AuthService _authService;
  final ApiClient _apiClient;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _isPreviewingStudentView = false;
  bool _isGoogleSignInPending = false;
  int _googleAttempt = 0;
  Timer? _offlineSyncTimer;
  bool _offlineSyncInProgress = false;
  Future<void>? _initialization;
  int _sessionGeneration = 0;

  AuthState({AuthService? authService, ApiClient? apiClient})
    : _apiClient = apiClient ?? authService?.client ?? ApiClient() {
    _authService = authService ?? AuthService(client: _apiClient);
    WidgetsBinding.instance.addObserver(this);
    // Zeroize token if interceptor catches 401
    _apiClient.onUnauthorized = () {
      _zeroizeSession();
    };
  }

  AuthStatus get status => _status;
  ApiClient get client => _apiClient;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isPreviewingStudentView => _isPreviewingStudentView;

  /// True while the browser is open for Google sign-in and the app is waiting for it.
  bool get isGoogleSignInPending => _isGoogleSignInPending;

  String get role =>
      _user?.role ?? (_user?.isAdmin == true ? 'admin' : 'student');

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _status == AuthStatus.authenticated &&
        _user != null) {
      _startOfflinePaperSync(_user!.id);
    }
  }

  @override
  void dispose() {
    _offlineSyncTimer?.cancel();
    _sessionGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Cold-start initialization helper
  Future<void> init() => _initialization ??= checkAuthStatus();

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

      // A saved session opens the local app immediately. Server availability
      // must never be a prerequisite for reading downloaded papers.
      final cached = await _readCachedUser();
      if (cached != null) {
        _user = cached;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        _startOfflinePaperSync(cached.id);
        unawaited(_refreshSavedSession(_sessionGeneration));
        return;
      }

      final profile = await _authService.getMe();
      _user = profile;
      await _cacheUser(profile);
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      _startOfflinePaperSync(profile.id);
    } catch (e) {
      // Only a server-confirmed 401 invalidates a Sanctum token. A dropped
      // connection or 5xx must never sign the student out.
      if (e is ApiException && e.statusCode == 401) {
        _user = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Your session expired. Please sign in again.';
        await _apiClient.deleteCachedUser();
        return;
      }
      final cached = await _readCachedUser();
      if (cached != null && await _apiClient.hasAuthToken()) {
        _user = cached;
        _status = AuthStatus.authenticated;
        _errorMessage = 'Offline: your saved account is available. Changes will sync when you reconnect.';
        _startOfflinePaperSync(cached.id);
      } else {
        _user = null;
        _status = AuthStatus.connectionUnavailable;
        _errorMessage = 'You are still signed in, but we could not reach the server to check your account. Check your connection and retry.';
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> _refreshSavedSession(int generation) async {
    try {
      final profile = await _authService.getMe();
      if (generation != _sessionGeneration || _user?.id != profile.id) return;
      _user = profile;
      await _cacheUser(profile);
      _errorMessage = null;
      notifyListeners();
    } on ApiException catch (error) {
      if (generation != _sessionGeneration) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _apiClient.deleteAuthToken();
        _zeroizeSession();
      }
      // A network failure leaves the saved account and downloads available.
    } catch (_) {
      // Keep the local session if the server cannot be checked.
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
      await _cacheUser(res.user);
      _startOfflinePaperSync(res.user.id);
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
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
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
        return _endGoogleAttempt(
          attempt,
          'Google did not return a sign-in token. Please try again.',
        );
      }

      final res = await _authService.loginWithGoogleIdToken(idToken);
      UserModel profile = res.user;
      try {
        profile = await _authService.getMe();
      } catch (_) {
        // Fall back to the profile that came with the session.
      }

      _user = profile;
      await _cacheUser(profile);
      _startOfflinePaperSync(profile.id);
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
      return _endGoogleAttempt(
        attempt,
        'Google sign-in could not be completed. Please try again.',
      );
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
      await _apiClient.patch<dynamic>(
        '/student/profile',
        data: {'name': trimmed},
      );
      _user = await _authService.getMe();
      await _cacheUser(_user!);
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
    _offlineSyncTimer?.cancel();
    _offlineSyncTimer = null;
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
  Future<bool> requestAccountDeletion({
    required String reason,
    String? details,
  }) async {
    try {
      await _authService.requestAccountDeletion(
        reason: reason,
        details: details,
      );
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
    _sessionGeneration++;
    _offlineSyncTimer?.cancel();
    _offlineSyncTimer = null;
    _apiClient.deleteCachedUser();
    _user = null;
    _isPreviewingStudentView = false;
    _googleAttempt++;
    _isGoogleSignInPending = false;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _cacheUser(UserModel user) async {
    try {
      await _apiClient.saveCachedUser(jsonEncode(user.toJson()));
    } catch (_) {
      // A profile-cache failure must not turn a successful login into a failure.
    }
  }

  void _startOfflinePaperSync(int userId) {
    _offlineSyncTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      final current = _user;
      if (_status == AuthStatus.authenticated && current != null) {
        unawaited(_syncOfflinePapers(current.id));
      }
    });
    unawaited(_syncOfflinePapers(userId));
  }

  Future<void> _syncOfflinePapers(int userId) async {
    if (_offlineSyncInProgress) return;
    _offlineSyncInProgress = true;
    try {
      await OfflinePaperStore.syncInterruptedDrafts(
        userId,
        QuizService(client: _apiClient),
        canSync: () =>
            _status == AuthStatus.authenticated && _user?.id == userId,
      );
    } catch (_) {
      // Offline drafts stay on device and will be retried next launch.
    } finally {
      _offlineSyncInProgress = false;
    }
  }

  Future<UserModel?> _readCachedUser() async {
    try {
      final value = await _apiClient.getCachedUser();
      if (value == null) return null;
      return UserModel.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
