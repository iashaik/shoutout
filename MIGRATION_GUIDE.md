# Migration Guide: v0.0.1 → v0.0.2

This guide helps you migrate from Shoutout v0.0.1 to v0.0.2 and take advantage of the new offline-first features.

## Overview

Version 0.0.2 introduces powerful offline-first capabilities while maintaining **100% backward compatibility**. All existing code will continue to work without changes.

## What's New?

- Failure pattern for clean error handling
- Network monitoring with real-time status
- Offline queue manager for automatic sync
- Cache manager with TTL support
- Repository and auth service interfaces
- Either/Result pattern for functional error handling

## Migration Steps

### ✅ Step 1: Update Dependencies (Optional)

The new features are **optional**. Your existing code works without any changes.

If you want to use the new features, update your `pubspec.yaml`:

```yaml
dependencies:
  shoutout:
    path: ../shoutout/shoutout
  # No additional dependencies needed - Shoutout includes everything!
```

Run:
```bash
flutter pub get
```

### ✅ Step 2: Choose Your Migration Path

You have **three options**:

#### Option A: Keep Using Exceptions (No Changes Required)

Your existing code works perfectly:

```dart
try {
  final users = await client.getList('User');
  print('Got ${users.length} users');
} on ShoutoutException catch (e) {
  print('Error: ${e.message}');
}
```

✅ **No migration needed!**

---

#### Option B: Gradually Adopt Failures

Start using the Failure pattern in new code:

```dart
// Old code (still works)
try {
  final users = await client.getList('User');
  return users;
} on ShoutoutException catch (e) {
  print('Error: ${e.message}');
  rethrow;
}

// New code (recommended for repositories)
Future<Either<Failure, List<User>>> getUsers() async {
  try {
    final response = await client.getList('User');
    final users = (response as List)
        .map((json) => User.fromJson(json))
        .toList();
    return Right(users);
  } on ShoutoutException catch (e) {
    return Left(e.toFailure());  // Convert to Failure
  }
}
```

---

#### Option C: Full Offline-First Migration

Implement complete offline-first architecture:

```dart
class UserRepository {
  final ShoutoutClient client;
  final CacheManager cache;
  final NetworkMonitor network;

  Future<Either<Failure, List<User>>> getUsers() async {
    try {
      // 1. Check cache first
      final cached = await cache.get<List<User>>('users');
      if (cached != null && network.isDisconnected) {
        return Right(cached);
      }

      // 2. Fetch from network
      final response = await client.getList('User');
      final users = (response as List)
          .map((json) => User.fromJson(json))
          .toList();

      // 3. Update cache
      await cache.put('users', users, expiresIn: Duration(minutes: 30));

      return Right(users);
    } on ShoutoutException catch (e) {
      return Left(e.toFailure());
    }
  }
}
```

## Feature-by-Feature Migration

### 1. Network Monitoring

**Before (v0.0.1):**
```dart
// No built-in network monitoring
// Had to use connectivity_plus manually
```

**After (v0.0.2):**
```dart
final networkMonitor = NetworkMonitor();

// Listen to changes
networkMonitor.statusStream.listen((status) {
  if (status.isConnected) {
    print('Online: ${status.connectionType}');
    // Trigger sync
  } else {
    print('Offline - using cached data');
  }
});

// Wait for connection
if (networkMonitor.isDisconnected) {
  await networkMonitor.waitForConnection();
}
```

### 2. Caching

**Before (v0.0.1):**
```dart
// Manual caching with shared_preferences or hive
final prefs = await SharedPreferences.getInstance();
final cached = prefs.getString('users');
if (cached != null) {
  return jsonDecode(cached);
}
```

**After (v0.0.2):**
```dart
final cacheManager = CacheManager();
await cacheManager.initialize();

// Simple cache-first
final users = await cacheManager.getOrFetch(
  'users',
  () => client.getList('User'),
  expiresIn: Duration(hours: 1),
);
```

### 3. Offline Queue

**Before (v0.0.1):**
```dart
// No built-in offline queue
// Had to implement manually
```

**After (v0.0.2):**
```dart
final queueManager = OfflineQueueManager(dio: client.dio);
await queueManager.initialize();

// Queue a request when offline
if (networkMonitor.isDisconnected) {
  await queueManager.enqueueFromOptions(
    // Your request options
    priority: 10,
  );
}

// Automatically syncs when online!
```

### 4. Repository Pattern

**Before (v0.0.1):**
```dart
// Custom repository with manual error handling
class UserRepository {
  final ShoutoutClient client;

  Future<List<User>> getUsers() async {
    try {
      final response = await client.getList('User');
      return (response as List).map((e) => User.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }
}
```

