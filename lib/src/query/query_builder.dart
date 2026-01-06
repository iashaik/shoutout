/// Fluent query builder for Frappe API with type-safe filters
/// Supports complex queries, sorting, pagination, and field selection
class QueryBuilder {
  final String _doctype;
  final List<Filter> _filters = [];
  String? _orderBy;
  bool _descending = false;
  int? _limit;
  int? _offset;
  final List<String> _fields = [];
  final Map<String, dynamic> _rawFilters = {};

  QueryBuilder(this._doctype);

  /// Add a simple equality filter
  QueryBuilder where(String field, dynamic value) {
    _filters.add(Filter(field, FilterOperator.equals, value));
    return this;
  }

  /// Add a not equals filter
  QueryBuilder whereNot(String field, dynamic value) {
    _filters.add(Filter(field, FilterOperator.notEquals, value));
    return this;
  }

  /// Add a greater than filter
  QueryBuilder whereGreaterThan(String field, dynamic value) {
    _filters.add(Filter(field, FilterOperator.greaterThan, value));
    return this;
  }

  /// Add a greater than or equal filter
  QueryBuilder whereGreaterThanOrEqual(String field, dynamic value) {
    _filters.add(Filter(field, FilterOperator.greaterThanOrEqual, value));
    return this;
  }

  /// Add a less than filter
  QueryBuilder whereLessThan(String field, dynamic value) {
    _filters.add(Filter(field, FilterOperator.lessThan, value));
    return this;
  }

  /// Add a less than or equal filter
  QueryBuilder whereLessThanOrEqual(String field, dynamic value) {
    _filters.add(Filter(field, FilterOperator.lessThanOrEqual, value));
    return this;
  }

  /// Add a like filter (contains)
  QueryBuilder whereLike(String field, String pattern) {
    _filters.add(Filter(field, FilterOperator.like, pattern));
    return this;
  }

  /// Add a not like filter
  QueryBuilder whereNotLike(String field, String pattern) {
    _filters.add(Filter(field, FilterOperator.notLike, pattern));
    return this;
  }

  /// Add an in filter (value in list)
  QueryBuilder whereIn(String field, List<dynamic> values) {
    _filters.add(Filter(field, FilterOperator.inList, values));
    return this;
  }

  /// Add a not in filter
  QueryBuilder whereNotIn(String field, List<dynamic> values) {
    _filters.add(Filter(field, FilterOperator.notIn, values));
    return this;
  }

  /// Add an is null filter
  QueryBuilder whereNull(String field) {
    _filters.add(Filter(field, FilterOperator.isNull, null));
    return this;
  }

  /// Add an is not null filter
  QueryBuilder whereNotNull(String field) {
    _filters.add(Filter(field, FilterOperator.isNotNull, null));
    return this;
  }

  /// Add a between filter
  QueryBuilder whereBetween(String field, dynamic start, dynamic end) {
    _filters.add(Filter(field, FilterOperator.between, [start, end]));
    return this;
  }

  /// Add a custom raw filter
  QueryBuilder whereRaw(String field, String operator, dynamic value) {
    _rawFilters[field] = [operator, value];
    return this;
  }

  /// Set order by field
  QueryBuilder orderBy(String field, {bool descending = false}) {
    _orderBy = field;
    _descending = descending;
    return this;
  }

  /// Set limit
  QueryBuilder limit(int count) {
    _limit = count;
    return this;
  }

  /// Set offset
  QueryBuilder offset(int count) {
    _offset = count;
    return this;
  }

  /// Select specific fields
  QueryBuilder select(List<String> fields) {
    _fields.clear();
    _fields.addAll(fields);
    return this;
  }

  /// Add a field to selection
  QueryBuilder addField(String field) {
    if (!_fields.contains(field)) {
      _fields.add(field);
    }
    return this;
  }

  /// Build the query parameters for Frappe API
  Map<String, dynamic> build() {
    final params = <String, dynamic>{};

    // Add doctype
    params['doctype'] = _doctype;

    // Build filters
    if (_filters.isNotEmpty) {
      params['filters'] = _filters
          .map((filter) => [
                filter.field,
                filter.operator.symbol,
                filter.value,
              ])
          .toList();
    }

    // Add raw filters
    if (_rawFilters.isNotEmpty) {
      params['filters'] ??= [];
      for (final entry in _rawFilters.entries) {
        params['filters'].add([entry.key, ...entry.value]);
      }
    }

    // Add order by
    if (_orderBy != null) {
      params['order_by'] = '${_orderBy!} ${_descending ? 'desc' : 'asc'}';
    }

    // Add limit
    if (_limit != null) {
      params['limit_page_length'] = _limit;
    }

    // Add offset
    if (_offset != null) {
      params['limit_start'] = _offset;
    }

    // Add fields
    if (_fields.isNotEmpty) {
      params['fields'] = _fields;
    }

    return params;
  }

