// პლატფორმა-სპეციფიკური OCR: native → Tesseract + კამერა, web → მხარდაუჭერელი.
export 'ocr_unsupported.dart' if (dart.library.io) 'ocr_mobile.dart';
