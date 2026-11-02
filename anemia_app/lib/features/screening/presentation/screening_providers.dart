import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/tflite_local_datasource.dart';
import '../../../services/image_validator.dart';
import '../data/offline_screening_repository.dart';
import '../domain/screening_repository.dart';

final screeningRepositoryProvider = Provider<ScreeningRepository>((ref) {
  final model = TFLiteLocalDataSource();
  ref.onDispose(model.dispose);
  return OfflineScreeningRepository(
    validator: ImageValidator(),
    model: model,
  );
});
