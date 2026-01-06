import 'package:dio/dio.dart';

/// Interceptor to add Frappe authentication headers
class FrappeAuthInterceptor extends Interceptor {
  String? _apiKey;
  String? _apiSecret;
  String? _token;

  /// Set API Key and Secret for authentication
  void setApiCredentials(String apiKey, String apiSecret) {
    _apiKey = apiKey;
    _apiSecret = apiSecret;
    _token = null;
  }

  /// Set Bearer token for authentication
  void setToken(String token) {
    _token = token;
    _apiKey = null;
    _apiSecret = null;
  }

  /// Clear all authentication credentials
  void clearAuth() {
    _apiKey = null;
    _apiSecret = null;
    _token = null;
  }

  /// Check if authenticated
  bool get isAuthenticated => _token != null || (_apiKey != null && _apiSecret != null);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token != null) {
      // Use bearer token authentication
      options.headers['Authorization'] = 'Bearer $_token';
    } else if (_apiKey != null && _apiSecret != null) {
      // Use API key/secret authentication
      options.headers['Authorization'] = 'token $_apiKey:$_apiSecret';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If we get 401, clear the token as it might be expired
    if (err.response?.statusCode == 401) {
      clearAuth();
    }
    handler.next(err);
  }
}
