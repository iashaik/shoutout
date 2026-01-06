import 'dart:async';
import 'package:hive/hive.dart';

/// Represents a cached item with expiration
class CachedItem<T> {
  final T data;
  final DateTime cachedAt;
  final Duration? expiresIn;

  const CachedItem({
    required this.data,
    required this.cachedAt,
    this.expiresIn,
  });

  bool get isExpired {
    if (expiresIn == null) return false;
    return DateTime.now().difference(cachedAt) > expiresIn!;
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'cachedAt': cachedAt.toIso8601String(),
      'expiresIn': expiresIn?.inSeconds,
    };
  }

  factory CachedItem.fromJson(Map<String, dynamic> json) {
    return CachedItem(
      data: json['data'] as T,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      expiresIn: json['expiresIn'] != null
          ? Duration(seconds: json['expiresIn'] as int)
          : null,
    );
  }
}

/// Configuration for cache behavior
class CacheConfig {
  final String boxName;
  final Duration defaultExpiration;
  final int maxSize;
  final bool cleanupOnInit;

  const CacheConfig({
    this.boxName = 'shoutout_cache',
    this.defaultExpiration = const Duration(hours: 1),
    this.maxSize = 1000,
    this.cleanupOnInit = true,
  });
}

/// Simple cache manager for storing API responses
class CacheManager {
  final CacheConfig config;
  Box<Map>? _cacheBox;

  CacheManager({this.config = const CacheConfig()});

  /// Initialize the cache manager
  Future<void> initialize() async {
    _cacheBox = await Hive.openBox<Map>(config.boxName);

    if (config.cleanupOnInit) {
      await _cleanupExpired();
    }

    // Enforce max size
    if (_cacheBox!.length > config.maxSize) {
      await _enforceMaxSize();
    }
  }

  /// Store data in cache
  Future<void> put<T>(
    String key,
    T data, {
    Duration? expiresIn,
  }) async {
    if (_cacheBox == null) {
      throw StateError('CacheManager not initialized');
    }

    final item = CachedItem<T>(
      data: data,
      cachedAt: DateTime.now(),
      expiresIn: expiresIn ?? config.defaultExpiration,
    );

    await _cacheBox!.put(key, item.toJson());

    // Check if we need to enforce max size
    if (_cacheBox!.length > config.maxSize) {
      await _enforceMaxSize();
    }
  }

  /// Get data from cache
  Future<T?> get<T>(String key) async {
    if (_cacheBox == null) {
      throw StateError('CacheManager not initialized');
    }

    final json = _cacheBox!.get(key);
    if (json == null) return null;

    try {
      final item = CachedItem<T>.fromJson(Map<String, dynamic>.from(json));

      if (item.isExpired) {
        await delete(key);
        return null;
      }

      return item.data;
    } catch (e) {
      // Invalid cache format, delete it
      await delete(key);
      return null;
    }
  }

  /// Get data from cache or fetch from provided function
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetchFn, {
    Duration? expiresIn,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await get<T>(key);
      if (cached != null) {
        return cached;
      }
    }

    final data = await fetchFn();
    await put(key, data, expiresIn: expiresIn);
    return data;
  }

  /// Check if key exists in cache (and is not expired)
  Future<bool> has(String key) async {
    final data = await get(key);
    return data != null;
  }

  /// Delete a specific cache entry
  Future<void> delete(String key) async {
    await _cacheBox?.delete(key);
  }

  /// Clear all cache
  Future<void> clear() async {
    await _cacheBox?.clear();
  }

  /// Get all cache keys
  List<String> get keys {
    if (_cacheBox == null) return [];
    return _cacheBox!.keys.cast<String>().toList();
  }

  /// Get cache size (number of entries)
  int get size => _cacheBox?.length ?? 0;

  /// Remove expired entries
  Future<void> _cleanupExpired() async {
    if (_cacheBox == null) return;

    final keysToDelete = <String>[];

    for (final key in _cacheBox!.keys) {
      try {
        final json = _cacheBox!.get(key);
        if (json != null) {
          final item = CachedItem.fromJson(Map<String, dynamic>.from(json));
          if (item.isExpired) {
            keysToDelete.add(key.toString());
          }
        }
      } catch (e) {
        // Invalid format, mark for deletion
        keysToDelete.add(key.toString());
      }
    }

    for (final key in keysToDelete) {
      await _cacheBox!.delete(key);
    }
  }

  /// Enforce maximum cache size by removing oldest entries
  Future<void> _enforceMaxSize() async {
    if (_cacheBox == null || _cacheBox!.length <= config.maxSize) return;

    // Get all entries with their cached time
    final entries = <MapEntry<String, DateTime>>[];

    for (final key in _cacheBox!.keys) {
      try {
        final json = _cacheBox!.get(key);
        if (json != null) {
          final item = CachedItem.fromJson(Map<String, dynamic>.from(json));
          entries.add(MapEntry(key.toString(), item.cachedAt));
        }
      } catch (e) {
        // Invalid format, will be removed
        entries.add(MapEntry(key.toString(), DateTime(1970)));
      }
    }

    // Sort by cached time (oldest first)
    entries.sort((a, b) => a.value.compareTo(b.value));

    // Remove oldest entries until we're under the limit
    final toRemove = entries.length - config.maxSize;
    for (var i = 0; i < toRemove; i++) {
      await _cacheBox!.delete(entries[i].key);
    }
  }

  /// Cleanup expired entries (can be called periodically)
  Future<void> cleanup() async {
    await _cleanupExpired();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    final total = size;
    var expired = 0;
    var valid = 0;

    for (final key in _cacheBox?.keys ?? []) {
      try {
        final json = _cacheBox!.get(key);
        if (json != null) {
          final item = CachedItem.fromJson(Map<String, dynamic>.from(json));
          if (item.isExpired) {
            expired++;
          } else {
            valid++;
          }
        }
      } catch (e) {
        expired++;
      }
    }

    return {
      'total': total,
      'valid': valid,
      'expired': expired,
      'maxSize': config.maxSize,
    };
  }

  /// Dispose the cache manager
  Future<void> dispose() async {
    await _cacheBox?.close();
  }
}
