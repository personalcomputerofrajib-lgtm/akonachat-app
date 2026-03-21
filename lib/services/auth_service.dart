import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'security_service.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Force webClientId if serverClientId is not set correctly in constants
    serverClientId: Constants.webClientId,
    scopes: ['email', 'profile'],
  );

  final ApiService _apiService = ApiService();

  /// Initiate Google Sign-In and authenticate with Backend
  /// Returns a map with 'user' (UserModel) and 'requiresUsername' (bool)
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // 1. Authenticate with Google First
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User aborted sign-in

      // 2. Extract Authentication Tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) throw Exception("Failed to retrieve ID Token from Google.");

      // 3. Send ID Token to our backend via ApiService
      final response = await _apiService.post(
        '/auth/google',
        body: {'idToken': idToken},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'];
        final UserModel user = UserModel.fromJson(data['user']);
        final bool requiresUsername = data['requiresUsername'] ?? false;

        // 4. Persist Auth Details
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(Constants.tokenKey, token);
        await prefs.setString(Constants.userKey, jsonEncode(user.toJson()));

        // 5. Initialize Encryption Keys (Signal Protocol) - CRITICAL: Must succeed
        try {
          await SecurityService().initializeKeys();
        } catch (e) {
          print("🚨 Security Key Initialization Error: $e");
          // If security init fails, we MUST logout and fail the auth flow
          await signOut();
          return null; 
        }

        return {
          'user': user,
          'requiresUsername': requiresUsername,
        };
      } else {
        print("Backend Auth Error: ${response.body}");
        _googleSignIn.signOut();
        return null;
      }
    } catch (error) {
      print("Google Sign-In Error: $error");
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
}
