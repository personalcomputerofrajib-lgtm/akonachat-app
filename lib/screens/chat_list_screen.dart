import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    final user = await _authService.loadUser();
    if (user != null) {
      await SocketService().connect();
    }
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                // Show profile settings or logout
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => Container(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: _currentUser?.profilePic != null
                              ? NetworkImage(_currentUser!.profilePic)
                              : null,
                        ),
                        SizedBox(height: 16),
                        Text(_currentUser?.name ?? 'User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(_currentUser?.email ?? '', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.logout),
                          label: Text('Log out'),
                        )
                      ],
                    ),
                  ),
                );
              },
              child: Hero(
                tag: 'profilePic',
                child: CircleAvatar(
                  backgroundImage: _currentUser?.profilePic != null
                      ? NetworkImage(_currentUser!.profilePic)
                      : null,
                  backgroundColor: Colors.grey[200],
                  child: _currentUser?.profilePic == null ? Icon(Icons.person, color: Colors.grey) : null,
                ),
              ),
            ),
          )
        ],
      ),
      body: ListView.builder(
        itemCount: 1, // Placeholder
        itemBuilder: (context, index) {
          // Placeholder for the Empty State or Demo Chat
          return _buildChatTile(
            name: 'Akona Support',
            message: 'Welcome to AkonaChat! We are setting up your secure environment.',
            time: 'Now',
            unread: 1,
            isOnline: true,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open new chat search
        },
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.edit, color: Colors.white),
        elevation: 4,
      ),
    );
  }

  Widget _buildChatTile({
    required String name,
    required String message,
    required String time,
    required int unread,
    required bool isOnline,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(chatName: name)),
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
                  child: Text(name[0], style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 20)),
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
}
