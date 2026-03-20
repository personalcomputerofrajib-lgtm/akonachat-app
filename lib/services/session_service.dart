import 'dart:convert';
import 'dart:typed_data';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'security_service.dart';
import 'signal_store.dart';

class SessionService {
  final _security = SecurityService();
  final _store = PersistentSignalStore();

  /// Start a secure session with a recipient if one doesn't exist
  Future<SessionCipher> getSessionCipher(String recipientUserId) async {
    final address = SignalProtocolAddress(recipientUserId, 1);
    
    // 1. Check if session already exists
    if (!await _store.containsSession(address)) {
      // 2. Fetch bundle from Backend
      final bundle = await _security.fetchRecipientBundle(recipientUserId);
      if (bundle == null) throw Exception('Recipient has no security keys');

      // 3. Initialize Session locally (X3DH handshake)
      final sessionBuilder = SessionBuilder(
        _store, 
        _store, 
        _store, 
        _store, 
        address
      );
      await sessionBuilder.processPreKeyBundle(bundle);
    }

    return SessionCipher(_store, _store, _store, _store, address);
  }

  /// Encrypt a message for a recipient
  Future<Map<String, dynamic>> encryptMessage(String recipientUserId, String plaintext) async {
    final cipher = await getSessionCipher(recipientUserId);
    final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
    
    return {
      'type': ciphertext.getType(),
      'body': base64Encode(ciphertext.serialize()),
    };
  }

  /// Decrypt a message from a sender
  Future<String> decryptMessage(String senderUserId, Map<String, dynamic> encryptedData) async {
    final cipher = await getSessionCipher(senderUserId);
    final ciphertextBytes = base64Decode(encryptedData['body']);
    
    late CiphertextMessage message;
    if (encryptedData['type'] == CiphertextMessage.prekeyType) {
      message = PreKeySignalMessage(ciphertextBytes);
    } else {
      message = SignalMessage(ciphertextBytes);
    }

    final decryptedBytes = await cipher.decrypt(message as dynamic);
    return utf8.decode(decryptedBytes);
  }

  /// Reset session for a user (manual intervention if desync happens)
  Future<void> resetSession(String recipientUserId) async {
    final address = SignalProtocolAddress(recipientUserId, 1);
    await _store.deleteSession(address);
  }
}
