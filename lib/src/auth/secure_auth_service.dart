import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../client/shoutout_client.dart';
import '../core/failure.dart';
import '../interfaces/i_auth_service.dart';
import 'frappe_auth_service.dart';
import 'local_auth_service.dart';

/// Authentication state for the app
enum AuthState {
  /// User is not logged in
  unauthenticated,

  /// User is logged in but app is locked (needs biometric)
  locked,

  /// User is fully authenticated
  authenticated,
}

/// Secure authentication service that combines Frappe login with local biometric protection
///
/// This service provides:
/// 1. Initial login via username/password, API key, or social login
/// 2. Post-login protection using device biometrics or credentials
/// 3. Automatic app locking when backgrounded
///
/// Usage:
/// ```dart
/// final secureAuth = SecureAuthService(client: shoutoutClient);
///
/// // Initial login
/// await secureAuth.loginWithPassword(email: 'user@example.com', password: 'pass');
///
/// // Enable biometric protection
/// await secureAuth.enableBiometricLock();
///
/// // On app resume, require biometric
/// await secureAuth.unlockWithBiometric();
/// ```
class SecureAuthService implements IFrappeAuthService, ISocialAuthService {
  final FrappeAuthService _frappeAuth;
  final LocalAuthService _localAuth;
  final FlutterSecureStorage _secureStorage;

  static const String _keyBiometricLockEnabled = 'biometric_lock_enabled';

  // Combined auth state stream
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  bool _isAppLocked = false;

