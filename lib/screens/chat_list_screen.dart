```dart
import 'package:flutter/material.dart';
import '../services/cache_manager.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../models/user_model.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/daily_reward_popup.dart';
import '../services/theme_service.dart';
import 'user_detail_screen.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'user_search_screen.dart';
import 'settings_screen.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  List<dynamic> _chats = [];
  bool _isLoading = true;
  String? _errorMessage;
  UserModel? _currentUser;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 1. LOAD LOCAL DATA IMMEDIATELY (Instant start)
      await _loadLocalChats();

      // 2. CONNECT IN BACKGROUND
      await Future.any([
        _initAppInternal(),
        Future.delayed(const Duration(seconds: 15), () {
          // If we have local data, don't throw - just warn
          if (_chats.isNotEmpty) {
            print('⚠️ Socket connection timed out, but viewing offline.');
          } else {
            throw TimeoutException('Connection took too long');
          }
        }),
      ]);
    } catch (e) {
      print('❌ Initialization error: $e');
      if (mounted) {
        // Sanitize error message to hide IPs
        String sanitizedMsg = e.toString();
        if (sanitizedMsg.contains('http')) {
          sanitizedMsg = 'Could not connect to the secure server. Please check your internet.';
        }
        
        setState(() {
          _errorMessage = sanitizedMsg;
          _isLoading = false;
        });
        
        _showRetryDialog(sanitizedMsg);
      }
    } finally {
      if (mounted) {
        if (_errorMessage == null || _chats.isNotEmpty) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _initAppInternal() async {
    final user = await _authService.loadUser();
    if (!mounted) return;
    setState(() => _currentUser = user);

    if (user != null) {
      final socketService = SocketService();
      socketService.reset();
      
      print('🔄 Attempting socket connection...');
      final socketConnected = await socketService.connect();

      if (!mounted) return;

      if (!socketConnected) {
        final errorMsg = socketService.lastError ?? 'Socket connection failed';
        
        // Sanitize to hide IP
        String displayError = errorMsg;
        if (displayError.contains('http') || displayError.contains('.')) {
          displayError = 'Server connection failed. Working in offline mode.';
        }

        print('❌ Socket failed: $displayError');
        
        if (_chats.isEmpty) {
          await _loadLocalChats();
        }
        
        setState(() {
          _errorMessage = displayError;
          _isLoading = false;
        });
        return;
      }

      print('✅ Socket connected successfully');
      final socket = socketService.socket;
      
      // Load from local DB first
      await _loadLocalChats();
      
      // Then fetch from server
      await _loadChats();
      _checkDailyReward();
      
      // Listen for real-time updates
      socket?.on('receive_message', (data) {
        if (mounted) {
          _loadChats();
        }
      });

      socket?.on('message_status', (data) {
        if (mounted) {
          _loadChats();
        }
      });

      socket?.on('presence', (data) {
        if (mounted) {
          setState(() {
            final userId = data['userId'];
            final isOnline = data['isOnline'];
            for (var chat in _chats) {
              final participants = chat['participants'] as List;
              for (var p in participants) {
                if (p['_id'] == userId) {
                  p['isOnline'] = isOnline;
                  p['lastSeen'] = data['lastSeen'];
                }
              }
            }
          });
        }
      });
    } else {
      // Go back to login if no user
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  void _showRetryDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismiss
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Connection Limited'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We couldn\'t establish a real-time connection.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Error: $error'),
              SizedBox(height: 16),
              Text('You can still view your cached messages while we try to reconnect in the background.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isLoading = false; // Allow user to see cached chats
              });
            },
            child: Text('View Offline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initApp(); // Retry
            },
            child: Text('Retry Now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkDailyReward() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/engagement/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['canClaim'] == true) {
          // Add a small delay so the app UI loads first
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              showDailyRewardPopup(
                context, 
                currentStreak: data['streak'], 
                nextRewardDay: data['nextRewardDay']
              );
            }
          });
        }
      }
    } catch (e) {
      print('Daily reward check error: $e');
    }
  }

  Future<void> _loadLocalChats() async {
    final localChats = await DatabaseService().getChats();
    if (localChats.isNotEmpty && mounted) {
      setState(() {
        _chats = localChats;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchChats() async {
    try {
      final response = await _apiService.get('/chats');

      if (response.statusCode == 200) {
        final List<dynamic> fetchedChats = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _chats = fetchedChats;
            _errorMessage = null; 
          });
        }

        // Save to local database
        for (var chat in fetchedChats) {
          await DatabaseService().saveChat(chat);
        }
      } else if (response.statusCode == 401) {
        _logout();
      }
    } catch (e) {
      print('Error fetching chats: $e');
      if (mounted && _chats.isEmpty) {
         setState(() => _errorMessage = 'Failed to load chats: $e');
      }
    }
  }

  void _logout() async {
    SocketService().reset();
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
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
              SizedBox(height: 16),
              Text('Connecting to AkonaChat...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _chats.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                SizedBox(height: 16),
                Text('Connection Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initApp,
                  child: Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              currentAccountPicture: Hero(
                tag: 'profilePic',
                child: CircleAvatar(
                  backgroundImage: _currentUser?.profilePic != null && _currentUser!.profilePic.isNotEmpty
                      ? CachedNetworkImageProvider(_currentUser!.profilePic, cacheManager: CustomCacheManager.instance)
                      : null,
                  backgroundColor: Colors.white,
                  child: (_currentUser?.profilePic == null || _currentUser!.profilePic.isEmpty)
                      ? Icon(Icons.person, size: 40, color: Colors.blueAccent)
                      : null,
                ),
              ),
              accountName: Text(
                _currentUser?.name ?? 'User',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_currentUser?.email ?? ''),
            ),
            ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.search),
              title: Text('Find Friends'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserSearchScreen()),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
            Spacer(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.redAccent),
              title: Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          'AkonaChat',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchChats,
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())),
          ),
        ],
      ),
      body: _chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text('No chats yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserSearchScreen())),
                    child: Text('Start a Conversation'),
                  )
                ],
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final lastMsg = chat['lastMessage'];
                int unreadCount = 0;
                if (chat['lastReadBy'] != null) {
                  final myReadInfo = (chat['lastReadBy'] as List).firstWhere(
                    (r) => r['userId'].toString().toLowerCase().trim() == _currentUser?.id.toString().toLowerCase().trim(),
                    orElse: () => null,
                  );
                  if (myReadInfo != null) {
                    unreadCount = (chat['lastSequence'] ?? 0) - (myReadInfo['lastReadSequence'] ?? 0);
                    if (unreadCount < 0) unreadCount = 0;
                  } else {
                    // If no read info yet, everything is unread
                    unreadCount = chat['lastSequence'] ?? 0;
                  }
                }

                // Robust otherUser selection
                final List participants = chat['participants'] is List ? (chat['participants'] as List) : [];
                final otherUser = participants.firstWhere(
                  (p) => p is Map && p['_id'] != null && p['_id'].toString().toLowerCase().trim() != _currentUser?.id.toString().toLowerCase().trim(),
                  orElse: () => participants.isNotEmpty ? participants.first : null,
                );

                if (otherUser == null) return SizedBox.shrink();

                String lastMsgText = 'No messages yet';
                if (lastMsg != null && lastMsg is Map) {
                  lastMsgText = lastMsg['ciphertext']?.toString() ?? 'No messages yet';
                }

                String formattedTime = '';
                if (chat['lastMessageAt'] != null) {
                  try {
                    formattedTime = _formatTime(DateTime.parse(chat['lastMessageAt'].toString()));
                  } catch (e) {
                    print('Date parse error: $e');
                  }
                }

                return _buildChatTile(
                  chatId: chat['_id']?.toString() ?? '',
                  name: otherUser['name']?.toString() ?? 'Unknown',
                  message: lastMsgText,
                  time: formattedTime,
                  unread: unreadCount,
                  isOnline: otherUser['isOnline'] == true,
                  profilePic: otherUser['profilePic']?.toString(),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserSearchScreen())),
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.edit, color: Colors.white),
        elevation: 4,
      ),
    );
  }

  Widget _buildChatTile({
    required String chatId,
    required String name,
    required String message,
    required String time,
    required int unread,
    required bool isOnline,
    String? profilePic,
  }) {
    return InkWell(
      onTap: () async {
        if (_isNavigating) return;
        _isNavigating = true;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatName: name,
            ),
          ),
        ).then((_) => _isNavigating = false);
        // Refresh when returning from the chat to clear the unread badge
        _fetchChats();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                // To get the other user's ID, we need to extract it from the chat object 
                // but _buildChatTile doesn't have the full chat object.
                // However, in 1-on-1 chats, the chatId is often the other user's ID or 
                // contains it. Let's assume the caller will pass it or we'll refine.
                // For now, let's navigate to the profile using the chatId if it's a userId.
                if (!chatId.contains('_')) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserDetailScreen(userId: chatId)
                  ));
                }
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      backgroundImage: profilePic != null && profilePic.isNotEmpty ? CachedNetworkImageProvider(profilePic, cacheManager: CustomCacheManager.instance) : null,
                    child: profilePic == null || profilePic.isEmpty 
                      ? Text(name[0], style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 20))
                      : null,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF00), // Neon Green
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF00).withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(time, style: TextStyle(color: unread > 0 ? Colors.blueAccent : Colors.grey, fontSize: 12, fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: unread > 0 ? Colors.black87 : Colors.grey[600], fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          child: Text(unread.toString(), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${time.day}/${time.month}';
  }
}
