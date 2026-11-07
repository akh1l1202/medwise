import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/core/theme/app_theme.dart';
import 'package:medwise/features/chemist_counter/presentation/screens/chemist_counter_screen.dart';

void main() {
  testWidgets('ChemistCounterScreen does not overflow when search bar is focused with keyboard up on compact screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChemistCounterScreen(),
        ),
      ),
    );

    // Verify initial screen renders
    expect(find.text('Chemist Counter "Smart Buy"'), findsOneWidget);
    expect(find.text('Enter Prescribed Medicine'), findsOneWidget);
    expect(find.text('Your Prescription Cart is Empty'), findsOneWidget);

    // Simulate opening keyboard (bottom inset = 350 on 640px screen leaves only 290px!)
    tester.view.viewInsets = const FakeViewPadding(bottom: 350);
    addTearDown(() => tester.view.resetViewInsets());

    // Tap search bar
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.tap(searchField);
    await tester.pumpAndSettle();

    // Verify no RenderFlex overflow occurred
    expect(tester.takeException(), isNull);
  });
}
