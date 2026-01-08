import 'package:dio/dio.dart';

/// Authentication type for Frappe
enum FrappeAuthType {
  /// No authentication
  none,

  /// API Key and Secret (token auth)
  apiKey,

  /// Bearer token (OAuth/JWT)
  bearer,

  /// Session-based authentication (cookies)
  session,
}

/// Callback for when authentication fails
typedef OnAuthFailure = void Function();

/// Interceptor to add Frappe authentication headers
class FrappeAuthInterceptor extends Interceptor {
  String? _apiKey;
  String? _apiSecret;
  String? _token;
  String? _sessionId;
  FrappeAuthType _authType = FrappeAuthType.none;

  /// Callback when authentication fails (401 response)
  OnAuthFailure? onAuthFailure;

  /// Set API Key and Secret for authentication
  void setApiCredentials(String apiKey, String apiSecret) {
    _apiKey = apiKey;
    _apiSecret = apiSecret;
    _token = null;
    _sessionId = null;
    _authType = FrappeAuthType.apiKey;
  }

  /// Set Bearer token for authentication (OAuth/JWT)
  void setToken(String token) {
    _token = token;
    _apiKey = null;
    _apiSecret = null;
    _sessionId = null;
    _authType = FrappeAuthType.bearer;
  }

  /// Set session ID for cookie-based authentication
  void setSessionId(String sessionId) {
    _sessionId = sessionId;
    _apiKey = null;
    _apiSecret = null;
    _token = null;
    _authType = FrappeAuthType.session;
  }

  /// Clear all authentication credentials
  void clearAuth() {
    _apiKey = null;
    _apiSecret = null;
    _token = null;
    _sessionId = null;
    _authType = FrappeAuthType.none;
  }

  /// Check if authenticated
  bool get isAuthenticated => _authType != FrappeAuthType.none;

  /// Get current authentication type
  FrappeAuthType get authType => _authType;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    switch (_authType) {
      case FrappeAuthType.bearer:
        // Use bearer token authentication (OAuth/JWT)
        options.headers['Authorization'] = 'Bearer $_token';
        break;

      case FrappeAuthType.apiKey:
        // Use API key/secret authentication
        options.headers['Authorization'] = 'token $_apiKey:$_apiSecret';
        break;

      case FrappeAuthType.session:
        // Use session cookie authentication
        final existingCookies = options.headers['Cookie'] as String? ?? '';
        if (existingCookies.isNotEmpty) {
          options.headers['Cookie'] = '$existingCookies; sid=$_sessionId';
        } else {
          options.headers['Cookie'] = 'sid=$_sessionId';
        }
        break;

      case FrappeAuthType.none:
        // No authentication
        break;
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Capture session cookie from login responses
    final cookies = response.headers['set-cookie'];
    if (cookies != null && cookies.isNotEmpty) {
      for (final cookie in cookies) {
        if (cookie.contains('sid=')) {
          final match = RegExp(r'sid=([^;]+)').firstMatch(cookie);
          final sessionId = match?.group(1);
          if (sessionId != null && sessionId != 'Guest') {
            _sessionId = sessionId;
            _authType = FrappeAuthType.session;
          }
        }
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If we get 401, notify and optionally clear credentials
    if (err.response?.statusCode == 401) {
      onAuthFailure?.call();
    }
    handler.next(err);
  }
}
