import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';

/// OCR მხარდაჭერილია native პლატფორმებზე (Android/iOS).
const bool kOcrSupported = true;

final ImagePicker _picker = ImagePicker();

/// კამერიდან ფოტოს გადაღება და ტექსტის ამოცნობა Tesseract-ით.
///
/// [georgian] = true → `kat+eng` (დასაშიფრი ქართული/შერეული ტექსტი);
/// false → `eng` (Base32 / ლათინური / ციფრები — სწრაფი).
/// აბრუნებს ამოცნობილ ტექსტს, ან `null`-ს თუ მომხმარებელმა გააუქმა.
Future<String?> scanTextFromCamera({bool georgian = false}) async {
  final XFile? photo = await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 100,
  );
  if (photo == null) return null; // გაუქმდა

  final String lang = georgian ? 'kat+eng' : 'eng';
  final String text = await FlutterTesseractOcr.extractText(
    photo.path,
    language: lang,
    args: {
      'preserve_interword_spaces': '1',
    },
  );
  return text.trim();
}
