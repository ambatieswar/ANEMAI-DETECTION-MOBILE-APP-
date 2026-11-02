import 'dart:typed_data';

import 'package:image/image.dart' as img;

class BlurResult {
  final bool isBlurry;
  final double score;

  const BlurResult({
    required this.isBlurry,
    required this.score,
  });
}

class BlurDetector {
  /// Lower threshold = more strict.
  static const double threshold = 80;

  BlurResult check(Uint8List bytes) {
    final image = img.decodeImage(bytes);

    if (image == null) {
      return const BlurResult(
        isBlurry: true,
        score: 0,
      );
    }

    final gray = img.grayscale(image);

    double mean = 0;
    double variance = 0;

    final values = <int>[];

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        values.add(pixel.r.toInt());
      }
    }

    mean = values.reduce((a, b) => a + b) / values.length;

    for (final value in values) {
      variance += (value - mean) * (value - mean);
    }

    variance /= values.length;

    return BlurResult(
      isBlurry: variance < threshold,
      score: variance,
    );
  }
}
