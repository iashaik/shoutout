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

## License

MIT License

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
