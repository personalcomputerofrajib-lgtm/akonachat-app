import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({Key? key, required this.chatId, required this.chatName}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  IO.Socket? _socket;
  UserModel? _currentUser;
  final Uuid _uuid = Uuid();

  bool _isOtherUserTyping = false;
  bool _isMeTyping = false;
  DateTime? _lastTypingTime;
  bool? _isOtherUserOnline;
  DateTime? _lastSeen;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initChat();
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_socket == null) return;
    
    if (!_isMeTyping && _messageController.text.isNotEmpty) {
      _isMeTyping = true;
      _socket!.emit('typing', {'chatId': widget.chatId});
    } else if (_isMeTyping && _messageController.text.isEmpty) {
      _isMeTyping = false;
      _socket!.emit('stop_typing', {'chatId': widget.chatId});
    }
    
    _lastTypingTime = DateTime.now();
    Future.delayed(Duration(seconds: 2), () {
      if (_isMeTyping && _lastTypingTime != null && DateTime.now().difference(_lastTypingTime!) >= Duration(seconds: 2)) {
        _isMeTyping = false;
        _socket!.emit('stop_typing', {'chatId': widget.chatId});
      }
    });
  }

  void _initChat() async {
    _currentUser = await AuthService().loadUser();
    _socket = SocketService().socket;

    if (_socket != null) {
      _socket!.emit('join', {'chatId': widget.chatId});
      _syncMessages();

      _socket!.on('receive_message', (data) {
        if (mounted && data['chatId'] == widget.chatId) {
          setState(() {
            final clientMsgId = data['clientMsgId'];
            final existingIndex = _messages.indexWhere(
              (m) => (m['clientMsgId'] == clientMsgId && clientMsgId != null) || m['_id'] == data['_id']
            );

            if (existingIndex != -1) {
              _messages[existingIndex] = data;
            } else {
              _messages.insert(0, data);
            }
            _messages.sort((a, b) {
              final aSeq = a['sequence'] ?? 0;
              final bSeq = b['sequence'] ?? 0;
              return bSeq.compareTo(aSeq);
            });
          });
          _socket!.emit('delivered', {'msgId': data['_id']});
          _socket!.emit('read', {'msgId': data['_id']});
        }
      });

      _socket!.on('sync_messages', (data) {
        if (mounted) {
          final List newlySynced = data as List;
          setState(() {
            for (var msg in newlySynced) {
              if (!_messages.any((m) => m['_id'] == msg['_id'])) {
                _messages.insert(0, msg);
              }
            }
            _messages.sort((a, b) {
              final aSeq = a['sequence'] ?? 0;
              final bSeq = b['sequence'] ?? 0;
              return bSeq.compareTo(aSeq);
            });
          });
        }
      });

      _socket!.on('message_status', (data) {
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m['_id'] == data['msgId']);
            if (index != -1) {
              _messages[index]['status'] = data['status'];
            }
          });
        }
      });

      _socket!.on('user_typing', (data) {
        if (mounted && data['chatId'] == widget.chatId) {
          setState(() => _isOtherUserTyping = true);
        }
      });

      _socket!.on('user_stop_typing', (data) {
        if (mounted && data['chatId'] == widget.chatId) {
          setState(() => _isOtherUserTyping = false);
        }
      });

      _socket!.on('presence', (data) {
        if (mounted && data['userId'] != _currentUser?.id) {
          setState(() {
            _isOtherUserOnline = data['isOnline'];
            _lastSeen = data['lastSeen'] != null ? DateTime.parse(data['lastSeen']) : null;
          });
        }
      });

      _socket!.on('connect', (_) {
        _socket!.emit('join', {'chatId': widget.chatId});
        _syncMessages();
      });
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _syncMessages() {
    if (_socket == null) return;
    int lastSeq = 0;
    if (_messages.isNotEmpty) {
      // Find the highest sequence number among messages that have one
      for (var msg in _messages) {
        if (msg['sequence'] != null && msg['sequence'] > lastSeq) {
          lastSeq = msg['sequence'];
        }
      }
    }
    _socket!.emit('sync', {'chatId': widget.chatId, 'lastSequence': lastSeq});
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    if (_socket == null || _currentUser == null) return;

    final String text = _messageController.text.trim();
    _messageController.clear();

    final String clientMsgId = _uuid.v4();
    final msgData = {
      'chatId': widget.chatId,
      'ciphertext': text,
      'iv': 'base64_iv_placeholder',
      'clientMsgId': clientMsgId,
    };

    _socket!.emit('send_message', msgData);

    setState(() {
      _messages.insert(0, {
        'chatId': widget.chatId,
        'senderId': {'_id': _currentUser!.id},
        'ciphertext': text,
        'clientMsgId': clientMsgId,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'sent'
      });
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        await _uploadMedia(File(image.path));
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _uploadMedia(File file) async {
    if (_socket == null || _currentUser == null) return;
    
    setState(() => _isUploading = true);
    try {
      final token = await AuthService().getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.apiUrl}/media/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['url'];
        
        final String clientMsgId = _uuid.v4();
        final msgData = {
          'chatId': widget.chatId,
          'ciphertext': '[Image]', // Placeholder text for E2EE or display
          'mediaUrl': imageUrl,
          'iv': 'base64_iv_placeholder',
          'clientMsgId': clientMsgId,
        };

        _socket!.emit('send_message', msgData);

        setState(() {
          _messages.insert(0, {
            'chatId': widget.chatId,
            'senderId': {'_id': _currentUser!.id},
            'ciphertext': '[Image]',
            'mediaUrl': imageUrl,
            'clientMsgId': clientMsgId,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'sent'
          });
        });
      }
    } catch (e) {
      print('Upload error: $e');
    } finally {
      setState(() => _isUploading = false);
    }
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
              child: Text(widget.chatName.isNotEmpty ? widget.chatName[0] : 'U', style: TextStyle(color: Colors.blueAccent)),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chatName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  _isOtherUserTyping 
                    ? 'Typing...' 
                    : (_isOtherUserOnline == true ? 'Online' : 'Offline'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOtherUserTyping 
                      ? Colors.blueAccent 
                      : (_isOtherUserOnline == true ? Colors.green[400] : Colors.grey),
                    fontWeight: (_isOtherUserTyping || _isOtherUserOnline == true) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
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
                final isMe = msg['senderId'] != null && msg['senderId']['_id'] == _currentUser?.id;
                
                return _buildMessageBubble(
                  msg['ciphertext'] ?? '', 
                  isMe, 
                  msg['status'] ?? 'sent',
                  msg['mediaUrl'],
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, String status, [String? mediaUrl]) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
              SizedBox(height: 8),
            ],
            Row(
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
                    status == 'sent' ? Icons.check : Icons.done_all,
                    size: 14,
                    color: status == 'read' ? Colors.blue[200] : Colors.white70,
                  )
                ]
              ],
            ),
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
              icon: _isUploading 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.attach_file, color: Colors.blueAccent),
              onPressed: _isUploading ? null : _pickImage,
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
