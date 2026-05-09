import 'dart:convert';
import 'dart:typed_data';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'security_service.dart';
import 'signal_store.dart';
import 'auth_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final _security = SecurityService();

  // FIX: Store is namespaced per userId. The _userId is set synchronously
  // on login so no async race condition can cause the wrong store to be used.
  PersistentSignalStore? _store;
  String? _currentUserId;

  /// Call this immediately on login BEFORE any encryption — sets up the
  /// correct user-scoped store synchronously so there is zero risk of the
  /// old account's store being used.
  Future<void> initForUser(String userId) async {
    if (_currentUserId != userId || _store == null) {
      _store = null; // Clear old store first
      _currentUserId = userId;
      _store = PersistentSignalStore(userId);
      print('✅ SessionService initialized for user: $userId');
    }
  }

  /// Lazily initialise the store once we know the current user's ID.
  Future<PersistentSignalStore> _getStore() async {
    if (_store != null && _currentUserId != null) return _store!;
    final user = await AuthService().loadUser();
    if (user == null) throw Exception('SessionService: no authenticated user');
    if (_currentUserId != user.id || _store == null) {
      _currentUserId = user.id;
      _store = PersistentSignalStore(user.id);
    }
    return _store!;
  }

  /// Invalidate the cached store — call this on logout.
  void reset() {
    _store = null;
    _currentUserId = null;
    print('🔄 SessionService reset — store cleared');
  }

  /// Start a secure session with a recipient if one doesn't exist.
  Future<SessionCipher> getSessionCipher(String recipientUserId) async {
    final store   = await _getStore();
    final address = SignalProtocolAddress(recipientUserId, 1);

    if (!await store.containsSession(address)) {
      PreKeyBundle? bundle = await _security.fetchRecipientBundle(recipientUserId);

      if (bundle == null) {
        try { await _security.initializeKeys(); } catch (_) {}
        bundle = await _security.fetchRecipientBundle(recipientUserId);
      }

      if (bundle == null) {
        throw Exception('no security keys — ask recipient to open the app');
      }

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
      // Auto-reset and retry ONCE on any Signal error
      final store   = await _getStore();
      final address = SignalProtocolAddress(recipientUserId, 1);
      print('⚠️ Encryption failed for $recipientUserId: $e — auto-resetting session...');
      try {
        await store.deleteSession(address);
        await store.deleteIdentity(address);
        final cipher     = await getSessionCipher(recipientUserId);
        final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
        print('✅ Auto-reset successful.');
        return {
          'type': ciphertext.getType(),
          'body': base64Encode(ciphertext.serialize()),
        };
      } catch (retryError) {
        print('❌ Auto-reset failed: $retryError');
        rethrow;
      }
    }
  }

  /// Decrypt a message from a sender.
  Future<String> decryptMessage(String senderUserId, Map<String, dynamic> encryptedData) async {
    try {
      final cipher         = await getSessionCipher(senderUserId);
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
      print('⚠️ Decrypt error for $senderUserId: $e — resetting session for next message');
      final store   = await _getStore();
      final address = SignalProtocolAddress(senderUserId, 1);
      await store.deleteSession(address);
      return '[[DECRYPTION_ERROR]]';
    }
  }

  /// Full reset: clears session AND trusted identity for a user.
  /// Use this when the manual "Reset Secure Session" button is tapped.
  Future<void> resetSession(String recipientUserId) async {
    final store   = await _getStore();
    final address = SignalProtocolAddress(recipientUserId, 1);
    await store.deleteSession(address);
    await store.deleteIdentity(address);
    print('🗑️ Session and Identity cleared for $recipientUserId');
  }
}
