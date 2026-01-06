# Shoutout 📢

A robust Frappe API client for Flutter with built-in retry logic, fault tolerance, and authentication.

## Features

✅ **Full Frappe API Support** - Call methods, CRUD operations on doctypes
✅ **Built-in Retry Logic** - Automatic retry with exponential backoff
✅ **Fault Tolerance** - Network connectivity checks, timeout handling
✅ **Multiple Auth Methods** - API Key/Secret and Bearer Token support
✅ **Type-Safe** - Strongly typed responses with generics
✅ **Detailed Logging** - Pretty network logs in debug mode
✅ **Custom Exceptions** - Specific exception types for better error handling
✅ **Highly Configurable** - Customize timeouts, retries, and more
✅ **Offline-First** - Request queuing and automatic sync when online
✅ **Network Monitoring** - Real-time connectivity detection and quality tracking
✅ **Cache Management** - Flexible caching with TTL for offline support
✅ **Clean Architecture** - Failure pattern with Either/Result types
✅ **File Upload/Download** - Progress tracking, pause/resume, batch uploads
✅ **Query Builder** - Fluent API for complex queries with filters and aggregations
✅ **Real-time Support** - WebSocket client for live updates and events
✅ **Batch Operations** - Bulk create, update, delete with parallel execution
✅ **Mock Client** - Complete testing support with in-memory data storage

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  shoutout:
    path: ../shoutout/shoutout
```

Then run:
```bash
flutter pub get
```

## Quick Start

### 1. Initialize the Client

```dart
import 'package:shoutout/shoutout.dart';

// Create configuration
final config = ShoutoutConfig(
  baseUrl: 'https://yoursite.frappe.cloud',
  connectTimeout: Duration(seconds: 30),
  maxRetries: 3,
  enableLogging: true,
);

// Initialize client
final client = ShoutoutClient(config: config);
```

### 2. Authenticate

#### Using API Key & Secret
```dart
client.setApiCredentials('your_api_key', 'your_api_secret');
```

#### Using Bearer Token
```dart
client.setToken('your_bearer_token');
```

### 3. Make API Calls

#### Call a Frappe Method
```dart
try {
  final result = await client.callMethod(
    'frappe.auth.get_logged_user',
    params: {'include_roles': true},
  );
  print('User: $result');
} on ShoutoutException catch (e) {
  print('Error: ${e.message}');
}
```

#### Get a Document
```dart
final user = await client.getDoc(
  'User',
  'user@example.com',
  fields: ['name', 'email', 'full_name'],
);
```

#### Get List of Documents
```dart
final users = await client.getList(
  'User',
  fields: ['name', 'email'],
  filters: {'enabled': 1},
  limitPageLength: 20,
  orderBy: 'creation desc',
);
```

#### Create a Document
```dart
final newUser = await client.createDoc(
  'User',
  data: {
    'email': 'newuser@example.com',
    'first_name': 'John',
    'last_name': 'Doe',
  },
);
```

#### Update a Document
```dart
await client.updateDoc(
  'User',
  'user@example.com',
  data: {'mobile_no': '+1234567890'},
);
```

#### Delete a Document
```dart
await client.deleteDoc('User', 'user@example.com');
```

## Advanced Usage

### Custom Configuration

```dart
final config = ShoutoutConfig(
  baseUrl: 'https://yoursite.frappe.cloud',
  connectTimeout: Duration(seconds: 60),
  receiveTimeout: Duration(seconds: 60),
  sendTimeout: Duration(seconds: 30),
  maxRetries: 5,
  retryDelays: [
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
  ],
  retryableStatuses: {408, 429, 500, 502, 503, 504},
  enableLogging: true,
  enableNetworkLogging: true,
);
```

### Error Handling

```dart
try {
  final result = await client.getDoc('User', 'test@example.com');
} on AuthenticationException catch (e) {
  print('Authentication failed: ${e.message}');
} on NetworkException catch (e) {
  print('No internet connection');
} on NotFoundException catch (e) {
  print('Document not found');
} on FrappeException catch (e) {
  print('Frappe error: ${e.serverMessage}');
} on ShoutoutException catch (e) {
  print('General error: ${e.message}');
}
```

### Access Underlying Dio Instance

For advanced use cases, you can access the underlying Dio instance:

```dart
final dio = client.dio;
dio.interceptors.add(yourCustomInterceptor);
```

## Exception Types

- `ShoutoutException` - Base exception class
- `NetworkException` - No internet connection
- `AuthenticationException` - 401 Unauthorized
- `AuthorizationException` - 403 Forbidden
- `NotFoundException` - 404 Not Found
- `ServerException` - 5xx Server errors
- `TimeoutException` - Request timeout
- `FrappeException` - Frappe-specific errors with server messages

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `baseUrl` | String | Required | Base URL of Frappe instance |
| `connectTimeout` | Duration | 30s | Connection timeout |
| `receiveTimeout` | Duration | 30s | Receive timeout |
| `sendTimeout` | Duration | 30s | Send timeout |
| `maxRetries` | int | 3 | Max retry attempts |
| `retryDelays` | List<Duration> | [1s, 2s, 4s] | Delays between retries |
| `retryableStatuses` | Set<int> | {408, 429, 503} | HTTP codes to retry |
| `enableLogging` | bool | true | Enable logging |
| `enableNetworkLogging` | bool | true | Enable network logs |

## Features in Detail

### Automatic Retry
Failed requests are automatically retried with exponential backoff for:
- Network timeouts
- Connection errors
- 5xx server errors
- Configurable HTTP status codes

### Network Connectivity
Requests are blocked if no internet connection is detected, preventing unnecessary failures.

### Frappe-Specific
- Automatic handling of Frappe response format (`data` and `message` fields)
- Support for Frappe API Key and Bearer Token authentication
- Proper parsing of Frappe error responses

## Offline-First Architecture (v0.0.2+)

Shoutout provides comprehensive offline-first capabilities:

### Network Monitoring
```dart
final networkMonitor = NetworkMonitor();

