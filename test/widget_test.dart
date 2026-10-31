
import 'package:flutter_test/flutter_test.dart';
import 'package:project_1/main.dart';

void main() {
  testWidgets('Sayanti app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SayantiApp());

    expect(find.text('أهلاً بك في صيانتي'), findsOneWidget);
    expect(find.text('خدمات الصيانة'), findsOneWidget);
  });
}
