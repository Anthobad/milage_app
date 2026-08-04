// Basic smoke test — verifies the app shell renders without errors.

import 'package:flutter_test/flutter_test.dart';
import 'package:triprank_project/app/app.dart';

void main() {
  testWidgets('App shell smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TripRankApp());
    // App should render without throwing.
    expect(find.byType(TripRankApp), findsOneWidget);
  });
}