networkMonitor.statusStream.listen((status) {
  if (status.isConnected) {
    print('Online: ${status.connectionType}');
  }
});
```

### Cache Manager
```dart
final cacheManager = CacheManager();
await cacheManager.initialize();

final users = await cacheManager.getOrFetch(
  'users',
  () => client.getList('User'),
  expiresIn: Duration(hours: 1),
);
```

### Offline Queue
```dart
final queueManager = OfflineQueueManager(dio: client.dio);
await queueManager.initialize();

// Automatically queues when offline and syncs when online
```

### Clean Architecture with Failures
```dart
Future<Either<Failure, List<User>>> getUsers() async {
  try {
    final response = await client.getList('User');
    final users = (response as List)
        .map((json) => User.fromJson(json))
        .toList();
    return Right(users);
  } on ShoutoutException catch (e) {
    return Left(e.toFailure());
  }
}

// In BLoC
result.fold(
  (failure) => emit(UserError(failure.message)),
  (users) => emit(UserLoaded(users)),
);
```

### Repository Interfaces
```dart
class UserRepository implements IRepository<User, String> {
  final ShoutoutClient client;

  @override
  Future<Either<Failure, User>> getById(String id) async {
    // Implementation
  }
}
```

### File Upload/Download
```dart
final fileManager = FileManager(dio: client.dio);

// Upload with progress
final result = await fileManager.uploadFile(
  url: 'https://example.com/upload',
  file: File('/path/to/file.jpg'),
  fileName: 'profile.jpg',
  onProgress: (sent, total) {
    print('Progress: ${(sent / total * 100).toStringAsFixed(1)}%');
  },
);
```

### Query Builder
```dart
final query = QueryBuilder('User')
  .where('enabled', 1)
  .whereLike('email', '%@example.com')
  .select(['name', 'email', 'full_name'])
  .orderBy('creation', descending: true)
  .limit(20);

final params = query.build();
final users = await client.getList('User', ...params);
```

### Real-time Support
```dart
final realtimeClient = RealtimeClient(
  baseUrl: 'https://yoursite.frappe.cloud',
  authToken: 'your_token',
);

await realtimeClient.connect();

// Subscribe to User updates
realtimeClient.subscribe('User').listen((event) {
  print('User ${event.type}: ${event.docname}');
});
```

### Batch Operations
```dart
final batchOps = BatchOperations(client: client);

final result = await batchOps.batchCreate(
  doctype: 'User',
  documents: [/* list of user data */],
  batchSize: 50,
);

print('Success: ${result.successCount}/${result.totalCount}');
```

### Mock Client for Testing
```dart
final mockClient = MockClientBuilder()
  .withNetworkDelay(true, delay: Duration(milliseconds: 50))
  .withSeedData('User', [
    {'name': 'user1', 'email': 'user1@example.com'},
  ])
  .build();

// Use in tests
final result = await mockClient.getDocument(
  doctype: 'User',
  name: 'user1',
);
```

See [USAGE_GUIDE.md](USAGE_GUIDE.md) for comprehensive examples and [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for upgrading from v0.0.1.

## Documentation

- **[README.md](README.md)** - Quick start and API reference
- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Comprehensive examples for 8+ app types
- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - Upgrade guide from v0.0.1
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[example/](example/)** - Working code examples

## License

MIT License

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
