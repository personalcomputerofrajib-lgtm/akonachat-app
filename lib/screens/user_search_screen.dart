import 'package:flutter/material.dart';
import '../services/cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'user_detail_screen.dart';

class UserSearchScreen extends StatefulWidget {
  @override
  _UserSearchScreenState createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String? _startingChatForId; // prevents double-tap

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await _apiService.get('/users/search?q=$encodedQuery');

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

  Future<void> _startChat(UserModel otherUser) async {
    if (_startingChatForId == otherUser.id) return;
    setState(() => _startingChatForId = otherUser.id);
    try {
      final response = await _apiService.post(
        '/chats/private',
        body: {'targetUserId': otherUser.id},
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start chat. Please try again.')),
          );
        }
      }
    } catch (e) {
      print('Chat creation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _startingChatForId = null);
    }
  }

  void _blockUser(String userId) async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.post(
        '/users/block',
        body: {'userIdToBlock': userId},
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

  /// Shows a bottom sheet with actions when a user result is tapped
  void _showUserActions(UserModel user) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              margin: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            // User header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: user.profilePic.isNotEmpty
                        ? CachedNetworkImageProvider(user.profilePic, cacheManager: CustomCacheManager.instance)
                        : null,
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    child: user.profilePic.isEmpty ? Icon(Icons.person, color: Colors.blueAccent) : null,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('@${user.username ?? "user"}', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(),
            // Message action
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
              ),
              title: Text('Message', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Start a conversation'),
              onTap: () {
                Navigator.pop(ctx);
                _startChat(user);
              },
            ),
            // View profile action
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: Icon(Icons.person_outline, color: Colors.black87, size: 20),
              ),
              title: Text('View Profile', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('See their full profile'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserDetailScreen(userId: user.id)),
                );
              },
            ),
            // Block action
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.withOpacity(0.1),
                child: Icon(Icons.block, color: Colors.red, size: 20),
              ),
              title: Text('Block User', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              subtitle: Text('Remove from search results'),
              onTap: () {
                Navigator.pop(ctx);
                _blockUser(user.id);
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
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
                      final bool isStarting = _startingChatForId == user.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profilePic.isNotEmpty
                              ? CachedNetworkImageProvider(user.profilePic, cacheManager: CustomCacheManager.instance)
                              : null,
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
                        trailing: isStarting
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                icon: Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                                tooltip: 'Message',
                                onPressed: () => _startChat(user),
                              ),
                        onTap: () => _showUserActions(user),
                      );
                    },
                  ),
            ),
        ],
      ),
    );
  }
}
