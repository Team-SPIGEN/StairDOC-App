// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stairdoc/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Splash screen renders app branding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StairDocApp());

    expect(find.text('Delivery Robot Control'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.textContaining(
        'autonomous stair-climbing deliveries',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
