import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'security_service.dart';
import 'session_service.dart';
import 'message_queue.dart';
import 'database_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: Constants.androidClientId,
    serverClientId: Constants.webClientId,
    scopes: ['email', 'profile'],
  );

  ApiService get _apiService => ApiService();

  /// Initiate Google Sign-In and authenticate with Backend
  /// Returns a map with 'user' (UserModel) and 'requiresUsername' (bool)
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // 1. Authenticate with Google First
      print(">>> [AUTH] Starting Google Sign-In...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print(">>> [AUTH] User aborted Google sign-in.");
        return null; 
      }
      print(">>> [AUTH] Google User: ${googleUser.email}");

      // 2. Extract Authentication Tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      
      if (idToken == null) {
        print("❌ [AUTH] Failed to retrieve ID Token from Google.");
        throw Exception("Failed to retrieve ID Token from Google.");
      }
      print(">>> [AUTH] ID Token retrieved (len: ${idToken.length})");

      // 3. Send ID Token to our backend via ApiService
      print(">>> [AUTH] Sending ID Token to backend: ${Constants.apiUrl}/auth/google");
      final response = await _apiService.post(
        '/auth/google',
        body: {'idToken': idToken},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ [AUTH] Backend Login Success: ${data['user']['email']}");
        final String token = data['token'];
        final UserModel user = UserModel.fromJson(data['user']);
        final bool requiresUsername = data['requiresUsername'] ?? false;
// ... (rest of the code remains the same)
        // 4. Persist Auth Details
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(Constants.tokenKey, token);
        await prefs.setString(Constants.userKey, jsonEncode(user.toJson()));

        // 5. CRITICAL: Reset old session state FIRST, then init for new user.
        // This prevents the old account's Signal store from being used.
        SessionService().reset();
        await SessionService().initForUser(user.id);

        // 6. Initialize Encryption Keys (Signal Protocol)
        try {
          await SecurityService().initializeKeys();
        } catch (e) {
          print("🚨 [AUTH] Security Key Initialization Error: $e");
          await signOut();
          return null;
        }

        return {
          'user': user,
          'requiresUsername': requiresUsername,
        };
      } else {
        print("❌ [AUTH] Backend Auth Error: Status ${response.statusCode}");
        print("❌ [AUTH] Backend Error Body: ${response.body}");
        _googleSignIn.signOut();
        return null;
      }
    } catch (error) {
      print("❌ [AUTH] Google Sign-In Exception: $error");
      return null;
    }
  }

  /// Load currently logged in user
  Future<UserModel?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userStr = prefs.getString(Constants.userKey);
    final String? token = prefs.getString(Constants.tokenKey);
    
    if (userStr != null && token != null) {
      return UserModel.fromJson(jsonDecode(userStr));
    }
    return null;
  }

  /// Get the local Auth token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Constants.tokenKey);
  }

  /// Sign out
  Future<void> signOut() async {
    // 1. Reset services so next login starts with clean state
    SessionService().reset();
    SecurityService().reset();
    // 2. Clear any pending outgoing messages (they use the old session's keys)
    await MessageQueue().clear();
    // 3. Close the encrypted local database to prevent cross-account leaks
    await DatabaseService().closeAndReset();

    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.tokenKey);
    await prefs.remove(Constants.userKey);
  }

  Future<void> logout() => signOut();

  /// Update local user cache
  Future<void> updateLocalUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.userKey, jsonEncode(user.toJson()));
  }

  /// Claim daily login reward
  Future<Map<String, dynamic>?> claimDailyReward() async {
    try {
      final response = await _apiService.post('/engagement/claim-daily');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentUser = await loadUser();
        if (currentUser != null) {
          final updatedUser = UserModel.fromJson({
            ...currentUser.toJson(),
            'coins': data['coins'],
            'streak': data['streak'],
          });
          await updateLocalUser(updatedUser);
        }
        return data;
      }
    } catch (e) {
      print('Error claiming daily reward: $e');
    }
    return null;
  }

  /// Send a sticker gift to someone
  Future<Map<String, dynamic>?> sendGift(String recipientId, String itemId, {bool isAnonymous = false}) async {
    try {
      final response = await _apiService.post(
        '/engagement/send-gift',
        body: {
          'recipientId': recipientId, 
          'itemId': itemId,
          'isAnonymous': isAnonymous,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentUser = await loadUser();
        if (currentUser != null) {
          final updatedUser = UserModel.fromJson({
            ...currentUser.toJson(),
            'coins': data['coins'],
          });
          await updateLocalUser(updatedUser);
        }
        return data;
      }
    } catch (e) {
      print('Error sending gift: $e');
    }
    return null;
  }
}
