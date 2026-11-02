import 'dart:typed_data';

import 'blur_detector.dart';
import 'brightness_detector.dart';
import 'eye_validator.dart';

enum ValidationStatus {
  success,
  blurry,
  tooDark,
  tooBright,
  notEye,
}

class ValidationResult {
  final ValidationStatus status;
  final String message;

  const ValidationResult({
    required this.status,
    required this.message,
  });

  bool get passed => status == ValidationStatus.success;
}

class ImageValidator {
  final _blur = BlurDetector();
  final _brightness = BrightnessDetector();
  final _eye = EyeValidator();

  Future<ValidationResult> validate(Uint8List imageBytes) async {
    final blur = _blur.check(imageBytes);

    if (blur.isBlurry) {
      return const ValidationResult(
        status: ValidationStatus.blurry,
        message: "Image is blurry.\nPlease hold your phone steady.",
      );
    }

    final brightness = _brightness.check(imageBytes);

    switch (brightness.status) {
      case BrightnessStatus.tooDark:
        return const ValidationResult(
          status: ValidationStatus.tooDark,
          message: "Image is too dark.\nIncrease the lighting.",
        );

      case BrightnessStatus.tooBright:
        return const ValidationResult(
          status: ValidationStatus.tooBright,
          message: "Image is overexposed.\nReduce flash or brightness.",
        );

      case BrightnessStatus.good:
        break;
    }

    final eye = await _eye.validate(imageBytes);

    if (!eye.detectorAvailable || !eye.isEye) {
      return const ValidationResult(
        status: ValidationStatus.notEye,
        message: "This image is not suitable for anemia screening.\n"
            "Please capture a clear image of the lower eyelid "
            "(palpebral conjunctiva).",
      );
    }

    return const ValidationResult(
      status: ValidationStatus.success,
      message: "Image quality is good.",
    );
  }
}
