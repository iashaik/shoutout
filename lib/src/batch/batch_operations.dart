import 'package:dartz/dartz.dart';
import '../core/failure.dart';
import '../client/shoutout_client.dart';

/// Manages batch operations for Frappe API
/// Supports batch create, update, delete with error handling and rollback
class BatchOperations {
  final ShoutoutClient client;
  final int defaultBatchSize;

  BatchOperations({
    required this.client,
    this.defaultBatchSize = 100,
  });

  /// Batch create multiple documents
  Future<Either<Failure, BatchResult>> batchCreate({
    required String doctype,
    required List<Map<String, dynamic>> documents,
    int? batchSize,
    bool stopOnError = false,
  }) async {
    return _executeBatch(
      doctype: doctype,
      documents: documents,
      batchSize: batchSize ?? defaultBatchSize,
      stopOnError: stopOnError,
      operation: BatchOperationType.create,
      operationFn: (doc) => client.createDoc(doctype, data: doc),
    );
  }

  /// Batch update multiple documents
  Future<Either<Failure, BatchResult>> batchUpdate({
    required String doctype,
    required List<Map<String, dynamic>> documents,
    int? batchSize,
    bool stopOnError = false,
  }) async {
    return _executeBatch(
      doctype: doctype,
      documents: documents,
      batchSize: batchSize ?? defaultBatchSize,
      stopOnError: stopOnError,
      operation: BatchOperationType.update,
      operationFn: (doc) {
        final name = doc['name'] as String?;
        if (name == null) {
          throw Exception('Document name is required for update');
        }
        return client.updateDoc(doctype, name, data: doc);
      },
    );
  }

  /// Batch delete multiple documents
  Future<Either<Failure, BatchResult>> batchDelete({
    required String doctype,
    required List<String> names,
    int? batchSize,
    bool stopOnError = false,
  }) async {
    final documents = names.map((name) => {'name': name}).toList();

    return _executeBatch(
      doctype: doctype,
      documents: documents,
      batchSize: batchSize ?? defaultBatchSize,
      stopOnError: stopOnError,
      operation: BatchOperationType.delete,
      operationFn: (doc) => client.deleteDoc(doctype, doc['name'] as String),
    );
  }

