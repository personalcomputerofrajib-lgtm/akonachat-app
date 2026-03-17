import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const AkonaChatApp());
}

class AkonaChatApp extends StatelessWidget {
  const AkonaChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AkonaChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Inter', // We can add fonts later, defaults to system sans
      ),
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
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    final user = await _authService.loadUser();
    if (mounted) {
      setState(() {
        _isAuthenticated = user != null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _isAuthenticated ? ChatListScreen() : LoginScreen();
  }
}
