import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class AnemiaPrediction {
  final String label;
  final double riskProbability;

  const AnemiaPrediction({
    required this.label,
    required this.riskProbability,
  });

  bool get suggestsIncreasedRisk =>
      label == 'AI Screening Suggests Increased Risk';
}

class TFLiteLocalDataSource {
  Interpreter? _interpreter;
  Map<String, dynamic>? _manifest;

  static const int inputSize = 224;

  Future<void> loadModel() async {
    if (_interpreter != null) {
      return;
    }

    final manifestJson =
        await rootBundle.loadString('assets/model_manifest.json');
    final manifest = jsonDecode(manifestJson);
    if (manifest is! Map<String, dynamic>) {
      throw StateError('The local model manifest is invalid.');
    }

    _manifest = manifest;
    if (manifest['enabled'] != true) {
      throw StateError(
        'Offline AI screening is disabled until a validated model package '
        'is installed. No prediction was produced.',
      );
    }

    final modelBytes = await rootBundle.load('assets/anemia_model.tflite');
    final expectedHash = manifest['model_sha256'] as String?;
    if (expectedHash != null) {
      final actualHash =
          sha256.convert(modelBytes.buffer.asUint8List()).toString();
      if (actualHash != expectedHash) {
        throw StateError('The local model integrity hash does not match.');
      }
    }

    _interpreter = await Interpreter.fromAsset('assets/anemia_model.tflite');

    final input = _interpreter!.getInputTensor(0);
    final output = _interpreter!.getOutputTensor(0);
    final expectedInput = manifest['input'] as Map<String, dynamic>?;
    if (input.shape.length != 4 ||
        input.shape[1] != expectedInput?['height'] ||
        input.shape[2] != expectedInput?['width'] ||
        input.shape[3] != expectedInput?['channels']) {
      dispose();
      throw StateError('The local model input does not match its manifest.');
    }
    if (output.shape.length != 2 || output.shape[1] != 1) {
      dispose();
      throw StateError('The local model output does not match its manifest.');
    }
  }

  Future<AnemiaPrediction> predict(Uint8List imageBytes) async {
    await loadModel();

    final interpreter = _interpreter!;

    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Unable to decode the captured image.');
    }

    // Resize the image to the exact model input size.
    final resizedImage = img.copyResize(
      decodedImage,
      width: inputSize,
      height: inputSize,
    );

    final inputContract = _manifest?['input'] as Map<String, dynamic>?;
    final normalization = inputContract?['normalization'];
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resizedImage.getPixel(x, y);

            final rgb = <double>[
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0,
            ];
            if (normalization == 'mobilenet_v3_preprocess_input') {
              return rgb.map((channel) => (channel * 2) - 1).toList();
            }
            return rgb;
          },
        ),
      ),
    );

    // Model output:
    // [1, 1]
    final output = [
      [0.0]
    ];

    interpreter.run(input, output);

    final positiveProbability = (output[0][0] as num).toDouble();
    if (positiveProbability < 0 || positiveProbability > 1) {
      throw StateError('The model returned an invalid probability.');
    }

    return AnemiaPrediction(
      label: positiveProbability >= 0.5
          ? 'AI Screening Suggests Increased Risk'
          : 'AI Screening Does Not Suggest Increased Risk',
      riskProbability: positiveProbability,
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
