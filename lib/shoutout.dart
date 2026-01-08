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

// Authentication
export 'src/auth/frappe_auth_service.dart';
export 'src/auth/local_auth_service.dart';
export 'src/auth/secure_auth_service.dart';

// File Management
export 'src/file/file_transfer.dart';
export 'src/file/file_manager.dart';

// Query Builder
export 'src/query/query_builder.dart';

// Real-time Support
export 'src/realtime/realtime_client.dart';

// Batch Operations
export 'src/batch/batch_operations.dart';

// Testing/Mocking
export 'src/testing/mock_client.dart';

// External dependencies (for convenience)
export 'package:dartz/dartz.dart' show Either, Left, Right;
