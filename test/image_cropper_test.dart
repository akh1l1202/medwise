import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/features/ocr_ingestion/domain/services/image_cropper_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCropperService Tests', () {
    late ImageCropperService service;
    late Directory tempDir;
    late String testImagePath;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('medwise_crop_test_');
      service = ImageCropperService(customOutputDir: tempDir);

      // Create a 200x400 test image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.blue;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 400), paint);

      // Draw distinctive center mark
      paint.color = Colors.red;
      canvas.drawRect(const Rect.fromLTWH(50, 100, 100, 200), paint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(200, 400);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      testImagePath = '${tempDir.path}/test_prescription.png';
      await File(testImagePath).writeAsBytes(byteData!.buffer.asUint8List());
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Crops specific sub-rectangle and produces valid image file', () async {
      final croppedPath = await service.cropImage(
        imagePath: testImagePath,
        cropRect: const Rect.fromLTWH(50, 100, 100, 150),
        rotationDegrees: 0,
      );

      final croppedFile = File(croppedPath);
      expect(croppedFile.existsSync(), isTrue);

      final bytes = await croppedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      expect(frame.image.width, equals(100));
      expect(frame.image.height, equals(150));
    });

    test('Handles 90 degree clockwise rotation and swaps dimensions', () async {
      // Rotated 90 deg: 200x400 -> 400x200
      final rotatedPath = await service.rotateImageOnly(
        imagePath: testImagePath,
        rotationDegrees: 90,
      );

      final rotatedFile = File(rotatedPath);
      expect(rotatedFile.existsSync(), isTrue);

      final bytes = await rotatedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      expect(frame.image.width, equals(400));
      expect(frame.image.height, equals(200));
    });

    test('Clamps out-of-bounds crop coordinates safely without crashing', () async {
      // Out of bounds crop request
      final croppedPath = await service.cropImage(
        imagePath: testImagePath,
        cropRect: const Rect.fromLTWH(-50, -50, 500, 800),
        rotationDegrees: 0,
      );

      final croppedFile = File(croppedPath);
      expect(croppedFile.existsSync(), isTrue);

      final bytes = await croppedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      // Must be safely clamped within the 200x400 image bounds
      expect(frame.image.width, lessThanOrEqualTo(200));
      expect(frame.image.height, lessThanOrEqualTo(400));
    });

    test('Crops free perspective quadrilateral with non-parallel and unequal sides', () async {
      // Arbitrary general quadrilateral with non-parallel, unequal opposite sides
      const quad = QuadrilateralPoints(
        topLeft: Offset(20, 50),
        topRight: Offset(180, 70), // tilted top edge
        bottomRight: Offset(190, 350), // non-parallel right edge
        bottomLeft: Offset(30, 320), // non-parallel bottom and left edges
      );

      final croppedPath = await service.cropQuadrilateral(
        imagePath: testImagePath,
        quad: quad,
        rotationDegrees: 0,
      );

      final croppedFile = File(croppedPath);
      expect(croppedFile.existsSync(), isTrue);

      final bytes = await croppedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      expect(frame.image.width, greaterThan(100));
      expect(frame.image.height, greaterThan(200));
    });

    test('Throws FileNotFoundException when image does not exist', () async {
      expect(
        () => service.cropImage(
          imagePath: '/non/existent/path/photo.png',
          cropRect: const Rect.fromLTWH(0, 0, 100, 100),
        ),
        throwsA(isA<FileNotFoundException>()),
      );
    });
  });
}
