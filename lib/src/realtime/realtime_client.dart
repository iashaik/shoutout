import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dartz/dartz.dart';
import '../core/failure.dart';

/// Real-time client for Frappe WebSocket connections
/// Supports subscribing to doctypes, document updates, and custom events
class RealtimeClient {
  final String baseUrl;
  final String? authToken;
  WebSocketChannel? _channel;
  final Map<String, StreamController<RealtimeEvent>> _subscriptions = {};
  final StreamController<ConnectionState> _connectionStateController =
      StreamController<ConnectionState>.broadcast();
  ConnectionState _connectionState = ConnectionState.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int maxReconnectAttempts;
  final Duration reconnectInterval;
  final Duration heartbeatInterval;

  RealtimeClient({
    required this.baseUrl,
    this.authToken,
    this.maxReconnectAttempts = 5,
    this.reconnectInterval = const Duration(seconds: 5),
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  /// Get connection state stream
  Stream<ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Get current connection state
  ConnectionState get connectionState => _connectionState;

  /// Check if connected
  bool get isConnected => _connectionState == ConnectionState.connected;

  /// Connect to WebSocket
  Future<Either<Failure, bool>> connect() async {
    if (_connectionState == ConnectionState.connected ||
        _connectionState == ConnectionState.connecting) {
      return const Right(true);
    }

    try {
      _updateConnectionState(ConnectionState.connecting);

      // Convert http(s) to ws(s)
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/socket.io/');

      _channel = WebSocketChannel.connect(uri);

      // Wait for connection
      await _channel!.ready;

      _updateConnectionState(ConnectionState.connected);
      _reconnectAttempts = 0;

      // Start listening to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      // Start heartbeat
      _startHeartbeat();

      // Authenticate if token provided
      if (authToken != null) {
        _send({
          'type': 'auth',
          'token': authToken,
        });
      }

      return const Right(true);
    } catch (e, stackTrace) {
      _updateConnectionState(ConnectionState.disconnected);
      return Left(NetworkFailure(
        message: 'Failed to connect to WebSocket: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Disconnect from WebSocket
  Future<Either<Failure, bool>> disconnect() async {
    try {
      _heartbeatTimer?.cancel();
      _reconnectTimer?.cancel();
      await _channel?.sink.close();
      _channel = null;
      _updateConnectionState(ConnectionState.disconnected);
      return const Right(true);
    } catch (e, stackTrace) {
      return Left(UnknownFailure(
        message: 'Failed to disconnect: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Subscribe to a doctype for updates
  Stream<RealtimeEvent> subscribe(String doctype, {String? docname}) {
    final key = _getSubscriptionKey(doctype, docname);

    if (!_subscriptions.containsKey(key)) {
      _subscriptions[key] = StreamController<RealtimeEvent>.broadcast();

      // Send subscription message
      _send({
        'type': 'subscribe',
        'doctype': doctype,
        if (docname != null) 'docname': docname,
      });
    }

    return _subscriptions[key]!.stream;
  }

  /// Unsubscribe from a doctype
  Future<void> unsubscribe(String doctype, {String? docname}) async {
    final key = _getSubscriptionKey(doctype, docname);

    if (_subscriptions.containsKey(key)) {
      await _subscriptions[key]!.close();
      _subscriptions.remove(key);

      // Send unsubscribe message
      _send({
        'type': 'unsubscribe',
        'doctype': doctype,
        if (docname != null) 'docname': docname,
      });
    }
  }

  /// Subscribe to a custom event
  Stream<RealtimeEvent> subscribeToEvent(String eventName) {
    final key = 'event:$eventName';

    if (!_subscriptions.containsKey(key)) {
      _subscriptions[key] = StreamController<RealtimeEvent>.broadcast();

      _send({
        'type': 'subscribe_event',
        'event': eventName,
      });
    }

    return _subscriptions[key]!.stream;
  }

  /// Unsubscribe from a custom event
  Future<void> unsubscribeFromEvent(String eventName) async {
    final key = 'event:$eventName';

    if (_subscriptions.containsKey(key)) {
      await _subscriptions[key]!.close();
      _subscriptions.remove(key);

      _send({
        'type': 'unsubscribe_event',
        'event': eventName,
      });
    }
  }

  /// Emit a custom event
  void emit(String eventName, Map<String, dynamic> data) {
    _send({
      'type': 'emit',
      'event': eventName,
      'data': data,
    });
  }

  /// Send a message through WebSocket
  void _send(Map<String, dynamic> message) {
    if (_channel != null && isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// Handle incoming messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'doc_update':
          _handleDocUpdate(data);
          break;
        case 'event':
          _handleEvent(data);
          break;
        case 'pong':
          // Heartbeat response
          break;
        default:
          // Unknown message type
          break;
      }
    } catch (e) {
      // Failed to parse message
    }
  }

  /// Handle document update events
  void _handleDocUpdate(Map<String, dynamic> data) {
    final doctype = data['doctype'] as String?;
    final docname = data['docname'] as String?;
    final updateType = data['update_type'] as String?;

    if (doctype == null) return;

    final event = RealtimeEvent(
      type: RealtimeEventType.fromString(updateType ?? 'update'),
      doctype: doctype,
      docname: docname,
      data: data['data'] as Map<String, dynamic>?,
      timestamp: DateTime.now(),
    );

    // Notify specific document subscription
    if (docname != null) {
      final specificKey = _getSubscriptionKey(doctype, docname);
      _subscriptions[specificKey]?.add(event);
    }

    // Notify doctype subscription
    final doctypeKey = _getSubscriptionKey(doctype, null);
    _subscriptions[doctypeKey]?.add(event);
  }

  /// Handle custom events
  void _handleEvent(Map<String, dynamic> data) {
    final eventName = data['event'] as String?;
    if (eventName == null) return;

    final event = RealtimeEvent(
      type: RealtimeEventType.customEvent,
      eventName: eventName,
      data: data['data'] as Map<String, dynamic>?,
      timestamp: DateTime.now(),
    );

    final key = 'event:$eventName';
    _subscriptions[key]?.add(event);
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    _updateConnectionState(ConnectionState.error);
    _attemptReconnect();
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    _updateConnectionState(ConnectionState.disconnected);
    _attemptReconnect();
  }

  /// Attempt to reconnect
  void _attemptReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      return;
    }

    _reconnectAttempts++;
    _reconnectTimer = Timer(reconnectInterval, () {
      connect();
    });
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _send({'type': 'ping'});
    });
  }

  /// Update connection state
  void _updateConnectionState(ConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  /// Get subscription key
  String _getSubscriptionKey(String doctype, String? docname) {
    return docname != null ? '$doctype:$docname' : doctype;
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    // Close all subscription controllers
    for (final controller in _subscriptions.values) {
      await controller.close();
    }
    _subscriptions.clear();

    await _connectionStateController.close();
    await disconnect();
  }
}

/// Real-time event from WebSocket
class RealtimeEvent {
  final RealtimeEventType type;
  final String? doctype;
  final String? docname;
  final String? eventName;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  RealtimeEvent({
    required this.type,
    this.doctype,
    this.docname,
    this.eventName,
    this.data,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'RealtimeEvent(type: $type, doctype: $doctype, docname: $docname, '
        'eventName: $eventName, timestamp: $timestamp)';
  }
}

/// Types of real-time events
enum RealtimeEventType {
  insert,
  update,
  delete,
  customEvent;

  static RealtimeEventType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'insert':
        return RealtimeEventType.insert;
      case 'update':
        return RealtimeEventType.update;
      case 'delete':
        return RealtimeEventType.delete;
      default:
        return RealtimeEventType.customEvent;
    }
  }
}

/// WebSocket connection state
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}
