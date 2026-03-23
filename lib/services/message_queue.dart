import 'dart:async';
import 'database_service.dart';
import 'socket_service.dart';

class MessageQueue {
  static final MessageQueue _instance = MessageQueue._internal();
  factory MessageQueue() => _instance;
  MessageQueue._internal();

  final DatabaseService _db = DatabaseService();
  final SocketService _socketService = SocketService();
  bool _isProcessing = false;

  /// Add a message to the outgoing queue (local DB)
  Future<void> enqueue(Map<String, dynamic> message) async {
    // Add pending status if not present
    final pendingMsg = {...message, 'status': 'pending'};
    await _db.saveMessage(pendingMsg);
    processQueue();
  }

  /// Process pending messages in the background
  Future<void> processQueue() async {
    if (_isProcessing || !_socketService.isConnected) return;
    _isProcessing = true;

    try {
      final pendingMessages = await _db.getPendingMessages();
      for (var msg in pendingMessages) {
        if (!_socketService.isConnected) break;

        // Emit via socket
        _socketService.socket?.emit('send_message', msg);
        
        // Let the 'receive_message' event update the local status to 'sent'
        // once the backend has actually stored it. This prevents fake delivery statuses.
      }
    } catch (e) {
      print('Error processing message queue: $e');
    } finally {
      _isProcessing = false;
    }
  }
}
