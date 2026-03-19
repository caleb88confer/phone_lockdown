import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PhoneLockdownApp(onboardingComplete: true));
    expect(find.text('Phone Lockdown'), findsOneWidget);
  });
}
