import 'dart:typed_data';

/// Shared client-side guard for images before they are held in memory or sent.
/// The backend repeats these checks; client validation only improves feedback.
abstract final class ConverterImageValidator {
  static const maxBytes = 5 * 1024 * 1024;

  static void validate({required Uint8List bytes, required String fileName}) {
    if (bytes.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }
    if (bytes.length > maxBytes) {
      throw const FormatException('Each image must be 5 MB or smaller.');
    }
    if (!_hasSupportedSignature(bytes)) {
      throw FormatException('$fileName is not a JPEG, PNG, or WebP image.');
    }
  }

  static bool _hasSupportedSignature(Uint8List bytes) {
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    final isWebp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return isJpeg || isPng || isWebp;
  }
}
