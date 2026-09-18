import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// On-device OCR (ML Kit, Latin script). Nothing is uploaded.
bool get canaryOcrAvailable => Platform.isAndroid || Platform.isIOS;

/// Opens the system photo picker (no storage permission needed on Android)
/// and returns the text found in the chosen screenshot, or null if the person
/// cancelled.
Future<String?> canaryPickScreenshotText() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(picked.path),
    );
    return result.text;
  } finally {
    await recognizer.close();
  }
}
