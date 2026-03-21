import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'services/security_service.dart';
import 'services/database_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/username_setup_screen.dart';
import 'screens/main_tabs_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'models/user_model.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const AkonaChatApp(),
    ),
  );
}

class AkonaChatApp extends StatelessWidget {
  const AkonaChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return MaterialApp(
      title: 'AkonaChat',
      debugShowCheckedModeBanner: false,
      theme: themeService.themeData,
      themeMode: ThemeMode.light, // Handled by themeData now
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _initError;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    try {
      final user = await _authService.loadUser();
      
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });

        if (user != null) {
          // Non-blocking background initializations
          SecurityService().initializeKeys().catchError((e) => print('Security init ignored: $e'));
          _authService.claimDailyReward();
        }
      }
    } catch (e) {
      print('Auth check failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _user = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Starting AkonaChat...', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 8),
              Text('Securing your connection...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                SizedBox(height: 24),
                Text('Initialization Failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text(_initError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _checkAuth,
                  child: Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _initError = null),
                  child: Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (_user == null) {
      return LoginScreen();
    }

    // Check if username is missing
    if (_user!.username == null || _user!.username!.isEmpty) {
      return UsernameSetupScreen();
    }

    return MainTabsScreen();
  }
}
