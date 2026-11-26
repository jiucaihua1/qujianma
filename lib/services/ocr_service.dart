import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pickup_item.dart';
import '../models/station_rule.dart';
import 'pickup_parser.dart';

class OcrResult {
  const OcrResult({
    required this.rawText,
    required this.candidates,
    required this.imagePath,
  });

  final String rawText;
  final List<ParsedPickupCandidate> candidates;
  final String imagePath;
}

class OcrService {
  OcrService();

  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery and runs 100% local offline Chinese OCR
  /// via Google ML Kit. Returns null if the user cancels image selection.
  Future<OcrResult?> pickAndRecognizeScreenshot({
    List<StationRule> stationRules = const [],
  }) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final inputImage = InputImage.fromFilePath(picked.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final recognized = await recognizer.processImage(inputImage);
      final rawText = recognized.text.trim();
      final candidates = PickupParser.parseAll(
        rawText,
        defaultSource: PickupSource.ocr,
        stationRules: stationRules,
      );
      return OcrResult(
        rawText: rawText,
        candidates: candidates,
        imagePath: picked.path,
      );
    } finally {
      await recognizer.close();
    }
  }
}
