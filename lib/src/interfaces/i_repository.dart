import 'package:dartz/dartz.dart';
import '../core/failure.dart';

/// Represents a paginated result with metadata
class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;

  PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get hasMore => page < totalPages;
}

/// Generic repository interface for CRUD operations
/// [T] - Entity type
/// [ID] - Identifier type (usually String for Frappe)
abstract class IRepository<T, ID> {
  /// Get a single entity by ID
  Future<Either<Failure, T>> getById(ID id);

  /// Get all entities
  Future<Either<Failure, List<T>>> getAll();

  /// Create a new entity
  Future<Either<Failure, T>> create(T entity);

  /// Update an existing entity
  Future<Either<Failure, T>> update(T entity);

  /// Delete an entity by ID
  Future<Either<Failure, bool>> delete(ID id);
}

/// Extended repository interface with pagination support
abstract class IPaginatedRepository<T, ID> extends IRepository<T, ID> {
  /// Get paginated results with optional filters
  Future<Either<Failure, PaginatedResult<T>>> getPaginated({
    int page = 1,
    int pageSize = 20,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool descending = true,
  });

  /// Search entities by query
  Future<Either<Failure, PaginatedResult<T>>> search({
    required String query,
    int page = 1,
    int pageSize = 20,
    Map<String, dynamic>? additionalFilters,
  });
}

/// Repository interface with caching support
abstract class ICachedRepository<T, ID> extends IRepository<T, ID> {
  /// Get from cache first, then network
  Future<Either<Failure, T>> getByIdCached(
    ID id, {
    bool forceRefresh = false,
  });

  /// Clear cache for this repository
  Future<void> clearCache();

  /// Check if data is cached
  Future<bool> isCached(ID id);

  /// Get cache timestamp
  Future<DateTime?> getCacheTimestamp(ID id);
}

/// Repository interface with sync support for offline-first apps
abstract class ISyncableRepository<T, ID> extends IRepository<T, ID> {
  /// Sync local data with server
  Future<Either<Failure, void>> sync();

  /// Get items pending sync
  Future<List<T>> getPendingSync();

  /// Mark item as synced
  Future<void> markAsSynced(ID id);

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime();
}

/// Base repository implementation with common functionality
/// Provides default implementations for Frappe-based repositories
abstract class BaseFrappeRepository<T, ID> implements IRepository<T, ID> {
  /// The Frappe doctype name (e.g., "User", "ToDo")
  String get doctype;

  /// Convert JSON to entity
  T fromJson(Map<String, dynamic> json);

  /// Convert entity to JSON
  Map<String, dynamic> toJson(T entity);

  /// Get entity ID
  ID getId(T entity);
}

/// Offline-first repository combining caching and sync
abstract class IOfflineFirstRepository<T, ID>
    implements ICachedRepository<T, ID>, ISyncableRepository<T, ID> {
  /// Save entity locally (for offline use)
  Future<Either<Failure, T>> saveLocally(T entity);

  /// Get all local entities
  Future<Either<Failure, List<T>>> getAllLocal();

  /// Delete local entity
  Future<Either<Failure, bool>> deleteLocally(ID id);

  /// Check if entity exists locally
  Future<bool> existsLocally(ID id);
}
