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
import 'dart:convert';
import 'user_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'media_gallery_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({Key? key, required this.chatId, required this.chatName}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;

  UserModel? _otherUser;
  
  Color _themeColor = Colors.blueAccent;
  String? _wallpaperUrl;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    final user = await AuthService().loadUser();
    _socket = SocketService().socket;
    
    // Fetch other user details (bio, username, etc.)
    try {
      final token = await AuthService().getToken();
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/chats/${widget.chatId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final chatData = jsonDecode(response.body);
        final List participants = chatData['participants'];
        final other = participants.firstWhere((p) => p['_id'] != user?.id, orElse: () => null);
        if (other != null) {
          setState(() {
            _otherUser = UserModel.fromJson(other);
            _isOtherUserOnline = _otherUser?.isOnline;
            _lastSeen = _otherUser?.lastSeen;
            if (chatData['themeColor'] != null) {
              try {
                _themeColor = Color(int.parse(chatData['themeColor'].replaceAll('#', '0xFF')));
              } catch (e) {
                _themeColor = Colors.blueAccent;
              }
            }
            _wallpaperUrl = chatData['wallpaperUrl'];
          });
        }
      }
    } catch (e) {
      print('Error fetching chat details: $e');
    }

    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }

    if (_socket != null) {
      _socket!.emit('join', {'chatId': widget.chatId});
      _socket!.emit('read_chat', {'chatId': widget.chatId});
      _syncMessages();

      _socket!.on('receive_message', (data) {
      if (mounted && data['chatId'] == widget.chatId) {
        setState(() {
          // Deduplication: Check if we already have this message (optimistic UI)
          final String? clientMsgId = data['clientMsgId'];
          if (clientMsgId != null) {
            final existingIndex = _messages.indexWhere((m) => m['clientMsgId'] == clientMsgId);
            if (existingIndex != -1) {
              // Update existing local message with server data
              _messages[existingIndex]['_id'] = data['_id'];
              _messages[existingIndex]['status'] = data['status'] ?? 'sent';
              _messages[existingIndex]['sequence'] = data['sequence'];
              // IMPORTANT: Update senderId from server to ensure it's accurate and populated
              _messages[existingIndex]['senderId'] = data['senderId'];
              return;
            }
          }

          // If it's from me but didn't have a matching clientMsgId (unlikely but safe)
          // or if it's from the other user, add it to the list.
          _messages.insert(0, data);
          _scrollToBottom();
        });
        
        // Mark entire chat as read so our lastReadBy sequence stays current.
        // This prevents a false unread badge when returning to the chat list.
        _socket!.emit('read_chat', {'chatId': widget.chatId});
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

      _socket!.on('message_deleted_everyone', (data) {
        if (mounted && data['chatId'] == widget.chatId) {
          setState(() {
            final index = _messages.indexWhere((m) => m['_id'] == data['msgId']);
            if (index != -1) {
              _messages[index]['isDeletedEveryone'] = true;
              _messages[index]['ciphertext'] = 'This message was deleted';
              _messages[index]['mediaUrl'] = null;
              _messages[index]['type'] = 'text';
            }
          });
        }
      });

      _socket!.on('message_deleted_me', (data) {
        if (mounted && data['chatId'] == widget.chatId) {
          setState(() {
            _messages.removeWhere((m) => m['_id'] == data['msgId']);
          });
        }
      });

      _socket!.on('message_edited', (data) {
        if (mounted && data['chatId'] == widget.chatId) {
          setState(() {
            final index = _messages.indexWhere((m) => m['_id'] == data['msgId']);
            if (index != -1) {
              _messages[index]['ciphertext'] = data['newText'];
              _messages[index]['isEdited'] = true;
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

      _socket!.on('message_reaction_updated', (data) {
        if (mounted && data['chatId'] == widget.chatId) {
          setState(() {
            final index = _messages.indexWhere((m) => m['_id'] == data['msgId']);
            if (index != -1) {
              _messages[index]['reactions'] = data['reactions'];
            }
          });
        }
      });

      _socket!.on('chat_settings_updated', (data) {
        if (mounted && data['chatId'] == widget.chatId) {
          setState(() {
            if (data['themeColor'] != null) {
              try {
                _themeColor = Color(int.parse(data['themeColor'].replaceAll('#', '0xFF')));
              } catch (e) {
                _themeColor = Colors.blueAccent;
              }
            }
            _wallpaperUrl = data['wallpaperUrl'];
          });
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
    _scrollController.dispose();
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
      _scrollToBottom();
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _recordingPath = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig();
        await _audioRecorder.start(config, path: _recordingPath!);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      print('Start recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await _uploadVoice(File(path));
      }
    } catch (e) {
      print('Stop recording error: $e');
    }
  }

  Future<void> _uploadVoice(File file) async {
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
        final voiceUrl = data['url'];
        
        final String clientMsgId = _uuid.v4();
        _socket!.emit('send_message', {
          'chatId': widget.chatId,
          'type': 'voice',
          'mediaUrl': voiceUrl,
          'ciphertext': '[Voice Message]',
          'iv': 'voice_iv_placeholder',
          'clientMsgId': clientMsgId,
        });

        setState(() {
          _messages.insert(0, {
            'chatId': widget.chatId,
            'senderId': {'_id': _currentUser!.id},
            'type': 'voice',
            'mediaUrl': voiceUrl,
            'ciphertext': '[Voice Message]',
            'clientMsgId': clientMsgId,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'sent'
          });
          _scrollToBottom();
        });
      }
    } catch (e) {
      print('Voice upload error: $e');
    } finally {
      setState(() => _isUploading = false);
    }
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
          _scrollToBottom();
        });
      }
    } catch (e) {
      print('Upload error: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }
  
  void _showOptions(Map<String, dynamic> msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '😮', '😢', '🙏', '👍'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    _socket!.emit('add_reaction', {'msgId': msg['_id'], 'emoji': emoji});
                    Navigator.pop(context);
                  },
                  child: Text(emoji, style: TextStyle(fontSize: 24)),
                );
              }).toList(),
            ),
          ),
          Divider(),
          if (isMe && !(msg['isDeletedEveryone'] == true)) ...[              title: Text('Edit Message'),
              onTap: () {
                Navigator.pop(context);
                _editMessagePrompt(msg);
              },
            ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete for Me'),
            onTap: () {
              Navigator.pop(context);
              _deleteMessage(msg['_id'], false);
            },
          ),
          if (isMe && !(msg['isDeletedEveryone'] == true))
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Delete for Everyone'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(msg['_id'], true);
              },
            ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  void _deleteMessage(String? msgId, bool everyone) {
    if (msgId == null || _socket == null) return;
    _socket!.emit('delete_message', {'msgId': msgId, 'everyone': everyone});
  }

  void _editMessagePrompt(Map<String, dynamic> msg) {
    final TextEditingController editController = TextEditingController(text: msg['ciphertext']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(hintText: "Enter new message"),
          maxLines: null,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != msg['ciphertext']) {
                _editMessage(msg['_id'], newText);
              }
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editMessage(String? msgId, String newText) {
    if (msgId == null || _socket == null) return;
    _socket!.emit('edit_message', {'msgId': msgId, 'newText': newText});
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // Scroll to the top (because ListView is reversed)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'Last seen just now';
    if (difference.inMinutes < 60) return 'Last seen ${difference.inMinutes}m ago';
    if (difference.inHours < 24) return 'Last seen ${difference.inHours}h ago';
    if (difference.inDays < 7) return 'Last seen ${DateFormat('EEEE').format(lastSeen)}';
    return 'Last seen ${DateFormat('MMM d').format(lastSeen)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            )
          : GestureDetector(
          onTap: () {
            if (_otherUser != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserDetailScreen(user: _otherUser!)),
              );
            }
          },
          child: Row(
            children: [
              Hero(
                tag: 'profile_pic_${_otherUser?.id ?? widget.chatId}',
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  backgroundImage: _otherUser?.profilePic != null && _otherUser!.profilePic!.isNotEmpty
                      ? CachedNetworkImageProvider(_otherUser!.profilePic!)
                      : null,
                  child: (_otherUser?.profilePic == null || _otherUser!.profilePic!.isEmpty)
                      ? Text(widget.chatName.isNotEmpty ? widget.chatName[0] : 'U', 
                        style: TextStyle(color: Colors.blueAccent, fontSize: 14))
                      : null,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.chatName, 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _isOtherUserTyping 
                        ? 'typing...' 
                        : (_isOtherUserOnline == true ? 'Online' : _formatLastSeen(_lastSeen)),
                      style: TextStyle(
                        fontSize: 11,
                        color: _isOtherUserOnline == true || _isOtherUserTyping ? Colors.green : Colors.grey,
                        fontWeight: (_isOtherUserOnline == true || _isOtherUserTyping) ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        elevation: 0.5,
        actions: [
          if (_isSearching)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              }),
            )
          else
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
          IconButton(
            icon: Icon(Icons.palette_outlined),
            onPressed: _showCustomizationMenu,
          ),
          IconButton(icon: Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.grey[50],
          image: _wallpaperUrl != null && _wallpaperUrl!.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(_wallpaperUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.1),
                  BlendMode.darken,
                ),
              )
            : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: EdgeInsets.all(16),
                itemCount: _isSearching && _searchQuery.isNotEmpty 
                  ? _messages.where((m) => (m['ciphertext'] ?? '').toString().toLowerCase().contains(_searchQuery)).length
                  : _messages.length,
                itemBuilder: (context, index) {
                  final filteredMessages = _isSearching && _searchQuery.isNotEmpty
                    ? _messages.where((m) => (m['ciphertext'] ?? '').toString().toLowerCase().contains(_searchQuery)).toList()
                    : _messages;
                  
                  final msg = filteredMessages[index];
                  final String currentUserId = _currentUser?.id ?? '';

                  // Filter out "Delete for Me" messages
                  final List? deletedFor = msg['isDeletedFor'];
                  if (deletedFor != null && deletedFor.any((id) => id.toString() == currentUserId)) {
                    return SizedBox.shrink();
                  }
                  
                  // Extract senderId
                  final dynamic senderIdRaw = msg['senderId'];
                  String msgSenderId = '';
                  if (senderIdRaw is Map) {
                    msgSenderId = (senderIdRaw['_id'] ?? senderIdRaw['id'] ?? '').toString();
                  } else if (senderIdRaw != null) {
                    msgSenderId = senderIdRaw.toString();
                  }

                  final bool isMe = msgSenderId.isNotEmpty &&
                      currentUserId.isNotEmpty &&
                      msgSenderId.toString().toLowerCase().trim() == currentUserId.toString().toLowerCase().trim();
                  
                  return GestureDetector(
                    onLongPress: () => _showOptions(msg, isMe),
                    child: _buildMessageBubble(
                      msg['isDeletedEveryone'] == true ? 'This message was deleted' : (msg['ciphertext'] ?? ''), 
                      isMe, 
                      msg['status'] ?? 'sent',
                      msg['isDeletedEveryone'] == true ? null : msg['mediaUrl'],
                      msg['isEdited'] ?? false,
                      msg['reactions'],
                      msg['type'] ?? 'text',
                    ),
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  void _showCustomizationMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('Theme Color', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Colors.blueAccent,
                Colors.greenAccent,
                Colors.purpleAccent,
                Colors.orangeAccent,
                Colors.pinkAccent,
                Colors.tealAccent,
              ].map((color) => GestureDetector(
                onTap: () {
                  final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                  _socket!.emit('update_chat_settings', {'chatId': widget.chatId, 'themeColor': hex});
                  Navigator.pop(context);
                },
                child: CircleAvatar(backgroundColor: color, radius: 20),
              )).toList(),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: Text('Media Gallery'),
              onTap: () {
                Navigator.pop(context);
                final imageUrls = _messages
                  .where((m) => m['type'] == 'image' && m['mediaUrl'] != null)
                  .map<String>((m) => m['mediaUrl'].toString())
                  .toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MediaGalleryScreen(imageUrls: imageUrls, chatName: widget.chatName),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.image_outlined),
              title: Text('Change Wallpaper'),
              onTap: () {
                Navigator.pop(context);
                _pickWallpaper();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickWallpaper() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() => _isUploading = true);
        final token = await AuthService().getToken();
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${Constants.apiUrl}/media/upload'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(await http.MultipartFile.fromPath('file', image.path));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final wallpaperUrl = data['url'];
          _socket!.emit('update_chat_settings', {'chatId': widget.chatId, 'wallpaperUrl': wallpaperUrl});
        }
      }
    } catch (e) {
      print('Wallpaper upload error: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildMessageBubble(String text, bool isMe, String status, [String? mediaUrl, bool isEdited = false, List? reactions, String type = 'text']) {
    if (text.isEmpty && (mediaUrl == null || mediaUrl.isEmpty)) return SizedBox.shrink();
    
    final bool isDeleted = text == 'This message was deleted';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 4, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? _themeColor : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100]),
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
                if (type == 'voice' && mediaUrl != null)
                  _VoicePlayer(url: mediaUrl, isMe: isMe)
                else if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        mediaUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
                if (text.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : (isDeleted ? Colors.grey : Colors.black87),
                            fontSize: 16,
                            fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (isEdited && !isDeleted) ...[
                        SizedBox(width: 4),
                        Text(
                          '(edited)',
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
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
              ],
            ),
          ),
          if (reactions != null && reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8, left: isMe ? 0 : 8, right: isMe ? 8 : 0),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: reactions.map<Widget>((r) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                    ),
                    child: Text(r['emoji'] ?? '', style: TextStyle(fontSize: 13)),
                  );
                }).toList(),
              ),
            ),
        ],
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
              child: _isRecording
                ? Container(
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mic, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Recording...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Spacer(),
                        TextButton(
                          onPressed: () {
                            _audioRecorder.stop();
                            setState(() => _isRecording = false);
                          },
                          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                        )
                      ],
                    ),
                  )
                : Container(
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
                color: _isRecording ? Colors.red : Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: _messageController.text.isEmpty && !_isRecording
                ? GestureDetector(
                    onLongPress: _startRecording,
                    onLongPressUp: _stopRecording,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(Icons.mic, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: Icon(_isRecording ? Icons.send : Icons.send, color: Colors.white),
                    onPressed: _isRecording ? _stopRecording : _sendMessage,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePlayer extends StatefulWidget {
  final String url;
  final bool isMe;
  const _VoicePlayer({Key? key, required this.url, required this.isMe}) : super(key: key);

  @override
  _VoicePlayerState createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerComplete.listen((_) => setState(() => _isPlaying = false));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: widget.isMe ? Colors.white : Colors.blueAccent),
          onPressed: _togglePlay,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
        SizedBox(width: 8),
        Text(
          "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / ${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}",
          style: TextStyle(color: widget.isMe ? Colors.white70 : Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}
