import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class PersistentSignalStore implements 
    SessionStore, 
    PreKeyStore, 
    SignedPreKeyStore, 
    IdentityKeyStore {
  
  final _storage = const FlutterSecureStorage();
  
  // Prefix for storage keys
  static const String _sessionPrefix = 'signal_session_';
  static const String _preKeyPrefix = 'signal_prekey_';
  static const String _signedPreKeyPrefix = 'signal_signed_prekey_';
  static const String _identityPrefix = 'signal_identity_';

  // --- SessionStore ---
  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final key = '$_sessionPrefix${address.toString()}';
    final data = await _storage.read(key: key);
    if (data != null) {
      return SessionRecord.fromBuffer(base64Decode(data));
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
    // Delete all sessions for a user name if needed
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
    return SignedPreKeyRecord.fromBuffer(base64Decode(data));
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    // Fetch all - requires listing keys which SecureStorage doesn't support well directly
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
    final data = await _storage.read(key: 'signal_identity_key_pair');
    if (data == null) throw Exception('No Identity Key Pair found');
    return IdentityKeyPair.fromBuffer(base64Decode(data));
  }

  @override
  Future<int> getLocalRegistrationId() async {
    final data = await _storage.read(key: 'signal_registration_id');
    if (data == null) throw Exception('No Registration ID found');
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
  Future<bool> isTrustedIdentity(SignalProtocolAddress address, IdentityKey? identityKey, Direction direction) async {
    if (identityKey == null) return false;
    
    final storedIdentity = await getIdentity(address);
    if (storedIdentity == null) {
      // Trust on first use (TOFU)
      await saveIdentity(address, identityKey);
      return true;
    }
    
    // Compare bytes to ensure it's the same key
    final storedBytes = storedIdentity.serialize();
    final newBytes = identityKey.serialize();
    
    // If they match, it's trusted
    bool match = true;
    if (storedBytes.length != newBytes.length) return false;
    for (int i = 0; i < storedBytes.length; i++) {
      if (storedBytes[i] != newBytes[i]) {
        match = false;
        break;
      }
    }
    
    return match;
  }
  
  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
      final key = '$_identityPrefix${address.toString()}';
      final data = await _storage.read(key: key);
      if (data == null) return null;
      return IdentityKey(Curve.decodePoint(base64Decode(data), 0));
  }
}
