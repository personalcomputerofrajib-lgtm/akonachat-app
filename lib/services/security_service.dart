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

  // FIX Bug 19: All storage keys must be prefixed with the current user's ID
  // so that multiple accounts on the same device never share key material.
  String? _currentUserId;

  /// Returns a user-namespaced storage key.
  String _prefixed(String key) {
    assert(_currentUserId != null, 'SecurityService used before _currentUserId was set');
    return '${_currentUserId!}_$key';
  }

  // Base storage key names (without user prefix — _prefixed() adds it at runtime)
  static const String _identityKeyPairKey       = 'signal_identity_key_pair';
  static const String _registrationIdKey        = 'signal_registration_id';
  static const String _signedPreKeyKey          = 'signal_signed_pre_key';
  static const String _dbEncryptionKey          = 'local_db_encryption_key';
  static const String _lastPreKeyIdKey          = 'signal_last_pre_key_id';
  static const String _signedPreKeyTimestampKey = 'signal_signed_pre_key_timestamp';

  /// Initialize and generate keys if they don't exist for the current user.
  Future<void> initializeKeys() async {
    // FIX Bug 19: Resolve the current user FIRST so all subsequent key operations
    // are namespaced correctly. If there's no logged-in user, fail loudly.
    final user = await AuthService().loadUser();
    if (user == null) throw Exception('SecurityService.initializeKeys: no authenticated user');
    _currentUserId = user.id;

    final existingId = await _storage.read(key: _prefixed(_registrationIdKey));
    if (existingId == null) {
      await _generateAndUploadNewKeys();
    } else {
      // Periodic check for replenishment - Run in background, don't block startup
      unawaited(checkAndReplenishPreKeys());
    }

    // Generate DB encryption key if missing (also per-user namespaced)
    final dbKey = await _storage.read(key: _prefixed(_dbEncryptionKey));
    if (dbKey == null) {
      final random = Random.secure();
      final keyBytes = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
      await _storage.write(key: _prefixed(_dbEncryptionKey), value: base64Encode(keyBytes));
    }
  }

  Future<String?> getDatabaseKey() async {
    // Ensure user context is set before reading
    if (_currentUserId == null) {
      final user = await AuthService().loadUser();
      _currentUserId = user?.id;
    }
    if (_currentUserId == null) return null;
    return await _storage.read(key: _prefixed(_dbEncryptionKey));
  }

  Future<void> _generateAndUploadNewKeys() async {
    // 1. Generate Identity Key Pair
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId  = generateRegistrationId(false);

    // 2. Generate Signed Pre-Key
    final signedPreKey = generateSignedPreKey(identityKeyPair, 1);

    // 3. Generate One-Time Pre-Keys (Batch of 100)
    final oneTimePreKeys = generatePreKeys(0, 100);

    // 4. Persist Keys Locally (namespaced per user)
    await _storage.write(key: _prefixed(_identityKeyPairKey),       value: base64Encode(identityKeyPair.serialize()));
    await _storage.write(key: _prefixed(_registrationIdKey),        value: registrationId.toString());
    await _storage.write(key: _prefixed(_signedPreKeyKey),          value: base64Encode(signedPreKey.serialize()));
    await _storage.write(key: _prefixed(_lastPreKeyIdKey),          value: '100');
    await _storage.write(key: _prefixed(_signedPreKeyTimestampKey), value: DateTime.now().millisecondsSinceEpoch.toString());

    // Also store the signed pre-key in the store so the SignedPreKeyStore can load it
    await _storage.write(
      key: '${_currentUserId!}_signal_signed_prekey_1',
      value: base64Encode(signedPreKey.serialize()),
    );

    // 5. Upload Public Bundle to Server
    await _uploadBundle(identityKeyPair, registrationId, signedPreKey, oneTimePreKeys);
  }

  Future<void> _uploadBundle(
    IdentityKeyPair identityKeyPair,
    int registrationId,
    SignedPreKeyRecord signedPreKey,
    List<PreKeyRecord> oneTimePreKeys,
  ) async {
    final token = await AuthService().getToken();

    final payload = {
      // FIX Bug 21: Send registrationId so the backend can store and return it
      'registrationId': registrationId,
      'identityKey': base64Encode(identityKeyPair.getPublicKey().serialize()),
      'signedPreKey': {
        'key': base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
        'signature': base64Encode(signedPreKey.signature),
        'id': signedPreKey.id,
      },
      'oneTimePreKeys': oneTimePreKeys.map((k) => {
        'key': base64Encode(k.getKeyPair().publicKey.serialize()),
        'id': k.id,
      }).toList(),
    };

    final response = await http.post(
      Uri.parse('${Constants.apiUrl}/keys/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to upload security bundle to server: ${response.body}');
    }
  }

  /// Get a remote bundle for a recipient to start a session.
  Future<PreKeyBundle?> fetchRecipientBundle(String userId) async {
    final token = await AuthService().getToken();
    final response = await http.get(
      Uri.parse('${Constants.apiUrl}/keys/fetch/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // FIX Bug 21: Use real registrationId returned from server
      final registrationId = (data['registrationId'] as num?)?.toInt() ?? 0;

      return PreKeyBundle(
        registrationId,
        1, // Device ID (Default 1)
        data['oneTimePreKey'] != null ? data['oneTimePreKey']['id'] : null,
        data['oneTimePreKey'] != null ? Curve.decodePoint(base64Decode(data['oneTimePreKey']['key']), 0) : null,
        data['signedPreKey']['id'],
        Curve.decodePoint(base64Decode(data['signedPreKey']['key']), 0),
        base64Decode(data['signedPreKey']['signature']),
        IdentityKey(Curve.decodePoint(base64Decode(data['identityKey']), 0)),
      );
    }
    return null;
  }

  /// Check if pre-keys are low or if signed pre-key is old, and replenish/rotate.
  Future<void> checkAndReplenishPreKeys() async {
    // Ensure user context
    if (_currentUserId == null) {
      final user = await AuthService().loadUser();
      _currentUserId = user?.id;
      if (_currentUserId == null) return;
    }

    // Cooldown check (don't check more than once every hour)
    if (_lastCheckTime != null && DateTime.now().difference(_lastCheckTime!).inHours < 1) {
      return;
    }
    _lastCheckTime = DateTime.now();

    final lastIdStr = await _storage.read(key: _prefixed(_lastPreKeyIdKey)) ?? '0';
    int lastId = int.parse(lastIdStr);

    final timestampStr = await _storage.read(key: _prefixed(_signedPreKeyTimestampKey)) ?? '0';
    final timestamp = int.parse(timestampStr);
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    bool needsSignedRotation = timestamp < sevenDaysAgo;

    if (needsSignedRotation) {
      final identityData = await _storage.read(key: _prefixed(_identityKeyPairKey));
      if (identityData == null) return;
      final identityKeyPair = IdentityKeyPair.fromSerialized(base64Decode(identityData));

      final registrationIdStr = await _storage.read(key: _prefixed(_registrationIdKey)) ?? '0';
      final registrationId = int.parse(registrationIdStr);

      // New Signed Pre-Key
      final newSignedId = (timestamp % 1000) + 1;
      final signedPreKey = generateSignedPreKey(identityKeyPair, newSignedId);

      // New One-Time Pre-Keys
      final oneTimePreKeys = generatePreKeys(lastId + 1, 100);
      final newLastId = lastId + 100;

      // Update storage
      await _storage.write(key: _prefixed(_signedPreKeyKey),          value: base64Encode(signedPreKey.serialize()));
      await _storage.write(key: _prefixed(_signedPreKeyTimestampKey), value: DateTime.now().millisecondsSinceEpoch.toString());
      await _storage.write(key: _prefixed(_lastPreKeyIdKey),          value: newLastId.toString());

      // Also store the new signed prekey so the store can load it
      await _storage.write(
        key: '${_currentUserId!}_signal_signed_prekey_$newSignedId',
        value: base64Encode(signedPreKey.serialize()),
      );

      // Upload to server (appends prekeys — not overwrites, handled server-side)
      await _uploadBundle(identityKeyPair, registrationId, signedPreKey, oneTimePreKeys);
    }
  }
}