  /// Build the filters array for Frappe API
  List<List<dynamic>> buildFilters() {
    return _filters
        .map((filter) => [
              filter.field,
              filter.operator.symbol,
              filter.value,
            ])
        .toList();
  }

  /// Create a copy of this query builder
  QueryBuilder clone() {
    final clone = QueryBuilder(_doctype);
    clone._filters.addAll(_filters);
    clone._orderBy = _orderBy;
    clone._descending = _descending;
    clone._limit = _limit;
    clone._offset = _offset;
    clone._fields.addAll(_fields);
    clone._rawFilters.addAll(_rawFilters);
    return clone;
  }

  /// Reset all filters
  QueryBuilder reset() {
    _filters.clear();
    _rawFilters.clear();
    _orderBy = null;
    _descending = false;
    _limit = null;
    _offset = null;
    _fields.clear();
    return this;
  }

  @override
  String toString() {
    return 'QueryBuilder(doctype: $_doctype, filters: ${_filters.length}, '
        'orderBy: $_orderBy, limit: $_limit, offset: $_offset, '
        'fields: ${_fields.length})';
  }
}

/// Represents a single filter condition
class Filter {
  final String field;
  final FilterOperator operator;
  final dynamic value;

  Filter(this.field, this.operator, this.value);

  @override
  String toString() {
    return '$field ${operator.symbol} $value';
  }
}

/// Filter operators supported by Frappe
enum FilterOperator {
  equals('='),
  notEquals('!='),
  greaterThan('>'),
  greaterThanOrEqual('>='),
  lessThan('<'),
  lessThanOrEqual('<='),
  like('like'),
  notLike('not like'),
  inList('in'),
  notIn('not in'),
  isNull('is'),
  isNotNull('is not'),
  between('between');

  final String symbol;
  const FilterOperator(this.symbol);
}

/// Helper to create complex AND/OR filter groups
class FilterGroup {
  final List<dynamic> filters = [];
  final FilterGroupType type;

  FilterGroup.and() : type = FilterGroupType.and;
  FilterGroup.or() : type = FilterGroupType.or;

  /// Add a simple filter
  FilterGroup add(String field, FilterOperator operator, dynamic value) {
    filters.add([field, operator.symbol, value]);
    return this;
  }

  /// Add a nested filter group
  FilterGroup addGroup(FilterGroup group) {
    filters.add(group.build());
    return this;
  }

  /// Build the filter group for Frappe API
  List<dynamic> build() {
    if (type == FilterGroupType.or) {
      return filters;
    }
    // For AND groups, return filters directly
    return filters;
  }
}

enum FilterGroupType { and, or }

/// Advanced query builder with support for joins and aggregations
/// Note: Frappe has limited join support, this is for future extensibility
class AdvancedQueryBuilder extends QueryBuilder {
  final List<String> _groupBy = [];
  final Map<String, AggregateFunction> _aggregates = {};

  AdvancedQueryBuilder(super.doctype);

  /// Add group by clause
  AdvancedQueryBuilder groupBy(String field) {
    if (!_groupBy.contains(field)) {
      _groupBy.add(field);
    }
    return this;
  }

  /// Add count aggregate
  AdvancedQueryBuilder count(String field, {String? alias}) {
    _aggregates[alias ?? 'count_$field'] =
        AggregateFunction.count(field);
    return this;
  }

  /// Add sum aggregate
  AdvancedQueryBuilder sum(String field, {String? alias}) {
    _aggregates[alias ?? 'sum_$field'] = AggregateFunction.sum(field);
    return this;
  }

  /// Add average aggregate
  AdvancedQueryBuilder avg(String field, {String? alias}) {
    _aggregates[alias ?? 'avg_$field'] = AggregateFunction.avg(field);
    return this;
  }

  /// Add min aggregate
  AdvancedQueryBuilder min(String field, {String? alias}) {
    _aggregates[alias ?? 'min_$field'] = AggregateFunction.min(field);
    return this;
  }

  /// Add max aggregate
  AdvancedQueryBuilder max(String field, {String? alias}) {
    _aggregates[alias ?? 'max_$field'] = AggregateFunction.max(field);
    return this;
  }

  @override
  Map<String, dynamic> build() {
    final params = super.build();

    // Add group by
    if (_groupBy.isNotEmpty) {
      params['group_by'] = _groupBy.join(',');
    }

    // Add aggregates (Frappe-specific implementation may vary)
    if (_aggregates.isNotEmpty) {
      params['aggregates'] = _aggregates.map(
        (alias, fn) => MapEntry(alias, {
          'function': fn.function,
          'field': fn.field,
        }),
      );
    }

    return params;
  }
}

/// Represents an aggregate function
class AggregateFunction {
  final String function;
  final String field;

  AggregateFunction.count(this.field) : function = 'count';
  AggregateFunction.sum(this.field) : function = 'sum';
  AggregateFunction.avg(this.field) : function = 'avg';
  AggregateFunction.min(this.field) : function = 'min';
  AggregateFunction.max(this.field) : function = 'max';
}
