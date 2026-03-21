import 'package:flutter/material.dart';
import '../services/cache_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/constants.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'chat_list_screen.dart';

import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _authService = AuthService();
  final _apiService = ApiService();
  
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final user = await _authService.getUser();
    setState(() => _user = user);
    if (user != null) {
      _nameController.text = user.name;
      _aboutController.text = user.about;
    }
  }

  Future<void> _pickImage() async {
    // Check permission based on platform/version
    if (Platform.isAndroid) {
      // For Android 13 (SDK 33) and above, we use photos permission
      // For below, we use storage
      final status = await Permission.photos.status;
      if (status.isDenied) {
        final result = await Permission.photos.request();
        if (result.isPermanentlyDenied) {
          _showPermissionDialog();
          return;
        }
        if (!result.isGranted) return;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isDenied || status.isLimited) {
        final result = await Permission.photos.request();
        if (!result.isGranted && !result.isLimited) return;
      }
    }

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

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Needed'),
        content: Text('AkonaChat needs access to your photos to set a profile picture. Please enable it in settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Settings'),
          ),
        ],
      ),
    );
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
      
      // Explicitly set content type to help backend multer/mime checks
      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        file.path,
        // Optional: you can add MediaType here if you import 'package:http_parser/http_parser.dart';
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          final imageUrl = "${data['url']}?t=${DateTime.now().millisecondsSinceEpoch}";
          _user = UserModel(
            id: _user!.id,
            email: _user!.email,
            name: _user!.name,
            profilePic: imageUrl,
            username: _user!.username,
            about: _user!.about,
            hasCompletedOnboarding: _user!.hasCompletedOnboarding,
          );
        });
      }
    } catch (e) {
      print('Upload error: $e');
      setState(() => _errorMessage = 'Server error during upload. Please try again.');
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
    if (name.length > 50) {
      setState(() => _errorMessage = 'Display name cannot exceed 50 characters');
      return;
    }
    if (about.length > 150) {
      setState(() => _errorMessage = 'About / Bio cannot exceed 150 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.patch(
        '/users/profile',
        body: {
          'name': name,
          'about': about,
          'profilePic': _user?.profilePic,
        },
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
                          ? CachedNetworkImageProvider(_user!.profilePic, cacheManager: CustomCacheManager.instance) 
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
                  maxLength: 50,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  ],
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
                  maxLength: 200,
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
