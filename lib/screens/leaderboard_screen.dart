import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../services/auth_service.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final AuthService _authService = AuthService();
  List<dynamic> _topUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/engagement/leaderboard'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _topUsers = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('BUddY Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchLeaderboard,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _topUsers.length,
                itemBuilder: (context, index) {
                  final user = _topUsers[index];
                  return _buildLeaderboardTile(index + 1, user);
                },
              ),
            ),
    );
  }

  Widget _buildLeaderboardTile(int rank, Map<String, dynamic> user) {
    Color rankColor;
    if (rank == 1) rankColor = Colors.amber;
    else if (rank == 2) rankColor = Colors.grey[400]!;
    else if (rank == 3) rankColor = Colors.brown[300]!;
    else rankColor = Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: rank <= 3 ? Border.all(color: rankColor, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: rank <= 3 ? rankColor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  color: rank <= 3 ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 25,
            backgroundImage: user['profilePic'] != null && user['profilePic'].isNotEmpty
                ? CachedNetworkImageProvider(user['profilePic'])
                : null,
            child: user['profilePic'] == null || user['profilePic'].isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '@${user['username'] ?? "user"}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.orange, size: 18),
              Text(
                '${user['giftCount'] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const Text('Popularity', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
