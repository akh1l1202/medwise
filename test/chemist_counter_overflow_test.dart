import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/core/theme/app_theme.dart';
import 'package:medwise/features/chemist_counter/presentation/screens/chemist_counter_screen.dart';
import 'package:medwise/features/chemist_counter/presentation/widgets/prescription_scan_modal.dart';

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

  testWidgets('ChemistCounterScreen has exactly one contextual Scan Slip button and no duplicate in AppBar', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChemistCounterScreen(),
        ),
      ),
    );

    // Verify exactly one "Scan Slip" widget exists
    expect(find.text('Scan Slip'), findsOneWidget);

    // Verify the AppBar actions does NOT contain a document scanner button
    final appBar = find.byType(AppBar);
    expect(appBar, findsOneWidget);
    expect(
      find.descendant(
        of: appBar,
        matching: find.byIcon(Icons.document_scanner_outlined),
      ),
      findsNothing,
    );
  });

  testWidgets('PrescriptionScanModal wraps content height (~50%) on open without empty bottom space', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
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

    // Tap Scan Slip
    await tester.tap(find.text('Scan Slip'));
    await tester.pumpAndSettle();

    // Verify modal is visible
    expect(find.text('Scan Prescription Slip'), findsOneWidget);
    expect(find.text('Snap a photo of the printed prescription'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    // Find the modal sheet size
    final modalFinder = find.byType(PrescriptionScanModal);
    expect(modalFinder, findsOneWidget);
    final modalSize = tester.getSize(modalFinder);

    // Verify modal height wraps to content (~50% of screen height, well below 88% = 704px)
    expect(modalSize.height, lessThan(500));
    expect(modalSize.height, greaterThan(250));
  });
}
