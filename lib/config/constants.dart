class Constants {
  // Use 10.0.2.2 for Android Emulator, or 52.66.216.152 for production
  static const String serverUrl = 'http://52.66.216.152:9000';
  static const String apiUrl = '$serverUrl/api';
  
  // Google Web Client ID (for requesting the ID token for backend)
  static const String webClientId = 
      '196123415057-liqimnfp9t2l819o8lcuaqdbne1rrkn9.apps.googleusercontent.com';
  
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
