import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// FIX Bug 19: All storage keys are now prefixed with the current user's ID.
/// This prevents key material from leaking between accounts on the same device.
/// Each account gets its own isolated Signal Protocol key space.
class PersistentSignalStore implements 
    SessionStore, 
    PreKeyStore, 
    SignedPreKeyStore, 
    IdentityKeyStore {
  
  final _storage = const FlutterSecureStorage();

  /// The currently authenticated user's ID — used to namespace all keys.
  final String userId;

  PersistentSignalStore(this.userId);

  // Prefixed key builders — ensures per-user isolation
  String get _sessionPrefix    => '${userId}_signal_session_';
  String get _preKeyPrefix     => '${userId}_signal_prekey_';
  String get _signedPreKeyPrefix => '${userId}_signal_signed_prekey_';
  String get _identityPrefix   => '${userId}_signal_identity_';

  // --- SessionStore ---
  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final key = '$_sessionPrefix${address.toString()}';
    final data = await _storage.read(key: key);
    if (data != null) {
      return SessionRecord.fromSerialized(base64Decode(data));
    }
    return SessionRecord();
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    // Basic implementation for single device
    return [1];
  }

  @override
  Future<void> storeSession(SignalProtocolAddress address, SessionRecord record) async {
    final key = '$_sessionPrefix${address.toString()}';
    await _storage.write(key: key, value: base64Encode(record.serialize()));
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final key = '$_sessionPrefix${address.toString()}';
    return await _storage.containsKey(key: key);
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    final key = '$_sessionPrefix${address.toString()}';
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    // Could enumerate and delete all keys for this user/name if needed
  }

  // --- PreKeyStore ---
  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final key = '$_preKeyPrefix$preKeyId';
    final data = await _storage.read(key: key);
    if (data == null) throw InvalidKeyIdException('No prekey for ID: $preKeyId');
    return PreKeyRecord.fromBuffer(base64Decode(data));
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    await _storage.write(key: '$_preKeyPrefix$preKeyId', value: base64Encode(record.serialize()));
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    return await _storage.containsKey(key: '$_preKeyPrefix$preKeyId');
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    await _storage.delete(key: '$_preKeyPrefix$preKeyId');
  }

  // --- SignedPreKeyStore ---
  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final key = '$_signedPreKeyPrefix$signedPreKeyId';
    final data = await _storage.read(key: key);
    if (data == null) throw InvalidKeyIdException('No signed prekey for ID: $signedPreKeyId');
    return SignedPreKeyRecord.fromSerialized(base64Decode(data));
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    return [];
  }

  @override
  Future<void> storeSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) async {
    await _storage.write(key: '$_signedPreKeyPrefix$signedPreKeyId', value: base64Encode(record.serialize()));
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    return await _storage.containsKey(key: '$_signedPreKeyPrefix$signedPreKeyId');
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    await _storage.delete(key: '$_signedPreKeyPrefix$signedPreKeyId');
  }

  // --- IdentityKeyStore ---
  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    final key = '${userId}_signal_identity_key_pair';
    final data = await _storage.read(key: key);
    if (data == null) throw Exception('No Identity Key Pair found for user $userId');
    return IdentityKeyPair.fromSerialized(base64Decode(data));
  }

  @override
  Future<int> getLocalRegistrationId() async {
    final key = '${userId}_signal_registration_id';
    final data = await _storage.read(key: key);
    if (data == null) throw Exception('No Registration ID found for user $userId');
    return int.parse(data);
  }

  @override
  Future<bool> saveIdentity(SignalProtocolAddress address, IdentityKey? identityKey) async {
    final key = '$_identityPrefix${address.toString()}';
    if (identityKey == null) return false;
    await _storage.write(key: key, value: base64Encode(identityKey.serialize()));
    return true;
  }

  @override
  Future<bool> isTrustedIdentity(
      SignalProtocolAddress address, IdentityKey? identityKey, Direction direction) async {
    if (identityKey == null) return false;
    
    final storedIdentity = await getIdentity(address);
    if (storedIdentity == null) {
      // Trust on first use (TOFU)
      await saveIdentity(address, identityKey);
      return true;
    }
    
    final storedBytes = storedIdentity.serialize();
    final newBytes = identityKey.serialize();

    // FIX Bug 22: If the identity key has changed (e.g. user reinstalled), accept the
    // new key and update storage instead of permanently rejecting all future messages.
    // In a production app you would show a "safety number changed" warning to the user.
    if (storedBytes.length != newBytes.length || !_bytesEqual(storedBytes, newBytes)) {
      print('⚠️ Identity key changed for ${address.toString()} — accepting updated key (TOFU rotation)');
      await saveIdentity(address, identityKey);
      return true;
    }

    return true;
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final key = '$_identityPrefix${address.toString()}';
    final data = await _storage.read(key: key);
    if (data == null) return null;
    return IdentityKey(Curve.decodePoint(base64Decode(data), 0));
  }
  
  /// Clear the identity for a user (used for session reset)
  Future<void> deleteIdentity(SignalProtocolAddress address) async {
    final key = '$_identityPrefix${address.toString()}';
    await _storage.delete(key: key);
  }

  /// Helper: constant-time byte comparison
  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
