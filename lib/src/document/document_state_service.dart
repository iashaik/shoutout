import 'package:dartz/dartz.dart';

import '../client/shoutout_client.dart';
import '../core/failure.dart';
import '../exceptions/shoutout_exception.dart';
import 'doc_status.dart';

/// Service for managing Frappe document state transitions
///
/// Handles document lifecycle operations:
/// - Submit (Draft → Submitted)
/// - Cancel (Submitted → Cancelled)
/// - Amend (Cancelled → New Draft copy)
///
/// Example:
/// ```dart
/// final stateService = DocumentStateService(client);
///
/// // Submit a sales order
/// final result = await stateService.submitDoc('Sales Order', 'SO-001');
/// result.fold(
///   (failure) => print('Failed: ${failure.message}'),
///   (doc) => print('Submitted: ${doc['name']}'),
/// );
/// ```
class DocumentStateService {
  final ShoutoutClient _client;

  DocumentStateService(this._client);

  /// Submit a document (Draft → Submitted)
  ///
  /// Changes docstatus from 0 to 1, triggering:
  /// - Accounting entries (for financial documents)
  /// - Stock movements (for inventory documents)
  /// - Workflow state changes
  ///
  /// Returns the updated document on success.
  ///
  /// Example:
  /// ```dart
  /// final result = await stateService.submitDoc('Sales Invoice', 'INV-001');
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> submitDoc(
    String doctype,
    String name,
  ) async {
    try {
      final result = await _client.callMethod<Map<String, dynamic>>(
        'frappe.client.submit',
        params: {
          'doc': {
            'doctype': doctype,
            'name': name,
          },
        },
      );

      return Right(result);
    } on ShoutoutException catch (e, stackTrace) {
      // Check for specific Frappe errors
      final message = e.message.toLowerCase();
      if (message.contains('already submitted')) {
        return Left(DocumentStateFailure.alreadySubmitted(doctype, name));
      }
      if (message.contains('cannot submit')) {
        return Left(DocumentStateFailure.cannotSubmit(doctype, name, -1));
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
        message: 'Failed to submit document: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Cancel a submitted document (Submitted → Cancelled)
  ///
  /// Changes docstatus from 1 to 2, reversing:
  /// - Accounting entries
  /// - Stock movements
  /// - Linked document references
  ///
  /// Returns the cancelled document on success.
  ///
  /// Example:
  /// ```dart
  /// final result = await stateService.cancelDoc('Sales Invoice', 'INV-001');
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> cancelDoc(
    String doctype,
    String name,
  ) async {
    try {
      final result = await _client.callMethod<Map<String, dynamic>>(
        'frappe.client.cancel',
        params: {
          'doctype': doctype,
          'name': name,
        },
      );

      return Right(result);
    } on ShoutoutException catch (e, stackTrace) {
      final message = e.message.toLowerCase();
      if (message.contains('already cancelled')) {
        return Left(DocumentStateFailure.alreadyCancelled(doctype, name));
      }
      if (message.contains('cannot cancel')) {
        return Left(DocumentStateFailure.cannotCancel(doctype, name, -1));
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
        message: 'Failed to cancel document: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Create an amended copy of a cancelled document
  ///
  /// Creates a new draft document based on the cancelled one.
  /// The new document will have:
  /// - docstatus = 0 (Draft)
  /// - name = original-name-1 (or next sequence)
  /// - amended_from = original document name
  ///
  /// Returns the new amended document on success.
  ///
  /// Example:
  /// ```dart
  /// final result = await stateService.amendDoc('Sales Invoice', 'INV-001');
  /// result.fold(
  ///   (failure) => print('Failed'),
  ///   (doc) => print('Created: ${doc['name']}'), // INV-001-1
  /// );
  /// ```
  Future<Either<Failure, Map<String, dynamic>>> amendDoc(
    String doctype,
    String name,
  ) async {
    try {
      final result = await _client.callMethod<Map<String, dynamic>>(
        'frappe.client.amend',
        params: {
          'doctype': doctype,
          'name': name,
        },
      );

      return Right(result);
    } on ShoutoutException catch (e, stackTrace) {
      final message = e.message.toLowerCase();
      if (message.contains('cannot amend') || message.contains('not cancelled')) {
        return Left(DocumentStateFailure.cannotAmend(doctype, name, -1));
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
        message: 'Failed to amend document: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get the current docstatus of a document
  ///
  /// Returns the [DocStatus] enum value.
  ///
  /// Example:
  /// ```dart
  /// final result = await stateService.getDocStatus('Sales Order', 'SO-001');
  /// result.fold(
  ///   (failure) => print('Failed'),
  ///   (status) {
  ///     if (status.canSubmit) {
  ///       // Show submit button
  ///     }
  ///   },
  /// );
  /// ```
  Future<Either<Failure, DocStatus>> getDocStatus(
    String doctype,
    String name,
  ) async {
    try {
      final result = await _client.callMethod<Map<String, dynamic>>(
        'frappe.client.get_value',
        params: {
          'doctype': doctype,
          'filters': {'name': name},
          'fieldname': 'docstatus',
        },
      );

      final docstatus = result['docstatus'];
      return Right(docstatus.toDocStatus());
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
        message: 'Failed to get document status: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Check if a document can be submitted
  ///
  /// Returns true if document is in draft state (docstatus = 0).
  Future<Either<Failure, bool>> canSubmit(String doctype, String name) async {
    final result = await getDocStatus(doctype, name);
    return result.map((status) => status.canSubmit);
  }

  /// Check if a document can be cancelled
  ///
  /// Returns true if document is in submitted state (docstatus = 1).
  Future<Either<Failure, bool>> canCancel(String doctype, String name) async {
    final result = await getDocStatus(doctype, name);
    return result.map((status) => status.canCancel);
  }

  /// Check if a document can be amended
  ///
  /// Returns true if document is in cancelled state (docstatus = 2).
  Future<Either<Failure, bool>> canAmend(String doctype, String name) async {
    final result = await getDocStatus(doctype, name);
    return result.map((status) => status.canAmend);
  }

  /// Get all amendments of a document
  ///
  /// Returns list of documents that were amended from the given document.
  ///
  /// Example:
  /// ```dart
  /// final result = await stateService.getAmendments('Sales Invoice', 'INV-001');
  /// // Returns: [INV-001-1, INV-001-2, ...]
  /// ```
  Future<Either<Failure, List<Map<String, dynamic>>>> getAmendments(
    String doctype,
    String name,
  ) async {
    try {
      final result = await _client.getList<Map<String, dynamic>>(
        doctype,
        fields: ['name', 'docstatus', 'modified', 'owner'],
        filters: {'amended_from': name},
        orderBy: 'creation desc',
      );

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
        message: 'Failed to get amendments: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get the original document that this document was amended from
  ///
  /// Returns null if document was not amended from another.
  Future<Either<Failure, String?>> getAmendedFrom(
    String doctype,
    String name,
  ) async {
    try {
      final result = await _client.callMethod<Map<String, dynamic>>(
        'frappe.client.get_value',
        params: {
          'doctype': doctype,
          'filters': {'name': name},
          'fieldname': 'amended_from',
        },
      );

      final amendedFrom = result['amended_from'] as String?;
      return Right(amendedFrom);
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
        message: 'Failed to get amended_from: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get documents by their state
  ///
  /// Convenience method to fetch all documents with a specific docstatus.
  ///
  /// Example:
  /// ```dart
  /// // Get all draft sales orders
  /// final drafts = await stateService.getByStatus(
  ///   'Sales Order',
  ///   DocStatus.draft,
  /// );
  ///
  /// // Get all submitted invoices
  /// final submitted = await stateService.getByStatus(
  ///   'Sales Invoice',
  ///   DocStatus.submitted,
  ///   additionalFilters: {'customer': 'CUST-001'},
  /// );
  /// ```
  Future<Either<Failure, List<Map<String, dynamic>>>> getByStatus(
    String doctype,
    DocStatus status, {
    List<String>? fields,
    Map<String, dynamic>? additionalFilters,
    int? limit,
    String? orderBy,
  }) async {
    try {
      final filters = <String, dynamic>{
        'docstatus': status.value,
        ...?additionalFilters,
      };

      final result = await _client.getList<Map<String, dynamic>>(
        doctype,
        fields: fields,
        filters: filters,
        limitPageLength: limit,
        orderBy: orderBy,
      );

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
        message: 'Failed to get documents by status: $e',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }
}
