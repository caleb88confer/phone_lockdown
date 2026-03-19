import 'package:flutter_test/flutter_test.dart';
import 'package:broke_app/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BrokeApp());
    expect(find.text('Broke'), findsOneWidget);
  });
}
