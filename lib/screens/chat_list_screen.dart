import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'user_search_screen.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final AuthService _authService = AuthService();
  List<dynamic> _chats = [];
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    final user = await _authService.loadUser();
    if (user != null) {
      await SocketService().connect();
      final socket = SocketService().socket;
      await _fetchChats();

      // Listen for real-time updates
      socket?.on('receive_message', (data) {
        if (mounted) {
          setState(() {
            final chatId = data['chatId'];
            final index = _chats.indexWhere((c) => c['_id'] == chatId);
            if (index != -1) {
              final chat = _chats.removeAt(index);
              chat['lastMessage'] = data;
              chat['lastSequence'] = data['sequence'];
              // If message is from someone else, it might increase unread count
              // The _fetchChats() below is a safe way to ensure all counts are right
              _chats.insert(0, chat);
            }
            _fetchChats(); // Refresh to get precise unread counts and sorting
          });
        }
      });
      
      socket?.on('message_status', (data) {
        if (mounted) {
          setState(() {
            _fetchChats();
          });
        }
      });

      socket?.on('presence', (data) {
        if (mounted) {
          setState(() {
            final userId = data['userId'];
            final isOnline = data['isOnline'];
            for (var chat in _chats) {
              final participants = chat['participants'] as List;
              for (var p in participants) {
                if (p['_id'] == userId) {
                  p['isOnline'] = isOnline;
                  p['lastSeen'] = data['lastSeen'];
                }
              }
            }
          });
        }
      });
    }
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchChats() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/chats'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _chats = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print('Error fetching chats: $e');
    }
  }

  void _logout() async {
    SocketService().disconnect();
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              currentAccountPicture: Hero(
                tag: 'profilePic',
                child: CircleAvatar(
                  backgroundImage: _currentUser?.profilePic != null && _currentUser!.profilePic.isNotEmpty
                      ? NetworkImage(_currentUser!.profilePic)
                      : null,
                  backgroundColor: Colors.white,
                  child: (_currentUser?.profilePic == null || _currentUser!.profilePic.isEmpty)
                      ? Icon(Icons.person, size: 40, color: Colors.blueAccent)
                      : null,
                ),
              ),
              accountName: Text(
                _currentUser?.name ?? 'User',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_currentUser?.email ?? ''),
            ),
            ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.search),
              title: Text('Find Friends'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserSearchScreen()),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            Spacer(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.redAccent),
              title: Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          'AkonaChat',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchChats,
          )
        ],
      ),
      body: _chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text('No chats yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserSearchScreen())),
                    child: Text('Start a Conversation'),
                  )
                ],
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final lastMsg = chat['lastMessage'];
                int unreadCount = 0;
                if (chat['lastReadBy'] != null) {
                  final myReadInfo = (chat['lastReadBy'] as List).firstWhere(
                    (r) => r['userId'].toString() == _currentUser?.id.toString(),
                    orElse: () => null,
                  );
                  if (myReadInfo != null) {
                    unreadCount = (chat['lastSequence'] ?? 0) - (myReadInfo['lastReadSequence'] ?? 0);
                    if (unreadCount < 0) unreadCount = 0;
                  } else {
                    // If no read info yet, everything is unread
                    unreadCount = chat['lastSequence'] ?? 0;
                  }
                }

                // Robust otherUser selection
                final participants = chat['participants'] as List;
                final otherUser = participants.firstWhere(
                  (p) => p['_id'].toString() != _currentUser?.id.toString(),
                  orElse: () => participants.first,
                );

                return _buildChatTile(
                  chatId: chat['_id'],
                  name: otherUser['name'] ?? 'Unknown',
                  message: lastMsg != null ? lastMsg['ciphertext'] : 'No messages yet',
                  time: chat['lastMessageAt'] != null 
                      ? _formatTime(DateTime.parse(chat['lastMessageAt'])) 
                      : '', 
                  unread: unreadCount,
                  isOnline: otherUser['isOnline'] ?? false,
                  profilePic: otherUser['profilePic'],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserSearchScreen())),
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.edit, color: Colors.white),
        elevation: 4,
      ),
    );
  }

  Widget _buildChatTile({
    required String chatId,
    required String name,
    required String message,
    required String time,
    required int unread,
    required bool isOnline,
    String? profilePic,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatName: name,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  backgroundImage: profilePic != null && profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                  child: profilePic == null || profilePic.isEmpty 
                    ? Text(name[0], style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 20))
                    : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent[400],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(time, style: TextStyle(color: unread > 0 ? Colors.blueAccent : Colors.grey, fontSize: 12, fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: unread > 0 ? Colors.black87 : Colors.grey[600], fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          child: Text(unread.toString(), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${time.day}/${time.month}';
  }
}
