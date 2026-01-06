import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../network/network_monitor.dart';
import 'queued_request.dart';

/// Configuration for offline queue behavior
class OfflineQueueConfig {
  final String boxName;
  final bool autoSync;
  final Duration syncInterval;
  final int maxQueueSize;
  final bool removeOnSuccess;
  final bool retryOnFailure;

  const OfflineQueueConfig({
    this.boxName = 'offline_queue',
    this.autoSync = true,
    this.syncInterval = const Duration(seconds: 30),
    this.maxQueueSize = 100,
    this.removeOnSuccess = true,
    this.retryOnFailure = true,
  });
}

/// Result of a queued request execution
class QueuedRequestResult {
  final QueuedRequest request;
  final bool success;
  final dynamic response;
  final dynamic error;

  const QueuedRequestResult({
    required this.request,
    required this.success,
    this.response,
    this.error,
  });
}

/// Manager for handling offline request queuing and syncing
class OfflineQueueManager {
  final Dio _dio;
  final NetworkMonitor _networkMonitor;
  final OfflineQueueConfig config;

  Box<QueuedRequest>? _queueBox;
  Timer? _syncTimer;
  StreamSubscription<NetworkStatus>? _connectivitySubscription;

  bool _isProcessing = false;
  final _resultsController = StreamController<QueuedRequestResult>.broadcast();

  Stream<QueuedRequestResult> get resultsStream => _resultsController.stream;

  OfflineQueueManager({
    required Dio dio,
    NetworkMonitor? networkMonitor,
    this.config = const OfflineQueueConfig(),
  })  : _dio = dio,
        _networkMonitor = networkMonitor ?? NetworkMonitorSingleton.instance;

  /// Initialize the offline queue manager
  Future<void> initialize() async {
    // Open Hive box for queue storage
    _queueBox = await Hive.openBox<QueuedRequest>(config.boxName);

    // Listen to connectivity changes
    _connectivitySubscription =
        _networkMonitor.statusStream.listen((status) {
      if (status.isConnected && !_isProcessing) {
        processQueue();
      }
    });

    // Start auto-sync timer if enabled
    if (config.autoSync) {
      _syncTimer = Timer.periodic(config.syncInterval, (_) {
        if (_networkMonitor.isConnected && !_isProcessing) {
          processQueue();
        }
      });
    }

    // Process queue if we're already online
    if (_networkMonitor.isConnected) {
      processQueue();
    }
  }

  /// Add a request to the offline queue
  Future<void> enqueue(QueuedRequest request) async {
    if (_queueBox == null) {
      throw StateError('OfflineQueueManager not initialized');
    }

    // Check queue size limit
    if (_queueBox!.length >= config.maxQueueSize) {
      // Remove oldest request
      final oldestKey = _queueBox!.keys.first;
      await _queueBox!.delete(oldestKey);
    }

    await _queueBox!.put(request.id, request);
  }

  /// Create and enqueue a request from Dio RequestOptions
  Future<void> enqueueFromOptions(
    RequestOptions options, {
    String? tag,
    int priority = 0,
    int maxRetries = 3,
  }) async {
    final request = QueuedRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: options.method,
      url: options.uri.toString(),
      headers: Map<String, dynamic>.from(options.headers),
      queryParameters: options.queryParameters.isNotEmpty
          ? Map<String, dynamic>.from(options.queryParameters)
          : null,
      data: options.data,
      createdAt: DateTime.now(),
      tag: tag,
      priority: priority,
      maxRetries: maxRetries,
    );

    await enqueue(request);
  }

  /// Get all queued requests
  List<QueuedRequest> getAllRequests() {
    if (_queueBox == null) return [];
    return _queueBox!.values.toList();
  }

  /// Get queued requests by tag
  List<QueuedRequest> getRequestsByTag(String tag) {
    if (_queueBox == null) return [];
    return _queueBox!.values.where((req) => req.tag == tag).toList();
  }

  /// Get queue size
  int get queueSize => _queueBox?.length ?? 0;

  /// Check if queue is empty
  bool get isEmpty => queueSize == 0;

  /// Clear all queued requests
  Future<void> clearQueue() async {
    await _queueBox?.clear();
  }

  /// Remove a specific request from queue
  Future<void> removeRequest(String requestId) async {
    await _queueBox?.delete(requestId);
  }

  /// Process all queued requests
  Future<void> processQueue() async {
    if (_queueBox == null || _isProcessing || isEmpty) return;

    if (!_networkMonitor.isConnected) {
      return;
    }

    _isProcessing = true;

    try {
      final requests = getAllRequests()
        ..sort((a, b) {
          // Sort by priority (higher first), then by creation time (older first)
          if (a.priority != b.priority) {
            return b.priority.compareTo(a.priority);
          }
          return a.createdAt.compareTo(b.createdAt);
        });

      for (final request in requests) {
        // Check if we should execute this request yet
        if (request.executeAfter != null &&
            DateTime.now().isBefore(request.executeAfter!)) {
          continue;
        }

        // Check if max retries exceeded
        if (request.retryCount >= request.maxRetries) {
          await _handleMaxRetriesExceeded(request);
          continue;
        }

        await _executeRequest(request);

        // Break if we lost connection during processing
        if (!_networkMonitor.isConnected) {
          break;
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _executeRequest(QueuedRequest request) async {
    try {
      final response = await _dio.request(
        request.url,
        data: request.data,
        queryParameters: request.queryParameters,
        options: Options(
          method: request.method,
          headers: request.headers,
        ),
      );

      // Success - remove from queue if configured
      if (config.removeOnSuccess) {
        await removeRequest(request.id);
      }

      _resultsController.add(
        QueuedRequestResult(
          request: request,
          success: true,
          response: response.data,
        ),
      );
    } catch (e) {
      // Failed - increment retry count
      if (config.retryOnFailure && request.retryCount < request.maxRetries) {
        final updatedRequest = request.copyWith(
          retryCount: request.retryCount + 1,
        );
        await _queueBox!.put(request.id, updatedRequest);
      } else {
        // Max retries exceeded or retry disabled
        await removeRequest(request.id);
      }

      _resultsController.add(
        QueuedRequestResult(
          request: request,
          success: false,
          error: e,
        ),
      );
    }
  }

  Future<void> _handleMaxRetriesExceeded(QueuedRequest request) async {
    await removeRequest(request.id);

    _resultsController.add(
      QueuedRequestResult(
        request: request,
        success: false,
        error: 'Max retries exceeded',
      ),
    );
  }

  /// Manually trigger queue processing
  Future<void> sync() async {
    return processQueue();
  }

  /// Pause auto-sync
  void pauseAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Resume auto-sync
  void resumeAutoSync() {
    if (config.autoSync && _syncTimer == null) {
      _syncTimer = Timer.periodic(config.syncInterval, (_) {
        if (_networkMonitor.isConnected && !_isProcessing) {
          processQueue();
        }
      });
    }
  }

  /// Dispose the manager
  Future<void> dispose() async {
    _syncTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _resultsController.close();
    await _queueBox?.close();
  }
}
