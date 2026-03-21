import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/constants.dart';
import 'auth_service.dart';
import 'message_queue.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  String? _connectionError;
  bool _timeoutOccurred = false;

  /// Reset service state to allow for a fresh connection attempt
  void reset() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _connectionError = null;
    _timeoutOccurred = false;
    print('🔄 Socket service reset');
  }

  /// Connect to Socket.IO server with timeout and error handling
  Future<bool> connect() async {
    _timeoutOccurred = false;
    
    if (_socket != null && _socket!.connected) {
      _isConnected = true;
      return true;
    }

    final token = await AuthService().getToken();
    if (token == null) {
      _connectionError = 'No authentication token found';
      return false;
    }

    try {
      _socket = IO.io(Constants.serverUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': false,
        'forceNew': true,
        'auth': {'token': token},
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'reconnectionAttempts': 5,
      });

      // Setup event listeners BEFORE connecting
      _setupEventListeners();

      // Connect with timeout
      final completer = Completer<bool>();
      
      // Timeout after 5 seconds
      final timeoutTimer = Timer(Duration(seconds: 5), () {
        if (!completer.isCompleted && !_timeoutOccurred) {
          _timeoutOccurred = true;
          _connectionError = 'Socket connection timeout (5s)';
          _socket?.disconnect();
          completer.complete(false);
          print('⏰ Socket connection timeout (5s)');
        }
      });

      // Listen for connection success
      _socket!.onConnect((_) {
        if (!completer.isCompleted && !_timeoutOccurred) {
          timeoutTimer.cancel();
          _isConnected = true;
          _connectionError = null;
          print('✅ Socket Connected: ${_socket!.id}');
          completer.complete(true);
        }
      });

      // Listen for connection error
      _socket!.onConnectError((error) {
        if (!completer.isCompleted && !_timeoutOccurred) {
          timeoutTimer.cancel();
          _isConnected = false;
          _connectionError = 'Connection error: $error';
          print('❌ Socket Connection Error: $error');
          completer.complete(false);
        }
      });

      _socket!.connect();
      
      final success = await completer.future;
      return success;
    } catch (e) {
      _connectionError = 'Socket initialization error: $e';
      _isConnected = false;
      print('❌ Socket Error: $e');
      return false;
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('⚠️ Socket Disconnected');
    });

    _socket!.on('error', (error) {
      _connectionError = 'Socket error: $error';
      print('❌ Socket Error: $error');
    });

    _socket!.on('disconnect', (data) {
      _isConnected = false;
      print('⚠️ Socket Disconnected: $data');
    });

    _socket!.on('connect_error', (error) {
      _connectionError = 'Connection error: $error';
      print('❌ Socket Connect Error: $error');
    });

    _socket!.on('connect', (_) {
      print('✅ Socket Connected Event - Processing Queue');
      MessageQueue().processQueue();
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }

  IO.Socket? get socket => _socket;
  bool get isConnected => _isConnected;
  String? get lastError => _connectionError;
}
