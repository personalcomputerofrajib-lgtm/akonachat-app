import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'auth_service.dart';

class SecurityService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  static DateTime? _lastCheckTime;
  
  // Storage Keys
  static const String _identityKeyPairKey = 'signal_identity_key_pair';
  static const String _registrationIdKey = 'signal_registration_id';
  static const String _signedPreKeyKey = 'signal_signed_pre_key';
  static const String _dbEncryptionKey = 'local_db_encryption_key';
  static const String _lastPreKeyIdKey = 'signal_last_pre_key_id';
  static const String _signedPreKeyTimestampKey = 'signal_signed_pre_key_timestamp';
  
  /// Initialize and generate keys if they don't exist
  Future<void> initializeKeys() async {
    final existingId = await _storage.read(key: _registrationIdKey);
    if (existingId == null) {
      await _generateAndUploadNewKeys();
    } else {
      // Periodic check for replenishment - Run in background, don't block startup
      unawaited(checkAndReplenishPreKeys());
    }
    
    // Generate DB key if missing
    final dbKey = await _storage.read(key: _dbEncryptionKey);
    if (dbKey == null) {
      final random = Random.secure();
      final keyBytes = Uint8List.fromList(List.generate(32, (index) => random.nextInt(256)));
      await _storage.write(key: _dbEncryptionKey, value: base64Encode(keyBytes));
    }
  }

  Future<String?> getDatabaseKey() async {
    return await _storage.read(key: _dbEncryptionKey);
  }

  Future<void> _generateAndUploadNewKeys() async {
    // 1. Generate Identity Key Pair
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    
    // 2. Generate Signed Pre-Key
    final signedPreKey = generateSignedPreKey(identityKeyPair, 1);
    
    // 3. Generate One-Time Pre-Keys (Batch of 100)
    final oneTimePreKeys = generatePreKeys(0, 100);
    
    // 4. Persist Keys Locally (Encrypted via SecureStorage)
    await _storage.write(key: _identityKeyPairKey, value: base64Encode(identityKeyPair.serialize()));
    await _storage.write(key: _registrationIdKey, value: registrationId.toString());
    await _storage.write(key: _signedPreKeyKey, value: base64Encode(signedPreKey.serialize()));
    await _storage.write(key: _lastPreKeyIdKey, value: '100');
    await _storage.write(key: _signedPreKeyTimestampKey, value: DateTime.now().millisecondsSinceEpoch.toString());
    
    // 5. Upload Public Bundle to Server
    await _uploadBundle(identityKeyPair, signedPreKey, oneTimePreKeys);
  }

  Future<void> _uploadBundle(
    IdentityKeyPair identityKeyPair, 
    SignedPreKeyRecord signedPreKey, 
    List<PreKeyRecord> oneTimePreKeys
  ) async {
    final token = await AuthService().getToken();
    
    final payload = {
      'identityKey': base64Encode(identityKeyPair.getPublicKey().serialize()),
      'signedPreKey': {
        'key': base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
        'signature': base64Encode(signedPreKey.signature),
        'id': signedPreKey.id
      },
      'oneTimePreKeys': oneTimePreKeys.map((k) => {
        'key': base64Encode(k.getKeyPair().publicKey.serialize()),
        'id': k.id
      }).toList()
    };

    final response = await http.post(
      Uri.parse('${Constants.apiUrl}/keys/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(payload)
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to upload security bundle to server: ${response.body}');
    }
  }

  /// Get a remote bundle for a recipient to start a session
  Future<PreKeyBundle?> fetchRecipientBundle(String userId) async {
    final token = await AuthService().getToken();
    final response = await http.get(
      Uri.parse('${Constants.apiUrl}/keys/fetch/$userId'),
      headers: {'Authorization': 'Bearer $token'}
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final registrationId = data['registrationId'] ?? 0; // Backend should give this if needed
      
      return PreKeyBundle(
        registrationId,
        1, // Device ID (Default 1)
        data['oneTimePreKey'] != null ? data['oneTimePreKey']['id'] : null,
        data['oneTimePreKey'] != null ? Curve.decodePoint(base64Decode(data['oneTimePreKey']['key']), 0) : null,
        data['signedPreKey']['id'],
        Curve.decodePoint(base64Decode(data['signedPreKey']['key']), 0),
        base64Decode(data['signedPreKey']['signature']),
        IdentityKey(Curve.decodePoint(base64Decode(data['identityKey']), 0))
      );
    }
    return null;
  }

  /// Check if pre-keys are low or if signed pre-key is old, and replenish/rotate
  Future<void> checkAndReplenishPreKeys() async {
    // Cooldown check (don't check more than once every hour)
    if (_lastCheckTime != null && DateTime.now().difference(_lastCheckTime!).inHours < 1) {
      return;
    }
    _lastCheckTime = DateTime.now();
    final lastIdStr = await _storage.read(key: _lastPreKeyIdKey) ?? '0';
    int lastId = int.parse(lastIdStr);
    
    final timestampStr = await _storage.read(key: _signedPreKeyTimestampKey) ?? '0';
    final timestamp = int.parse(timestampStr);
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch;

    bool needsSignedRotation = timestamp < sevenDaysAgo;
    
    // For simplicity, we replenish if we have less than 20 left 
    // (This is a naive check; in real Signal we track consumed keys)
    // Here we'll just periodically upload a new batch of 100 every week with rotation
    if (needsSignedRotation) {
      final identityData = await _storage.read(key: _identityKeyPairKey);
      if (identityData == null) return;
      final identityKeyPair = IdentityKeyPair.fromSerialized(base64Decode(identityData));
      
      // New Signed Pre-Key
      final newSignedId = (timestamp % 1000) + 1; // Simple incrementing ID
      final signedPreKey = generateSignedPreKey(identityKeyPair, newSignedId);
      
      // New One-Time Pre-Keys
      final oneTimePreKeys = generatePreKeys(lastId + 1, 100);
      final newLastId = lastId + 100;

      // Update storage
      await _storage.write(key: _signedPreKeyKey, value: base64Encode(signedPreKey.serialize()));
      await _storage.write(key: _signedPreKeyTimestampKey, value: DateTime.now().millisecondsSinceEpoch.toString());
      await _storage.write(key: _lastPreKeyIdKey, value: newLastId.toString());

      // Upload to server
      await _uploadBundle(identityKeyPair, signedPreKey, oneTimePreKeys);
    }
  }
}
