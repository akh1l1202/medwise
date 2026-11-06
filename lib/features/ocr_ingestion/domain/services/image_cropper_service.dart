import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final imageCropperServiceProvider = Provider<ImageCropperService>((ref) {
  return ImageCropperService();
});

class QuadrilateralPoints {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const QuadrilateralPoints({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  List<Offset> toList() => [topLeft, topRight, bottomRight, bottomLeft];

  QuadrilateralPoints copyWith({
    Offset? topLeft,
    Offset? topRight,
    Offset? bottomRight,
    Offset? bottomLeft,
  }) {
    return QuadrilateralPoints(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomRight: bottomRight ?? this.bottomRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
    );
  }
}

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

  /// Performs perspective-corrected quadrilateral crop on an image file.
  /// Rectifies any arbitrary quadrilateral (with non-parallel or unequal opposite sides)
  /// into an upright, rectangular image using hardware-accelerated bilinear mesh warping.
  Future<String> cropQuadrilateral({
    required String imagePath,
    required QuadrilateralPoints quad,
    int rotationDegrees = 0,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileNotFoundException(imagePath);
    }

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image rawImage = frame.image;

    final rot = (rotationDegrees % 360 + 360) % 360;

    // If image needs rotation, rotate it first so user quad coordinates match 1:1
    ui.Image workingImage = rawImage;
    if (rot != 0) {
      final origW = rawImage.width.toDouble();
      final origH = rawImage.height.toDouble();
      final rotatedW = (rot == 90 || rot == 270) ? origH : origW;
      final rotatedH = (rot == 90 || rot == 270) ? origW : origH;

      final rotRecorder = ui.PictureRecorder();
      final rotCanvas = Canvas(rotRecorder);
      if (rot == 90) {
        rotCanvas.translate(origH, 0);
        rotCanvas.rotate(math.pi / 2);
      } else if (rot == 180) {
        rotCanvas.translate(origW, origH);
        rotCanvas.rotate(math.pi);
      } else if (rot == 270) {
        rotCanvas.translate(0, origW);
        rotCanvas.rotate(3 * math.pi / 2);
      }
      rotCanvas.drawImage(rawImage, Offset.zero, Paint());
      final rotPic = rotRecorder.endRecording();
      workingImage = await rotPic.toImage(rotatedW.round(), rotatedH.round());
    }

    final p0 = quad.topLeft;
    final p1 = quad.topRight;
    final p2 = quad.bottomRight;
    final p3 = quad.bottomLeft;

    // Calculate rectified destination dimensions based on edge lengths
    final topLen = (p1 - p0).distance;
    final bottomLen = (p2 - p3).distance;
    final leftLen = (p3 - p0).distance;
    final rightLen = (p2 - p1).distance;

    final int targetW = math.max(topLen, bottomLen).round().clamp(30, 4000);
    final int targetH = math.max(leftLen, rightLen).round().clamp(30, 4000);

    // Create a 16x16 bilinear warp mesh
    const int gridSteps = 16;
    final List<Offset> destPositions = [];
    final List<Offset> textureCoordinates = [];

    // Bilinear helper: mapping normalized (u, v) -> source quad point
    Offset interpolateQuad(double u, double v) {
      final x = (1 - u) * (1 - v) * p0.dx +
          u * (1 - v) * p1.dx +
          u * v * p2.dx +
          (1 - u) * v * p3.dx;
      final y = (1 - u) * (1 - v) * p0.dy +
          u * (1 - v) * p1.dy +
          u * v * p2.dy +
          (1 - u) * v * p3.dy;
      return Offset(
        x.clamp(0.0, workingImage.width.toDouble()),
        y.clamp(0.0, workingImage.height.toDouble()),
      );
    }

    for (int i = 0; i < gridSteps; i++) {
      for (int j = 0; j < gridSteps; j++) {
        final u0 = i / gridSteps;
        final u1 = (i + 1) / gridSteps;
        final v0 = j / gridSteps;
        final v1 = (j + 1) / gridSteps;

        final dst00 = Offset(u0 * targetW, v0 * targetH);
        final dst10 = Offset(u1 * targetW, v0 * targetH);
        final dst11 = Offset(u1 * targetW, v1 * targetH);
        final dst01 = Offset(u0 * targetW, v1 * targetH);

        final src00 = interpolateQuad(u0, v0);
        final src10 = interpolateQuad(u1, v0);
        final src11 = interpolateQuad(u1, v1);
        final src01 = interpolateQuad(u0, v1);

        // Triangle 1 (00 -> 10 -> 11)
        destPositions.add(dst00);
        destPositions.add(dst10);
        destPositions.add(dst11);
        textureCoordinates.add(src00);
        textureCoordinates.add(src10);
        textureCoordinates.add(src11);

        // Triangle 2 (00 -> 11 -> 01)
        destPositions.add(dst00);
        destPositions.add(dst11);
        destPositions.add(dst01);
        textureCoordinates.add(src00);
        textureCoordinates.add(src11);
        textureCoordinates.add(src01);
      }
    }

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      destPositions,
      textureCoordinates: textureCoordinates,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final matrix4 = Float64List(16)
      ..[0] = 1.0
      ..[5] = 1.0
      ..[10] = 1.0
      ..[15] = 1.0;

    final shader = ImageShader(
      workingImage,
      TileMode.clamp,
      TileMode.clamp,
      matrix4,
    );

    final paint = Paint()..shader = shader;
    canvas.drawVertices(vertices, BlendMode.src, paint);

    final picture = recorder.endRecording();
    final rectifiedImage = await picture.toImage(targetW, targetH);
    final byteData = await rectifiedImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode quadrilateral cropped image to PNG');
    }

    final tempDir = await _getOutputDir();
    final targetPath = '${tempDir.path}/cropped_quad_${DateTime.now().millisecondsSinceEpoch}.png';
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(byteData.buffer.asUint8List());

    debugPrint('[ImageCropperService] Perspective quadrilateral crop saved to: $targetPath (${targetW}x$targetH)');
    return targetPath;
  }
}

class FileNotFoundException implements Exception {
  final String path;
  FileNotFoundException(this.path);
  @override
  String toString() => 'File not found at: $path';
}
