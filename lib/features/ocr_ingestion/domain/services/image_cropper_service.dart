import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final imageCropperServiceProvider = Provider<ImageCropperService>((ref) {
  return ImageCropperService();
});

class ImageCropperService {
  final Directory? customOutputDir;

  ImageCropperService({this.customOutputDir});

  Future<Directory> _getOutputDir() async {
    if (customOutputDir != null) return customOutputDir!;
    return await getTemporaryDirectory();
  }

  /// Crops a rectangular region from an image on disk, optionally applying 0/90/180/270 degree rotation.
  /// Returns the absolute path of the cropped PNG file.
  Future<String> cropImage({
    required String imagePath,
    required Rect cropRect,
    int rotationDegrees = 0,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileNotFoundException(imagePath);
    }

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image originalImage = frame.image;

    final origW = originalImage.width.toDouble();
    final origH = originalImage.height.toDouble();

    final rot = (rotationDegrees % 360 + 360) % 360;

    // Dimensions after rotation
    final double rotatedW = (rot == 90 || rot == 270) ? origH : origW;
    final double rotatedH = (rot == 90 || rot == 270) ? origW : origH;

    // Clamp crop rect to rotated dimensions
    final double safeLeft = cropRect.left.clamp(0.0, math.max(0.0, rotatedW - 1.0)).toDouble();
    final double safeTop = cropRect.top.clamp(0.0, math.max(0.0, rotatedH - 1.0)).toDouble();
    final double safeWidth = cropRect.width.clamp(10.0, rotatedW - safeLeft).toDouble();
    final double safeHeight = cropRect.height.clamp(10.0, rotatedH - safeTop).toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Translate so crop origin (safeLeft, safeTop) is at canvas (0, 0)
    canvas.translate(-safeLeft, -safeTop);

    if (rot == 90) {
      canvas.translate(origH, 0);
      canvas.rotate(math.pi / 2);
    } else if (rot == 180) {
      canvas.translate(origW, origH);
      canvas.rotate(math.pi);
    } else if (rot == 270) {
      canvas.translate(0, origW);
      canvas.rotate(3 * math.pi / 2);
    }

    canvas.drawImage(originalImage, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final croppedUiImage = await picture.toImage(
      safeWidth.round().clamp(1, 10000),
      safeHeight.round().clamp(1, 10000),
    );
    final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode cropped image to PNG');
    }

    final outBytes = byteData.buffer.asUint8List();
    final tempDir = await _getOutputDir();
    final targetPath = '${tempDir.path}/cropped_prescription_${DateTime.now().millisecondsSinceEpoch}.png';
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(outBytes);

    debugPrint('[ImageCropperService] Cropped image saved to: $targetPath (${safeWidth.round()}x${safeHeight.round()})');
    return targetPath;
  }

  /// Rotates the entire image without cropping (used when user chooses "Scan Full Page" with rotation)
  Future<String> rotateImageOnly({
    required String imagePath,
    required int rotationDegrees,
  }) async {
    final rot = (rotationDegrees % 360 + 360) % 360;
    if (rot == 0) return imagePath;

    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image originalImage = frame.image;

    final origW = originalImage.width.toDouble();
    final origH = originalImage.height.toDouble();

    final double rotatedW = (rot == 90 || rot == 270) ? origH : origW;
    final double rotatedH = (rot == 90 || rot == 270) ? origW : origH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (rot == 90) {
      canvas.translate(origH, 0);
      canvas.rotate(math.pi / 2);
    } else if (rot == 180) {
      canvas.translate(origW, origH);
      canvas.rotate(math.pi);
    } else if (rot == 270) {
      canvas.translate(0, origW);
      canvas.rotate(3 * math.pi / 2);
    }

    canvas.drawImage(originalImage, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final rotatedUiImage = await picture.toImage(
      rotatedW.round().clamp(1, 10000),
      rotatedH.round().clamp(1, 10000),
    );
    final byteData = await rotatedUiImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode rotated image to PNG');
    }

    final tempDir = await _getOutputDir();
    final targetPath = '${tempDir.path}/rotated_prescription_${DateTime.now().millisecondsSinceEpoch}.png';
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(byteData.buffer.asUint8List());

    debugPrint('[ImageCropperService] Rotated image saved to: $targetPath');
    return targetPath;
  }
}

class FileNotFoundException implements Exception {
  final String path;
  FileNotFoundException(this.path);
  @override
  String toString() => 'File not found at: $path';
}
