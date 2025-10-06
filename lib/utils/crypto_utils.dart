import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class CryptoUtils {
  // Generate secure random bytes
  static Uint8List _secureRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  // Generate a 256-bit AES key
  static Uint8List generateAESKey() => _secureRandomBytes(32);

  // Generate a 96-bit IV (recommended for GCM)
  static Uint8List generateIV() => _secureRandomBytes(12);

  // AES-GCM encryption
  static Uint8List aesGcmEncrypt(Uint8List key, Uint8List iv, Uint8List plaintext) {
    final cipher = GCMBlockCipher(AESEngine());
    final aeadParams = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));

    cipher.init(true, aeadParams);

    // process() may throw if buffer not large enough, so wrap in try/catch
    try {
      return cipher.process(plaintext);
    } catch (e) {
      throw Exception('AES-GCM encryption failed: $e');
    }
  }

  // AES-GCM decryption
  static Uint8List aesGcmDecrypt(Uint8List key, Uint8List iv, Uint8List ciphertext) {
    final cipher = GCMBlockCipher(AESEngine());
    final aeadParams = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));

    cipher.init(false, aeadParams);

    try {
      return cipher.process(ciphertext);
    } catch (e) {
      throw Exception('AES-GCM decryption failed: $e');
    }
  }
}
