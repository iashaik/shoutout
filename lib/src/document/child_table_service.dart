import 'package:dartz/dartz.dart';

import '../client/shoutout_client.dart';
import '../core/failure.dart';
import '../exceptions/shoutout_exception.dart';

/// Service for managing Frappe child table operations
///
/// Child tables are embedded tables within parent documents.
/// For example, a Sales Order has an "items" child table containing
/// Sales Order Item rows.
///
/// Example:
/// ```dart
/// final childService = ChildTableService(client);
///
/// // Add an item to a sales order
/// await childService.addChild(
///   'Sales Order',
///   'SO-001',
///   'items',
///   {
///     'item_code': 'ITEM-001',
///     'qty': 5,
///     'rate': 100,
///   },
/// );
/// ```
class ChildTableService {
  final ShoutoutClient _client;

  ChildTableService(this._client);

  /// Add a new row to a child table
  ///
  /// The new row will be appended to the end of the child table.
  /// Frappe will automatically assign a `name` and `idx` to the row.
  ///
  /// Example:
  /// ```dart
  /// final result = await childService.addChild(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   {
  ///     'item_code': 'ITEM-001',
  ///     'qty': 5,
  ///     'rate': 100,
  ///   },
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> addChild(
    String doctype,
    String name,
    String tableName,
    Map<String, dynamic> data,
  ) async {
    try {
      // Fetch the current document
      final doc = await _client.getDoc<Map<String, dynamic>>(doctype, name);

      // Get existing child table or create empty list
      final children = List<Map<String, dynamic>>.from(
        (doc[tableName] as List?) ?? [],
      );

      // Add new row (without name - Frappe will assign it)
      children.add(data);

      // Update the document
      final updated = await _client.updateDoc<Map<String, dynamic>>(
        doctype,
        name,
        data: {tableName: children},
      );

      return Right(updated);
    } on ShoutoutException catch (e, stackTrace) {
      if (e.statusCode == 404) {
        return Left(NotFoundFailure(
          message: '$doctype $name not found',
          originalError: e,
          stackTrace: stackTrace,
        ));
      }

      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to add child row: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Add multiple rows to a child table
  ///
  /// All rows are appended in order to the end of the child table.
  ///
  /// Example:
  /// ```dart
  /// await childService.addChildren(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   [
  ///     {'item_code': 'ITEM-001', 'qty': 5, 'rate': 100},
  ///     {'item_code': 'ITEM-002', 'qty': 3, 'rate': 200},
  ///   ],
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> addChildren(
    String doctype,
    String name,
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      // Fetch the current document
      final doc = await _client.getDoc<Map<String, dynamic>>(doctype, name);

      // Get existing child table or create empty list
      final children = List<Map<String, dynamic>>.from(
        (doc[tableName] as List?) ?? [],
      );

      // Add all new rows
      children.addAll(rows);

      // Update the document
      final updated = await _client.updateDoc<Map<String, dynamic>>(
        doctype,
        name,
        data: {tableName: children},
      );

      return Right(updated);
    } on ShoutoutException catch (e, stackTrace) {
      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to add child rows: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update a specific row in a child table
  ///
  /// The row is identified by its `name` field (row ID).
  ///
  /// Example:
  /// ```dart
  /// await childService.updateChild(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   'row-abc123',
  ///   {'qty': 10},
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> updateChild(
    String doctype,
    String name,
    String tableName,
    String rowName,
    Map<String, dynamic> data,
  ) async {
    try {
      // Fetch the current document
      final doc = await _client.getDoc<Map<String, dynamic>>(doctype, name);

      // Get existing child table
      final children = List<Map<String, dynamic>>.from(
        (doc[tableName] as List?) ?? [],
      );

      // Find and update the row
      var found = false;
      for (var i = 0; i < children.length; i++) {
        if (children[i]['name'] == rowName) {
          children[i] = {...children[i], ...data};
          found = true;
          break;
        }
      }

      if (!found) {
        return Left(NotFoundFailure(
          message: 'Child row $rowName not found in $tableName',
        ));
      }

      // Update the document
      final updated = await _client.updateDoc<Map<String, dynamic>>(
        doctype,
        name,
        data: {tableName: children},
      );

      return Right(updated);
    } on ShoutoutException catch (e, stackTrace) {
      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to update child row: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update a child row by its index (0-based)
  ///
  /// Example:
  /// ```dart
  /// // Update the first item
  /// await childService.updateChildByIndex(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   0,
  ///   {'qty': 10},
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> updateChildByIndex(
    String doctype,
    String name,
    String tableName,
    int index,
    Map<String, dynamic> data,
  ) async {
    try {
      // Fetch the current document
      final doc = await _client.getDoc<Map<String, dynamic>>(doctype, name);

      // Get existing child table
      final children = List<Map<String, dynamic>>.from(
        (doc[tableName] as List?) ?? [],
      );

      if (index < 0 || index >= children.length) {
        return Left(ValidationFailure(
          message: 'Index $index is out of bounds (0-${children.length - 1})',
        ));
      }

      // Update the row
      children[index] = {...children[index], ...data};

      // Update the document
      final updated = await _client.updateDoc<Map<String, dynamic>>(
        doctype,
        name,
        data: {tableName: children},
      );

      return Right(updated);
    } on ShoutoutException catch (e, stackTrace) {
      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to update child row: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Remove a row from a child table by its name
  ///
  /// Example:
  /// ```dart
  /// await childService.removeChild(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   'row-abc123',
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> removeChild(
    String doctype,
    String name,
    String tableName,
    String rowName,
  ) async {
    try {
      // Fetch the current document
      final doc = await _client.getDoc<Map<String, dynamic>>(doctype, name);

      // Get existing child table
      final children = List<Map<String, dynamic>>.from(
        (doc[tableName] as List?) ?? [],
      );

      // Remove the row
      final initialLength = children.length;
      children.removeWhere((row) => row['name'] == rowName);

      if (children.length == initialLength) {
        return Left(NotFoundFailure(
          message: 'Child row $rowName not found in $tableName',
        ));
      }

      // Update the document
      final updated = await _client.updateDoc<Map<String, dynamic>>(
        doctype,
        name,
        data: {tableName: children},
      );

      return Right(updated);
    } on ShoutoutException catch (e, stackTrace) {
      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to remove child row: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Remove a row from a child table by its index
  ///
  /// Example:
  /// ```dart
  /// // Remove the first item
  /// await childService.removeChildByIndex(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   0,
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> removeChildByIndex(
    String doctype,
    String name,
    String tableName,
    int index,
  ) async {
    try {
      // Fetch the current document
      final doc = await _client.getDoc<Map<String, dynamic>>(doctype, name);

      // Get existing child table
      final children = List<Map<String, dynamic>>.from(
        (doc[tableName] as List?) ?? [],
      );

      if (index < 0 || index >= children.length) {
        return Left(ValidationFailure(
          message: 'Index $index is out of bounds (0-${children.length - 1})',
        ));
      }

      // Remove the row
      children.removeAt(index);

      // Update the document
      final updated = await _client.updateDoc<Map<String, dynamic>>(
        doctype,
        name,
        data: {tableName: children},
      );

      return Right(updated);
    } on ShoutoutException catch (e, stackTrace) {
      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to remove child row: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get all rows from a child table
  ///
  /// Example:
  /// ```dart
  /// final result = await childService.getChildren(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  /// );
  /// result.fold(
  ///   (failure) => print('Error'),
  ///   (items) {
  ///     for (final item in items) {
  ///       print('${item['item_code']}: ${item['qty']}');
  ///     }
  ///   },
  /// );
  /// ```
  Future<Either<Failure, List<Map<String, dynamic>>>> getChildren(
    String doctype,
    String name,
    String tableName,
  ) async {
    try {
      // Fetch the document
      final doc = await _client.getDoc<Map<String, dynamic>>(doctype, name);

      // Get child table
      final children = List<Map<String, dynamic>>.from(
        (doc[tableName] as List?) ?? [],
      );

      return Right(children);
    } on ShoutoutException catch (e, stackTrace) {
      if (e.statusCode == 404) {
        return Left(NotFoundFailure(
          message: '$doctype $name not found',
          originalError: e,
          stackTrace: stackTrace,
        ));
      }

      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to get child rows: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get a specific row from a child table by name
  ///
  /// Example:
  /// ```dart
  /// final result = await childService.getChild(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   'row-abc123',
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> getChild(
    String doctype,
    String name,
    String tableName,
    String rowName,
  ) async {
    final result = await getChildren(doctype, name, tableName);

    return result.flatMap((children) {
      final row = children.firstWhere(
        (r) => r['name'] == rowName,
        orElse: () => {},
      );

      if (row.isEmpty) {
        return Left(NotFoundFailure(
          message: 'Child row $rowName not found in $tableName',
        ));
      }

      return Right(row);
    });
  }

  /// Get a row from a child table by index
  ///
  /// Example:
  /// ```dart
  /// // Get the first item
  /// final result = await childService.getChildByIndex(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   0,
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> getChildByIndex(
    String doctype,
    String name,
    String tableName,
    int index,
  ) async {
    final result = await getChildren(doctype, name, tableName);

    return result.flatMap((children) {
      if (index < 0 || index >= children.length) {
        return Left(ValidationFailure(
          message: 'Index $index is out of bounds (0-${children.length - 1})',
        ));
      }

      return Right(children[index]);
    });
  }

  /// Replace all rows in a child table
  ///
  /// Example:
  /// ```dart
  /// await childService.setChildren(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   [
  ///     {'item_code': 'ITEM-001', 'qty': 5, 'rate': 100},
  ///     {'item_code': 'ITEM-002', 'qty': 3, 'rate': 200},
  ///   ],
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> setChildren(
    String doctype,
    String name,
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      // Update the document with new child table
      final updated = await _client.updateDoc<Map<String, dynamic>>(
        doctype,
        name,
        data: {tableName: rows},
      );

      return Right(updated);
    } on ShoutoutException catch (e, stackTrace) {
      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to set child rows: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Clear all rows from a child table
  ///
  /// Example:
  /// ```dart
  /// await childService.clearChildren(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> clearChildren(
    String doctype,
    String name,
    String tableName,
  ) async {
    return setChildren(doctype, name, tableName, []);
  }

  /// Reorder rows in a child table
  ///
  /// The [order] list should contain row names in the desired order.
  ///
  /// Example:
  /// ```dart
  /// await childService.reorderChildren(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   ['row-3', 'row-1', 'row-2'],
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> reorderChildren(
    String doctype,
    String name,
    String tableName,
    List<String> order,
  ) async {
    try {
      // Fetch the current document
      final doc = await _client.getDoc<Map<String, dynamic>>(doctype, name);

      // Get existing child table
      final children = List<Map<String, dynamic>>.from(
        (doc[tableName] as List?) ?? [],
      );

      // Create a map for quick lookup
      final childMap = {
        for (final child in children) child['name'] as String: child,
      };

      // Reorder based on the provided order
      final reordered = <Map<String, dynamic>>[];
      for (final rowName in order) {
        final child = childMap[rowName];
        if (child != null) {
          reordered.add(child);
          childMap.remove(rowName);
        }
      }

      // Add any remaining rows not in the order list
      reordered.addAll(childMap.values);

      // Update idx values
      for (var i = 0; i < reordered.length; i++) {
        reordered[i]['idx'] = i + 1;
      }

      // Update the document
      final updated = await _client.updateDoc<Map<String, dynamic>>(
        doctype,
        name,
        data: {tableName: reordered},
      );

      return Right(updated);
    } on ShoutoutException catch (e, stackTrace) {
      return Left(FrappeFailure(
        message: e.message,
        serverMessage: e is FrappeException ? e.serverMessage : null,
        statusCode: e.statusCode,
        originalError: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to reorder child rows: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Move a row up in the child table
  ///
  /// Example:
  /// ```dart
  /// await childService.moveChildUp(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   'row-abc123',
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> moveChildUp(
    String doctype,
    String name,
    String tableName,
    String rowName,
  ) async {
    final result = await getChildren(doctype, name, tableName);

    return result.fold(
      (failure) => Left(failure),
      (children) async {
        final index = children.indexWhere((r) => r['name'] == rowName);

        if (index == -1) {
          return Left(NotFoundFailure(
            message: 'Child row $rowName not found in $tableName',
          ));
        }

        if (index == 0) {
          // Already at the top
          try {
            return Right(
                await _client.getDoc<Map<String, dynamic>>(doctype, name));
          } catch (e) {
            return Left(UnknownFailure(message: 'Failed to get document: $e'));
          }
        }

        // Swap with previous row
        final order = children.map((r) => r['name'] as String).toList();
        final temp = order[index];
        order[index] = order[index - 1];
        order[index - 1] = temp;

        return reorderChildren(doctype, name, tableName, order);
      },
    );
  }

  /// Move a row down in the child table
  ///
  /// Example:
  /// ```dart
  /// await childService.moveChildDown(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  ///   'row-abc123',
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> moveChildDown(
    String doctype,
    String name,
    String tableName,
    String rowName,
  ) async {
    final result = await getChildren(doctype, name, tableName);

    return result.fold(
      (failure) => Left(failure),
      (children) async {
        final index = children.indexWhere((r) => r['name'] == rowName);

        if (index == -1) {
          return Left(NotFoundFailure(
            message: 'Child row $rowName not found in $tableName',
          ));
        }

        if (index == children.length - 1) {
          // Already at the bottom
          try {
            return Right(
                await _client.getDoc<Map<String, dynamic>>(doctype, name));
          } catch (e) {
            return Left(UnknownFailure(message: 'Failed to get document: $e'));
          }
        }

        // Swap with next row
        final order = children.map((r) => r['name'] as String).toList();
        final temp = order[index];
        order[index] = order[index + 1];
        order[index + 1] = temp;

        return reorderChildren(doctype, name, tableName, order);
      },
    );
  }

  /// Get the count of rows in a child table
  ///
  /// Example:
  /// ```dart
  /// final result = await childService.getChildCount(
  ///   'Sales Order',
  ///   'SO-001',
  ///   'items',
  /// );
  /// result.fold(
  ///   (failure) => print('Error'),
  ///   (count) => print('Order has $count items'),
  /// );
  /// ```
  Future<Either<Failure, int>> getChildCount(
    String doctype,
    String name,
    String tableName,
  ) async {
    final result = await getChildren(doctype, name, tableName);
    return result.map((children) => children.length);
  }
}
