import 'dart:typed_data';

import 'package:anemia_app/services/eye_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not accept an image without a real eye detector', () async {
    final result = await EyeValidator().validate(Uint8List(0));

    expect(result.detectorAvailable, isFalse);
    expect(result.isEye, isFalse);
    expect(result.confidence, 0);
    expect(result.message, contains('No prediction was produced'));
  });
}