  SecureAuthService({
    required ShoutoutClient client,
    FlutterSecureStorage? secureStorage,
    SocialLoginConfig? socialConfig,
    OtpAuthConfig? otpConfig,
    LocalAuthConfig? localAuthConfig,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _frappeAuth = FrappeAuthService(
          client: client,
          secureStorage: secureStorage,
          socialConfig: socialConfig,
          otpConfig: otpConfig,
        ),
        _localAuth = LocalAuthService(
          secureStorage: secureStorage,
          config: localAuthConfig ?? const LocalAuthConfig(),
        );

  /// Get the underlying Frappe auth service
  FrappeAuthService get frappeAuth => _frappeAuth;

  /// Get the underlying local auth service
  LocalAuthService get localAuth => _localAuth;

  /// Stream of authentication state changes
  Stream<AuthState> get secureAuthStateChanges => _authStateController.stream;

  /// Check if app is currently locked
  bool get isLocked => _isAppLocked;

  /// Get current auth state
  Future<AuthState> getAuthState() async {
    final isLoggedIn = await _frappeAuth.isLoggedIn();
    if (!isLoggedIn) {
      return AuthState.unauthenticated;
    }

    final biometricEnabled = await isBiometricLockEnabled();
    if (biometricEnabled && _isAppLocked) {
      return AuthState.locked;
    }

    return AuthState.authenticated;
  }

  // ==================== Biometric Lock Methods ====================

  /// Check if biometric lock is enabled
  Future<bool> isBiometricLockEnabled() async {
    final enabled = await _secureStorage.read(key: _keyBiometricLockEnabled);
    return enabled == 'true';
  }

  /// Check if device supports biometric authentication
  Future<bool> canUseBiometricLock() async {
    return await _localAuth.canCheckBiometrics() ||
        await _localAuth.isDeviceSupported();
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _localAuth.getAvailableBiometrics();
  }

  /// Enable biometric lock for the app
  Future<Either<Failure, bool>> enableBiometricLock() async {
    // First verify user is logged in
    final isLoggedIn = await _frappeAuth.isLoggedIn();
    if (!isLoggedIn) {
      return const Left(
        AuthenticationFailure(
          message: 'You must be logged in to enable biometric lock',
          code: 'NOT_LOGGED_IN',
        ),
      );
    }

    // Enable local auth
    final result = await _localAuth.enableLocalAuth();
    return result.fold(
      (failure) => Left(failure),
      (success) async {
        await _secureStorage.write(key: _keyBiometricLockEnabled, value: 'true');
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
        return const Right(true);
      },
    );
  }

  /// Disable biometric lock for the app
  Future<Either<Failure, bool>> disableBiometricLock() async {
    final result = await _localAuth.disableLocalAuth();
    return result.fold(
      (failure) => Left(failure),
      (success) async {
        await _secureStorage.write(key: _keyBiometricLockEnabled, value: 'false');
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
        return const Right(true);
      },
    );
  }

  /// Lock the app (call when app goes to background)
  Future<void> lockApp() async {
    final biometricEnabled = await isBiometricLockEnabled();
    final requireOnResume = await _localAuth.requiresAuthOnResume();

    if (biometricEnabled && requireOnResume) {
      // Check if within timeout window
      final withinTimeout = await _localAuth.authenticateIfEnabled();
      final shouldLock = withinTimeout.fold((_) => true, (success) => !success);

      if (shouldLock) {
        _isAppLocked = true;
        _authStateController.add(AuthState.locked);
      }
    }
  }

  /// Unlock the app with biometric/credential
  Future<Either<Failure, bool>> unlockWithBiometric({String? reason}) async {
    final isLoggedIn = await _frappeAuth.isLoggedIn();
    if (!isLoggedIn) {
      _isAppLocked = false;
      _authStateController.add(AuthState.unauthenticated);
      return const Left(
        AuthenticationFailure(
          message: 'Session expired. Please log in again.',
          code: 'SESSION_EXPIRED',
        ),
      );
    }

    final result = await _localAuth.authenticate(
      reason: reason ?? 'Unlock to access the app',
    );

    return result.fold(
      (failure) => Left(failure),
      (success) {
        if (success) {
          _isAppLocked = false;
          _authStateController.add(AuthState.authenticated);
        }
        return Right(success);
      },
    );
  }

  /// Set authentication timeout in minutes
  Future<void> setLockTimeout(int minutes) async {
    await _localAuth.setAuthTimeout(minutes);
  }

  /// Get current lock timeout in minutes
  Future<int> getLockTimeout() async {
    return await _localAuth.getAuthTimeout();
  }

  /// Set whether to require auth when app resumes
  Future<void> setRequireAuthOnResume(bool require) async {
    await _localAuth.setRequireAuthOnResume(require);
  }

  // ==================== Two-Factor Authentication ====================

  /// Login with password, handling 2FA if required
  ///
  /// Returns [LoginResult] which indicates whether login is complete
  /// or if 2FA verification is needed.
  Future<Either<Failure, LoginResult>> loginWithPasswordAndHandle2FA({
    required String email,
    required String password,
  }) async {
    final result = await _frappeAuth.loginWithPasswordAndHandle2FA(
      email: email,
      password: password,
    );

    result.fold(
      (_) {},
      (loginResult) {
        if (loginResult.isComplete) {
          _isAppLocked = false;
          _authStateController.add(AuthState.authenticated);
        }
      },
    );

    return result;
  }

  /// Verify 2FA OTP to complete login
  Future<Either<Failure, String>> verify2FACode({
    required String otp,
    String? tmpId,
  }) async {
    final result = await _frappeAuth.verify2FACode(otp: otp, tmpId: tmpId);

    result.fold(
      (_) {},
      (_) {
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
      },
    );

    return result;
  }

  /// Resend OTP to phone number
  Future<Either<Failure, bool>> resendOtp({required String phone}) =>
      _frappeAuth.resendOtp(phone: phone);

  // ==================== IAuthService Delegation ====================

  @override
  Stream<bool> get authStateChanges => _frappeAuth.authStateChanges;

  @override
  Future<bool> isLoggedIn() => _frappeAuth.isLoggedIn();

  @override
  Future<String?> getCurrentUserId() => _frappeAuth.getCurrentUserId();

  @override
  Future<String?> getAuthToken() => _frappeAuth.getAuthToken();

  @override
  Future<Either<Failure, String>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final result = await _frappeAuth.loginWithPassword(
      email: email,
      password: password,
    );

    result.fold(
      (_) {},
      (_) {
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, String>> loginWithOtp({
    required String phone,
    required String otp,
  }) async {
    final result = await _frappeAuth.loginWithOtp(phone: phone, otp: otp);

    result.fold(
      (_) {},
      (_) {
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, bool>> sendOtp({required String phone}) =>
      _frappeAuth.sendOtp(phone: phone);

  @override
  Future<Either<Failure, bool>> verifyOtp({
    required String phone,
    required String otp,
  }) =>
      _frappeAuth.verifyOtp(phone: phone, otp: otp);

  @override
  Future<Either<Failure, bool>> logout() async {
    final result = await _frappeAuth.logout();

    // Clear biometric lock state on logout
    await _secureStorage.delete(key: _keyBiometricLockEnabled);
    await _localAuth.clearAuthSession();
    _isAppLocked = false;
    _authStateController.add(AuthState.unauthenticated);

    return result;
  }

  @override
  Future<Either<Failure, String>> refreshToken() => _frappeAuth.refreshToken();

  @override
  Future<void> saveAuthToken(String token) => _frappeAuth.saveAuthToken(token);

  @override
  Future<void> clearAuthToken() => _frappeAuth.clearAuthToken();

  @override
  Future<void> saveUserSession({
    required String userId,
    required String token,
    Map<String, dynamic>? userData,
  }) =>
      _frappeAuth.saveUserSession(
        userId: userId,
        token: token,
        userData: userData,
      );

  @override
  Future<void> clearUserSession() async {
    await _frappeAuth.clearUserSession();
    await _secureStorage.delete(key: _keyBiometricLockEnabled);
    await _localAuth.clearAuthSession();
    _isAppLocked = false;
  }

  @override
  Future<bool> isTokenValid() => _frappeAuth.isTokenValid();

  @override
  Future<Map<String, dynamic>?> getUserData() => _frappeAuth.getUserData();

  // ==================== IFrappeAuthService Delegation ====================

  @override
  Future<Either<Failure, String>> loginWithApiKey({
    required String apiKey,
    required String apiSecret,
  }) async {
    final result = await _frappeAuth.loginWithApiKey(
      apiKey: apiKey,
      apiSecret: apiSecret,
    );

    result.fold(
      (_) {},
      (_) {
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getLoggedUser() =>
      _frappeAuth.getLoggedUser();

  @override
  Future<Either<Failure, bool>> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) =>
      _frappeAuth.updatePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

  @override
  Future<Either<Failure, bool>> resetPassword({required String email}) =>
      _frappeAuth.resetPassword(email: email);

  @override
  Future<Either<Failure, bool>> verifyResetToken({
    required String token,
    required String newPassword,
  }) =>
      _frappeAuth.verifyResetToken(token: token, newPassword: newPassword);

  // ==================== ISocialAuthService Delegation ====================

  @override
  Future<Either<Failure, String>> loginWithGoogle() async {
    final result = await _frappeAuth.loginWithGoogle();

    result.fold(
      (_) {},
      (_) {
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, String>> loginWithApple() async {
    final result = await _frappeAuth.loginWithApple();

    result.fold(
      (_) {},
      (_) {
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, String>> loginWithFacebook() async {
    final result = await _frappeAuth.loginWithFacebook();

    result.fold(
      (_) {},
      (_) {
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
      },
    );

    return result;
  }

  /// Complete social login with OAuth token
  Future<Either<Failure, String>> loginWithSocialToken({
    required String provider,
    required String token,
    String? accessToken,
    String? idToken,
  }) async {
    final result = await _frappeAuth.loginWithSocialToken(
      provider: provider,
      token: token,
      accessToken: accessToken,
      idToken: idToken,
    );

    result.fold(
      (_) {},
      (_) {
        _isAppLocked = false;
        _authStateController.add(AuthState.authenticated);
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, bool>> linkGoogle() => _frappeAuth.linkGoogle();

  @override
  Future<Either<Failure, bool>> linkApple() => _frappeAuth.linkApple();

  @override
  Future<Either<Failure, bool>> unlinkSocialAccount(String provider) =>
      _frappeAuth.unlinkSocialAccount(provider);

  // ==================== Session Restore ====================

  /// Restore session and check if biometric unlock is needed
  ///
  /// Returns the current auth state after attempting to restore session
  Future<AuthState> restoreSession() async {
    final sessionRestored = await _frappeAuth.restoreSession();

    if (!sessionRestored) {
      _authStateController.add(AuthState.unauthenticated);
      return AuthState.unauthenticated;
    }

    final biometricEnabled = await isBiometricLockEnabled();
    if (biometricEnabled) {
      _isAppLocked = true;
      _authStateController.add(AuthState.locked);
      return AuthState.locked;
    }

    _authStateController.add(AuthState.authenticated);
    return AuthState.authenticated;
  }

  /// Dispose resources
  void dispose() {
    _frappeAuth.dispose();
    _authStateController.close();
  }
}
