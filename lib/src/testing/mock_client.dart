import 'dart:async';
import 'package:dartz/dartz.dart';
import '../core/failure.dart';

/// Mock Frappe client for testing
/// Simulates API responses without making real HTTP calls
class MockShoutoutClient {
  final Map<String, dynamic> _storage = {};
  final Map<String, List<Map<String, dynamic>>> _doctypeStorage = {};
  final bool simulateNetworkDelay;
  final Duration networkDelay;
  final bool randomFailures;
  final double failureRate;
  int _callCount = 0;

  MockShoutoutClient({
    this.simulateNetworkDelay = true,
    this.networkDelay = const Duration(milliseconds: 100),
    this.randomFailures = false,
    this.failureRate = 0.1,
  });

  /// Get call count (for testing)
  int get callCount => _callCount;

  /// Reset call count
  void resetCallCount() => _callCount = 0;

  /// Simulate network delay
  Future<void> _delay() async {
    _callCount++;
    if (simulateNetworkDelay) {
      await Future.delayed(networkDelay);
    }
  }

  /// Simulate random failures
  void _checkFailure() {
    if (randomFailures && _shouldFail()) {
      throw Exception('Simulated network failure');
    }
  }

  bool _shouldFail() {
    return DateTime.now().millisecondsSinceEpoch % 100 < (failureRate * 100);
  }

  /// Get a document by name
  Future<Either<Failure, Map<String, dynamic>>> getDocument({
    required String doctype,
    required String name,
  }) async {
    await _delay();
    _checkFailure();

    final key = '$doctype:$name';
    if (_storage.containsKey(key)) {
      return Right(_storage[key]!);
    }

    return Left(NotFoundFailure(
      message: 'Document $name of type $doctype not found',
    ));
  }

  /// Get multiple documents
  Future<Either<Failure, List<Map<String, dynamic>>>> getDocuments({
    required String doctype,
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    await _delay();
    _checkFailure();

    var documents = _doctypeStorage[doctype] ?? [];

    // Apply filters
    if (filters != null) {
      documents = documents.where((doc) {
        return filters.entries.every((entry) {
          return doc[entry.key] == entry.value;
        });
      }).toList();
    }

    // Apply ordering
    if (orderBy != null) {
      final descending = orderBy.contains('desc');
      final field = orderBy.replaceAll(' desc', '').replaceAll(' asc', '').trim();
      documents.sort((a, b) {
        final aValue = a[field];
        final bValue = b[field];
        if (aValue == null || bValue == null) return 0;
        final comparison = aValue.toString().compareTo(bValue.toString());
        return descending ? -comparison : comparison;
      });
    }

    // Apply offset
    if (offset != null && offset > 0) {
      documents = documents.skip(offset).toList();
    }

    // Apply limit
    if (limit != null && limit > 0) {
      documents = documents.take(limit).toList();
    }

    return Right(documents);
  }

  /// Create a document
  Future<Either<Failure, Map<String, dynamic>>> createDocument({
    required String doctype,
    required Map<String, dynamic> data,
  }) async {
    await _delay();
    _checkFailure();

    final name = data['name'] ?? _generateName(doctype);
    final document = {
      ...data,
      'name': name,
      'doctype': doctype,
      'creation': DateTime.now().toIso8601String(),
      'modified': DateTime.now().toIso8601String(),
      'owner': 'Administrator',
      'modified_by': 'Administrator',
    };

    // Store in both storage types
    final key = '$doctype:$name';
    _storage[key] = document;

    if (!_doctypeStorage.containsKey(doctype)) {
      _doctypeStorage[doctype] = [];
    }
    _doctypeStorage[doctype]!.add(document);

    return Right(document);
  }

  /// Update a document
  Future<Either<Failure, Map<String, dynamic>>> updateDocument({
    required String doctype,
    required String name,
    required Map<String, dynamic> data,
  }) async {
    await _delay();
    _checkFailure();

    final key = '$doctype:$name';
    if (!_storage.containsKey(key)) {
      return Left(NotFoundFailure(
        message: 'Document $name of type $doctype not found',
      ));
    }

    final document = <String, dynamic>{
      ..._storage[key]!,
      ...data,
      'modified': DateTime.now().toIso8601String(),
      'modified_by': 'Administrator',
    };

    _storage[key] = document;

    // Update in doctype storage
    final doctypeList = _doctypeStorage[doctype];
    if (doctypeList != null) {
      final index = doctypeList.indexWhere((doc) => doc['name'] == name);
      if (index != -1) {
        doctypeList[index] = document;
      }
    }

    return Right(document);
  }

  /// Delete a document
  Future<Either<Failure, bool>> deleteDocument({
    required String doctype,
    required String name,
  }) async {
    await _delay();
    _checkFailure();

    final key = '$doctype:$name';
    if (!_storage.containsKey(key)) {
      return Left(NotFoundFailure(
        message: 'Document $name of type $doctype not found',
      ));
    }

    _storage.remove(key);

    // Remove from doctype storage
    final doctypeList = _doctypeStorage[doctype];
    if (doctypeList != null) {
      doctypeList.removeWhere((doc) => doc['name'] == name);
    }

    return const Right(true);
  }

  /// Call a Frappe method
  Future<Either<Failure, T>> callMethod<T>({
    required String method,
    Map<String, dynamic>? params,
  }) async {
    await _delay();
    _checkFailure();

    // Return mock data based on method
    return Right(_getMockMethodResponse<T>(method, params));
  }

  /// Seed the mock database with initial data
  void seed(String doctype, List<Map<String, dynamic>> documents) {
    _doctypeStorage[doctype] = [];

    for (final doc in documents) {
      final name = doc['name'] ?? _generateName(doctype);
      final document = {
        ...doc,
        'name': name,
        'doctype': doctype,
        'creation': DateTime.now().toIso8601String(),
        'modified': DateTime.now().toIso8601String(),
      };

      final key = '$doctype:$name';
      _storage[key] = document;
      _doctypeStorage[doctype]!.add(document);
    }
  }

  /// Clear all data
  void clear() {
    _storage.clear();
    _doctypeStorage.clear();
    _callCount = 0;
  }

  /// Clear data for specific doctype
  void clearDoctype(String doctype) {
    _doctypeStorage.remove(doctype);
    _storage.removeWhere((key, _) => key.startsWith('$doctype:'));
  }

  /// Get all documents for a doctype
  List<Map<String, dynamic>> getAllDocuments(String doctype) {
    return _doctypeStorage[doctype] ?? [];
  }

  /// Check if a document exists
  bool documentExists(String doctype, String name) {
    return _storage.containsKey('$doctype:$name');
  }

  /// Get count of documents for a doctype
  int getDocumentCount(String doctype) {
    return _doctypeStorage[doctype]?.length ?? 0;
  }

  /// Generate a unique document name
  String _generateName(String doctype) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$doctype-$timestamp';
  }

