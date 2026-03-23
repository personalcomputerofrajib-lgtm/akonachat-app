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
      PreKeyBundle? bundle = await _security.fetchRecipientBundle(recipientUserId);
      
      // Bug Fix: If bundle not found, try re-initializing OUR OWN keys first and retry once
      // (handles case where recipient hasn't uploaded keys yet — prompts them to on next open)
      if (bundle == null) {
        // Also ensure our own keys are uploaded in case there was a network failure during login
        try {
          await _security.initializeKeys();
        } catch (_) {}
        // Retry fetching once more
        bundle = await _security.fetchRecipientBundle(recipientUserId);
      }
      
      if (bundle == null) throw Exception('Recipient has no security keys. Ask them to open the app.');

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
    try {
      final cipher = await getSessionCipher(recipientUserId);
      final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
      
      return {
        'type': ciphertext.getType(),
        'body': base64Encode(ciphertext.serialize()),
      };
    } catch (e) {
      // If encryption fails due to session state, reset and retry once
      final address = SignalProtocolAddress(recipientUserId, 1);
      if (e.toString().contains('InvalidMessage') || e.toString().contains('session')) {
        print('⚠️ Encryption session error, resetting: $e');
        await _store.deleteSession(address);
        // Re-establish session from scratch
        final cipher = await getSessionCipher(recipientUserId);
        final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
        return {
          'type': ciphertext.getType(),
          'body': base64Encode(ciphertext.serialize()),
        };
      }
      rethrow;
    }
  }

  /// Decrypt a message from a sender
  Future<String> decryptMessage(String senderUserId, Map<String, dynamic> encryptedData) async {
    try {
      final cipher = await getSessionCipher(senderUserId);
      final ciphertextBytes = base64Decode(encryptedData['body']);
      
      late CiphertextMessage message;
      if (encryptedData['type'] == CiphertextMessage.prekeyType) {
        message = PreKeySignalMessage(ciphertextBytes);
      } else {
        message = SignalMessage.fromSerialized(ciphertextBytes);
      }

      final decryptedBytes = await cipher.decrypt(message as dynamic);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      // Bug Fix: On decrypt failure (session mismatch), auto-reset the session
      // so the NEXT message triggers a fresh X3DH handshake
      print('⚠️ Decrypt error, auto-resetting session for $senderUserId: $e');
      final address = SignalProtocolAddress(senderUserId, 1);
      await _store.deleteSession(address);
      // Return a user-friendly message; the next exchange will re-sync
      return '[⚠️ Message could not be decrypted. Session reset — try sending again.]';
    }
  }

  /// Reset session for a user (manual intervention if desync happens)
  Future<void> resetSession(String recipientUserId) async {
    final address = SignalProtocolAddress(recipientUserId, 1);
    await _store.deleteSession(address);
  }
}
