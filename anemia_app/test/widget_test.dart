import 'package:flutter_test/flutter_test.dart';
import 'package:anemia_app/main.dart';

void main() {
  testWidgets('Anemia app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AnemiaApp());

    expect(find.text('Anemia Screening'), findsOneWidget);
    expect(find.text('Start Screening'), findsOneWidget);
  });
}
