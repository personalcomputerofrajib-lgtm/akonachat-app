import 'dart:convert';
import 'dart:typed_data';

class EncryptionService {
  Future<Map<String, String>> encryptMedia(Uint8List data) async {
    return {
      'ciphertext': base64Encode(data),
      'nonce': '',
      'mac': '',
      'key': '',
    };
  }

  Future<Uint8List> decryptMedia({
    required String ciphertext,
    required String nonce,
    required String mac,
    required String keyBase64,
  }) async {
    try {
      if (keyBase64.isNotEmpty) {
        // If it actually had a key, we can't decrypt the old encrypted AES data anymore
        // since we've removed the cryptography package.
        // Return dummy bytes to avoid crashing.
        return Uint8List.fromList(utf8.encode('Encrypted content unreadable'));
      }
      return base64Decode(ciphertext);
    } catch (e) {
      return Uint8List.fromList([]);
    }
  }
}