  /// Get mock response for method calls
  T _getMockMethodResponse<T>(String method, Map<String, dynamic>? params) {
    // Return type-appropriate mock data
    if (T == String) {
      return 'Mock response for $method' as T;
    } else if (T == bool) {
      return true as T;
    } else if (T == int) {
      return 0 as T;
    } else if (T == List<dynamic>) {
      return <dynamic>[] as T;
    } else if (T == Map<String, dynamic>) {
      return <String, dynamic>{'message': 'Mock response'} as T;
    }

    return {'message': 'Mock response for $method'} as T;
  }

  /// Add a custom mock response for a specific method
  final Map<String, dynamic> _customResponses = {};

  void setMethodResponse(String method, dynamic response) {
    _customResponses[method] = response;
  }

  T? getMethodResponse<T>(String method) {
    return _customResponses[method] as T?;
  }
}

/// Mock builder for creating configured mock clients
class MockClientBuilder {
  bool _simulateNetworkDelay = true;
  Duration _networkDelay = const Duration(milliseconds: 100);
  bool _randomFailures = false;
  double _failureRate = 0.1;
  final Map<String, List<Map<String, dynamic>>> _seedData = {};

  MockClientBuilder();

  /// Enable/disable network delay simulation
  MockClientBuilder withNetworkDelay(bool enabled, {Duration? delay}) {
    _simulateNetworkDelay = enabled;
    if (delay != null) {
      _networkDelay = delay;
    }
    return this;
  }

  /// Enable random failures
  MockClientBuilder withRandomFailures(bool enabled, {double? rate}) {
    _randomFailures = enabled;
    if (rate != null) {
      _failureRate = rate;
    }
    return this;
  }

  /// Add seed data for a doctype
  MockClientBuilder withSeedData(
    String doctype,
    List<Map<String, dynamic>> documents,
  ) {
    _seedData[doctype] = documents;
    return this;
  }

  /// Build the mock client
  MockShoutoutClient build() {
    final client = MockShoutoutClient(
      simulateNetworkDelay: _simulateNetworkDelay,
      networkDelay: _networkDelay,
      randomFailures: _randomFailures,
      failureRate: _failureRate,
    );

    // Seed data
    for (final entry in _seedData.entries) {
      client.seed(entry.key, entry.value);
    }

    return client;
  }
}
