import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/core/constants/app_colors.dart';
import 'package:medwise/core/theme/app_theme.dart';
import 'package:medwise/features/ocr_ingestion/presentation/screens/prescription_crop_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String testImagePath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('medwise_crop_ui_test_');

    // Create a 300x500 dummy prescription image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 500), paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(300, 500);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    testImagePath = '${tempDir.path}/test_slip.png';
    await File(testImagePath).writeAsBytes(byteData!.buffer.asUint8List());
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('PrescriptionCropScreen renders both rotate buttons in Deep Emerald Teal and supports anti-clockwise rotation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: PrescriptionCropScreen(imagePath: testImagePath),
        ),
      ),
    );

    // Pump to process image loading future
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify header title
    expect(find.text('Free Perspective Crop'), findsOneWidget);

    // Verify both anti-clockwise and clockwise rotate buttons exist and no third button
    final antiClockwiseFinder = find.byIcon(Icons.rotate_left_rounded);
    final clockwiseFinder = find.byIcon(Icons.rotate_right_rounded);
    final resetFinder = find.byIcon(Icons.restart_alt_rounded);

    expect(antiClockwiseFinder, findsOneWidget);
    expect(clockwiseFinder, findsOneWidget);
    expect(resetFinder, findsNothing);

    // Verify both rotate icons are colored Deep Emerald Teal (AppColors.primary)
    final Icon antiClockwiseIcon = tester.widget(antiClockwiseFinder);
    final Icon clockwiseIcon = tester.widget(clockwiseFinder);

    expect(antiClockwiseIcon.color, equals(AppColors.primary));
    expect(clockwiseIcon.color, equals(AppColors.primary));

    // Tap anti-clockwise rotate button
    await tester.tap(antiClockwiseFinder);
    await tester.pump(const Duration(milliseconds: 100));

    // Verify no exception occurred
    expect(tester.takeException(), isNull);

    // Tap clockwise rotate button twice
    await tester.tap(clockwiseFinder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(clockwiseFinder);
    await tester.pump(const Duration(milliseconds: 100));

    // Verify no exception occurred
    expect(tester.takeException(), isNull);
  });
}
