import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

class BlockedUsersScreen extends StatefulWidget {
  @override
  _BlockedUsersScreenState createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    try {
      final response = await _apiService.get('/users/blocked');
      if (response.statusCode == 200) {
        setState(() {
          _blockedUsers = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching blocked users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      final response = await _apiService.post('/users/unblock', body: {'userId': userId});
      if (response.statusCode == 200) {
        setState(() {
          _blockedUsers.removeWhere((user) => user['_id'] == userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User unblocked'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unblock user'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Blocked Users'),
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 80, color: Colors.grey[300]),
                      SizedBox(height: 16),
                      Text('No blocked users', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user['profilePic'] != null && user['profilePic'].isNotEmpty
                            ? CachedNetworkImageProvider(user['profilePic'])
                            : null,
                        child: (user['profilePic'] == null || user['profilePic'].isEmpty)
                            ? Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user['name'] ?? 'Unknown', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      subtitle: Text(user['username'] ?? '', style: TextStyle(color: Colors.grey)),
                      trailing: TextButton(
                        onPressed: () => _unblockUser(user['_id']),
                        child: Text('UNBLOCK', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }
}
