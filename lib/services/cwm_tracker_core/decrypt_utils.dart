// decrypt_utils.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class DecryptUtils {
  static String decrypt(String ciphertextBase64, String seed) {
    // 生成AES密钥
    final keyBytes = sha256.convert(utf8.encode(seed)).bytes;
    final key = Key(Uint8List.fromList(keyBytes));
    final iv = IV(Uint8List.fromList(List.filled(16, 0)));

    // AES CBC解密
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final ciphertext = Encrypted.fromBase64(ciphertextBase64);

    // 解填充并解码
    final plaintext = encrypter.decrypt(ciphertext, iv: iv);
    return plaintext;
  }
}
