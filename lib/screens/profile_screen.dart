import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../config/constants.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../widgets/profile_dashboard_box.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _signatureController = TextEditingController();
  final _gameIdController = TextEditingController();
  
  UserModel? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();
  String _selectedBannerCategory = 'Gaming';

  final Map<String, List<Map<String, String>>> _bannerCategories = {
    'Gaming': [
      {'name': 'PUBG', 'url': 'http://52.66.216.152:9000/static/pubg_banner.jpg'},
      {'name': 'BGMI', 'url': 'http://52.66.216.152:9000/static/bgmi_banner.jpg'},
      {'name': 'Free Fire', 'url': 'http://52.66.216.152:9000/static/free_fire_banner.jpg'},
      {'name': 'COD', 'url': 'http://52.66.216.152:9000/static/call_of_duty.jpg'},
    ],
    'Naruto': List.generate(8, (i) => {
      'name': 'Naruto ${i + 1}',
      'url': 'http://52.66.216.152:9000/static/naruto/BANNER ${i + 1}${i == 0 ? ".PNG" : ".jpg"}'
    }),
    'Dragon Ball': List.generate(10, (i) => {
      'name': 'DB ${i + 1}',
      'url': 'http://52.66.216.152:9000/static/dragonball/BANNER ${i + 1} OF DRAGON BALL.jpg'
    }),
    'One Piece': List.generate(5, (i) => {
      'name': 'OP ${i + 1}',
      'url': 'http://52.66.216.152:9000/static/onepiece/BANNER ${i + 1} OF ONE PIECE.jpg'
    }),
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = await _authService.loadUser();
    setState(() {
      _user = user;
      if (user != null) {
        _nameController.text = user.name;
        _usernameController.text = user.username ?? '';
        _aboutController.text = user.about ?? '';
        _signatureController.text = user.signature ?? '';
        _gameIdController.text = user.gameId ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _updateBanner(String bannerUrl) async {
    setState(() => _isSaving = true);
    try {
      final token = await _authService.getToken();
      final response = await http.patch(
        Uri.parse('${Constants.apiUrl}/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'profileBanner': bannerUrl}),
      );

      if (response.statusCode == 200) {
        final updatedUser = UserModel.fromJson(jsonDecode(response.body));
        await _authService.updateLocalUser(updatedUser);
        setState(() => _user = updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile banner updated!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating banner: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    
    try {
      final token = await _authService.getToken();
      
      // 1. Update Basic Profile
      final profileResp = await http.patch(
        Uri.parse('${Constants.apiUrl}/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'about': _aboutController.text.trim(),
          'signature': _signatureController.text.trim(),
          'gameId': _gameIdController.text.trim(),
        }),
      );

      bool usernameSuccess = true;
      String? usernameError;

      // 2. Update Username if changed
      if (_usernameController.text.trim() != _user?.username) {
        final usernameResp = await http.post(
          Uri.parse('${Constants.apiUrl}/users/username'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'username': _usernameController.text.trim(),
          }),
        );

        if (usernameResp.statusCode != 200) {
          usernameSuccess = false;
          final errorData = jsonDecode(usernameResp.body);
          usernameError = errorData['error'] ?? 'Username update failed';
        }
      }

      if (profileResp.statusCode == 200 && usernameSuccess) {
        final data = jsonDecode(profileResp.body);
        UserModel updatedUser = UserModel.fromJson(data);
        
        // Refresh full user data to get updated username
        final meResp = await http.get(
          Uri.parse('${Constants.apiUrl}/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (meResp.statusCode == 200) {
          updatedUser = UserModel.fromJson(jsonDecode(meResp.body));
        }

        await _authService.updateLocalUser(updatedUser);
        setState(() => _user = updatedUser);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(usernameError ?? 'Failed to update profile')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        await _uploadImage(File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _uploadImage(File file) async {
    setState(() => _isSaving = true);
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
        final imageUrl = data['url'];

        // Update profile in backend
        final updateResp = await http.patch(
          Uri.parse('${Constants.apiUrl}/users/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'profilePic': imageUrl}),
        );

        if (updateResp.statusCode == 200) {
          final userData = jsonDecode(updateResp.body);
          // Force refresh by appending a timestamp to the URL
          if (userData['profilePic'] != null) {
            userData['profilePic'] = "${userData['profilePic']}?t=${DateTime.now().millisecondsSinceEpoch}";
          }
          final updatedUser = UserModel.fromJson(userData);
          await _authService.updateLocalUser(updatedUser);
          
          setState(() {
            _user = updatedUser;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile picture updated!')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickBannerFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        await _uploadBanner(File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking banner: $e')));
    }
  }

  Future<void> _uploadBanner(File file) async {
    setState(() => _isSaving = true);
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
        final imageUrl = data['url'];

        // Update profile banner in backend
        final updateResp = await http.patch(
          Uri.parse('${Constants.apiUrl}/users/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'profileBanner': imageUrl}),
        );

        if (updateResp.statusCode == 200) {
          final userData = jsonDecode(updateResp.body);
          final updatedUser = UserModel.fromJson(userData);
          await _authService.updateLocalUser(updatedUser);
          setState(() => _user = updatedUser);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Custom banner updated!')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isSaving)
            Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            IconButton(
              icon: Icon(Icons.check, color: Colors.blueAccent),
              onPressed: _updateProfile,
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_user != null) ProfileDashboardBox(user: _user!, isCurrentUser: true),
            const SizedBox(height: 8),
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _user?.profilePic != null && _user!.profilePic.isNotEmpty
                      ? CachedNetworkImageProvider(_user!.profilePic)
                      : null,
                  backgroundColor: Colors.grey[200],
                  child: (_user?.profilePic == null || _user!.profilePic.isEmpty)
                      ? Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    radius: 20,
                    child: IconButton(
                      icon: Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.alternate_email),
                prefixText: '@',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g. rajib_123',
                helperText: 'Unique handle, 5-10 characters [a-z0-9_]',
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _aboutController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'About / Bio',
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Tell us something about yourself...',
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _gameIdController,
              decoration: InputDecoration(
                labelText: 'Game ID',
                prefixIcon: Icon(Icons.games_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Your Game ID (e.g. PUBG, Free Fire)',
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _signatureController,
              decoration: InputDecoration(
                labelText: 'Profile Signature',
                prefixIcon: Icon(Icons.edit_note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'A short sentence for your profile...',
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Your Profile Banner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _pickBannerFromGallery,
                  icon: Icon(Icons.add_photo_alternate),
                  label: Text('Custom'),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Category Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _bannerCategories.keys.map((cat) {
                  bool isSelected = _selectedBannerCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedBannerCategory = cat);
                      },
                      selectedColor: Colors.blueAccent.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.blueAccent : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 12),
            // Banners Grid-like Scroll
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _bannerCategories[_selectedBannerCategory]?.length ?? 0,
                itemBuilder: (context, index) {
                  final banner = _bannerCategories[_selectedBannerCategory]![index];
                  // Important: Encode URL to handle spaces properly
                  final encodedUrl = Uri.encodeFull(banner['url']!);
                  return _buildBannerOption(banner['name']!, encodedUrl);
                },
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Email: ${_user?.email ?? ""}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerOption(String label, String url) {
    bool isSelected = _user?.profileBanner == url;
    return GestureDetector(
      onTap: () => _updateBanner(url),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          image: DecorationImage(
            image: CachedNetworkImageProvider(url),
            fit: BoxFit.cover,
            colorFilter: isSelected ? null : ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}
