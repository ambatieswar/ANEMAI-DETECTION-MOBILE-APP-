import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum BrightnessStatus {
  tooDark,
  good,
  tooBright,
}

class BrightnessResult {
  final BrightnessStatus status;
  final double brightness;

  const BrightnessResult({
    required this.status,
    required this.brightness,
  });
}

class BrightnessDetector {
  BrightnessResult check(Uint8List bytes) {
    final image = img.decodeImage(bytes);

    if (image == null) {
      return const BrightnessResult(
        status: BrightnessStatus.tooDark,
        brightness: 0,
      );
    }

    double total = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        total += (pixel.r + pixel.g + pixel.b) / 3;
      }
    }

    final avg = total / (image.width * image.height);

    if (avg < 60) {
      return BrightnessResult(
        status: BrightnessStatus.tooDark,
        brightness: avg,
      );
    }

    if (avg > 210) {
      return BrightnessResult(
        status: BrightnessStatus.tooBright,
        brightness: avg,
      );
    }

    return BrightnessResult(
      status: BrightnessStatus.good,
      brightness: avg,
    );
  }
}
