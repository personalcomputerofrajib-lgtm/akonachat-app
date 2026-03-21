import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'profile_setup_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  @override
  _UsernameSetupScreenState createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _submitUsername() async {
    final username = _usernameController.text.trim();
    
    if (username.length < 5 || username.length > 10) {
      setState(() => _errorMessage = 'Username must be 5-10 characters');
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username.toLowerCase())) {
      setState(() => _errorMessage = 'Only letters, numbers, and underscores allowed');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.post(
        '/users/username',
        body: {'username': username},
      );

      if (response.statusCode == 200) {
        // Update local user data first
        final data = jsonDecode(response.body);
        final updatedUser = UserModel.fromJson(data);
        await _authService.updateLocalUser(updatedUser);

        // Success - Go to Profile Setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfileSetupScreen()),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['error'] ?? 'Failed to set username');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Server error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 48),
              Text(
                'Choose a Username',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This is how others will find you on AkonaChat. (5-10 chars)',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  prefixText: '@',
                  hintText: 'username',
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
              ),
              SizedBox(height: 24),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitUsername,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Complete Setup', style: TextStyle(fontSize: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
