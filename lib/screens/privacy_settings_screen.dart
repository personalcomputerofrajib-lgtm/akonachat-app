import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'blocked_users_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  @override
  _PrivacySettingsScreenState createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _showLastSeen = true;
  bool _showReadReceipts = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPrivacySettings();
  }

  Future<void> _fetchPrivacySettings() async {
    try {
      final response = await _apiService.get('/users/me');
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final settings = userData['privacySettings'];
        if (settings != null) {
          setState(() {
            _showLastSeen = settings['showLastSeen'] ?? true;
            _showReadReceipts = settings['showReadReceipts'] ?? true;
          });
        }
      }
    } catch (e) {
      print('Error fetching privacy settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrivacy(String key, bool value) async {
    setState(() {
      if (key == 'showLastSeen') _showLastSeen = value;
      if (key == 'showReadReceipts') _showReadReceipts = value;
    });

    try {
      await _apiService.patch('/users/privacy', body: {key: value});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update settings'))
      );
      // Revert on failure
      setState(() {
        if (key == 'showLastSeen') _showLastSeen = !value;
        if (key == 'showReadReceipts') _showReadReceipts = !value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy'),
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Privacy Settings'),
                SwitchListTile(
                  title: Text('Last Seen', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text('Show others when you were last online', style: TextStyle(color: Colors.grey)),
                  secondary: Icon(Icons.timer_outlined, color: Colors.blueAccent),
                  value: _showLastSeen,
                  onChanged: (val) => _updatePrivacy('showLastSeen', val),
                ),
                SwitchListTile(
                  title: Text('Read Receipts', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text('If turned off, you won\'t send or receive read receipts', style: TextStyle(color: Colors.grey)),
                  secondary: Icon(Icons.done_all, color: Colors.blueAccent),
                  value: _showReadReceipts,
                  onChanged: (val) => _updatePrivacy('showReadReceipts', val),
                ),
                Divider(),
                _buildSectionHeader('Advanced'),
                ListTile(
                  leading: Icon(Icons.block, color: Colors.redAccent),
                  title: Text('Blocked Users', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text('Manage users you have blocked', style: TextStyle(color: Colors.grey)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BlockedUsersScreen()),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
      ),
    );
  }
}
