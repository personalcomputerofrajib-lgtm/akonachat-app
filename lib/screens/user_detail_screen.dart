import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/profile_dashboard_box.dart';
import '../widgets/gift_picker_sheet.dart';

import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/constants.dart';
import '../widgets/glass_container.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';

class UserDetailScreen extends StatefulWidget {
  final String? userId; // If null, show current user

  const UserDetailScreen({
    Key? key,
    this.userId,
  }) : super(key: key);

  @override
  _UserDetailScreenState createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final AuthService _authService = AuthService();
  UserModel? _user;
  List<dynamic> _moments = [];
  bool _isLoading = true;
  bool _isLoadingMoments = true;

  List<dynamic> _guards = [];
  bool _isLoadingGuards = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchUserMoments();
    _fetchGuards();
  }

  Future<void> _fetchUserData() async {
    try {
      final token = await _authService.getToken();
      final url = widget.userId == null
          ? '${Constants.apiUrl}/auth/profile'
          : '${Constants.apiUrl}/users/${widget.userId}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _user = UserModel.fromJson(jsonDecode(response.body));
          _isLoading = false;
        });
      } else {
        print('Failed to load user data: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserMoments() async {
    try {
      final token = await _authService.getToken();
      final targetId = widget.userId ?? (await _authService.loadUser())?.id;
      if (targetId == null) {
        if (mounted) setState(() => _isLoadingMoments = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/moments/user/$targetId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _moments = jsonDecode(response.body);
            _isLoadingMoments = false;
          });
        }
      } else {
        print('Failed to load user moments: ${response.statusCode}');
        if (mounted) setState(() => _isLoadingMoments = false);
      }
    } catch (e) {
      print('Error fetching user moments: $e');
      if (mounted) setState(() => _isLoadingMoments = false);
    }
  }

  Future<void> _fetchGuards() async {
    if (_user == null && widget.userId == null) {
      // Wait for _user to be fetched if it's the current user's profile
      // Or if userId is provided, use that directly.
      // For now, we'll assume _user will be available or userId is provided.
      // A more robust solution might involve chaining futures or using a FutureBuilder.
      if (mounted) setState(() => _isLoadingGuards = false);
      return;
    }

    final String? targetUserId = widget.userId ?? _user?.id;
    if (targetUserId == null) {
      if (mounted) setState(() => _isLoadingGuards = false);
      return;
    }

    try {
      final token = await AuthService().getToken();
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/engagement/guards/$targetUserId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _guards = jsonDecode(response.body);
            _isLoadingGuards = false;
          });
        }
      } else {
        print('Failed to load guards: ${response.statusCode}');
        if (mounted) setState(() => _isLoadingGuards = false);
      }
    } catch (e) {
      print('Error fetching guards: $e');
      if (mounted) setState(() => _isLoadingGuards = false);
    }
  }

  UserModel get user => _user!; // Access _user, assuming it's loaded or handled by _isLoading

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isCyber = themeService.currentTheme == ThemeMode.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Not Found')),
        body: const Center(child: Text('Could not load user profile.')),
      );
    }

    return Scaffold(
      backgroundColor: isCyber ? Colors.black : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, isCyber),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -40),
              child: _buildProfileBody(context, isCyber),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(context, isCyber),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isCyber) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      backgroundColor: isCyber ? Colors.black : Colors.blueAccent,
      leading: BackButton(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (user.profileBanner != null || user.animeBanner != null)
              PageView(
                children: [
                   if (user.profileBanner != null && user.profileBanner!.isNotEmpty)
                     CachedNetworkImage(imageUrl: user.profileBanner!, fit: BoxFit.cover),
                   if (user.animeBanner != null && user.animeBanner!.isNotEmpty)
                     CachedNetworkImage(imageUrl: user.animeBanner!, fit: BoxFit.cover),
                ],
              )
            else
              Container(color: isCyber ? Colors.grey[900] : Colors.blueAccent.withOpacity(0.8)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBody(BuildContext context, bool isCyber) {
    return Container(
      decoration: BoxDecoration(
        color: isCyber ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  if (user.profilePic.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: user.profilePic)));
                  }
                },
                child: Hero(
                  tag: 'profile_pic_${user.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isCyber ? Colors.black : Colors.white, width: 4),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: user.profilePic.isNotEmpty ? CachedNetworkImageProvider(user.profilePic) : null,
                      backgroundColor: isCyber ? Colors.grey[800] : Colors.grey[200],
                      child: user.profilePic.isEmpty ? Icon(Icons.person, size: 50, color: isCyber ? Colors.grey[600] : Colors.grey) : null,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _buildInteractionStat('Moments', _moments.length, isCyber),
            ],
          ),
          const SizedBox(height: 16),
          Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildLevelBadge(isCyber),
              const SizedBox(width: 8),
              Text('ID:${user.gameId ?? user.id.substring(0, 8)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              IconButton(icon: const Icon(Icons.copy, size: 14, color: Colors.grey), onPressed: () {}, constraints: const BoxConstraints(), padding: const EdgeInsets.only(left: 4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionStat(String label, int count, bool isCyber) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCyber ? Colors.white : Colors.black87)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildGiftWallPart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gift Wall', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 12),
        if (user.gifts == null || user.gifts!.isEmpty)
          Text('No gifts yet. Be the first to send one!', style: TextStyle(color: Colors.grey[400], fontSize: 13))
        else
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: user.gifts!.length,
              itemBuilder: (context, i) => Container(
                margin: EdgeInsets.only(right: i == 0 ? 0 : 8),
                child: CircleAvatar(
                  backgroundColor: Colors.pink.withOpacity(0.05),
                  radius: 25,
                  child: Icon(Icons.card_giftcard, color: Colors.pink[200]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Signature', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          user.signature ?? 'This person says nothing!',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildBFFSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('BFF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['Bro and sis', 'Besties', 'Bro', 'Confidant'].map((label) => Column(
            children: [
              Container(
                width: 75,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: const Icon(Icons.add, color: Colors.orange),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildBUddYSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('BUddY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingGuards)
          const Center(child: CircularProgressIndicator())
        else if (_guards.isEmpty)
          Container(
            height: 50,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('No guards yet', style: TextStyle(color: Colors.grey[400]))),
          )
        else
          Row(
            children: _guards.map((g) {
              final info = g['senderInfo'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Tooltip(
                  message: '${info['name']} (${g['count']} gifts)',
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: (info['profilePic'] != null && info['profilePic'].isNotEmpty)
                        ? CachedNetworkImageProvider(info['profilePic'])
                        : null,
                    child: (info['profilePic'] == null || info['profilePic'].isEmpty)
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, bool isCyber) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCyber ? Colors.black : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openGiftPicker(context),
              icon: const Icon(Icons.card_giftcard),
              label: const Text('Send Gift'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D8D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _startChat(context),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C2FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(bool isCyber) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 12, color: Colors.blueAccent),
          const SizedBox(width: 4),
          Text(
            'Lv.${user.level ?? 1}',
            style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _openGiftPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftPickerSheet(recipientId: user.id, recipientName: user.name),
    );
  }

  void _startChat(BuildContext context) async {
    // Reuse logic or navigate - for now just POP and let user decide if they came from chat or search
    // Actually, common pattern is to find or create a chat
    // I'll leave this to be implemented with real logic in the next step
  }
}

