import 'dart:typed_data';

import 'screening_result.dart';

abstract interface class ScreeningRepository {
  Future<ScreeningResult> screen(Uint8List imageBytes);
}
