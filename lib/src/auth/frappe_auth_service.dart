import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../client/shoutout_client.dart';
import '../core/failure.dart';
import '../interfaces/i_auth_service.dart';

/// Configuration for social login providers
class SocialLoginConfig {
  final String? googleClientId;
  final String? appleClientId;
  final String? facebookAppId;
  final String? redirectUri;

  const SocialLoginConfig({
    this.googleClientId,
    this.appleClientId,
    this.facebookAppId,
    this.redirectUri,
  });
}

/// Configuration for OTP-based authentication
class OtpAuthConfig {
  /// Custom endpoint for generating/sending OTP
  /// Default: null (uses Frappe's built-in SMS settings)
  /// Example: 'myapp.api.auth.generate_otp'
  final String? generateOtpMethod;

  /// Custom endpoint for verifying OTP and logging in
  /// Default: null (uses Frappe's built-in SMS settings)
  /// Example: 'myapp.api.auth.verify_otp'
  final String? verifyOtpMethod;

  /// Default country code to prepend to phone numbers
  /// Example: '+91' for India, '+1' for USA
  final String? defaultCountryCode;

  /// OTP length (for validation purposes)
  final int otpLength;

  const OtpAuthConfig({
    this.generateOtpMethod,
    this.verifyOtpMethod,
    this.defaultCountryCode,
    this.otpLength = 6,
  });
}

/// Result of a login attempt that requires 2FA verification
class TwoFactorAuthRequired {
  /// Temporary ID for the 2FA session
  final String tmpId;

  /// Verification method (Email, SMS, OTP App)
  final String method;

  /// Prompt message to show the user
  final String prompt;

  /// Whether 2FA setup is complete
  final bool setup;

  const TwoFactorAuthRequired({
    required this.tmpId,
    required this.method,
    required this.prompt,
    required this.setup,
  });

  factory TwoFactorAuthRequired.fromJson(Map<String, dynamic> json) {
    final verification = json['verification'] as Map<String, dynamic>? ?? {};
    return TwoFactorAuthRequired(
      tmpId: json['tmp_id']?.toString() ?? '',
      method: verification['method']?.toString() ?? 'Email',
      prompt: verification['prompt']?.toString() ??
          'Please enter the verification code',
      setup: verification['setup'] == true,
    );
  }
}

/// Login result that may require 2FA
class LoginResult {
  /// User ID if login was successful
  final String? userId;

  /// 2FA details if verification is required
  final TwoFactorAuthRequired? twoFactorRequired;

  /// Whether login is complete (no 2FA required)
  bool get isComplete => userId != null && twoFactorRequired == null;

  /// Whether 2FA verification is needed
  bool get requires2FA => twoFactorRequired != null;

  const LoginResult({this.userId, this.twoFactorRequired});
}

/// Frappe authentication service implementation
/// Supports username/password login, API key authentication, OTP, and social login
class FrappeAuthService implements IFrappeAuthService, ISocialAuthService {
  final ShoutoutClient _client;
  final FlutterSecureStorage _secureStorage;
  final SocialLoginConfig? socialConfig;
  final OtpAuthConfig otpConfig;

  // Storage keys
  static const String _keyAuthToken = 'frappe_auth_token';
  static const String _keyUserId = 'frappe_user_id';
  static const String _keyUserData = 'frappe_user_data';
  static const String _keyApiKey = 'frappe_api_key';
  static const String _keyApiSecret = 'frappe_api_secret';
  static const String _keySessionId = 'frappe_session_id';
  static const String _keyTmpId = 'frappe_tmp_id';

  // Auth state stream controller
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  FrappeAuthService({
    required ShoutoutClient client,
    FlutterSecureStorage? secureStorage,
    this.socialConfig,
    OtpAuthConfig? otpConfig,
  })  : _client = client,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        otpConfig = otpConfig ?? const OtpAuthConfig();

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  // ==================== IAuthService Implementation ====================

