import 'dart:convert';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Future<void> initForUser(String userId) async {}
  void reset() {}

  Future<Map<String, dynamic>> encryptMessage(String recipientUserId, String plaintext) async {
    return {
      'type': 0,
      'body': base64Encode(utf8.encode(plaintext)),
    };
  }

  Future<String> decryptMessage(String senderUserId, Map<String, dynamic> encryptedData) async {
    try {
      final type = encryptedData['type'];
      // Types > 0 were Signal Protocol messages. We can't decrypt old ones anymore.
      if (type != null && type > 0) {
        return '🔓 Old Encrypted Message (Keys removed)';
      }
      final bytes = base64Decode(encryptedData['body'] ?? '');
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      return encryptedData['body']?.toString() ?? '';
    }
  }

  Future<void> resetSession(String recipientUserId) async {}
}
