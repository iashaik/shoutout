/// Configuration class for Shoutout Frappe API client
class ShoutoutConfig {
  /// Base URL of the Frappe instance (e.g., 'https://yoursite.frappe.cloud')
  final String baseUrl;

  /// Connect timeout in seconds
  final Duration connectTimeout;

  /// Receive timeout in seconds
  final Duration receiveTimeout;

  /// Send timeout in seconds
  final Duration sendTimeout;

  /// Maximum number of retry attempts
  final int maxRetries;

  /// Delay durations for each retry attempt
  final List<Duration> retryDelays;

  /// Additional HTTP status codes to retry (besides 5xx errors)
  final Set<int> retryableStatuses;

  /// Enable detailed logging
  final bool enableLogging;

  /// Enable request/response logging in debug mode
  final bool enableNetworkLogging;

  const ShoutoutConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    this.retryableStatuses = const {408, 429, 503},
    this.enableLogging = true,
    this.enableNetworkLogging = true,
  });

  /// Frappe API method endpoint
  String get apiMethodUrl => '$baseUrl/api/method';

  /// Frappe API resource endpoint
  String get apiResourceUrl => '$baseUrl/api/resource';

  /// Copy with method for creating modified instances
  ShoutoutConfig copyWith({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    int? maxRetries,
    List<Duration>? retryDelays,
    Set<int>? retryableStatuses,
    bool? enableLogging,
    bool? enableNetworkLogging,
  }) {
    return ShoutoutConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelays: retryDelays ?? this.retryDelays,
      retryableStatuses: retryableStatuses ?? this.retryableStatuses,
      enableLogging: enableLogging ?? this.enableLogging,
      enableNetworkLogging: enableNetworkLogging ?? this.enableNetworkLogging,
    );
  }
}
