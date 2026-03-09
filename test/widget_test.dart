import 'package:flutter_test/flutter_test.dart';
import 'package:focusmateapp/main.dart';

void main() {
  testWidgets('FocusMate smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FocusMateApp());

    // Verify that the app title is present
    expect(find.text('FocusMate'), findsOneWidget);
  });
}