  @override
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    final userId = await getCurrentUserId();
    return token != null || userId != null;
  }

  @override
  Future<String?> getCurrentUserId() async {
    return await _secureStorage.read(key: _keyUserId);
  }

  @override
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: _keyAuthToken);
  }

  @override
  Future<Either<Failure, String>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final result = await loginWithPasswordAndHandle2FA(
      email: email,
      password: password,
    );

    return result.fold(
      (failure) => Left(failure),
      (loginResult) {
        if (loginResult.requires2FA) {
          // Return special failure indicating 2FA is required
          return Left(
            AuthenticationFailure(
              message: loginResult.twoFactorRequired!.prompt,
              code: 'TWO_FACTOR_REQUIRED',
            ),
          );
        }
        return Right(loginResult.userId!);
      },
    );
  }

  /// Login with password, handling 2FA if required
  ///
  /// Returns [LoginResult] which indicates whether login is complete
  /// or if 2FA verification is needed.
  ///
  /// Example:
  /// ```dart
  /// final result = await authService.loginWithPasswordAndHandle2FA(
  ///   email: 'user@example.com',
  ///   password: 'password',
  /// );
  ///
  /// result.fold(
  ///   (failure) => showError(failure.message),
  ///   (loginResult) {
  ///     if (loginResult.requires2FA) {
  ///       // Show OTP input screen
  ///       final tfaInfo = loginResult.twoFactorRequired!;
  ///       showOtpScreen(prompt: tfaInfo.prompt, method: tfaInfo.method);
  ///     } else {
  ///       // Login complete
  ///       navigateToHome();
  ///     }
  ///   },
  /// );
  /// ```
  Future<Either<Failure, LoginResult>> loginWithPasswordAndHandle2FA({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/method/login',
        data: {
          'usr': email,
          'pwd': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Check if 2FA is required
        if (data is Map && data['verification'] != null) {
          final twoFactorInfo = TwoFactorAuthRequired.fromJson(
            Map<String, dynamic>.from(data),
          );

          // Store tmp_id for later verification
          await _secureStorage.write(key: _keyTmpId, value: twoFactorInfo.tmpId);
          // Also store email for the 2FA verification call
          await _secureStorage.write(key: '${_keyTmpId}_user', value: email);

          return Right(LoginResult(twoFactorRequired: twoFactorInfo));
        }

        // Login successful without 2FA
        return _handleSuccessfulLogin(email, response);
      } else if (response.statusCode == 401) {
        return Left(AuthenticationFailure.invalidCredentials());
      } else {
        final errorMessage = response.data is Map
            ? (response.data['message'] ?? 'Login failed')
            : 'Login failed';
        return Left(AuthenticationFailure(message: errorMessage.toString()));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return Left(AuthenticationFailure.invalidCredentials());
      }
      return Left(
        ServerFailure(
          message: e.message ?? 'Login failed',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Login failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Verify 2FA OTP to complete login
  ///
  /// Call this after [loginWithPasswordAndHandle2FA] returns a [LoginResult]
  /// with [requires2FA] = true.
  ///
  /// Example:
  /// ```dart
  /// final result = await authService.verify2FACode(otp: '123456');
  /// result.fold(
  ///   (failure) => showError(failure.message),
  ///   (userId) => navigateToHome(),
  /// );
  /// ```
  Future<Either<Failure, String>> verify2FACode({
    required String otp,
    String? tmpId,
  }) async {
    try {
      // Get stored tmp_id if not provided
      final storedTmpId = tmpId ?? await _secureStorage.read(key: _keyTmpId);
      final storedUser = await _secureStorage.read(key: '${_keyTmpId}_user');

      if (storedTmpId == null) {
        return const Left(
          AuthenticationFailure(
            message: 'No pending 2FA verification found. Please login again.',
            code: 'NO_PENDING_2FA',
          ),
        );
      }

      final response = await _client.dio.post(
        '/api/method/login',
        data: {
          'usr': storedUser,
          'otp': otp,
          'tmp_id': storedTmpId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Check if still requiring verification (wrong OTP)
        if (data is Map && data['verification'] != null) {
          return const Left(
            AuthenticationFailure(
              message: 'Invalid verification code. Please try again.',
              code: 'INVALID_OTP',
            ),
          );
        }

        // Clear stored tmp_id
        await _secureStorage.delete(key: _keyTmpId);
        await _secureStorage.delete(key: '${_keyTmpId}_user');

        // Login successful
        final result = await _handleSuccessfulLogin(storedUser ?? '', response);
        return result.fold(
          (failure) => Left(failure),
          (loginResult) => Right(loginResult.userId!),
        );
      } else if (response.statusCode == 401) {
        return const Left(
          AuthenticationFailure(
            message: 'Invalid verification code',
            code: 'INVALID_OTP',
          ),
        );
      } else {
        final errorMessage = response.data is Map
            ? (response.data['message'] ?? 'Verification failed')
            : 'Verification failed';
        return Left(AuthenticationFailure(message: errorMessage.toString()));
      }
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? '2FA verification failed',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: '2FA verification failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Handle successful login response
  Future<Either<Failure, LoginResult>> _handleSuccessfulLogin(
    String email,
    Response response,
  ) async {
    try {
      final data = response.data;

      // Extract user info from response
      String userId = email;
      if (data is Map && data['full_name'] != null) {
        userId = data['full_name'] as String;
      }

      // Get session cookies if available
      final cookies = response.headers['set-cookie'];
      String? sessionId;
      if (cookies != null && cookies.isNotEmpty) {
        for (final cookie in cookies) {
          if (cookie.contains('sid=')) {
            final match = RegExp(r'sid=([^;]+)').firstMatch(cookie);
            sessionId = match?.group(1);
            break;
          }
        }
      }

      // Save session
      await saveUserSession(
        userId: email,
        token: sessionId ?? email,
        userData: data is Map ? Map<String, dynamic>.from(data) : null,
      );

      // Notify auth state change
      _authStateController.add(true);

      return Right(LoginResult(userId: email));
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to process login response: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, String>> loginWithOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phone);

      // Use custom endpoint if configured, otherwise use default
      final endpoint = otpConfig.verifyOtpMethod != null
          ? '/api/method/${otpConfig.verifyOtpMethod}'
          : '/api/method/frappe.core.doctype.sms_settings.sms_settings.verify_otp';

      final response = await _client.dio.post(
        endpoint,
        data: {
          'mobile_no': formattedPhone,
          'phone': formattedPhone, // Some implementations use 'phone'
          'otp': otp,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final message = data['message'];

        // Handle different response formats
        String userId;
        Map<String, dynamic>? userData;

        if (message is Map) {
          userId = message['user']?.toString() ??
              message['email']?.toString() ??
              formattedPhone;
          userData = Map<String, dynamic>.from(message);
        } else if (message is String) {
          userId = message;
        } else {
          userId = formattedPhone;
        }

        // Get session cookies if available
        final cookies = response.headers['set-cookie'];
        String? sessionId;
        if (cookies != null && cookies.isNotEmpty) {
          for (final cookie in cookies) {
            if (cookie.contains('sid=')) {
              final match = RegExp(r'sid=([^;]+)').firstMatch(cookie);
              sessionId = match?.group(1);
              break;
            }
          }
        }

        await saveUserSession(
          userId: userId,
          token: sessionId ?? userId,
          userData: userData,
        );

        _authStateController.add(true);
        return Right(userId);
      } else {
        return Left(
          AuthenticationFailure(
            message: response.data?['message']?.toString() ??
                response.data?['exc']?.toString() ??
                'OTP verification failed',
            code: 'INVALID_OTP',
          ),
        );
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ??
              e.response?.data['exc']?.toString())
          : null;
      return Left(
        ServerFailure(
          message: errorMessage ?? e.message ?? 'OTP verification failed',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'OTP verification failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> sendOtp({required String phone}) async {
    try {
      final formattedPhone = _formatPhoneNumber(phone);

      // Use custom endpoint if configured, otherwise use default
      final endpoint = otpConfig.generateOtpMethod != null
          ? '/api/method/${otpConfig.generateOtpMethod}'
          : '/api/method/frappe.core.doctype.sms_settings.sms_settings.send_otp';

      final response = await _client.dio.post(
        endpoint,
        data: {
          'mobile_no': formattedPhone,
          'phone': formattedPhone, // Some implementations use 'phone'
        },
      );

      if (response.statusCode == 200) {
        return const Right(true);
      } else {
        return Left(
          ServerFailure(
            message: response.data?['message']?.toString() ?? 'Failed to send OTP',
            statusCode: response.statusCode,
          ),
        );
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data is Map
          ? e.response?.data['message']?.toString()
          : null;
      return Left(
        ServerFailure(
          message: errorMessage ?? e.message ?? 'Failed to send OTP',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to send OTP: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Format phone number with country code if configured
  String _formatPhoneNumber(String phone) {
    if (otpConfig.defaultCountryCode != null &&
        !phone.startsWith('+') &&
        !phone.startsWith('00')) {
      return '${otpConfig.defaultCountryCode}$phone';
    }
    return phone;
  }

  /// Resend OTP to the same phone number
  ///
  /// Convenience method that calls [sendOtp] again
  Future<Either<Failure, bool>> resendOtp({required String phone}) async {
    return sendOtp(phone: phone);
  }

  @override
  Future<Either<Failure, bool>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final result = await loginWithOtp(phone: phone, otp: otp);
    return result.fold(
      (failure) => Left(failure),
      (_) => const Right(true),
    );
  }

  @override
  Future<Either<Failure, bool>> logout() async {
    try {
      // Call Frappe logout endpoint
      await _client.dio.get('/api/method/logout');

      // Clear local session
      await clearUserSession();
      _client.clearAuth();

      _authStateController.add(false);
      return const Right(true);
    } on DioException catch (e) {
      // Even if server logout fails, clear local session
      await clearUserSession();
      _client.clearAuth();
      _authStateController.add(false);

      return Left(
        ServerFailure(
          message: e.message ?? 'Logout failed on server',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      await clearUserSession();
      _client.clearAuth();
      _authStateController.add(false);

      return Left(
        UnknownFailure(
          message: 'Logout failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    // Frappe uses session-based auth, so we need to re-authenticate
    // or rely on the session cookie being valid
    try {
      final result = await getLoggedUser();
      return result.fold(
        (failure) => Left(failure),
        (userData) {
          final userId = userData['name'] ?? userData['email'];
          return Right(userId?.toString() ?? '');
        },
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Token refresh failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: _keyAuthToken, value: token);
  }

  @override
  Future<void> clearAuthToken() async {
    await _secureStorage.delete(key: _keyAuthToken);
  }

  @override
  Future<void> saveUserSession({
    required String userId,
    required String token,
    Map<String, dynamic>? userData,
  }) async {
    await Future.wait([
      _secureStorage.write(key: _keyUserId, value: userId),
      _secureStorage.write(key: _keyAuthToken, value: token),
      if (userData != null)
        _secureStorage.write(key: _keyUserData, value: jsonEncode(userData)),
    ]);
  }

  @override
  Future<void> clearUserSession() async {
    await Future.wait([
      _secureStorage.delete(key: _keyUserId),
      _secureStorage.delete(key: _keyAuthToken),
      _secureStorage.delete(key: _keyUserData),
      _secureStorage.delete(key: _keyApiKey),
      _secureStorage.delete(key: _keyApiSecret),
      _secureStorage.delete(key: _keySessionId),
    ]);
  }

  @override
  Future<bool> isTokenValid() async {
    try {
      final result = await getLoggedUser();
      return result.isRight();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getUserData() async {
    final userData = await _secureStorage.read(key: _keyUserData);
    if (userData != null) {
      return jsonDecode(userData) as Map<String, dynamic>;
    }
    return null;
  }

  // ==================== IFrappeAuthService Implementation ====================

  @override
  Future<Either<Failure, String>> loginWithApiKey({
    required String apiKey,
    required String apiSecret,
  }) async {
    try {
      // Set credentials on client
      _client.setApiCredentials(apiKey, apiSecret);

      // Verify credentials by fetching logged user
      final result = await getLoggedUser();

      return result.fold(
        (failure) {
          _client.clearAuth();
          return Left(failure);
        },
        (userData) async {
          final userId = userData['name'] ?? userData['email'] ?? 'api_user';

          // Save credentials securely
          await Future.wait([
            _secureStorage.write(key: _keyApiKey, value: apiKey),
            _secureStorage.write(key: _keyApiSecret, value: apiSecret),
            saveUserSession(
              userId: userId.toString(),
              token: '$apiKey:$apiSecret',
              userData: userData,
            ),
          ]);

          _authStateController.add(true);
          return Right(userId.toString());
        },
      );
    } catch (e, stackTrace) {
      _client.clearAuth();
      return Left(
        UnknownFailure(
          message: 'API key login failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getLoggedUser() async {
    try {
      final response = await _client.dio.get(
        '/api/method/frappe.auth.get_logged_user',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final message = data['message'];

        if (message is String) {
          // Just the username/email returned
          return Right({'name': message, 'email': message});
        } else if (message is Map) {
          return Right(Map<String, dynamic>.from(message));
        } else {
          return Right({'name': message?.toString() ?? 'unknown'});
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return Left(AuthenticationFailure.sessionExpired());
      } else {
        return Left(
          ServerFailure(
            message: 'Failed to get logged user',
            statusCode: response.statusCode,
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return Left(AuthenticationFailure.sessionExpired());
      }
      return Left(
        ServerFailure(
          message: e.message ?? 'Failed to get logged user',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to get logged user: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/method/frappe.core.doctype.user.user.update_password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );

      if (response.statusCode == 200) {
        return const Right(true);
      } else {
        return Left(
          ServerFailure(
            message: response.data?['message'] ?? 'Failed to update password',
            statusCode: response.statusCode,
          ),
        );
      }
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? 'Failed to update password',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to update password: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> resetPassword({required String email}) async {
    try {
      final response = await _client.dio.post(
        '/api/method/frappe.core.doctype.user.user.reset_password',
        data: {'user': email},
      );

      if (response.statusCode == 200) {
        return const Right(true);
      } else {
        return Left(
          ServerFailure(
            message:
                response.data?['message'] ?? 'Failed to send reset password',
            statusCode: response.statusCode,
          ),
        );
      }
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? 'Failed to send reset password',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to send reset password: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> verifyResetToken({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/method/frappe.core.doctype.user.user.update_password',
        data: {
          'key': token,
          'new_password': newPassword,
        },
      );

      if (response.statusCode == 200) {
        return const Right(true);
      } else {
        return Left(
          ServerFailure(
            message: response.data?['message'] ?? 'Invalid reset token',
            statusCode: response.statusCode,
          ),
        );
      }
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? 'Failed to verify reset token',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to verify reset token: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==================== ISocialAuthService Implementation ====================

  @override
  Future<Either<Failure, String>> loginWithGoogle() async {
    return _loginWithSocialProvider('google');
  }

  @override
  Future<Either<Failure, String>> loginWithApple() async {
    return _loginWithSocialProvider('apple');
  }

  @override
  Future<Either<Failure, String>> loginWithFacebook() async {
    return _loginWithSocialProvider('facebook');
  }

  /// Generic social login handler
  ///
  /// This method initiates OAuth flow with Frappe's social login.
  /// The actual OAuth flow should be handled by the app using packages like:
  /// - google_sign_in for Google
  /// - sign_in_with_apple for Apple
  /// - flutter_facebook_auth for Facebook
  ///
  /// After getting the OAuth token from the provider, call [loginWithSocialToken]
  Future<Either<Failure, String>> _loginWithSocialProvider(
    String provider,
  ) async {
    try {
      // Get OAuth authorization URL from Frappe
      final response = await _client.dio.get(
        '/api/method/frappe.integrations.oauth2_logins.get_oauth_url',
        queryParameters: {'provider': provider},
      );

      if (response.statusCode == 200) {
        final authUrl = response.data['message'];
        if (authUrl != null) {
          // Return the auth URL - the app should handle the OAuth flow
          // and then call loginWithSocialToken with the result
          return Right(authUrl.toString());
        }
      }

      return Left(
        ServerFailure(
          message: 'Failed to get OAuth URL for $provider',
          statusCode: response.statusCode,
        ),
      );
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? 'Failed to initiate $provider login',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to initiate $provider login: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Complete social login with OAuth token from provider
  ///
  /// Call this after completing the OAuth flow with the provider's SDK
  Future<Either<Failure, String>> loginWithSocialToken({
    required String provider,
    required String token,
    String? accessToken,
    String? idToken,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/method/frappe.integrations.oauth2_logins.login_via_token',
        data: {
          'provider': provider,
          'token': token,
          if (accessToken != null) 'access_token': accessToken,
          if (idToken != null) 'id_token': idToken,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final userId = data['message']?['user'] ??
            data['message']?['email'] ??
            'social_user';

        await saveUserSession(
          userId: userId.toString(),
          token: token,
          userData: data['message'] is Map
              ? Map<String, dynamic>.from(data['message'])
              : null,
        );

        _authStateController.add(true);
        return Right(userId.toString());
      } else {
        return Left(
          AuthenticationFailure(
            message:
                response.data?['message'] ?? 'Social login failed',
          ),
        );
      }
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? 'Social login failed',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Social login failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> linkGoogle() async {
    return _linkSocialAccount('google');
  }

  @override
  Future<Either<Failure, bool>> linkApple() async {
    return _linkSocialAccount('apple');
  }

  Future<Either<Failure, bool>> _linkSocialAccount(String provider) async {
    try {
      final response = await _client.dio.post(
        '/api/method/frappe.integrations.oauth2_logins.link_social_account',
        data: {'provider': provider},
      );

      if (response.statusCode == 200) {
        return const Right(true);
      } else {
        return Left(
          ServerFailure(
            message: response.data?['message'] ?? 'Failed to link $provider',
            statusCode: response.statusCode,
          ),
        );
      }
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? 'Failed to link $provider',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to link $provider: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> unlinkSocialAccount(String provider) async {
    try {
      final response = await _client.dio.post(
        '/api/method/frappe.integrations.oauth2_logins.unlink_social_account',
        data: {'provider': provider},
      );

      if (response.statusCode == 200) {
        return const Right(true);
      } else {
        return Left(
          ServerFailure(
            message: response.data?['message'] ?? 'Failed to unlink $provider',
            statusCode: response.statusCode,
          ),
        );
      }
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? 'Failed to unlink $provider',
          statusCode: e.response?.statusCode,
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Left(
        UnknownFailure(
          message: 'Failed to unlink $provider: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==================== Restore Session ====================

  /// Restore session from secure storage
  /// Call this on app startup to restore previous session
  Future<bool> restoreSession() async {
    try {
      // Try to restore API key credentials
      final apiKey = await _secureStorage.read(key: _keyApiKey);
      final apiSecret = await _secureStorage.read(key: _keyApiSecret);

      if (apiKey != null && apiSecret != null) {
        _client.setApiCredentials(apiKey, apiSecret);

        // Verify the session is still valid
        final result = await getLoggedUser();
        if (result.isRight()) {
          _authStateController.add(true);
          return true;
        }
      }

      // Try to restore token-based session
      final token = await getAuthToken();
      if (token != null) {
        _client.setToken(token);

        // Verify the session is still valid
        final result = await getLoggedUser();
        if (result.isRight()) {
          _authStateController.add(true);
          return true;
        }
      }

      // Session could not be restored
      await clearUserSession();
      _client.clearAuth();
      _authStateController.add(false);
      return false;
    } catch (_) {
      _authStateController.add(false);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}
