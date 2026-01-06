import 'package:equatable/equatable.dart';

/// Base class for all failures in the application
/// Failures represent expected errors that should be handled gracefully
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const Failure({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

/// Server-side error (5xx, 4xx)
class ServerFailure extends Failure {
  final int? statusCode;
  final Map<String, dynamic>? responseData;

  const ServerFailure({
    required super.message,
    this.statusCode,
    this.responseData,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ServerFailure.fromStatusCode(int statusCode, String message) {
    return ServerFailure(
      message: message,
      statusCode: statusCode,
      code: 'SERVER_ERROR_$statusCode',
    );
  }

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// Network connectivity error
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection',
    super.code = 'NETWORK_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Local cache error
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Cache error occurred',
    super.code = 'CACHE_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Validation error (form validation, business rules)
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    this.fieldErrors,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// Authentication error (401)
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    super.message = 'Authentication failed',
    super.code = 'AUTHENTICATION_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory AuthenticationFailure.unauthorized() {
    return const AuthenticationFailure(
      message: 'You are not authorized to perform this action',
      code: 'UNAUTHORIZED',
    );
  }

  factory AuthenticationFailure.sessionExpired() {
    return const AuthenticationFailure(
      message: 'Your session has expired. Please log in again',
      code: 'SESSION_EXPIRED',
    );
  }

  factory AuthenticationFailure.invalidCredentials() {
    return const AuthenticationFailure(
      message: 'Invalid credentials',
      code: 'INVALID_CREDENTIALS',
    );
  }
}

/// Authorization error (403)
class AuthorizationFailure extends Failure {
  const AuthorizationFailure({
    super.message = 'You do not have permission to perform this action',
    super.code = 'AUTHORIZATION_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Resource not found error (404)
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Resource not found',
    super.code = 'NOT_FOUND',
    super.originalError,
    super.stackTrace,
  });
}

/// Timeout error
class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.message = 'Request timeout',
    super.code = 'TIMEOUT_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Parsing/Serialization error
class ParsingFailure extends Failure {
  const ParsingFailure({
    super.message = 'Failed to parse data',
    super.code = 'PARSING_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Frappe-specific error with server messages
class FrappeFailure extends Failure {
  final String? serverMessage;
  final String? exc;
  final int? statusCode;

  const FrappeFailure({
    required super.message,
    this.serverMessage,
    this.exc,
    this.statusCode,
    super.code = 'FRAPPE_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  List<Object?> get props => [...super.props, serverMessage, exc, statusCode];
}

/// Unknown/Unexpected error
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.code = 'UNKNOWN_ERROR',
    super.originalError,
    super.stackTrace,
  });
}
