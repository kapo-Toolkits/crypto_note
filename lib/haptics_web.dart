import 'dart:js_interop';

@JS('navigator.vibrate')
external JSBoolean? _navigatorVibrate(JSAny pattern);

/// მსუბუქი ვიბრაცია მობილურ ბრაუზერზე (Android Chrome).
/// iOS Safari-ს Vibration API არ აქვს — ჩუმად იგნორდება.
void hapticTick([int ms = 20]) {
  try {
    _navigatorVibrate(ms.toJS);
  } catch (_) {
    // უგულებელყოფა — არ არის მხარდაჭერილი
  }
}
