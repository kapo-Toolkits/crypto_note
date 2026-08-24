import 'package:flutter/foundation.dart';

import 'crypto_service.dart';

enum Mode { encrypt, decrypt }

class AppState extends ChangeNotifier {
  final CryptoService _service = CryptoService();

  Mode mode = Mode.encrypt;
  String result = '';
  String? error;
  bool busy = false;

  void setMode(Mode m) {
    if (mode == m) return;
    mode = m;
    result = '';
    error = null;
    notifyListeners();
  }

  Future<void> run(String text, String pin) async {
    error = null;
    result = '';

    if (pin.trim().isEmpty) {
      error = 'შეიყვანე PIN';
      notifyListeners();
      return;
    }
    if (text.trim().isEmpty) {
      error = 'შეიყვანე ტექსტი';
      notifyListeners();
      return;
    }

    busy = true;
    notifyListeners();

    try {
      if (mode == Mode.encrypt) {
        result = await _service.encrypt(text, pin);
      } else {
        result = await _service.decrypt(text, pin);
      }
    } catch (e) {
      if (mode == Mode.decrypt) {
        error = 'განშიფვრა ვერ მოხერხდა — შეამოწმე PIN და ტექსტი.';
      } else {
        error = 'შეცდომა: $e';
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
