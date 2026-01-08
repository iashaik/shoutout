## 0.0.4

### 🚀 New Features: Document State Management, Advanced Queries & Child Tables

This release adds powerful features for working with Frappe's document lifecycle, complex queries, and child table operations.

**New Components:**

- **Document State Management (`DocumentStateService`)**
  - `submitDoc()` - Submit draft documents (docstatus 0 → 1)
  - `cancelDoc()` - Cancel submitted documents (docstatus 1 → 2)
  - `amendDoc()` - Create amended copy of cancelled documents
  - `getDocStatus()` - Get current document status
  - `canSubmit()`, `canCancel()`, `canAmend()` - Check allowed transitions
  - `getAmendments()` - Get all amendments of a document
  - `getAmendedFrom()` - Get original document name
  - `getByStatus()` - Query documents by docstatus

- **DocStatus Enum**
  - Type-safe representation of Frappe's docstatus field
  - `DocStatus.draft` (0), `DocStatus.submitted` (1), `DocStatus.cancelled` (2)
  - Helper methods: `canSubmit`, `canCancel`, `canAmend`, `isEditable`
  - Factory constructor `DocStatus.fromValue(int)`

- **Advanced Query Service (`QueryService`)**
  - `getCount()` - Efficient document counting with filters
  - `getValue()` - Get single field value from a document
  - `getValues()` - Get multiple field values at once
  - `search()` - Full-text search with field targeting
  - `exists()` - Check if document exists
  - `existsWhere()` - Check if any document matches filters
  - Aggregation methods: `sum()`, `min()`, `max()`, `avg()`
  - `distinct()` - Get unique values of a field

- **Enhanced QueryBuilder with OR Filters**
  - `orWhere()`, `orWhereNot()` - OR equality filters
  - `orWhereLike()`, `orWhereIn()`, `orWhereNotIn()` - OR pattern/list filters
  - `orWhereNull()`, `orWhereNotNull()` - OR null checks
  - `orWhereBetween()` - OR range filters
  - `orWhereGreaterThan()`, `orWhereLessThan()` - OR comparison filters
  - `orGroup()` - Add FilterGroup as OR conditions
  - `search()` - Quick search term filter

- **Child Table Support in QueryBuilder**
  - `withChildren()` - Include child table in response
  - `childField()` - Select specific child table fields
  - `whereChild()` - Filter by child table field
  - `whereChildOp()` - Filter child table with custom operator

- **Child Table Service (`ChildTableService`)**
  - `addChild()` / `addChildren()` - Add rows to child table
  - `updateChild()` / `updateChildByIndex()` - Update child rows
  - `removeChild()` / `removeChildByIndex()` - Remove child rows
  - `getChildren()` / `getChild()` / `getChildByIndex()` - Get child rows
  - `setChildren()` - Replace all child rows
  - `clearChildren()` - Remove all child rows
  - `reorderChildren()` - Reorder child rows by name list
  - `moveChildUp()` / `moveChildDown()` - Move single row up/down
  - `getChildCount()` - Count child rows

- **New Failure Type**
  - `DocumentStateFailure` - For invalid state transitions
  - Factory constructors: `alreadySubmitted`, `alreadyCancelled`, `cannotSubmit`, `cannotCancel`, `cannotAmend`
  - Includes `currentStatus`, `targetStatus`, `doctype`, `documentName`

**Enhanced Client:**
- `getList()` now supports `orFilters` parameter
- New `getListWithQuery()` method accepts `QueryBuilder` directly

**Breaking Changes:**
- None! All new features are additive and backward compatible

**Bug Fixes:**
- Fixed SDK version constraint for broader compatibility (^3.5.0)

**Documentation:**
- Updated README with comprehensive examples for all new features
- Added Document State Management section
- Added Advanced Query Service section
- Added OR Filters section
- Added Child Table Operations section

---

## 0.0.3

### 🎉 Major Features: Complete Offline-First & Advanced Features

This release transforms Shoutout into a comprehensive, production-ready Frappe API client with offline-first architecture, file management, real-time updates, batch operations, and complete testing support.

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

- **File Upload/Download Manager**
  - Progress tracking with `FileTransfer` model
  - Pause/resume/cancel functionality
  - Upload multiple files with `uploadMultiple()`
  - Download files with caching support
  - Automatic retry on failure
  - Transfer history and statistics
  - Works seamlessly with ShoutoutClient/Dio

- **Query Builder**
  - Fluent API for building complex Frappe queries
  - Type-safe filter operations (equals, like, in, between, etc.)
  - Support for ordering, pagination, and field selection
  - `FilterGroup` for complex AND/OR conditions
  - `AdvancedQueryBuilder` with aggregations (count, sum, avg, min, max)
  - Raw filter support for custom queries
  - Clone and reset capabilities

- **Real-time Support**
  - WebSocket client for Frappe real-time updates
  - Subscribe to doctype changes (insert, update, delete)
  - Subscribe to specific document updates
  - Custom event subscription and emission
  - Automatic reconnection with exponential backoff
  - Heartbeat monitoring
  - Connection state streams
  - Authentication support

- **Batch Operations**
  - Batch create, update, delete operations
  - Configurable batch sizes for optimal performance
  - Parallel execution within batches
  - `batchUpsert()` for create-or-update logic
  - Comprehensive error handling with `BatchResult`
  - Success rate tracking and statistics
  - Stop-on-error or continue-on-error modes
  - Custom batch operations with `batchExecute()`

- **Mock Client for Testing**
  - Complete mock implementation of ShoutoutClient
  - In-memory data storage
  - Seed data support
  - Simulated network delays
  - Random failure simulation
  - Call count tracking
  - `MockClientBuilder` for easy configuration
  - Perfect for unit and widget testing

**New Dependencies:**
- `dartz: ^0.10.1` - Functional programming (Either/Result pattern)
- `equatable: ^2.0.7` - Equality comparison for Failures
- `hive: ^2.2.3` - Local storage for offline queue and cache
- `hive_flutter: ^1.1.0` - Hive Flutter integration
- `path_provider: ^2.1.5` - Path access for storage
- `web_socket_channel: ^3.0.1` - WebSocket support for real-time features
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
