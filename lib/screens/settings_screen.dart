import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      body: ListView(
        children: [
          _buildSectionHeader('Appearance', isDark),
          SwitchListTile(
            title: Text('Dark Mode', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: Text('Toggle dark and light themes', style: TextStyle(color: Colors.grey)),
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Colors.blueAccent),
            value: isDark,
            onChanged: (val) => themeService.toggleTheme(),
          ),
          Divider(),
          _buildSectionHeader('Account', isDark),
          ListTile(
            leading: Icon(Icons.person_outline, color: Colors.blueAccent),
            title: Text('Profile Settings', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () {
              // Navigate to Profile Editing
            },
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: Colors.blueAccent),
            title: Text('Privacy & Security', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () {
              // Navigate to privacy settings
            },
          ),
          Divider(),
          _buildSectionHeader('Chat', isDark),
          ListTile(
            leading: Icon(Icons.color_lens_outlined, color: Colors.blueAccent),
            title: Text('Chat Wallpaper & Colors', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () {
              // TODO: Chat customization
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await AuthService().logout();
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }
}
