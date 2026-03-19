import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../config/constants.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'chat_list_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    final user = await _authService.loadUser();
    if (user != null) {
      setState(() {
        _user = user;
        _nameController.text = user.name;
        _aboutController.text = user.about ?? '';
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        _uploadProfileImage(File(image.path));
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _uploadProfileImage(File file) async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.apiUrl}/media/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _user = UserModel(
            id: _user!.id,
            email: _user!.email,
            name: _user!.name,
            profilePic: data['url'],
            username: _user!.username,
            about: _user!.about,
            hasCompletedOnboarding: _user!.hasCompletedOnboarding,
          );
        });
      }
    } catch (e) {
      print('Upload error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _saveProfile() async {
    final name = _nameController.text.trim();
    final about = _aboutController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Display name cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authService.getToken();
      final response = await http.patch(
        Uri.parse('${Constants.apiUrl}/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'about': about,
          'profilePic': _user?.profilePic,
        }),
      );

      if (response.statusCode == 200) {
        // Update local user data
        final data = jsonDecode(response.body);
        final updatedUser = UserModel.fromJson(data);
        await _authService.updateLocalUser(updatedUser);

        // Success - Go to Chat List
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ChatListScreen()),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['error'] ?? 'Failed to update profile');
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
      appBar: AppBar(
        title: Text('Complete Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: _user?.profilePic != null && _user!.profilePic.isNotEmpty 
                          ? NetworkImage(_user!.profilePic) 
                          : null,
                        child: _user?.profilePic == null || _user!.profilePic.isEmpty 
                          ? Icon(Icons.person, size: 50, color: Colors.blueAccent) 
                          : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _aboutController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'About / Bio',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: 16),
                  Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                ],
                SizedBox(height: 32),
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Get Started', style: TextStyle(fontSize: 16)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
