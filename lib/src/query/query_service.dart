import 'package:dartz/dartz.dart';

import '../client/shoutout_client.dart';
import '../core/failure.dart';
import '../exceptions/shoutout_exception.dart';

/// Service for advanced Frappe query operations
///
/// Provides methods for:
/// - Counting documents
/// - Getting single field values
/// - Full-text search
/// - Existence checks
///
/// Example:
/// ```dart
/// final queryService = QueryService(client);
///
/// // Count unpaid invoices
/// final count = await queryService.getCount(
///   'Sales Invoice',
///   filters: {'status': 'Unpaid'},
/// );
///
/// // Get customer name
/// final name = await queryService.getValue(
///   'Customer',
///   'CUST-001',
///   'customer_name',
/// );
/// ```
class QueryService {
  final ShoutoutClient _client;

  QueryService(this._client);

  /// Count documents matching filters
  ///
  /// Uses `frappe.client.get_count` for efficient counting without
  /// fetching actual documents.
  ///
  /// Example:
  /// ```dart
  /// // Count all active customers
  /// final result = await queryService.getCount(
  ///   'Customer',
  ///   filters: {'disabled': 0},
  /// );
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (count) => print('Found $count customers'),
  /// );
  ///
  /// // Count submitted orders for a customer
  /// final orderCount = await queryService.getCount(
  ///   'Sales Order',
  ///   filters: {
  ///     'customer': 'CUST-001',
  ///     'docstatus': 1,
  ///   },
  /// );
  /// ```
  Future<Either<Failure, int>> getCount(
    String doctype, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final result = await _client.callMethod<dynamic>(
        'frappe.client.get_count',
        params: {
          'doctype': doctype,
          if (filters != null) 'filters': filters,
        },
      );

      // Result can be int directly or wrapped in message
      if (result is int) {
        return Right(result);
      }
      if (result is Map && result.containsKey('message')) {
        return Right(result['message'] as int? ?? 0);
      }

      return Right(result as int? ?? 0);
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
        message: 'Failed to get count: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get a single field value from a document
  ///
  /// Uses `frappe.client.get_value` for efficient single-field fetching.
  ///
  /// Example:
  /// ```dart
  /// // Get customer name
  /// final result = await queryService.getValue(
  ///   'Customer',
  ///   'CUST-001',
  ///   'customer_name',
  /// );
  ///
  /// // Get item price
  /// final price = await queryService.getValue(
  ///   'Item',
  ///   'ITEM-001',
  ///   'standard_rate',
  /// );
  /// ```
  Future<Either<Failure, T?>> getValue<T>(
    String doctype,
    String name,
    String fieldname,
  ) async {
    try {
      final result = await _client.callMethod<Map<String, dynamic>>(
        'frappe.client.get_value',
        params: {
          'doctype': doctype,
          'filters': {'name': name},
          'fieldname': fieldname,
        },
      );

      final value = result[fieldname];
      return Right(value as T?);
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
        message: 'Failed to get value: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get multiple field values from a document
  ///
  /// Example:
  /// ```dart
  /// final result = await queryService.getValues(
  ///   'Customer',
  ///   'CUST-001',
  ///   ['customer_name', 'email_id', 'mobile_no'],
  /// );
  /// result.fold(
  ///   (failure) => print('Error'),
  ///   (values) {
  ///     print('Name: ${values['customer_name']}');
  ///     print('Email: ${values['email_id']}');
  ///   },
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> getValues(
    String doctype,
    String name,
    List<String> fieldnames,
  ) async {
    try {
      final result = await _client.callMethod<Map<String, dynamic>>(
        'frappe.client.get_value',
        params: {
          'doctype': doctype,
          'filters': {'name': name},
          'fieldname': fieldnames,
        },
      );

      return Right(result);
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
        message: 'Failed to get values: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Search documents using full-text search
  ///
  /// Uses Frappe's search functionality to find documents
  /// matching the search term.
  ///
  /// Example:
  /// ```dart
  /// // Search for items containing 'laptop'
  /// final result = await queryService.search(
  ///   'Item',
  ///   'laptop',
  ///   fields: ['name', 'item_name', 'description'],
  ///   limit: 20,
  /// );
  ///
  /// // Search customers
  /// final customers = await queryService.search(
  ///   'Customer',
  ///   'acme',
  ///   searchFields: ['customer_name', 'email_id'],
  /// );
  /// ```
  Future<Either<Failure, List<Map<String, dynamic>>>> search(
    String doctype,
    String term, {
    List<String>? fields,
    List<String>? searchFields,
    Map<String, dynamic>? filters,
    int limit = 20,
  }) async {
    try {
      // Build search filters using LIKE on searchable fields
      final searchFilters = <String, dynamic>{
        ...?filters,
      };

      // If specific search fields provided, use OR logic
      // Otherwise, search in 'name' field
      final effectiveSearchFields = searchFields ?? ['name'];

      // For simple search, use LIKE on first search field
      // For complex OR search across multiple fields, we'd need or_filters
      if (effectiveSearchFields.length == 1) {
        searchFilters[effectiveSearchFields.first] = ['like', '%$term%'];
      }

      final result = await _client.getList<Map<String, dynamic>>(
        doctype,
        fields: fields,
        filters: searchFilters,
        limitPageLength: limit,
      );

      // If we have multiple search fields, filter client-side
      // (Frappe REST API has limited OR support in GET requests)
      if (effectiveSearchFields.length > 1) {
        final termLower = term.toLowerCase();
        return Right(result.where((doc) {
          for (final field in effectiveSearchFields) {
            final value = doc[field]?.toString().toLowerCase() ?? '';
            if (value.contains(termLower)) {
              return true;
            }
          }
          return false;
        }).toList());
      }

      return Right(result);
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
        message: 'Failed to search: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Check if a document exists
  ///
  /// Efficiently checks existence without fetching the full document.
  ///
  /// Example:
  /// ```dart
  /// final exists = await queryService.exists('Customer', 'CUST-001');
  /// exists.fold(
  ///   (failure) => print('Error'),
  ///   (found) {
  ///     if (found) {
  ///       print('Customer exists');
  ///     }
  ///   },
  /// );
  /// ```
  Future<Either<Failure, bool>> exists(
    String doctype,
    String name,
  ) async {
    final result = await getCount(doctype, filters: {'name': name});
    return result.map((count) => count > 0);
  }

  /// Check if any document matches the given filters
  ///
  /// Example:
  /// ```dart
  /// // Check if customer has any orders
  /// final hasOrders = await queryService.existsWhere(
  ///   'Sales Order',
  ///   filters: {'customer': 'CUST-001'},
  /// );
  /// ```
  Future<Either<Failure, bool>> existsWhere(
    String doctype, {
    required Map<String, dynamic> filters,
  }) async {
    final result = await getCount(doctype, filters: filters);
    return result.map((count) => count > 0);
  }

  /// Get the sum of a numeric field
  ///
  /// Example:
  /// ```dart
  /// // Get total outstanding amount
  /// final total = await queryService.sum(
  ///   'Sales Invoice',
  ///   'outstanding_amount',
  ///   filters: {'docstatus': 1},
  /// );
  /// ```
  Future<Either<Failure, double>> sum(
    String doctype,
    String field, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final result = await _client.callMethod<dynamic>(
        'frappe.client.get_list',
        params: {
          'doctype': doctype,
          'fields': ['sum($field) as total'],
          if (filters != null) 'filters': filters,
          'limit_page_length': 1,
        },
      );

      if (result is List && result.isNotEmpty) {
        final total = result[0]['total'];
        return Right((total as num?)?.toDouble() ?? 0.0);
      }

      return const Right(0.0);
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
        message: 'Failed to get sum: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get the minimum value of a field
  ///
  /// Example:
  /// ```dart
  /// final minPrice = await queryService.min(
  ///   'Item',
  ///   'standard_rate',
  ///   filters: {'disabled': 0},
  /// );
  /// ```
  Future<Either<Failure, T?>> min<T>(
    String doctype,
    String field, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final result = await _client.callMethod<dynamic>(
        'frappe.client.get_list',
        params: {
          'doctype': doctype,
          'fields': ['min($field) as value'],
          if (filters != null) 'filters': filters,
          'limit_page_length': 1,
        },
      );

      if (result is List && result.isNotEmpty) {
        return Right(result[0]['value'] as T?);
      }

      return const Right(null);
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
        message: 'Failed to get min: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get the maximum value of a field
  ///
  /// Example:
  /// ```dart
  /// final maxPrice = await queryService.max(
  ///   'Item',
  ///   'standard_rate',
  ///   filters: {'disabled': 0},
  /// );
  /// ```
  Future<Either<Failure, T?>> max<T>(
    String doctype,
    String field, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final result = await _client.callMethod<dynamic>(
        'frappe.client.get_list',
        params: {
          'doctype': doctype,
          'fields': ['max($field) as value'],
          if (filters != null) 'filters': filters,
          'limit_page_length': 1,
        },
      );

      if (result is List && result.isNotEmpty) {
        return Right(result[0]['value'] as T?);
      }

      return const Right(null);
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
        message: 'Failed to get max: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get the average of a numeric field
  ///
  /// Example:
  /// ```dart
  /// final avgPrice = await queryService.avg(
  ///   'Item',
  ///   'standard_rate',
  ///   filters: {'item_group': 'Electronics'},
  /// );
  /// ```
  Future<Either<Failure, double>> avg(
    String doctype,
    String field, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final result = await _client.callMethod<dynamic>(
        'frappe.client.get_list',
        params: {
          'doctype': doctype,
          'fields': ['avg($field) as value'],
          if (filters != null) 'filters': filters,
          'limit_page_length': 1,
        },
      );

      if (result is List && result.isNotEmpty) {
        final value = result[0]['value'];
        return Right((value as num?)?.toDouble() ?? 0.0);
      }

      return const Right(0.0);
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
        message: 'Failed to get average: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get distinct values of a field
  ///
  /// Example:
  /// ```dart
  /// // Get all unique item groups
  /// final groups = await queryService.distinct(
  ///   'Item',
  ///   'item_group',
  ///   filters: {'disabled': 0},
  /// );
  /// ```
  Future<Either<Failure, List<T>>> distinct<T>(
    String doctype,
    String field, {
    Map<String, dynamic>? filters,
    int? limit,
  }) async {
    try {
      final result = await _client.getList<Map<String, dynamic>>(
        doctype,
        fields: [field],
        filters: filters,
        limitPageLength: limit ?? 1000,
        orderBy: field,
      );

      // Extract unique values
      final seen = <T>{};
      final values = <T>[];
      for (final doc in result) {
        final value = doc[field] as T?;
        if (value != null && seen.add(value)) {
          values.add(value);
        }
      }

      return Right(values);
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
        message: 'Failed to get distinct values: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }
}
