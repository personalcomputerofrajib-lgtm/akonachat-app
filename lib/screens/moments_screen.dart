import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../config/constants.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_container.dart';
import '../services/theme_service.dart';
import '../services/error_sanitizer.dart';
import 'package:provider/provider.dart';
import 'user_detail_screen.dart';

class MomentsScreen extends StatefulWidget {
  @override
  _MomentsScreenState createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  final AuthService _authService = AuthService();
  List<dynamic> _moments = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _currentUser = await _authService.loadUser();
    await _fetchMoments();
  }

  Future<void> _fetchMoments() async {
    setState(() => _isLoading = true);
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/moments'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _moments = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorSanitizer.sanitize(e))),
        );
      }
    }
  }

  Future<void> _createMoment(String text, String? imageUrl) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/moments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'text': text,
          'imageUrl': imageUrl,
          'type': imageUrl != null ? 'image' : 'text',
        }),
      );

      if (response.statusCode == 200) {
        _fetchMoments();
      }
    } catch (e) {
      print('Error creating moment: $e');
    }
  }

  Future<void> _likeMoment(String momentId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/moments/like/$momentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final newLikes = jsonDecode(response.body) as List;
        setState(() {
          final index = _moments.indexWhere((m) => m['_id'] == momentId);
          if (index != -1) {
            _moments[index]['likes'] = newLikes;
          }
        });
      }
    } catch (e) {
      print('Error liking moment: $e');
    }
  }

  void _showCreateMomentSheet() {
    final textController = TextEditingController();
    File? selectedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New Moment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => setModalState(() => selectedImage = null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.blue),
                        onPressed: () async {
                          final img = await _picker.pickImage(source: ImageSource.gallery);
                          if (img != null) {
                            setModalState(() => selectedImage = File(img.path));
                          }
                        },
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (textController.text.isEmpty && selectedImage == null) return;
                          
                          String? uploadedUrl;
                          if (selectedImage != null) {
                            uploadedUrl = await _uploadImage(selectedImage!);
                          }
                          
                          await _createMoment(textController.text, uploadedUrl);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Post'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _uploadImage(File file) async {
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
        return jsonDecode(response.body)['url'];
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed. Please check your connection.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorSanitizer.sanitize(e))),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Moments', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMoments),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchMoments,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _moments.length,
                itemBuilder: (context, index) {
                  final moment = _moments[index];
                  return _buildMomentCard(moment);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateMomentSheet,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add_photo_alternate, color: Colors.white),
      ),
    );
  }

  Widget _buildMomentCard(Map<String, dynamic> moment) {
    final user = moment['userId'] is Map ? moment['userId'] : <String, dynamic>{};
    final List likes = (moment['likes'] as List?) ?? [];
    final bool isLiked = likes.any((l) => l.toString() == _currentUser?.id);
    final String rawDate = moment['createdAt']?.toString() ?? '';
    final String timeStr = rawDate.isNotEmpty
        ? DateFormat('MMM d, h:mm a').format(DateTime.tryParse(rawDate) ?? DateTime.now())
        : '';

    final bool isCyber = Provider.of<ThemeService>(context, listen: false).isCyberMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GlassContainer(
        blur: isCyber ? 15 : 5,
        opacity: isCyber ? 0.08 : 0.05,
        borderRadius: 24,
        color: isCyber ? const Color(0xFF00E5FF) : Colors.white,
        padding: const EdgeInsets.all(20),
        border: isCyber ? Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3), width: 1.5) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (user['_id'] != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserDetailScreen(userId: user['_id'].toString())
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.cyan, Colors.purple]),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: user['profilePic'] != null && user['profilePic'].isNotEmpty
                          ? CachedNetworkImageProvider(user['profilePic'])
                          : null,
                      child: user['profilePic'] == null || user['profilePic'].isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(timeStr, style: TextStyle(color: isCyber ? Colors.white60 : Colors.grey[600], fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (moment['text'] != null && moment['text'].isNotEmpty)
              Text(
                moment['text'], 
                style: TextStyle(fontSize: 16, height: 1.5, color: isCyber ? Colors.white : Colors.black87)
              ),
            if (moment['imageUrl'] != null && moment['imageUrl'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: moment['imageUrl'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${likes.length}',
                  color: isLiked ? Colors.redAccent : (isCyber ? Colors.white70 : Colors.grey),
                  onTap: () => _likeMoment(moment['_id']),
                ),
                const Spacer(),
                const Icon(Icons.share_outlined, color: Colors.grey, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
