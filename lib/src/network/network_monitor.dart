import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Enum representing connection types
enum ConnectionType {
  wifi,
  mobile,
  ethernet,
  vpn,
  bluetooth,
  other,
  none,
}

/// Enum representing connection quality
enum ConnectionQuality {
  excellent,
  good,
  poor,
  none,
}

/// Class representing network status
class NetworkStatus {
  final bool isConnected;
  final ConnectionType connectionType;
  final ConnectionQuality quality;
  final DateTime timestamp;

  const NetworkStatus({
    required this.isConnected,
    required this.connectionType,
    required this.quality,
    required this.timestamp,
  });

  NetworkStatus copyWith({
    bool? isConnected,
    ConnectionType? connectionType,
    ConnectionQuality? quality,
    DateTime? timestamp,
  }) {
    return NetworkStatus(
      isConnected: isConnected ?? this.isConnected,
      connectionType: connectionType ?? this.connectionType,
      quality: quality ?? this.quality,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'NetworkStatus(isConnected: $isConnected, type: $connectionType, quality: $quality)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkStatus &&
        other.isConnected == isConnected &&
        other.connectionType == connectionType &&
        other.quality == quality;
  }

  @override
  int get hashCode =>
      isConnected.hashCode ^ connectionType.hashCode ^ quality.hashCode;
}

/// Service for monitoring network connectivity in real-time
class NetworkMonitor {
  final Connectivity _connectivity;
  final StreamController<NetworkStatus> _statusController;

  Stream<NetworkStatus> get statusStream => _statusController.stream;
  NetworkStatus? _currentStatus;

  NetworkStatus get currentStatus =>
      _currentStatus ??
      NetworkStatus(
        isConnected: false,
        connectionType: ConnectionType.none,
        quality: ConnectionQuality.none,
        timestamp: DateTime.now(),
      );

  bool get isConnected => currentStatus.isConnected;
  bool get isDisconnected => !isConnected;
  ConnectionType get connectionType => currentStatus.connectionType;

  NetworkMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        _statusController = StreamController<NetworkStatus>.broadcast() {
    _initialize();
  }

  void _initialize() {
    // Check initial connectivity
    _checkConnectivity();

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((results) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );

      final connectionType = _getConnectionType(results);
      final quality = await _estimateQuality(connectionType);

      final status = NetworkStatus(
        isConnected: hasConnection,
        connectionType: connectionType,
        quality: quality,
        timestamp: DateTime.now(),
      );

      // Only emit if status changed
      if (_currentStatus != status) {
        _currentStatus = status;
        _statusController.add(status);
      }
    } catch (e) {
      // In case of error, assume no connection
      final status = NetworkStatus(
        isConnected: false,
        connectionType: ConnectionType.none,
        quality: ConnectionQuality.none,
        timestamp: DateTime.now(),
      );

      if (_currentStatus != status) {
        _currentStatus = status;
        _statusController.add(status);
      }
    }
  }

  ConnectionType _getConnectionType(List<ConnectivityResult> results) {
    if (results.isEmpty || results.first == ConnectivityResult.none) {
      return ConnectionType.none;
    }

    // Return the first (primary) connection type
    switch (results.first) {
      case ConnectivityResult.wifi:
        return ConnectionType.wifi;
      case ConnectivityResult.mobile:
        return ConnectionType.mobile;
      case ConnectivityResult.ethernet:
        return ConnectionType.ethernet;
      case ConnectivityResult.vpn:
        return ConnectionType.vpn;
      case ConnectivityResult.bluetooth:
        return ConnectionType.bluetooth;
      case ConnectivityResult.other:
        return ConnectionType.other;
      case ConnectivityResult.none:
        return ConnectionType.none;
    }
  }

  Future<ConnectionQuality> _estimateQuality(
    ConnectionType connectionType,
  ) async {
    // Basic quality estimation based on connection type
    // In production, you might want to do actual speed tests
    switch (connectionType) {
      case ConnectionType.wifi:
      case ConnectionType.ethernet:
        return ConnectionQuality.excellent;
      case ConnectionType.mobile:
        return ConnectionQuality.good;
      case ConnectionType.vpn:
      case ConnectionType.bluetooth:
      case ConnectionType.other:
        return ConnectionQuality.poor;
      case ConnectionType.none:
        return ConnectionQuality.none;
    }
  }

  /// Perform a more accurate connectivity check
  /// Returns true if we can actually reach the internet
  Future<bool> hasInternetAccess() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Wait for connection to be established
  /// Useful for retrying operations after connection is restored
  Future<void> waitForConnection({Duration? timeout}) async {
    if (isConnected) return;

    final completer = Completer<void>();
    late StreamSubscription<NetworkStatus> subscription;

    subscription = statusStream.listen((status) {
      if (status.isConnected && !completer.isCompleted) {
        completer.complete();
        subscription.cancel();
      }
    });

    if (timeout != null) {
      return completer.future.timeout(
        timeout,
        onTimeout: () {
          subscription.cancel();
          throw TimeoutException('Connection timeout');
        },
      );
    }

    return completer.future;
  }

  /// Refresh connectivity status manually
  Future<NetworkStatus> refresh() async {
    await _checkConnectivity();
    return currentStatus;
  }

  /// Dispose the monitor
  void dispose() {
    _statusController.close();
  }
}

/// Singleton instance for easy access
class NetworkMonitorSingleton {
  static NetworkMonitor? _instance;

  static NetworkMonitor get instance {
    _instance ??= NetworkMonitor();
    return _instance!;
  }

  static void dispose() {
    _instance?.dispose();
    _instance = null;
  }
}
