/// Sanitizes error messages before showing them to users.
/// Strips internal server IPs, ports, URLs, and stack traces.
class ErrorSanitizer {
  static const _sensitivePatterns = [
    // IP addresses with optional port (e.g. 52.66.216.152:9000)
    r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?',
    // localhost with optional port
    r'localhost(:\d+)?',
    // Full HTTP/HTTPS URLs
    r'https?://[^\s]+',
    // Long base64-like strings that might be tokens/keys
    r'[A-Za-z0-9+/]{40,}={0,2}',
  ];

  static final _regexes = _sensitivePatterns
      .map((p) => RegExp(p))
      .toList();

  /// Returns a safe, user-friendly error string
  static String sanitize(dynamic error) {
    String msg = error.toString();
    
    // Replace sensitive patterns with generic placeholders
    for (final regex in _regexes) {
      msg = msg.replaceAll(regex, '[server]');
    }
    
    // Map common technical errors to friendly messages
    if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('[server]')) {
      return 'Could not connect to the server. Please check your internet connection.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'The request timed out. Please try again.';
    }
    if (msg.contains('HandshakeException') || msg.contains('certificate')) {
      return 'Secure connection failed. Please try again.';
    }
    if (msg.contains('404')) {
      return 'The requested content was not found.';
    }
    if (msg.contains('401') || msg.contains('403') || msg.contains('Unauthorized')) {
      return 'Session expired. Please log out and sign in again.';
    }
    if (msg.contains('500') || msg.contains('Internal Server Error')) {
      return 'Server error. Please try again in a moment.';
    }
    
    // Remove "Exception:" prefix which is technical noise
    msg = msg.replaceAll(RegExp(r'^Exception:\s*'), '');
    
    return msg.isEmpty ? 'An unexpected error occurred.' : msg;
  }
}
