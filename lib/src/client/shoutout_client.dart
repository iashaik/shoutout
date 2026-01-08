import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/shoutout_config.dart';
import '../exceptions/shoutout_exception.dart';
import '../interceptors/connectivity_interceptor.dart';
import '../interceptors/frappe_auth_interceptor.dart';
import '../query/query_builder.dart';

/// Main Shoutout client for interacting with Frappe APIs
class ShoutoutClient {
  late final Dio _dio;
  late final FrappeAuthInterceptor _authInterceptor;
  final ShoutoutConfig config;

  ShoutoutClient({required this.config}) {
    _initialize();
  }

  /// Initialize Dio with configuration and interceptors
  void _initialize() {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _addInterceptors();
  }

  void _addInterceptors() {
    // 1. Connectivity Check
    _dio.interceptors.add(ConnectivityInterceptor());

    // 2. Authentication
    _authInterceptor = FrappeAuthInterceptor();
    _dio.interceptors.add(_authInterceptor);

    // 3. Retry Logic
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: (message) {
          if (config.enableLogging) {
            debugPrint('[SHOUTOUT RETRY] $message');
          }
        },
        retries: config.maxRetries,
        retryDelays: config.retryDelays,
        retryableExtraStatuses: config.retryableStatuses,
      ),
    );

    // 4. Logging (debug only)
    if (kDebugMode && config.enableNetworkLogging) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          error: true,
          compact: true,
        ),
      );
    }
  }

  /// Get the underlying Dio instance for advanced usage
  Dio get dio => _dio;

  /// Set API key and secret for authentication
  void setApiCredentials(String apiKey, String apiSecret) {
    _authInterceptor.setApiCredentials(apiKey, apiSecret);
  }

  /// Set bearer token for authentication
  void setToken(String token) {
    _authInterceptor.setToken(token);
  }

  /// Clear authentication
  void clearAuth() {
    _authInterceptor.clearAuth();
  }

  /// Check if client is authenticated
  bool get isAuthenticated => _authInterceptor.isAuthenticated;

  // ==================== Frappe API Methods ====================

  /// Call a Frappe whitelisted method
  ///
  /// Example:
  /// ```dart
  /// final result = await client.callMethod(
  ///   'frappe.auth.get_logged_user',
  ///   params: {'include_roles': true},
  /// );
  /// ```
  Future<T> callMethod<T>(
    String method, {
    Map<String, dynamic>? params,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${config.apiMethodUrl}/$method',
        data: params,
        options: options,
      );

      return _handleResponse<T>(response);
    } on DioException catch (e, stackTrace) {
      throw e.toShoutoutException();
    }
  }

  /// Get a Frappe document
  ///
  /// Example:
  /// ```dart
  /// final user = await client.getDoc(
  ///   'User',
  ///   'user@example.com',
  /// );
  /// ```
  Future<T> getDoc<T>(
    String doctype,
    String name, {
    List<String>? fields,
    Options? options,
  }) async {
    try {
      final queryParams = fields != null ? {'fields': fields} : null;

      final response = await _dio.get<Map<String, dynamic>>(
        '${config.apiResourceUrl}/$doctype/$name',
        queryParameters: queryParams,
        options: options,
      );

      return _handleResponse<T>(response);
    } on DioException catch (e, stackTrace) {
      throw e.toShoutoutException();
    }
  }

  /// Get list of Frappe documents
  ///
  /// Example:
  /// ```dart
  /// final users = await client.getList(
  ///   'User',
  ///   fields: ['name', 'email', 'full_name'],
  ///   filters: {'enabled': 1},
  ///   limitPageLength: 20,
  /// );
  /// ```
  Future<List<T>> getList<T>(
    String doctype, {
    List<String>? fields,
    Map<String, dynamic>? filters,
    List<List<dynamic>>? orFilters,
    int? limitStart,
    int? limitPageLength,
    String? orderBy,
    Options? options,
  }) async {
    try {
      final queryParams = <String, dynamic>{};

      if (fields != null) {
        queryParams['fields'] = fields;
      }
      if (filters != null) {
        queryParams['filters'] = filters;
      }
      if (orFilters != null && orFilters.isNotEmpty) {
        queryParams['or_filters'] = orFilters;
      }
      if (limitStart != null) {
        queryParams['limit_start'] = limitStart;
      }
      if (limitPageLength != null) {
        queryParams['limit_page_length'] = limitPageLength;
      }
      if (orderBy != null) {
        queryParams['order_by'] = orderBy;
      }

      final response = await _dio.get<Map<String, dynamic>>(
        '${config.apiResourceUrl}/$doctype',
        queryParameters: queryParams,
        options: options,
      );

      final data = response.data?['data'];
      if (data is! List) {
        throw ShoutoutException(message: 'Invalid response format: expected list');
      }

      return (data as List).cast<T>();
    } on DioException catch (e, stackTrace) {
      throw e.toShoutoutException();
    }
  }

  /// Get list of Frappe documents using a QueryBuilder
  ///
  /// Provides a fluent API for building complex queries with
  /// AND/OR filters, child tables, and pagination.
  ///
  /// Example:
  /// ```dart
  /// final query = QueryBuilder('Item')
  ///   .where('disabled', 0)
  ///   .orWhere('item_group', 'Electronics')
  ///   .orWhere('item_group', 'Computers')
  ///   .select(['name', 'item_name', 'standard_rate'])
  ///   .orderBy('modified', descending: true)
  ///   .limit(20);
  ///
  /// final items = await client.getListWithQuery<Map<String, dynamic>>(query);
  /// ```
  Future<List<T>> getListWithQuery<T>(
    QueryBuilder query, {
    Options? options,
  }) async {
    final params = query.build();

    return getList<T>(
      params['doctype'] as String,
      fields: params['fields'] as List<String>?,
      filters: params['filters'] != null
          ? {'filters': params['filters']}
          : null,
      orFilters: params['or_filters'] as List<List<dynamic>>?,
      limitStart: params['limit_start'] as int?,
      limitPageLength: params['limit_page_length'] as int?,
      orderBy: params['order_by'] as String?,
      options: options,
    );
  }

  /// Create a new Frappe document
  ///
  /// Example:
  /// ```dart
  /// final newUser = await client.createDoc(
  ///   'User',
  ///   data: {
  ///     'email': 'newuser@example.com',
  ///     'first_name': 'John',
  ///     'last_name': 'Doe',
  ///   },
  /// );
  /// ```
  Future<T> createDoc<T>(
    String doctype, {
    required Map<String, dynamic> data,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${config.apiResourceUrl}/$doctype',
        data: data,
        options: options,
      );

      return _handleResponse<T>(response);
    } on DioException catch (e, stackTrace) {
      throw e.toShoutoutException();
    }
  }

  /// Update an existing Frappe document
  ///
  /// Example:
  /// ```dart
  /// final updated = await client.updateDoc(
  ///   'User',
  ///   'user@example.com',
  ///   data: {'mobile_no': '+1234567890'},
  /// );
  /// ```
  Future<T> updateDoc<T>(
    String doctype,
    String name, {
    required Map<String, dynamic> data,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '${config.apiResourceUrl}/$doctype/$name',
        data: data,
        options: options,
      );

      return _handleResponse<T>(response);
    } on DioException catch (e, stackTrace) {
      throw e.toShoutoutException();
    }
  }

  /// Delete a Frappe document
  ///
  /// Example:
  /// ```dart
  /// await client.deleteDoc('User', 'user@example.com');
  /// ```
  Future<void> deleteDoc(
    String doctype,
    String name, {
    Options? options,
  }) async {
    try {
      await _dio.delete(
        '${config.apiResourceUrl}/$doctype/$name',
        options: options,
      );
    } on DioException catch (e, stackTrace) {
      throw e.toShoutoutException();
    }
  }

  /// Handle Frappe response format
  T _handleResponse<T>(Response<Map<String, dynamic>> response) {
    final data = response.data;

    if (data == null) {
      throw ShoutoutException(message: 'Empty response from server');
    }

    // Frappe wraps responses in a 'data' or 'message' field
    if (data.containsKey('data')) {
      return data['data'] as T;
    } else if (data.containsKey('message')) {
      return data['message'] as T;
    }

    return data as T;
  }

  /// Close the client and cleanup resources
  void dispose() {
    _dio.close();
  }
}
