// Basic smoke test — verifies the app shell renders without errors.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprank_project/app/app.dart';

void main() {
  testWidgets('App shell smoke test', (WidgetTester tester) async {
    // ThemeModeNotifier.build() reads SharedPreferences — provide a mock
    // so the async init completes in the test environment.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TripRankApp());
    // App should render without throwing.
    expect(find.byType(TripRankApp), findsOneWidget);
  });
}
