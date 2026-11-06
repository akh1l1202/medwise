import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/app.dart';

void main() {
  testWidgets('MedWiseApp launches with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MedWiseApp(),
      ),
    );

    // Verify app bar brand title and offline status
    expect(find.text('MedWise'), findsOneWidget);
    expect(find.text('100% Offline Safe'), findsOneWidget);

    // Verify navigation tabs
    expect(find.text('Cabinet'), findsOneWidget);
    expect(find.text('Chemist Buy'), findsOneWidget);
    expect(find.text('Scan Strip'), findsOneWidget);
    expect(find.text('Adherence'), findsOneWidget);
  });
}