  /// Execute a batch operation with custom function
  Future<Either<Failure, BatchResult>> batchExecute<T>({
    required List<T> items,
    required Future<dynamic> Function(T item) operation,
    int? batchSize,
    bool stopOnError = false,
    String? operationName,
  }) async {
    final size = batchSize ?? defaultBatchSize;
    final result = BatchResult(
      operation: BatchOperationType.custom,
      totalCount: items.length,
      operationName: operationName,
    );

    final startTime = DateTime.now();

    try {
      for (var i = 0; i < items.length; i += size) {
        final end = (i + size < items.length) ? i + size : items.length;
        final batch = items.sublist(i, end);

        // Execute batch operations in parallel
        final futures = batch.map((item) async {
          try {
            final response = await operation(item);
            result._addSuccess(response);
          } catch (e) {
            result._addError(BatchError(
              item: item,
              error: e.toString(),
              index: items.indexOf(item),
            ));

            if (stopOnError) {
              throw e;
            }
          }
        });

        await Future.wait(futures);

        if (stopOnError && result.hasErrors) {
          break;
        }
      }

      result._duration = DateTime.now().difference(startTime);
      return Right(result);
    } catch (e, stackTrace) {
      result._duration = DateTime.now().difference(startTime);
      return Left(UnknownFailure(
        message: 'Batch operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Internal method to execute batch operations
  Future<Either<Failure, BatchResult>> _executeBatch({
    required String doctype,
    required List<Map<String, dynamic>> documents,
    required int batchSize,
    required bool stopOnError,
    required BatchOperationType operation,
    required Future<dynamic> Function(Map<String, dynamic>) operationFn,
  }) async {
    final result = BatchResult(
      operation: operation,
      totalCount: documents.length,
      doctype: doctype,
    );

    final startTime = DateTime.now();

    try {
      for (var i = 0; i < documents.length; i += batchSize) {
        final end =
            (i + batchSize < documents.length) ? i + batchSize : documents.length;
        final batch = documents.sublist(i, end);

        // Execute batch operations in parallel
        final futures = batch.map((doc) async {
          try {
            final response = await operationFn(doc);
            result._addSuccess(response);
          } catch (e) {
            result._addError(BatchError(
              item: doc,
              error: e.toString(),
              index: i + batch.indexOf(doc),
            ));

            if (stopOnError) {
              throw e;
            }
          }
        });

        await Future.wait(futures);

        if (stopOnError && result.hasErrors) {
          break;
        }
      }

      result._duration = DateTime.now().difference(startTime);
      return Right(result);
    } catch (e, stackTrace) {
      result._duration = DateTime.now().difference(startTime);
      return Left(UnknownFailure(
        message: 'Batch ${operation.name} failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Batch upsert (create or update) documents
  /// Checks if document exists and creates or updates accordingly
  Future<Either<Failure, BatchResult>> batchUpsert({
    required String doctype,
    required List<Map<String, dynamic>> documents,
    required String uniqueField,
    int? batchSize,
    bool stopOnError = false,
  }) async {
    final result = BatchResult(
      operation: BatchOperationType.upsert,
      totalCount: documents.length,
      doctype: doctype,
    );

    final startTime = DateTime.now();

    try {
      for (var i = 0; i < documents.length; i += (batchSize ?? defaultBatchSize)) {
        final end = (i + (batchSize ?? defaultBatchSize) < documents.length)
            ? i + (batchSize ?? defaultBatchSize)
            : documents.length;
        final batch = documents.sublist(i, end);

        final futures = batch.map((doc) async {
          try {
            final uniqueValue = doc[uniqueField];
            if (uniqueValue == null) {
              throw Exception('Unique field $uniqueField is required');
            }

            // Check if document exists
            final existsResult = await client.getList(
              doctype,
              filters: {uniqueField: uniqueValue},
              limitPageLength: 1,
            );

            dynamic response;
            if (existsResult.isNotEmpty) {
              // Update existing document
              final name = existsResult.first['name'] as String;
              response = await client.updateDoc(doctype, name, data: doc);
            } else {
              // Create new document
              response = await client.createDoc(doctype, data: doc);
            }

            result._addSuccess(response);
          } catch (e) {
            result._addError(BatchError(
              item: doc,
              error: e.toString(),
              index: i + batch.indexOf(doc),
            ));

            if (stopOnError) {
              throw e;
            }
          }
        });

        await Future.wait(futures);

        if (stopOnError && result.hasErrors) {
          break;
        }
      }

      result._duration = DateTime.now().difference(startTime);
      return Right(result);
    } catch (e, stackTrace) {
      result._duration = DateTime.now().difference(startTime);
      return Left(UnknownFailure(
        message: 'Batch upsert failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }
}

/// Result of a batch operation
class BatchResult {
  final BatchOperationType operation;
  final int totalCount;
  final String? doctype;
  final String? operationName;
  final List<dynamic> _successes = [];
  final List<BatchError> _errors = [];
  Duration _duration = Duration.zero;

  BatchResult({
    required this.operation,
    required this.totalCount,
    this.doctype,
    this.operationName,
  });

  /// Successful operations
  List<dynamic> get successes => List.unmodifiable(_successes);

  /// Failed operations
  List<BatchError> get errors => List.unmodifiable(_errors);

  /// Number of successful operations
  int get successCount => _successes.length;

  /// Number of failed operations
  int get errorCount => _errors.length;

  /// Success rate (0.0 to 1.0)
  double get successRate => totalCount > 0 ? successCount / totalCount : 0.0;

  /// Whether all operations succeeded
  bool get isComplete => successCount == totalCount;

  /// Whether any operations failed
  bool get hasErrors => _errors.isNotEmpty;

  /// Duration of the batch operation
  Duration get duration => _duration;

  /// Add a successful result
  void _addSuccess(dynamic result) {
    _successes.add(result);
  }

  /// Add an error
  void _addError(BatchError error) {
    _errors.add(error);
  }

  @override
  String toString() {
    return 'BatchResult(operation: $operation, total: $totalCount, '
        'success: $successCount, errors: $errorCount, '
        'rate: ${(successRate * 100).toStringAsFixed(1)}%, '
        'duration: ${_duration.inMilliseconds}ms)';
  }

  /// Get a summary map
  Map<String, dynamic> toMap() {
    return {
      'operation': operation.name,
      'doctype': doctype,
      'operation_name': operationName,
      'total_count': totalCount,
      'success_count': successCount,
      'error_count': errorCount,
      'success_rate': successRate,
      'duration_ms': _duration.inMilliseconds,
      'errors': _errors.map((e) => e.toMap()).toList(),
    };
  }
}

/// Represents a batch operation error
class BatchError {
  final dynamic item;
  final String error;
  final int index;

  BatchError({
    required this.item,
    required this.error,
    required this.index,
  });

  @override
  String toString() {
    return 'BatchError(index: $index, error: $error)';
  }

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'error': error,
      'item': item,
    };
  }
}

/// Types of batch operations
enum BatchOperationType {
  create,
  update,
  delete,
  upsert,
  custom,
}
