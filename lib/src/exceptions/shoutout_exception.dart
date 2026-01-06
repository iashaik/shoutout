import 'package:dio/dio.dart';

/// Base exception class for Shoutout package
class ShoutoutException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalException;
  final StackTrace? stackTrace;

  ShoutoutException({
    required this.message,
    this.statusCode,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'ShoutoutException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

/// Network connectivity exception
class NetworkException extends ShoutoutException {
  NetworkException({
    super.message = 'No internet connection',
    super.originalException,
    super.stackTrace,
  });
}

/// Authentication exception
class AuthenticationException extends ShoutoutException {
  AuthenticationException({
    super.message = 'Authentication failed',
    super.statusCode = 401,
    super.originalException,
    super.stackTrace,
  });
}

/// Authorization exception
class AuthorizationException extends ShoutoutException {
  AuthorizationException({
    super.message = 'Access forbidden',
    super.statusCode = 403,
    super.originalException,
    super.stackTrace,
  });
}

/// Resource not found exception
class NotFoundException extends ShoutoutException {
  NotFoundException({
    super.message = 'Resource not found',
    super.statusCode = 404,
    super.originalException,
    super.stackTrace,
  });
}

/// Server error exception
class ServerException extends ShoutoutException {
  ServerException({
    super.message = 'Server error occurred',
    super.statusCode = 500,
    super.originalException,
    super.stackTrace,
  });
}

/// Timeout exception
class TimeoutException extends ShoutoutException {
  TimeoutException({
    super.message = 'Request timeout',
    super.statusCode = 408,
    super.originalException,
    super.stackTrace,
  });
}

/// Frappe-specific error exception
class FrappeException extends ShoutoutException {
  final String? serverMessage;
  final String? exc;

  FrappeException({
    super.message = 'Frappe server error',
    super.statusCode,
    this.serverMessage,
    this.exc,
    super.originalException,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('FrappeException: $message');
    if (statusCode != null) buffer.write(' (Status: $statusCode)');
    if (serverMessage != null) buffer.write('\nServer Message: $serverMessage');
    if (exc != null) buffer.write('\nException: $exc');
    return buffer.toString();
  }
}

/// Extension to convert DioException to ShoutoutException
extension DioExceptionExtension on DioException {
  ShoutoutException toShoutoutException() {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(
          originalException: this,
          stackTrace: stackTrace,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          originalException: this,
          stackTrace: stackTrace,
        );

      case DioExceptionType.badResponse:
        final statusCode = response?.statusCode;
        final data = response?.data;

        // Try to parse Frappe error response
        if (data is Map<String, dynamic>) {
          final serverMessage = data['message'] as String?;
          final exc = data['exc'] as String?;

          if (serverMessage != null || exc != null) {
            return FrappeException(
              statusCode: statusCode,
              serverMessage: serverMessage,
              exc: exc,
              originalException: this,
              stackTrace: stackTrace,
            );
          }
        }

        // Handle standard HTTP errors
        if (statusCode != null) {
          switch (statusCode) {
            case 401:
              return AuthenticationException(
                originalException: this,
                stackTrace: stackTrace,
              );
            case 403:
              return AuthorizationException(
                originalException: this,
                stackTrace: stackTrace,
              );
            case 404:
              return NotFoundException(
                originalException: this,
                stackTrace: stackTrace,
              );
            case >= 500:
              return ServerException(
                message: 'Server error: ${response?.statusMessage ?? "Unknown"}',
                statusCode: statusCode,
                originalException: this,
                stackTrace: stackTrace,
              );
            default:
              return ShoutoutException(
                message: 'HTTP error: ${response?.statusMessage ?? "Unknown"}',
                statusCode: statusCode,
                originalException: this,
                stackTrace: stackTrace,
              );
          }
        }

        // Fallback for bad response with no status code
        return ShoutoutException(
          message: 'Bad response: ${response?.statusMessage ?? "Unknown"}',
          originalException: this,
          stackTrace: stackTrace,
        );

      case DioExceptionType.cancel:
        return ShoutoutException(
          message: 'Request cancelled',
          originalException: this,
          stackTrace: stackTrace,
        );

      default:
        return ShoutoutException(
          message: 'Unknown error occurred',
          originalException: this,
          stackTrace: stackTrace,
        );
    }
  }
}
