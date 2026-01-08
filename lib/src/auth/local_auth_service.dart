import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../core/failure.dart';

/// Biometric types available on the device
enum BiometricType {
  fingerprint,
  faceId,
  iris,
  strong,
  weak,
}

/// Configuration for local authentication
class LocalAuthConfig {
  /// Message shown during biometric prompt
  final String localizedReason;

  /// Whether to use error dialogs (Android)
  final bool useErrorDialogs;

  /// Whether to stick to biometrics only (no PIN fallback)
  final bool biometricOnly;

  /// Options for authentication
  final bool stickyAuth;

  /// Sensitivity required for biometric authentication
  final bool sensitiveTransaction;

  const LocalAuthConfig({
    this.localizedReason = 'Please authenticate to access the app',
    this.useErrorDialogs = true,
    this.biometricOnly = false,
    this.stickyAuth = true,
    this.sensitiveTransaction = true,
  });
}

/// Service for local biometric and credential-based authentication
///
/// Use this to protect app access after initial login with username/password
/// or social login. The user can unlock the app using:
/// - Fingerprint
/// - Face ID
/// - Device PIN/Password/Pattern
class LocalAuthService {
  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;
  final LocalAuthConfig config;

  // Storage keys
  static const String _keyLocalAuthEnabled = 'local_auth_enabled';
  static const String _keyRequireAuthOnResume = 'require_auth_on_resume';
  static const String _keyLastAuthTime = 'last_auth_time';
  static const String _keyAuthTimeoutMinutes = 'auth_timeout_minutes';

  LocalAuthService({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
    this.config = const LocalAuthConfig(),
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Check if biometrics can be used (enrolled and available)
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Get list of available biometric types on the device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final available = await _localAuth.getAvailableBiometrics();
      return available.map((bio) {
        switch (bio) {
          case LocalAuthBiometricType.fingerprint:
            return BiometricType.fingerprint;
          case LocalAuthBiometricType.face:
            return BiometricType.faceId;
          case LocalAuthBiometricType.iris:
            return BiometricType.iris;
          case LocalAuthBiometricType.strong:
            return BiometricType.strong;
          case LocalAuthBiometricType.weak:
            return BiometricType.weak;
        }
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check if local authentication is enabled by the user
  Future<bool> isLocalAuthEnabled() async {
    final enabled = await _secureStorage.read(key: _keyLocalAuthEnabled);
    return enabled == 'true';
  }

  /// Enable local authentication protection
  Future<Either<Failure, bool>> enableLocalAuth() async {
    try {
      // First verify the user can authenticate
      final canAuth = await canCheckBiometrics() || await isDeviceSupported();
      if (!canAuth) {
        return const Left(
          ValidationFailure(
            message: 'Device does not support biometric or credential authentication',
            code: 'BIOMETRIC_NOT_AVAILABLE',
          ),
        );
      }

      // Verify user identity before enabling
      final authResult = await authenticate(
        reason: 'Verify your identity to enable app lock',
      );

      return authResult.fold(
        (failure) => Left(failure),
        (success) async {
          if (success) {
            await _secureStorage.write(key: _keyLocalAuthEnabled, value: 'true');
            await _updateLastAuthTime();
            return const Right(true);
          }
          return const Left(
            AuthenticationFailure(
              message: 'Authentication failed',
              code: 'AUTH_FAILED',
            ),
          );
        },
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to enable local authentication: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Disable local authentication protection
  Future<Either<Failure, bool>> disableLocalAuth() async {
    try {
      // Verify user identity before disabling
      final authResult = await authenticate(
        reason: 'Verify your identity to disable app lock',
      );

      return authResult.fold(
        (failure) => Left(failure),
        (success) async {
          if (success) {
            await _secureStorage.write(key: _keyLocalAuthEnabled, value: 'false');
            return const Right(true);
          }
          return const Left(
            AuthenticationFailure(
              message: 'Authentication failed',
              code: 'AUTH_FAILED',
            ),
          );
        },
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to disable local authentication: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Authenticate user using biometrics or device credentials
  Future<Either<Failure, bool>> authenticate({
    String? reason,
    bool biometricOnly = false,
  }) async {
    try {
      final localizedReason = reason ?? config.localizedReason;

      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: config.useErrorDialogs,
          stickyAuth: config.stickyAuth,
          biometricOnly: biometricOnly || config.biometricOnly,
          sensitiveTransaction: config.sensitiveTransaction,
        ),
      );

      if (authenticated) {
        await _updateLastAuthTime();
        return const Right(true);
      }

      return const Left(
        AuthenticationFailure(
          message: 'Authentication cancelled or failed',
          code: 'AUTH_CANCELLED',
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Authentication error: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Authenticate if local auth is enabled
  /// Returns Right(true) if auth not required or auth successful
  Future<Either<Failure, bool>> authenticateIfEnabled({String? reason}) async {
    final isEnabled = await isLocalAuthEnabled();
    if (!isEnabled) {
      return const Right(true);
    }

    // Check if we're within the timeout window
    if (await _isWithinAuthTimeout()) {
      return const Right(true);
    }

    return authenticate(reason: reason);
  }

  /// Set whether authentication is required when app resumes from background
  Future<void> setRequireAuthOnResume(bool require) async {
    await _secureStorage.write(
      key: _keyRequireAuthOnResume,
      value: require.toString(),
    );
  }

  /// Check if authentication is required when app resumes
  Future<bool> requiresAuthOnResume() async {
    final require = await _secureStorage.read(key: _keyRequireAuthOnResume);
    return require != 'false'; // Default to true
  }

  /// Set authentication timeout in minutes
  /// User won't be prompted again within this window
  Future<void> setAuthTimeout(int minutes) async {
    await _secureStorage.write(
      key: _keyAuthTimeoutMinutes,
      value: minutes.toString(),
    );
  }

  /// Get current authentication timeout in minutes
  Future<int> getAuthTimeout() async {
    final timeout = await _secureStorage.read(key: _keyAuthTimeoutMinutes);
    return int.tryParse(timeout ?? '') ?? 5; // Default 5 minutes
  }

  /// Check if we're within the authentication timeout window
  Future<bool> _isWithinAuthTimeout() async {
    final lastAuthStr = await _secureStorage.read(key: _keyLastAuthTime);
    if (lastAuthStr == null) return false;

    final lastAuth = DateTime.tryParse(lastAuthStr);
    if (lastAuth == null) return false;

    final timeout = await getAuthTimeout();
    final now = DateTime.now();
    final difference = now.difference(lastAuth).inMinutes;

    return difference < timeout;
  }

  /// Update last authentication time
  Future<void> _updateLastAuthTime() async {
    await _secureStorage.write(
      key: _keyLastAuthTime,
      value: DateTime.now().toIso8601String(),
    );
  }

  /// Clear last authentication time (force re-auth)
  Future<void> clearAuthSession() async {
    await _secureStorage.delete(key: _keyLastAuthTime);
  }

  /// Cancel any ongoing authentication
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (_) {
      // Ignore errors when stopping
    }
  }
}
