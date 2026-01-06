import 'package:flutter_test/flutter_test.dart';
import 'package:shoutout/shoutout.dart';

void main() {
  group('QueryBuilder', () {
    test('builds simple query with where clause', () {
      final query = QueryBuilder('User').where('enabled', 1);

      final params = query.build();

      expect(params['doctype'], 'User');
      expect(params['filters'], [
        ['enabled', '=', 1]
      ]);
    });

    test('builds query with multiple filters', () {
      final query = QueryBuilder('User')
          .where('enabled', 1)
          .whereLike('email', '%@example.com');

      final params = query.build();

      expect(params['filters'], [
        ['enabled', '=', 1],
        ['email', 'like', '%@example.com']
      ]);
    });

    test('builds query with ordering', () {
      final query = QueryBuilder('User')
          .orderBy('creation', descending: true);

      final params = query.build();

      expect(params['order_by'], 'creation desc');
    });

    test('builds query with ascending order', () {
      final query = QueryBuilder('User').orderBy('name');

      final params = query.build();

      expect(params['order_by'], 'name asc');
    });

    test('builds query with limit', () {
      final query = QueryBuilder('User').limit(20);

      final params = query.build();

      expect(params['limit_page_length'], 20);
    });

    test('builds query with offset', () {
      final query = QueryBuilder('User').offset(10);

      final params = query.build();

      expect(params['limit_start'], 10);
    });

    test('builds query with field selection', () {
      final query = QueryBuilder('User')
          .select(['name', 'email', 'full_name']);

      final params = query.build();

      expect(params['fields'], ['name', 'email', 'full_name']);
    });

    test('supports comparison operators', () {
      final query = QueryBuilder('Task')
          .whereGreaterThan('priority', 5)
          .whereLessThan('completion', 100);

      final params = query.build();

      expect(params['filters'], [
        ['priority', '>', 5],
        ['completion', '<', 100]
      ]);
    });

    test('supports in operator', () {
      final query = QueryBuilder('User')
          .whereIn('role', ['Admin', 'Manager']);

      final params = query.build();

      expect(params['filters'], [
        ['role', 'in', ['Admin', 'Manager']]
      ]);
    });

    test('supports null checks', () {
      final query = QueryBuilder('User')
          .whereNull('middle_name')
          .whereNotNull('email');

      final params = query.build();

      expect(params['filters'], [
        ['middle_name', 'is', null],
        ['email', 'is not', null]
      ]);
    });

    test('supports between operator', () {
      final query = QueryBuilder('Task')
          .whereBetween('creation', '2024-01-01', '2024-12-31');

      final params = query.build();

      expect(params['filters'], [
        ['creation', 'between', ['2024-01-01', '2024-12-31']]
      ]);
    });

    test('clone creates independent copy', () {
      final original = QueryBuilder('User')
          .where('enabled', 1)
          .limit(10);

      final clone = original.clone();
      clone.where('email', 'test@example.com');

      final originalParams = original.build();
      final cloneParams = clone.build();

      expect(originalParams['filters'].length, 1);
      expect(cloneParams['filters'].length, 2);
    });

    test('reset clears all filters and options', () {
      final query = QueryBuilder('User')
          .where('enabled', 1)
          .limit(10)
          .orderBy('name');

      query.reset();
      final params = query.build();

      expect(params.containsKey('filters'), false);
      expect(params.containsKey('limit_page_length'), false);
      expect(params.containsKey('order_by'), false);
    });

    test('addField adds unique fields', () {
      final query = QueryBuilder('User')
          .addField('name')
          .addField('email')
          .addField('name'); // Duplicate

      final params = query.build();

      expect(params['fields'], ['name', 'email']);
    });

    test('toString provides readable representation', () {
      final query = QueryBuilder('User')
          .where('enabled', 1)
          .limit(10);

      final str = query.toString();

      expect(str, contains('User'));
      expect(str, contains('filters: 1'));
      expect(str, contains('limit: 10'));
    });
  });

  group('AdvancedQueryBuilder', () {
    test('supports group by', () {
      final query = AdvancedQueryBuilder('Task')
          .groupBy('status');

      final params = query.build();

      expect(params['group_by'], 'status');
    });

    test('supports aggregations', () {
      final query = AdvancedQueryBuilder('Task')
          .count('name', alias: 'total_tasks')
          .sum('hours', alias: 'total_hours');

      final params = query.build();

      expect(params['aggregates'], isNotNull);
      expect(params['aggregates']['total_tasks']['function'], 'count');
      expect(params['aggregates']['total_hours']['function'], 'sum');
    });

    test('supports min and max aggregations', () {
      final query = AdvancedQueryBuilder('Task')
          .min('priority')
          .max('completion');

      final params = query.build();

      expect(params['aggregates']['min_priority']['function'], 'min');
      expect(params['aggregates']['max_completion']['function'], 'max');
    });
  });

  group('Filter', () {
    test('toString provides readable representation', () {
      final filter = Filter('enabled', FilterOperator.equals, 1);

      expect(filter.toString(), 'enabled = 1');
    });
  });

  group('FilterOperator', () {
    test('has correct symbols', () {
      expect(FilterOperator.equals.symbol, '=');
      expect(FilterOperator.notEquals.symbol, '!=');
      expect(FilterOperator.greaterThan.symbol, '>');
      expect(FilterOperator.lessThan.symbol, '<');
      expect(FilterOperator.like.symbol, 'like');
      expect(FilterOperator.inList.symbol, 'in');
    });
  });
}
