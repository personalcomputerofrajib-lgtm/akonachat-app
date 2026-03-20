import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  @override
  _UserSearchScreenState createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  List<UserModel> _searchResults = [];
  bool _isLoading = false;

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/users/search?q=$query'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _searchResults = data.map((u) => UserModel.fromJson(u)).toList();
        });
      }
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startChat(UserModel otherUser) async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/chats/private'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'targetUserId': otherUser.id}),
      );

      if (response.statusCode == 200) {
        final chatData = jsonDecode(response.body);
        final String chatId = chatData['_id'];
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatName: otherUser.name,
            ),
          ),
        );
      }
    } catch (e) {
      print('Chat creation error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _blockUser(String userId) async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/users/block'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userIdToBlock': userId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _searchResults.removeWhere((u) => u.id == userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User blocked')));
      }
    } catch (e) {
      print('Block error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Find Friends'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or @username...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _searchUsers,
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator()
          else
            Expanded(
              child: _searchResults.isEmpty && !_isLoading && _searchController.text.isNotEmpty
                ? Center(child: Text('No users found', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profilePic.isNotEmpty ? NetworkImage(user.profilePic) : null,
                          backgroundColor: Colors.blueAccent.withOpacity(0.1),
                          child: user.profilePic.isEmpty ? Icon(Icons.person, color: Colors.blueAccent) : null,
                        ),
                        title: Text(user.name, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${user.username ?? "user"}', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
                            if (user.about != null && user.about!.isNotEmpty)
                              Text(
                                user.about!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        isThreeLine: user.about != null && user.about!.isNotEmpty,
                        trailing: IconButton(
                          icon: Icon(Icons.block, color: Colors.grey),
                          onPressed: () => _blockUser(user.id),
                        ),
                        onTap: () => _startChat(user),
                      );
                    },
                  ),
            ),
        ],
      ),
    );
  }
}
