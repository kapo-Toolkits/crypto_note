import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_note/crypto_service.dart';

void main() {
  final service = CryptoService();

  test('encrypt → decrypt round-trip returns original text', () async {
    const original = 'გამარჯობა, ეს არის საიდუმლო შეტყობინება 123!';
    const pin = '4271';

    final encrypted = await service.encrypt(original, pin);
    final decrypted = await service.decrypt(encrypted, pin);

    expect(decrypted, original);
  });

  test('output uses only Crockford Base32 alphabet + spaces', () async {
    final encrypted = await service.encrypt('test', '1234');
    final stripped = encrypted.replaceAll(' ', '');
    expect(RegExp(r'^[0-9A-HJKMNP-TV-Z]+$').hasMatch(stripped), isTrue);
  });

  test('decrypt tolerates normalized input (lowercase, O/I/L confusion)', () async {
    final encrypted = await service.encrypt('hello world', '9999');
    // მომხმარებელმა ხელით გადაწერა: lowercase + O/I/L აღრევა
    final messy = encrypted.toLowerCase().replaceAll('0', 'o');
    final decrypted = await service.decrypt(messy, '9999');
    expect(decrypted, 'hello world');
  });

  test('wrong PIN fails to decrypt', () async {
    final encrypted = await service.encrypt('secret', '1111');
    expect(
      () => service.decrypt(encrypted, '2222'),
      throwsA(anything),
    );
  });

  test('normalizeInput maps confusables correctly', () {
    expect(CryptoService.normalizeInput('ab O I L o i l'), 'AB011011');
  });
}
