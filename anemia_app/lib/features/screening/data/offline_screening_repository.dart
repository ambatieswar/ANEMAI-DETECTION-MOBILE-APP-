import 'dart:typed_data';

import '../../../data/tflite_local_datasource.dart';
import '../../../services/image_validator.dart';
import '../domain/screening_repository.dart';
import '../domain/screening_result.dart';

class OfflineScreeningRepository implements ScreeningRepository {
  final ImageValidator validator;
  final TFLiteLocalDataSource model;

  const OfflineScreeningRepository({
    required this.validator,
    required this.model,
  });

  @override
  Future<ScreeningResult> screen(Uint8List imageBytes) async {
    final validation = await validator.validate(imageBytes);
    if (!validation.passed) {
      throw StateError(validation.message);
    }

    final prediction = await model.predict(imageBytes);
    return ScreeningResult(
      label: prediction.label,
      riskProbability: prediction.riskProbability,
      qualityScore: 1,
      createdAt: DateTime.now(),
      heatmap: null,
      disclaimer: 'This application is an AI-assisted screening tool. '
          'It cannot diagnose anemia. Consult a qualified healthcare '
          'professional for laboratory confirmation.',
    );
  }
}
