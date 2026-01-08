/// Fluent query builder for Frappe API with type-safe filters
/// Supports complex queries, sorting, pagination, and field selection
class QueryBuilder {
  final String _doctype;
  final List<Filter> _filters = [];
  final List<Filter> _orFilters = [];
  String? _orderBy;
  bool _descending = false;
  int? _limit;
  int? _offset;
  final List<String> _fields = [];
  final Map<String, dynamic> _rawFilters = {};
  final List<String> _childTables = [];
  final Map<String, List<String>> _childFields = {};
  String? _searchTerm;

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

  // ==================== OR Filters ====================

  /// Add an OR equality filter
  ///
  /// Example:
  /// ```dart
  /// QueryBuilder('Item')
  ///   .where('disabled', 0)
  ///   .orWhere('item_group', 'Electronics')
  ///   .orWhere('item_group', 'Computers');
  /// // Result: disabled=0 AND (item_group='Electronics' OR item_group='Computers')
  /// ```
  QueryBuilder orWhere(String field, dynamic value) {
    _orFilters.add(Filter(field, FilterOperator.equals, value));
    return this;
  }

  /// Add an OR not equals filter
  QueryBuilder orWhereNot(String field, dynamic value) {
    _orFilters.add(Filter(field, FilterOperator.notEquals, value));
    return this;
  }

  /// Add an OR greater than filter
  QueryBuilder orWhereGreaterThan(String field, dynamic value) {
    _orFilters.add(Filter(field, FilterOperator.greaterThan, value));
    return this;
  }

  /// Add an OR less than filter
  QueryBuilder orWhereLessThan(String field, dynamic value) {
    _orFilters.add(Filter(field, FilterOperator.lessThan, value));
    return this;
  }

  /// Add an OR like filter (contains)
  ///
  /// Example:
  /// ```dart
  /// QueryBuilder('Item')
  ///   .orWhereLike('item_name', '%laptop%')
  ///   .orWhereLike('description', '%laptop%');
  /// // Matches items where name OR description contains 'laptop'
  /// ```
  QueryBuilder orWhereLike(String field, String pattern) {
    _orFilters.add(Filter(field, FilterOperator.like, pattern));
    return this;
  }

  /// Add an OR in filter (value in list)
  ///
  /// Example:
  /// ```dart
  /// QueryBuilder('Sales Order')
  ///   .orWhereIn('status', ['Open', 'Pending'])
  ///   .orWhereIn('priority', ['High', 'Urgent']);
  /// ```
  QueryBuilder orWhereIn(String field, List<dynamic> values) {
    _orFilters.add(Filter(field, FilterOperator.inList, values));
    return this;
  }

  /// Add an OR not in filter
  QueryBuilder orWhereNotIn(String field, List<dynamic> values) {
    _orFilters.add(Filter(field, FilterOperator.notIn, values));
    return this;
  }

  /// Add an OR is null filter
  QueryBuilder orWhereNull(String field) {
    _orFilters.add(Filter(field, FilterOperator.isNull, null));
    return this;
  }

  /// Add an OR is not null filter
  QueryBuilder orWhereNotNull(String field) {
    _orFilters.add(Filter(field, FilterOperator.isNotNull, null));
    return this;
  }

  /// Add an OR between filter
  QueryBuilder orWhereBetween(String field, dynamic start, dynamic end) {
    _orFilters.add(Filter(field, FilterOperator.between, [start, end]));
    return this;
  }

  /// Add a filter group as OR conditions
  ///
  /// Example:
  /// ```dart
  /// final group = FilterGroup.or()
  ///   .add('city', FilterOperator.equals, 'Mumbai')
  ///   .add('city', FilterOperator.equals, 'Delhi');
  ///
  /// QueryBuilder('Customer')
  ///   .where('enabled', 1)
  ///   .orGroup(group);
  /// ```
  QueryBuilder orGroup(FilterGroup group) {
    for (final filter in group.filters) {
      if (filter is List && filter.length >= 3) {
        final field = filter[0] as String;
        final op = filter[1] as String;
        final value = filter[2];
        _orFilters.add(Filter(
          field,
          FilterOperator.values.firstWhere(
            (e) => e.symbol == op,
            orElse: () => FilterOperator.equals,
          ),
          value,
        ));
      }
    }
    return this;
  }

  // ==================== Search ====================

  /// Add a search term for full-text search
  ///
  /// This adds LIKE filters on common text fields.
  /// For actual full-text search, use QueryService.search()
  ///
  /// Example:
  /// ```dart
  /// QueryBuilder('Item')
  ///   .search('laptop')
  ///   .limit(20);
  /// ```
  QueryBuilder search(String term) {
    _searchTerm = term;
    return this;
  }

