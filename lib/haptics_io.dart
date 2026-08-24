import 'package:flutter/services.dart';

/// ჰაპტიკა native პლატფორმებზე (Android/iOS) Flutter-ის HapticFeedback-ით.
/// `ms` პარამეტრი აქ ხანგრძლივობის მიხედვ ირჩევს ინტენსივობას.
void hapticTick([int ms = 20]) {
  if (ms >= 50) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.selectionClick();
  }
}
