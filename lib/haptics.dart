// პლატფორმა-სპეციფიკური ჰაპტიკა: web → navigator.vibrate, native → HapticFeedback.
export 'haptics_io.dart' if (dart.library.js_interop) 'haptics_web.dart';
