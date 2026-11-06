import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/core/theme/app_theme.dart';
import 'package:medwise/features/cabinet/data/models/cabinet_item.dart';
import 'package:medwise/features/cabinet/presentation/widgets/emergency_search_dialog.dart';

void main() {
  final sampleCabinet = [
    CabinetItem(
      id: 'item-1',
      brandName: 'Dolo 650',
      activeSalt: 'Paracetamol',
      strength: '650mg',
      form: 'Tablet',
      quantityRemaining: 15,
      printedExpiry: '12/2026',
      storageLocation: 'First Aid Box',
      symptomTags: ['Fever', 'Headache', 'Body Pain'],
      profileId: 'profile-1',
      createdAt: DateTime.now(),
    ),
    CabinetItem(
      id: 'item-2',
      brandName: 'Pan 40',
      activeSalt: 'Pantoprazole',
      strength: '40mg',
      form: 'Tablet',
      quantityRemaining: 8,
      printedExpiry: '06/2026',
      storageLocation: 'Kitchen Shelf',
      symptomTags: ['Acidity', 'Heartburn', 'GERD'],
      profileId: 'profile-1',
      createdAt: DateTime.now(),
    ),
    CabinetItem(
      id: 'item-3',
      brandName: 'Refresh Tears',
      activeSalt: 'Carboxymethylcellulose',
      strength: '0.5%',
      form: 'Ophthalmic Drop',
      quantityRemaining: 1,
      printedExpiry: '10/2026',
      storageLocation: 'Bedside Table',
      symptomTags: ['Dry Eyes', 'Eye Irritation'],
      profileId: 'profile-1',
      createdAt: DateTime.now(),
    ),
  ];

  testWidgets('EmergencySearchDialog renders without overflow on compact screen', (WidgetTester tester) async {
    // Set a compact screen size typical of smaller Android devices
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    CabinetItem? selectedItem;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => EmergencySearchDialog(
                    cabinetItems: sampleCabinet,
                    onSelect: (item) => selectedItem = item,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify title and symptom chips rendered
    expect(find.text('2:00 AM Quick Finder'), findsOneWidget);
    expect(find.text('Acidity'), findsOneWidget);
    expect(find.text('Fever'), findsOneWidget);

    // Initial items visible
    expect(find.text('Dolo 650'), findsOneWidget);
    expect(find.text('Pan 40'), findsOneWidget);

    // Filter by tapping 'Acidity' symptom chip
    await tester.tap(find.text('Acidity'));
    await tester.pumpAndSettle();

    // Verify Pan 40 is visible and Dolo 650 is filtered out
    expect(find.text('Pan 40'), findsOneWidget);
    expect(find.text('Dolo 650'), findsNothing);

    // Tap Pan 40 to select
    await tester.tap(find.text('Pan 40'));
    await tester.pumpAndSettle();

    // Verify dialog closed and item was passed to onSelect
    expect(find.text('2:00 AM Quick Finder'), findsNothing);
    expect(selectedItem?.brandName, 'Pan 40');
  });

  testWidgets('EmergencySearchDialog close button dismisses dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => EmergencySearchDialog(
                    cabinetItems: sampleCabinet,
                    onSelect: (_) {},
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('2:00 AM Quick Finder'), findsOneWidget);

    // Tap close icon button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('2:00 AM Quick Finder'), findsNothing);
  });
}
