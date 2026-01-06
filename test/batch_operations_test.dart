import 'package:flutter_test/flutter_test.dart';
import 'package:shoutout/shoutout.dart';

void main() {
  group('BatchResult', () {
    test('creates result with correct properties', () {
      final result = BatchResult(
        operation: BatchOperationType.create,
        totalCount: 10,
        doctype: 'User',
      );

      expect(result.operation, BatchOperationType.create);
      expect(result.totalCount, 10);
      expect(result.doctype, 'User');
      expect(result.successCount, 0);
      expect(result.errorCount, 0);
    });

    test('initial state shows no successes or errors', () {
      final result = BatchResult(
        operation: BatchOperationType.update,
        totalCount: 5,
      );

      expect(result.successes, isEmpty);
      expect(result.errors, isEmpty);
      expect(result.hasErrors, false);
      expect(result.isComplete, false);
    });

    test('toString provides readable summary', () {
      final result = BatchResult(
        operation: BatchOperationType.create,
        totalCount: 10,
      );

      final str = result.toString();

      expect(str, contains('create'));
      expect(str, contains('total: 10'));
    });

    test('toMap returns complete summary', () {
      final result = BatchResult(
        operation: BatchOperationType.update,
        totalCount: 5,
        doctype: 'User',
      );

      final map = result.toMap();

      expect(map['operation'], 'update');
      expect(map['doctype'], 'User');
      expect(map['total_count'], 5);
      expect(map['success_count'], 0);
      expect(map['error_count'], 0);
      expect(map.containsKey('duration_ms'), true);
    });
  });

  group('BatchError', () {
    test('creates error with all properties', () {
      final error = BatchError(
        item: {'name': 'test'},
        error: 'Test error message',
        index: 5,
      );

      expect(error.item, {'name': 'test'});
      expect(error.error, 'Test error message');
      expect(error.index, 5);
    });

    test('toString provides readable representation', () {
      final error = BatchError(
        item: {'name': 'test'},
        error: 'Failed',
        index: 3,
      );

      final str = error.toString();

      expect(str, contains('index: 3'));
      expect(str, contains('Failed'));
    });

    test('toMap returns complete error info', () {
      final error = BatchError(
        item: {'name': 'test', 'value': 123},
        error: 'Validation failed',
        index: 2,
      );

      final map = error.toMap();

      expect(map['index'], 2);
      expect(map['error'], 'Validation failed');
      expect(map['item'], {'name': 'test', 'value': 123});
    });
  });

  group('BatchOperationType', () {
    test('has all expected types', () {
      expect(BatchOperationType.create, isNotNull);
      expect(BatchOperationType.update, isNotNull);
      expect(BatchOperationType.delete, isNotNull);
      expect(BatchOperationType.upsert, isNotNull);
      expect(BatchOperationType.custom, isNotNull);
    });

    test('name returns correct string', () {
      expect(BatchOperationType.create.name, 'create');
      expect(BatchOperationType.update.name, 'update');
      expect(BatchOperationType.delete.name, 'delete');
    });
  });
}
