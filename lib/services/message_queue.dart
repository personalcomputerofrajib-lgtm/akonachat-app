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
        _socketService.socket?.emit('send_message', msg);
      }
    } catch (e) {
      print('Error processing message queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Clear all pending messages — must be called on logout so stale
  /// encrypted payloads from the old account are never re-sent.
  Future<void> clear() async {
    try {
      await _db.clearPendingMessages();
      print('🗑️ MessageQueue cleared on logout');
    } catch (e) {
      print('Error clearing message queue: $e');
    }
  }
}
