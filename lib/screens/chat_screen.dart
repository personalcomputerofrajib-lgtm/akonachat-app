import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String chatName;

  const ChatScreen({Key? key, required this.chatName}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  IO.Socket? _socket;
  UserModel? _currentUser;
  final String _mockChatId = "60d5ecb8b392d7001f8e4c12"; // Placeholder
  final Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() async {
    _currentUser = await AuthService().loadUser();
    _socket = SocketService().socket;

    if (_socket != null) {
      _socket!.on('receive_message', (data) {
        if (mounted) {
          setState(() {
            _messages.insert(0, data);
          });
        }
      });
      // Placeholder: emit join room or similar if backend requires explicit join beyond default
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    if (_socket == null || _currentUser == null) return;

    final String text = _messageController.text.trim();
    _messageController.clear();

    // In a real E2EE environment, this text would be encrypted with Signal Protocol here.
    // For MVP frontend placeholder, we send plaintext pretending it's ciphertext to match backend schema.
    final msgData = {
      'chatId': _mockChatId,
      'ciphertext': text, // Placeholder
      'iv': 'base64_iv_placeholder',
      'clientMsgId': _uuid.v4(),
    };

    _socket!.emit('send_message', msgData);

    // Optimistically add to UI
    setState(() {
      _messages.insert(0, {
        'senderId': {'_id': _currentUser!.id},
        'ciphertext': text,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'sent'
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              child: Text(widget.chatName[0], style: TextStyle(color: Colors.blueAccent)),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chatName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Online', style: TextStyle(fontSize: 12, color: Colors.greenAccent[400], fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.call), onPressed: () {}),
          IconButton(icon: Icon(Icons.videocam), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['senderId']['_id'] == _currentUser?.id;
                
                return _buildMessageBubble(
                  msg['ciphertext'], 
                  isMe, 
                  msg['status'] ?? 'sent'
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, String status) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
            if (isMe) ...[
              SizedBox(width: 4),
              Icon(
                status == 'read' ? Icons.done_all : Icons.check,
                size: 14,
                color: status == 'read' ? Colors.blue[200] : Colors.white70,
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          )
        ]
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.attach_file, color: Colors.blueAccent),
              onPressed: () {},
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: null,
                ),
              ),
            ),
            SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
