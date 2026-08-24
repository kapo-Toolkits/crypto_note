import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-GCM 256-bit დაშიფვრა/განშიფვრა PIN-ით.
///
/// გასაღები მიიღება PBKDF2-ით (100000 iteration, ფიქსირებული salt, SHA-256).
/// IV: 12 შემთხვევითი ბაიტი, ჩაშენებულია ciphertext-ის დასაწყისში.
/// გამოსავალი: Crockford Base32, 5-სიმბოლოიან ჯგუფებად.
class CryptoService {
  static const String _saltString = 'saidumlo-minaweri-v1';
  static const int _iterations = 100000;
  static const int _ivLength = 12;

  static final _cipher = AesGcm.with256bits();
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  /// Crockford Base32 ანბანი (გამოტოვებულია I, L, O, U).
  static const String _base32Alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  Future<SecretKey> _deriveKey(String pin) {
    final salt = utf8.encode(_saltString);
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  /// ტექსტის დაშიფვრა. აბრუნებს Crockford Base32 სტრიქონს ჯგუფებად.
  Future<String> encrypt(String plainText, String pin) async {
    final key = await _deriveKey(pin);

    final rnd = Random.secure();
    final iv = Uint8List(_ivLength);
    for (var i = 0; i < _ivLength; i++) {
      iv[i] = rnd.nextInt(256);
    }

    final secretBox = await _cipher.encrypt(
      utf8.encode(plainText),
      secretKey: key,
      nonce: iv,
    );

    // ფორმატი: IV(12) + ciphertext + MAC(16)
    final combined = Uint8List.fromList(
      [...iv, ...secretBox.cipherText, ...secretBox.mac.bytes],
    );

    return _groupInFives(_base32Encode(combined));
  }

  /// განშიფვრა. input ნორმალიზდება ავტომატურად.
  Future<String> decrypt(String encoded, String pin) async {
    final normalized = normalizeInput(encoded);
    final combined = _base32Decode(normalized);

    if (combined.length < _ivLength + 16) {
      throw const FormatException('ცუდი მონაცემი: ძალიან მოკლეა');
    }

    final iv = combined.sublist(0, _ivLength);
    final macBytes = combined.sublist(combined.length - 16);
    final cipherText = combined.sublist(_ivLength, combined.length - 16);

    final key = await _deriveKey(pin);
    final secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(macBytes));

    final clear = await _cipher.decrypt(secretBox, secretKey: key);
    return utf8.decode(clear);
  }

  /// input-ის ნორმალიზება: uppercase, spaces/newlines წაშლა, O→0, I/L→1.
  static String normalizeInput(String input) {
    final buffer = StringBuffer();
    for (final ch in input.toUpperCase().split('')) {
      if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' || ch == '-') {
        continue;
      }
      if (ch == 'O') {
        buffer.write('0');
      } else if (ch == 'I' || ch == 'L') {
        buffer.write('1');
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// 5-სიმბოლოიან ჯგუფებად, ჰარით გამოყოფილი.
  static String _groupInFives(String s) {
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i += 5) {
      if (i > 0) buffer.write(' ');
      final end = (i + 5 < s.length) ? i + 5 : s.length;
      buffer.write(s.substring(i, end));
    }
    return buffer.toString();
  }

  static String _base32Encode(List<int> data) {
    final buffer = StringBuffer();
    var bits = 0;
    var value = 0;
    for (final b in data) {
      value = (value << 8) | b;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        buffer.write(_base32Alphabet[(value >> bits) & 0x1F]);
      }
    }
    if (bits > 0) {
      buffer.write(_base32Alphabet[(value << (5 - bits)) & 0x1F]);
    }
    return buffer.toString();
  }

  static Uint8List _base32Decode(String s) {
    final output = <int>[];
    var bits = 0;
    var value = 0;
    for (final ch in s.split('')) {
      final idx = _base32Alphabet.indexOf(ch);
      if (idx < 0) {
        throw FormatException('არასწორი სიმბოლო: $ch');
      }
      value = (value << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        output.add((value >> bits) & 0xFF);
      }
    }
    return Uint8List.fromList(output);
  }
}
