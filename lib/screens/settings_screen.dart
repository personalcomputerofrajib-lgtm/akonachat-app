import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'privacy_settings_screen.dart';

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildThemeCard(context, AppTheme.light, Icons.light_mode, 'Light'),
                _buildThemeCard(context, AppTheme.dark, Icons.dark_mode, 'Dark'),
                _buildThemeCard(context, AppTheme.cyber, Icons.bolt, 'Cyber'),
              ],
            ),
          ),
          Divider(),
          _buildSectionHeader('Notifications', isDark),
          SwitchListTile(
            title: Text('Sound', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: Text('Play sound for new messages', style: TextStyle(color: Colors.grey)),
            secondary: Icon(Icons.notifications_outlined, color: Colors.blueAccent),
            value: true, 
            onChanged: (val) {
              // Implementation note: This would typically update a SettingsProvider/Service
            },
          ),
          SwitchListTile(
            title: Text('Vibration', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: Text('Vibrate for new messages', style: TextStyle(color: Colors.grey)),
            secondary: Icon(Icons.vibration, color: Colors.blueAccent),
            value: true,
            onChanged: (val) {
              // Implementation note: This would typically update a SettingsProvider/Service
            },
          ),
          Divider(),
          _buildSectionHeader('Account', isDark),
          ListTile(
            leading: Icon(Icons.person_outline, color: Colors.blueAccent),
            title: Text('Profile Settings', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: Colors.blueAccent),
            title: Text('Privacy & Security', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrivacySettingsScreen()),
              );
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

  Widget _buildThemeCard(BuildContext context, AppTheme theme, IconData icon, String label) {
    final themeService = Provider.of<ThemeService>(context);
    final bool isSelected = themeService.currentTheme == theme;
    final bool isDark = themeService.isDarkMode;

    return GestureDetector(
      onTap: () => themeService.setTheme(theme),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                ? (theme == AppTheme.cyber ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.blueAccent.withOpacity(0.1))
                : (isDark ? Colors.grey[800] : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? (theme == AppTheme.cyber ? const Color(0xFF00E5FF) : Colors.blueAccent)
                  : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected && theme == AppTheme.cyber 
                ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 8)]
                : null,
            ),
            child: Icon(
              icon, 
              color: isSelected 
                ? (theme == AppTheme.cyber ? const Color(0xFF00E5FF) : Colors.blueAccent)
                : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected 
                ? (theme == AppTheme.cyber ? const Color(0xFF00E5FF) : Colors.blueAccent)
                : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
