class Constants {
  // Production AWS Server:
  static const String serverUrl = 'http://52.66.216.152:9000';
  // Local Testing: 'http://localhost:9000'
  static const String apiUrl = 'http://52.66.216.152:9000/api';
  
  // Google Client IDs
  static const String webClientId = 
      '196123415057-tengfcv2ude47c7je9vv101r2pnqju0m.apps.googleusercontent.com';
  static const String androidClientId = 
      '196123415057-liqimnfp9t2l819o8lcuaqdbne1rrkn9.apps.googleusercontent.com';
  
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
// Trigger Build #13 - Bug fixes: offline messages, error sanitization, moments crash, perf improvements
