/// Web (and any platform without dart:io): no OCR. The leak screen then only
/// offers paste.
bool get canaryOcrAvailable => false;

Future<String?> canaryPickScreenshotText() async => null;
