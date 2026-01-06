## 0.0.2 (Unreleased)

### 🎉 Major Features: Offline-First Architecture

**New Components:**
- **Failure Pattern (Clean Architecture)**
  - Added comprehensive `Failure` class hierarchy with 11 specific failure types
  - `NetworkFailure`, `AuthenticationFailure`, `AuthorizationFailure`, `NotFoundFailure`, `TimeoutFailure`, `ServerFailure`, `FrappeFailure`, `CacheFailure`, `ValidationFailure`, `ParsingFailure`, `UnknownFailure`
  - Extension methods to convert `ShoutoutException` to `Failure`
  - Full support for `Either<Failure, T>` pattern via dartz

- **Network Monitoring**
  - Real-time connectivity detection with streams
  - Connection type detection (WiFi, Mobile, Ethernet, VPN, Bluetooth, etc.)
  - Connection quality estimation (Excellent, Good, Poor, None)
  - `NetworkStatus` class with complete connectivity information
  - `waitForConnection()` method for automatic retry scenarios
  - Singleton instance available via `NetworkMonitorSingleton`

- **Offline Queue Manager**
  - Automatic request queuing when offline
  - Priority-based queue processing
  - Configurable auto-sync with customizable intervals
  - Retry logic with max attempts
  - Request tagging for grouping and filtering
  - Delayed execution support
  - Result streams for real-time monitoring
  - Hive-based persistence (optional)

- **Cache Manager**
  - Flexible TTL-based caching with automatic expiration
  - `getOrFetch()` for cache-first strategies
  - Max size enforcement with LRU-like eviction
  - Cache statistics and analytics
  - Manual cleanup and maintenance
  - Hive-based storage

- **Repository Interfaces**
  - `IRepository<T, ID>` - Basic CRUD operations
  - `IPaginatedRepository<T, ID>` - With pagination support
  - `ICachedRepository<T, ID>` - With caching capabilities
  - `ISyncableRepository<T, ID>` - With offline sync
  - `IOfflineFirstRepository<T, ID>` - Complete offline-first pattern
  - `BaseFrappeRepository<T, ID>` - Base implementation for Frappe
  - `PaginatedResult<T>` - Pagination wrapper with metadata

- **Auth Service Interfaces**
  - `IAuthService` - Core authentication operations
  - `ISocialAuthService` - Social login (Google, Apple, Facebook)
  - `IMFAAuthService` - Multi-factor authentication
  - `IFrappeAuthService` - Frappe-specific authentication

**New Dependencies:**
- `dartz: ^0.10.1` - Functional programming (Either/Result pattern)
- `equatable: ^2.0.7` - Equality comparison for Failures
- `hive: ^2.2.3` - Local storage for offline queue and cache
- `hive_flutter: ^1.1.0` - Hive Flutter integration
- `path_provider: ^2.1.5` - Path access for storage
- `hive_generator: ^2.0.1` (dev) - Code generation for Hive adapters

**Documentation:**
- Comprehensive USAGE_GUIDE.md Section 9: "Offline-First Architecture"
- Complete offline-first examples with NetworkMonitor, Cache, and Queue
- Repository pattern examples
- Best practices for offline apps
- Updated README with new features
- New `offline_example.dart` demonstrating all features

**Breaking Changes:**
- None! All new features are additive and backward compatible

**Improvements:**
- Better error handling with specific Failure types
- Cleaner architecture with Either pattern
- Production-ready offline support
- Comprehensive interfaces for common patterns

---

## 0.0.1

### Initial Release

**Core Features:**
- Full Frappe API support (method calls, CRUD operations)
- Built-in retry logic with exponential backoff
- Network connectivity checks before requests
- Multiple authentication methods (API Key/Secret, Bearer Token)
- Type-safe responses with generics
- Detailed logging with pretty printer
- Custom exception hierarchy
- Highly configurable timeouts and retries

**Components:**
- `ShoutoutClient` - Main API client
- `ShoutoutConfig` - Configuration system
- `ConnectivityInterceptor` - Pre-request connectivity check
- `FrappeAuthInterceptor` - Authentication header injection
- Exception types: `NetworkException`, `AuthenticationException`, `AuthorizationException`, `NotFoundException`, `ServerException`, `TimeoutException`, `FrappeException`

**Dependencies:**
- `dio: ^5.7.0`
- `dio_smart_retry: ^6.0.0`
- `pretty_dio_logger: ^1.4.0`
- `connectivity_plus: ^6.1.5`
- `json_annotation: ^4.9.0`
- `flutter_secure_storage: ^9.2.4`

**Documentation:**
- Comprehensive README with examples
- Detailed USAGE_GUIDE with 8 real-world application examples
- Example file demonstrating all features
