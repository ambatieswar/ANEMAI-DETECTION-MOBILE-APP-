import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:anemia_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('application starts in safe screening mode', (tester) async {
    await tester.pumpWidget(const AnemiaApp());
    await tester.pumpAndSettle();

    expect(find.text('Start Screening'), findsOneWidget);
    expect(find.text('AI-Powered\nAnemia Screening'), findsOneWidget);
  });
}
