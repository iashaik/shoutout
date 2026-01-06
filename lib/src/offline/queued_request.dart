import 'package:hive/hive.dart';

// To generate the Hive adapter, run: flutter pub run build_runner build
// Uncomment the line below after generating:
// part 'queued_request.g.dart';

/// Represents a queued HTTP request to be executed when online
/// Note: Hive adapter generation is optional. You can use this class
/// without Hive if you prefer a different storage solution.
@HiveType(typeId: 0)
class QueuedRequest extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String method; // GET, POST, PUT, DELETE, PATCH

  @HiveField(2)
  final String url;

  @HiveField(3)
  final Map<String, dynamic>? headers;

  @HiveField(4)
  final Map<String, dynamic>? queryParameters;

  @HiveField(5)
  final dynamic data; // Request body

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final int retryCount;

  @HiveField(8)
  final int maxRetries;

  @HiveField(9)
  final String? tag; // Optional tag for grouping requests

  @HiveField(10)
  final int priority; // Higher number = higher priority

  @HiveField(11)
  final DateTime? executeAfter; // For delayed execution

  QueuedRequest({
    required this.id,
    required this.method,
    required this.url,
    this.headers,
    this.queryParameters,
    this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.tag,
    this.priority = 0,
    this.executeAfter,
  });

  QueuedRequest copyWith({
    String? id,
    String? method,
    String? url,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    DateTime? createdAt,
    int? retryCount,
    int? maxRetries,
    String? tag,
    int? priority,
    DateTime? executeAfter,
  }) {
    return QueuedRequest(
      id: id ?? this.id,
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      queryParameters: queryParameters ?? this.queryParameters,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      tag: tag ?? this.tag,
      priority: priority ?? this.priority,
      executeAfter: executeAfter ?? this.executeAfter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'url': url,
      'headers': headers,
      'queryParameters': queryParameters,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'tag': tag,
      'priority': priority,
      'executeAfter': executeAfter?.toIso8601String(),
    };
  }

  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    return QueuedRequest(
      id: json['id'] as String,
      method: json['method'] as String,
      url: json['url'] as String,
      headers: json['headers'] as Map<String, dynamic>?,
      queryParameters: json['queryParameters'] as Map<String, dynamic>?,
      data: json['data'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 3,
      tag: json['tag'] as String?,
      priority: json['priority'] as int? ?? 0,
      executeAfter: json['executeAfter'] != null
          ? DateTime.parse(json['executeAfter'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'QueuedRequest(id: $id, method: $method, url: $url, priority: $priority)';
  }
}
