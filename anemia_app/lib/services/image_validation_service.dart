import 'dart:typed_data';

import 'image_validator.dart';

class ImageValidationResult {
  final bool isValid;
  final String message;

  const ImageValidationResult({
    required this.isValid,
    required this.message,
  });
}

class ImageValidationService {
  final ImageValidator _validator = ImageValidator();

  Future<ImageValidationResult> validate(
    Uint8List imageBytes,
  ) async {
    final result = await _validator.validate(imageBytes);
    return ImageValidationResult(
      isValid: result.passed,
      message: result.message,
    );
  }
}
