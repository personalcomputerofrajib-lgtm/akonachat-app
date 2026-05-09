import 'dart:convert';
import 'dart:typed_data';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'security_service.dart';
import 'signal_store.dart';
import 'auth_service.dart';

class SessionService {
  final _security = SecurityService();

  // FIX Bug 19: Store is now created with the current user's ID so all
  // session/prekey/identity keys are isolated per account on this device.
  PersistentSignalStore? _store;

  /// Lazily initialise the store once we know the current user's ID.
  Future<PersistentSignalStore> _getStore() async {
    if (_store != null) return _store!;
    final user = await AuthService().loadUser();
    if (user == null) throw Exception('SessionService: no authenticated user');
    _store = PersistentSignalStore(user.id);
    return _store!;
  }

  /// Invalidate the cached store — call this on logout so the next login
  /// picks up the correct user-scoped store.
  void reset() {
    _store = null;
  }

  /// Start a secure session with a recipient if one doesn't exist.
  Future<SessionCipher> getSessionCipher(String recipientUserId) async {
    final store   = await _getStore();
    final address = SignalProtocolAddress(recipientUserId, 1);

    // 1. Check if session already exists
    if (!await store.containsSession(address)) {
      // 2. Fetch bundle from Backend
      PreKeyBundle? bundle = await _security.fetchRecipientBundle(recipientUserId);

      // If bundle not found, ensure our own keys are uploaded first, then retry once
      if (bundle == null) {
        try {
          await _security.initializeKeys();
        } catch (_) {}
        bundle = await _security.fetchRecipientBundle(recipientUserId);
      }

      if (bundle == null) {
        throw Exception('Recipient has no security keys. Ask them to open the app.');
      }

      // 3. Initialize Session locally (X3DH handshake)
      final sessionBuilder = SessionBuilder(store, store, store, store, address);
      await sessionBuilder.processPreKeyBundle(bundle);
    }

    return SessionCipher(store, store, store, store, address);
  }

  /// Encrypt a message for a recipient.
  Future<Map<String, dynamic>> encryptMessage(String recipientUserId, String plaintext) async {
    try {
      final cipher     = await getSessionCipher(recipientUserId);
      final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));

      return {
        'type': ciphertext.getType(),
        'body': base64Encode(ciphertext.serialize()),
      };
    } catch (e) {
      // FIX Bug 23: Broaden the retry logic. If ANY encryption error occurs 
      // (Identity mismatch, Session desync, etc.), clear the state and retry once.
      final store   = await _getStore();
      final address = SignalProtocolAddress(recipientUserId, 1);
      
      print('⚠️ Encryption failed for $recipientUserId: $e. Attempting auto-reset and retry...');
      
      try {
        await store.deleteSession(address);
        await store.deleteIdentity(address); // Also clear identity to be safe
        
        // Re-establish session from scratch
        final cipher     = await getSessionCipher(recipientUserId);
        final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
        
        print('✅ Auto-reset successful. Message encrypted.');
        return {
          'type': ciphertext.getType(),
          'body': base64Encode(ciphertext.serialize()),
        };
      } catch (retryError) {
        print('❌ Auto-reset retry failed: $retryError');
        rethrow;
      }
    }
  }

  /// Decrypt a message from a sender.
  Future<String> decryptMessage(String senderUserId, Map<String, dynamic> encryptedData) async {
    try {
      final cipher        = await getSessionCipher(senderUserId);
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
      // On decrypt failure (session mismatch), auto-reset so the NEXT message
      // triggers a fresh X3DH handshake.
      print('⚠️ Decrypt error, auto-resetting session for $senderUserId: $e');
      final store   = await _getStore();
      final address = SignalProtocolAddress(senderUserId, 1);
      await store.deleteSession(address);
      return '[⚠️ Message could not be decrypted. Session reset — try sending again.]';
    }
  }

  /// Reset session for a user (manual intervention if desync happens).
  Future<void> resetSession(String recipientUserId) async {
    final store   = await _getStore();
    final address = SignalProtocolAddress(recipientUserId, 1);
    
    // Clear session AND identity so TOFU can trigger again
    await store.deleteSession(address);
    await store.deleteIdentity(address); 
    
    print('🗑️ Session and Identity cleared for $recipientUserId');
  }
}
