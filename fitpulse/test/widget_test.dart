import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpulse/main.dart';

void main() {
  testWidgets('FitPulse onboarding smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: FitPulseApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Onboarding Screen renders on fresh start
    expect(find.text('Welcome to FitPulse'), findsOneWidget);
    expect(find.text('Your Full Name'), findsOneWidget);
    expect(find.text('Your Age'), findsOneWidget);
  });
}