  // ==================== Child Tables ====================

  /// Include a child table in the response
  ///
  /// Example:
  /// ```dart
  /// QueryBuilder('Sales Order')
  ///   .withChildren('items')
  ///   .withChildren('taxes');
  /// ```
  QueryBuilder withChildren(String tableName) {
    if (!_childTables.contains(tableName)) {
      _childTables.add(tableName);
      // Add the child table to fields
      if (!_fields.contains(tableName)) {
        _fields.add(tableName);
      }
    }
    return this;
  }

  /// Select specific fields from a child table
  ///
  /// Example:
  /// ```dart
  /// QueryBuilder('Sales Order')
  ///   .withChildren('items')
  ///   .childField('items', 'item_code')
  ///   .childField('items', 'qty')
  ///   .childField('items', 'rate');
  /// ```
  QueryBuilder childField(String tableName, String field) {
    // Ensure child table is included
    withChildren(tableName);

    // Add to child fields map
    _childFields.putIfAbsent(tableName, () => []);
    if (!_childFields[tableName]!.contains(field)) {
      _childFields[tableName]!.add(field);
    }

    // Add as dotted field notation for Frappe
    final dottedField = '$tableName.$field';
    if (!_fields.contains(dottedField)) {
      _fields.add(dottedField);
    }

    return this;
  }

  /// Filter by a child table field
  ///
  /// Note: This creates a filter on the child doctype.
  /// Results will include parent documents where ANY child row matches.
  ///
  /// Example:
  /// ```dart
  /// QueryBuilder('Sales Order')
  ///   .whereChild('items', 'item_code', 'ITEM-001');
  /// // Returns sales orders containing ITEM-001
  /// ```
  QueryBuilder whereChild(String tableName, String field, dynamic value) {
    // Store as a special filter that will be handled in build()
    _filters.add(Filter(
      '`tab$tableName`.$field',
      FilterOperator.equals,
      value,
    ));
    return this;
  }

  /// Filter child table with custom operator
  QueryBuilder whereChildOp(
    String tableName,
    String field,
    FilterOperator operator,
    dynamic value,
  ) {
    _filters.add(Filter(
      '`tab$tableName`.$field',
      operator,
      value,
    ));
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

    // Build AND filters
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
        (params['filters'] as List).add([entry.key, ...entry.value as List]);
      }
    }

    // Build OR filters
    if (_orFilters.isNotEmpty) {
      params['or_filters'] = _orFilters
          .map((filter) => [
                filter.field,
                filter.operator.symbol,
                filter.value,
              ])
          .toList();
    }

    // Add search term as LIKE filter on name field
    if (_searchTerm != null && _searchTerm!.isNotEmpty) {
      params['filters'] ??= [];
      (params['filters'] as List).add(['name', 'like', '%$_searchTerm%']);
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

  /// Build OR filters array for Frappe API
  List<List<dynamic>> buildOrFilters() {
    return _orFilters
        .map((filter) => [
              filter.field,
              filter.operator.symbol,
              filter.value,
            ])
        .toList();
  }

  /// Check if query has OR filters
  bool get hasOrFilters => _orFilters.isNotEmpty;

  /// Check if query has child table includes
  bool get hasChildTables => _childTables.isNotEmpty;

  /// Get the list of included child tables
  List<String> get childTables => List.unmodifiable(_childTables);

  /// Get the search term if set
  String? get searchTerm => _searchTerm;

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
    clone._orFilters.addAll(_orFilters);
    clone._orderBy = _orderBy;
    clone._descending = _descending;
    clone._limit = _limit;
    clone._offset = _offset;
    clone._fields.addAll(_fields);
    clone._rawFilters.addAll(_rawFilters);
    clone._childTables.addAll(_childTables);
    clone._childFields.addAll(_childFields);
    clone._searchTerm = _searchTerm;
    return clone;
  }

  /// Reset all filters
  QueryBuilder reset() {
    _filters.clear();
    _orFilters.clear();
    _rawFilters.clear();
    _childTables.clear();
    _childFields.clear();
    _searchTerm = null;
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
        'orFilters: ${_orFilters.length}, orderBy: $_orderBy, '
        'limit: $_limit, offset: $_offset, fields: ${_fields.length}, '
        'childTables: ${_childTables.length})';
  }

  /// Get the doctype this query is for
  String get doctype => _doctype;
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
