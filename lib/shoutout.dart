library shoutout;

// Client
export 'src/client/shoutout_client.dart';

// Configuration
export 'src/config/shoutout_config.dart';

// Exceptions
export 'src/exceptions/shoutout_exception.dart';

// Interceptors
export 'src/interceptors/connectivity_interceptor.dart';
export 'src/interceptors/frappe_auth_interceptor.dart';

// Failures (Clean Architecture error handling)
export 'src/core/failure.dart';
export 'src/core/exception_to_failure.dart';

// Network Monitoring
export 'src/network/network_monitor.dart';

// Offline Support
export 'src/offline/queued_request.dart';
export 'src/offline/offline_queue_manager.dart';

// Cache Management
export 'src/cache/cache_manager.dart';

// Interfaces (Clean Architecture)
export 'src/interfaces/i_repository.dart';
export 'src/interfaces/i_auth_service.dart';

// External dependencies (for convenience)
export 'package:dartz/dartz.dart' show Either, Left, Right;
