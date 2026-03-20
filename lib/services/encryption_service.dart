import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionService {
  final _algorithm = AesGcm.with256bits();

  /// Encrypt arbitrary data using AES-256-GCM
  /// Returns a Map with 'ciphertext', 'iv', and 'key' (all base64)
  Future<Map<String, String>> encryptMedia(Uint8List data) async {
    // 1. Generate a random 32-byte key
    final SecretKey key = await _algorithm.newSecretKey();
    
    // 2. Encrypt
    final nonce = _algorithm.newNonce();
    final SecretBox box = await _algorithm.encrypt(
      data,
      secretKey: key,
      nonce: nonce,
    );

    final keyBytes = await key.extractBytes();

    return {
      'ciphertext': base64Encode(box.cipherText),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'key': base64Encode(keyBytes),
    };
  }

  /// Decrypt with given parameters
  Future<Uint8List> decryptMedia({
    required String ciphertext,
    required String nonce,
    required String mac,
    required String keyBase64,
  }) async {
    final keyBytes = base64Decode(keyBase64);
    final secretKey = SecretKey(keyBytes);
    
    final SecretBox box = SecretBox(
      base64Decode(ciphertext),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );

    final cleartext = await _algorithm.decrypt(
      box,
      secretKey: secretKey,
    );

    return Uint8List.fromList(cleartext);
  }
}
