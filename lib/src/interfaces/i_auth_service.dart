import 'package:dartz/dartz.dart';
import '../core/failure.dart';

/// Interface for authentication operations
/// Generic auth service that can be implemented for different backends
/// (Frappe, Firebase, custom API, etc.)
abstract class IAuthService {
  /// Check if user is logged in
  Future<bool> isLoggedIn();

  /// Get current user ID
  Future<String?> getCurrentUserId();

  /// Get auth token
  Future<String?> getAuthToken();

  /// Login with phone and OTP
  Future<Either<Failure, String>> loginWithOtp({
    required String phone,
    required String otp,
  });

  /// Login with email and password
  Future<Either<Failure, String>> loginWithPassword({
    required String email,
    required String password,
  });

  /// Send OTP to phone
  Future<Either<Failure, bool>> sendOtp({
    required String phone,
  });

  /// Verify OTP
  Future<Either<Failure, bool>> verifyOtp({
    required String phone,
    required String otp,
  });

  /// Logout
  Future<Either<Failure, bool>> logout();

  /// Refresh token
  Future<Either<Failure, String>> refreshToken();

  /// Stream of auth state changes
  Stream<bool> get authStateChanges;

  /// Save auth token
  Future<void> saveAuthToken(String token);

  /// Clear auth token
  Future<void> clearAuthToken();

  /// Save user session
  Future<void> saveUserSession({
    required String userId,
    required String token,
    Map<String, dynamic>? userData,
  });

  /// Clear user session
  Future<void> clearUserSession();

  /// Check if token is valid
  Future<bool> isTokenValid();

  /// Get user data from session
  Future<Map<String, dynamic>?> getUserData();
}

/// Extended auth service with social login support
abstract class ISocialAuthService extends IAuthService {
  /// Login with Google
  Future<Either<Failure, String>> loginWithGoogle();

  /// Login with Apple
  Future<Either<Failure, String>> loginWithApple();

  /// Login with Facebook
  Future<Either<Failure, String>> loginWithFacebook();

  /// Link Google account
  Future<Either<Failure, bool>> linkGoogle();

  /// Link Apple account
  Future<Either<Failure, bool>> linkApple();

  /// Unlink social account
  Future<Either<Failure, bool>> unlinkSocialAccount(String provider);
}

/// Auth service with MFA (Multi-Factor Authentication) support
abstract class IMFAAuthService extends IAuthService {
  /// Enable MFA for user
  Future<Either<Failure, String>> enableMFA();

  /// Disable MFA for user
  Future<Either<Failure, bool>> disableMFA();

  /// Verify MFA code
  Future<Either<Failure, bool>> verifyMFACode(String code);

  /// Check if MFA is enabled
  Future<bool> isMFAEnabled();

  /// Get backup codes
  Future<Either<Failure, List<String>>> getBackupCodes();
}

/// Frappe-specific auth service interface
abstract class IFrappeAuthService extends IAuthService {
  /// Login with API key and secret
  Future<Either<Failure, String>> loginWithApiKey({
    required String apiKey,
    required String apiSecret,
  });

  /// Get logged user from Frappe
  Future<Either<Failure, Map<String, dynamic>>> getLoggedUser();

  /// Update password
  Future<Either<Failure, bool>> updatePassword({
    required String oldPassword,
    required String newPassword,
  });

  /// Reset password with email
  Future<Either<Failure, bool>> resetPassword({
    required String email,
  });

  /// Verify reset password token
  Future<Either<Failure, bool>> verifyResetToken({
    required String token,
    required String newPassword,
  });
}
