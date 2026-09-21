// Platform-safe OCR entry point, same pattern as services/measure_reporting.dart.
// google_mlkit_text_recognition is Android/iOS-only, so the web build must
// never import it: the conditional export keeps it out of the web program.
export 'canary_ocr_stub.dart' if (dart.library.io) 'canary_ocr_mlkit.dart';