**After (v0.0.2):**
```dart
// Use provided interfaces
class UserRepository implements IRepository<User, String> {
  final ShoutoutClient client;

  @override
  Future<Either<Failure, User>> getById(String id) async {
    try {
      final response = await client.getDoc('User', id);
      return Right(User.fromJson(response));
    } on ShoutoutException catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, List<User>>> getAll() async {
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

  // ... other methods
}
```

### 5. BLoC Integration

**Before (v0.0.1):**
```dart
class UserBloc extends Bloc<UserEvent, UserState> {
  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final users = await repository.getUsers();
      emit(UserLoaded(users));
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }
}
```

**After (v0.0.2):**
```dart
class UserBloc extends Bloc<UserEvent, UserState> {
  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserState> emit) async {
    emit(UserLoading());

    final result = await repository.getUsers();

    result.fold(
      (failure) => emit(UserError(failure.message)),
      (users) => emit(UserLoaded(users)),
    );
  }
}
```

## Common Patterns

### Pattern 1: Cache-First with Network Fallback

```dart
Future<Either<Failure, List<T>>> getData<T>(String key, Future<List<T>> Function() fetchFn) async {
  try {
    // Try cache
    final cached = await cache.get<List<T>>(key);
    if (cached != null) {
      return Right(cached);
    }

    // Fetch from network
    final data = await fetchFn();
    await cache.put(key, data);
    return Right(data);
  } on ShoutoutException catch (e) {
    return Left(e.toFailure());
  }
}
```

### Pattern 2: Offline-First Writes

```dart
Future<Either<Failure, void>> createItem<T>(String doctype, T item) async {
  try {
    if (network.isConnected) {
      await client.createDoc(doctype, data: item.toJson());
    } else {
      // Queue for later
      await queueManager.enqueueFromOptions(...);
    }
    return const Right(null);
  } on ShoutoutException catch (e) {
    return Left(e.toFailure());
  }
}
```

### Pattern 3: Smart Refresh

```dart
Future<Either<Failure, List<T>>> getDataWithRefresh<T>(
  String key,
  Future<List<T>> Function() fetchFn,
  {bool forceRefresh = false}
) async {
  try {
    return Right(await cache.getOrFetch(
      key,
      fetchFn,
      forceRefresh: forceRefresh,
    ));
  } on ShoutoutException catch (e) {
    return Left(e.toFailure());
  }
}
```

## Benefits of Migrating

### Using Failures
- ✅ Type-safe error handling
- ✅ Clear error types (NetworkFailure, AuthFailure, etc.)
- ✅ No exceptions in business logic
- ✅ Better testability

### Using Cache
- ✅ Faster app startup
- ✅ Works offline
- ✅ Reduces API calls
- ✅ Better user experience

### Using Network Monitor
- ✅ Real-time connectivity status
- ✅ Better error messages
- ✅ Automatic retry when online
- ✅ User feedback

### Using Offline Queue
- ✅ Never lose user data
- ✅ Automatic sync
- ✅ Priority-based processing
- ✅ Works seamlessly

## Testing Changes

### Before (v0.0.1)
```dart
test('should load users', () async {
  when(() => client.getList('User'))
      .thenAnswer((_) async => [{'name': 'John'}]);

  final result = await repository.getUsers();
  expect(result, isA<List<User>>());
});
```

### After (v0.0.2)
```dart
test('should return Right with users on success', () async {
  when(() => client.getList('User'))
      .thenAnswer((_) async => [{'name': 'John'}]);

  final result = await repository.getUsers();

  expect(result.isRight(), true);
  result.fold(
    (failure) => fail('Should not fail'),
    (users) => expect(users, hasLength(1)),
  );
});

test('should return Left with NetworkFailure on error', () async {
  when(() => client.getList('User'))
      .thenThrow(NetworkException());

  final result = await repository.getUsers();

  expect(result.isLeft(), true);
  result.fold(
    (failure) => expect(failure, isA<NetworkFailure>()),
    (users) => fail('Should not succeed'),
  );
});
```

## Troubleshooting

### Issue: "Can't find PaginatedResult"
**Solution:** Import from Shoutout:
```dart
import 'package:shoutout/shoutout.dart';
```

### Issue: "Either type not recognized"
**Solution:** Shoutout exports Either, no need for separate dartz import:
```dart
import 'package:shoutout/shoutout.dart';
// Don't need: import 'package:dartz/dartz.dart';
```

### Issue: "Hive adapter not found"
**Solution:** Hive adapters are optional. Comment out the part directive if not using:
```dart
// part 'queued_request.g.dart';
```

## Questions?

- Check the USAGE_GUIDE.md for detailed examples
- See offline_example.dart for a complete working example
- Review the README.md for quick reference

## Summary

- ✅ **Backward Compatible** - No breaking changes
- ✅ **Optional Features** - Use what you need
- ✅ **Gradual Migration** - Adopt at your own pace
- ✅ **Better Architecture** - Clean, testable code
- ✅ **Production Ready** - Battle-tested patterns

Happy coding! 🚀
