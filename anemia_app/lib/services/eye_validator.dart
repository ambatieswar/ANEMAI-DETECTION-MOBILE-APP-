import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class EyeValidationResult {
  final bool isEye;
  final double confidence;
  final bool detectorAvailable;
  final String message;

  const EyeValidationResult({
    required this.isEye,
    required this.confidence,
    required this.detectorAvailable,
    required this.message,
  });
}

class EyeValidator {
  Interpreter? _interpreter;
  bool _checked = false;

  Future<EyeValidationResult> validate(Uint8List imageBytes) async {
    if (!_checked) {
      _checked = true;
      final manifest = jsonDecode(
        await rootBundle.loadString('assets/eye_detector_manifest.json'),
      );
      if (manifest is Map<String, dynamic> && manifest['enabled'] == true) {
        _interpreter = await Interpreter.fromAsset(
          'assets/eye_detector.tflite',
        );
      }
    }

    final interpreter = _interpreter;
    if (interpreter != null) {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        return const EyeValidationResult(
          isEye: false,
          confidence: 0,
          detectorAvailable: true,
          message: 'The image could not be decoded.',
        );
      }
      final resized = img.copyResize(decoded, width: 224, height: 224);
      final input = [
        List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resized.getPixel(x, y);
              return <double>[
                pixel.r.toDouble() / 255,
                pixel.g.toDouble() / 255,
                pixel.b.toDouble() / 255,
              ];
            },
          ),
        ),
      ];
      final output = [
        [0.0]
      ];
      interpreter.run(input, output);
      final confidence = (output[0][0] as num).toDouble();
      final isEye = confidence >= 0.8;
      return EyeValidationResult(
        isEye: isEye,
        confidence: confidence,
        detectorAvailable: true,
        message:
            isEye ? 'Eye detected.' : 'No suitable lower eyelid was detected.',
      );
    }

    return const EyeValidationResult(
      isEye: false,
      confidence: 0,
      detectorAvailable: false,
      message: 'Eye detection is unavailable. No prediction was produced.',
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
