import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../exceptions/shoutout_exception.dart';

/// Interceptor to check network connectivity before making requests
class ConnectivityInterceptor extends Interceptor {
  final Connectivity _connectivity;

  ConnectivityInterceptor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final results = await _connectivity.checkConnectivity();
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!hasConnection) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: NetworkException(),
        ),
      );
      return;
    }

    handler.next(options);
  }
}
