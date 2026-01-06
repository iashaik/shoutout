import '../exceptions/shoutout_exception.dart';
import 'failure.dart';

/// Extension to convert ShoutoutException to Failure
extension ShoutoutExceptionToFailure on ShoutoutException {
  Failure toFailure() {
    if (this is NetworkException) {
      return NetworkFailure(
        message: message,
        originalError: originalException,
        stackTrace: stackTrace,
      );
    }

    if (this is AuthenticationException) {
      return AuthenticationFailure(
        message: message,
        originalError: originalException,
        stackTrace: stackTrace,
      );
    }

    if (this is AuthorizationException) {
      return AuthorizationFailure(
        message: message,
        originalError: originalException,
        stackTrace: stackTrace,
      );
    }

    if (this is NotFoundException) {
      return NotFoundFailure(
        message: message,
        originalError: originalException,
        stackTrace: stackTrace,
      );
    }

    if (this is TimeoutException) {
      return TimeoutFailure(
        message: message,
        originalError: originalException,
        stackTrace: stackTrace,
      );
    }

    if (this is ServerException) {
      return ServerFailure(
        message: message,
        statusCode: statusCode,
        originalError: originalException,
        stackTrace: stackTrace,
      );
    }

    if (this is FrappeException) {
      final frappeEx = this as FrappeException;
      return FrappeFailure(
        message: message,
        serverMessage: frappeEx.serverMessage,
        exc: frappeEx.exc,
        statusCode: frappeEx.statusCode,
        originalError: originalException,
        stackTrace: stackTrace,
      );
    }

    // Generic failure for unknown exceptions
    return UnknownFailure(
      message: message,
      originalError: originalException,
      stackTrace: stackTrace,
    );
  }
}

/// Extension to convert any Exception to Failure
extension ExceptionToFailure on Exception {
  Failure toFailure() {
    if (this is ShoutoutException) {
      return (this as ShoutoutException).toFailure();
    }

    return UnknownFailure(
      message: toString(),
      originalError: this,
    );
  }
}
