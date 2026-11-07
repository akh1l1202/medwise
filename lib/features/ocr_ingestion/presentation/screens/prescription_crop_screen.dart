import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/services/image_cropper_service.dart';

enum _ActiveCorner {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
  none,
}

/// A flexible perspective prescription cropping screen that allows users
/// to freely position 4 independent corners to form any quadrilateral
/// (trapezoid, tilted rectangle, or arbitrary non-parallel polygon).
/// Automatically rectifies perspective distortion so that ML Kit OCR reads
/// horizontal, crystal-clear text lines with maximum confidence.
class PrescriptionCropScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const PrescriptionCropScreen({
    super.key,
    required this.imagePath,
  });

  @override
  ConsumerState<PrescriptionCropScreen> createState() => _PrescriptionCropScreenState();
}

class _PrescriptionCropScreenState extends ConsumerState<PrescriptionCropScreen> {
  ui.Image? _loadedImage;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  int _rotationDegrees = 0; // 0, 90, 180, 270

  // 4 corners of the free quadrilateral on screen
  QuadrilateralPoints? _quad;
  Rect? _imageDisplayRect;
  double _scale = 1.0;
  Size _lastViewportSize = Size.zero;

  _ActiveCorner _activeCorner = _ActiveCorner.none;
  bool _isPanningPolygon = false;

  static const double _cornerHitRadius = 44.0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final file = File(widget.imagePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'Prescription image file not found.';
          _isLoading = false;
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _loadedImage = frame.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load prescription: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
      // Invalidate quad so it re-centers on the newly rotated orientation
      _quad = null;
    });
  }

  void _rotateCounterClockwise() {
    setState(() {
      _rotationDegrees = (_rotationDegrees - 90 + 360) % 360;
      // Invalidate quad so it re-centers on the newly rotated orientation
      _quad = null;
    });
  }

  void _updateLayout(Size viewportSize) {
    if (_loadedImage == null) return;
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

    final origW = _loadedImage!.width.toDouble();
    final origH = _loadedImage!.height.toDouble();

    final isSideways = (_rotationDegrees == 90 || _rotationDegrees == 270);
    final rotW = isSideways ? origH : origW;
    final rotH = isSideways ? origW : origH;

    final scale = math.min(
      viewportSize.width / rotW,
      viewportSize.height / rotH,
    );
    final renderedW = rotW * scale;
    final renderedH = rotH * scale;
    final offsetX = (viewportSize.width - renderedW) / 2.0;
    final offsetY = (viewportSize.height - renderedH) / 2.0;

    _scale = scale;
    _imageDisplayRect = Rect.fromLTWH(offsetX, offsetY, renderedW, renderedH);

    // If quad is not initialized or viewport changed significantly
    if (_quad == null || viewportSize != _lastViewportSize) {
      _lastViewportSize = viewportSize;

      // Default free quadrilateral: middle 84% width, 18% to 82% height
      final leftX = offsetX + (renderedW * 0.08);
      final rightX = offsetX + (renderedW * 0.92);
      final topY = offsetY + (renderedH * 0.18);
      final bottomY = offsetY + (renderedH * 0.82);

      _quad = QuadrilateralPoints(
        topLeft: Offset(leftX, topY),
        topRight: Offset(rightX, topY),
        bottomRight: Offset(rightX, bottomY),
        bottomLeft: Offset(leftX, bottomY),
      );
    }
  }

  bool _isPointInQuad(Offset pos, QuadrilateralPoints quad) {
    final poly = Path()
      ..addPolygon([quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft], true);
    return poly.contains(pos);
  }

  void _onPanStart(DragStartDetails details) {
    if (_quad == null || _imageDisplayRect == null) return;

    final pos = details.localPosition;

    // Check 4 corner grab handles first
    if ((pos - _quad!.topLeft).distance <= _cornerHitRadius) {
      _activeCorner = _ActiveCorner.topLeft;
      _isPanningPolygon = false;
    } else if ((pos - _quad!.topRight).distance <= _cornerHitRadius) {
      _activeCorner = _ActiveCorner.topRight;
      _isPanningPolygon = false;
    } else if ((pos - _quad!.bottomRight).distance <= _cornerHitRadius) {
      _activeCorner = _ActiveCorner.bottomRight;
      _isPanningPolygon = false;
    } else if ((pos - _quad!.bottomLeft).distance <= _cornerHitRadius) {
      _activeCorner = _ActiveCorner.bottomLeft;
      _isPanningPolygon = false;
    } else if (_isPointInQuad(pos, _quad!)) {
      _activeCorner = _ActiveCorner.none;
      _isPanningPolygon = true;
    } else {
      _activeCorner = _ActiveCorner.none;
      _isPanningPolygon = false;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_quad == null || _imageDisplayRect == null) return;
    final img = _imageDisplayRect!;
    final pos = details.localPosition;
    final delta = details.delta;

    setState(() {
      if (_activeCorner == _ActiveCorner.topLeft) {
        final clamped = Offset(
          pos.dx.clamp(img.left, img.right),
          pos.dy.clamp(img.top, img.bottom),
        );
        _quad = _quad!.copyWith(topLeft: clamped);
      } else if (_activeCorner == _ActiveCorner.topRight) {
        final clamped = Offset(
          pos.dx.clamp(img.left, img.right),
          pos.dy.clamp(img.top, img.bottom),
        );
        _quad = _quad!.copyWith(topRight: clamped);
      } else if (_activeCorner == _ActiveCorner.bottomRight) {
        final clamped = Offset(
          pos.dx.clamp(img.left, img.right),
          pos.dy.clamp(img.top, img.bottom),
        );
        _quad = _quad!.copyWith(bottomRight: clamped);
      } else if (_activeCorner == _ActiveCorner.bottomLeft) {
        final clamped = Offset(
          pos.dx.clamp(img.left, img.right),
          pos.dy.clamp(img.top, img.bottom),
        );
        _quad = _quad!.copyWith(bottomLeft: clamped);
      } else if (_isPanningPolygon) {
        // Shift entire quadrilateral simultaneously, keeping all 4 corners inside image bounds
        final minX = math.min(math.min(_quad!.topLeft.dx, _quad!.topRight.dx), math.min(_quad!.bottomLeft.dx, _quad!.bottomRight.dx));
        final maxX = math.max(math.max(_quad!.topLeft.dx, _quad!.topRight.dx), math.max(_quad!.bottomLeft.dx, _quad!.bottomRight.dx));
        final minY = math.min(math.min(_quad!.topLeft.dy, _quad!.topRight.dy), math.min(_quad!.bottomLeft.dy, _quad!.bottomRight.dy));
        final maxY = math.max(math.max(_quad!.topLeft.dy, _quad!.topRight.dy), math.max(_quad!.bottomLeft.dy, _quad!.bottomRight.dy));

        final safeDx = delta.dx.clamp(img.left - minX, img.right - maxX);
        final safeDy = delta.dy.clamp(img.top - minY, img.bottom - maxY);
        final safeShift = Offset(safeDx, safeDy);

        _quad = QuadrilateralPoints(
          topLeft: _quad!.topLeft + safeShift,
          topRight: _quad!.topRight + safeShift,
          bottomRight: _quad!.bottomRight + safeShift,
          bottomLeft: _quad!.bottomLeft + safeShift,
        );
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _activeCorner = _ActiveCorner.none;
      _isPanningPolygon = false;
    });
  }

  Future<void> _scanCroppedArea() async {
    if (_loadedImage == null || _quad == null || _imageDisplayRect == null) return;

    setState(() => _isProcessing = true);

    try {
      // Map screen quadrilateral points to image pixels
      final img = _imageDisplayRect!;
      final quadImg = QuadrilateralPoints(
        topLeft: Offset((_quad!.topLeft.dx - img.left) / _scale, (_quad!.topLeft.dy - img.top) / _scale),
        topRight: Offset((_quad!.topRight.dx - img.left) / _scale, (_quad!.topRight.dy - img.top) / _scale),
        bottomRight: Offset((_quad!.bottomRight.dx - img.left) / _scale, (_quad!.bottomRight.dy - img.top) / _scale),
        bottomLeft: Offset((_quad!.bottomLeft.dx - img.left) / _scale, (_quad!.bottomLeft.dy - img.top) / _scale),
      );

      final cropper = ref.read(imageCropperServiceProvider);
      final croppedPath = await cropper.cropQuadrilateral(
        imagePath: widget.imagePath,
        quad: quadImg,
        rotationDegrees: _rotationDegrees,
      );

      if (mounted) {
        Navigator.of(context).pop(croppedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop perspective area: $e')),
        );
      }
    }
  }

  Future<void> _scanFullPage() async {
    setState(() => _isProcessing = true);
    try {
      final cropper = ref.read(imageCropperServiceProvider);
      // If image was rotated, rotate full page so ML Kit reads upright text
      final fullPath = await cropper.rotateImageOnly(
        imagePath: widget.imagePath,
        rotationDegrees: _rotationDegrees,
      );

      if (mounted) {
        Navigator.of(context).pop(fullPath);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(widget.imagePath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Free Perspective Crop',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              'Drag any corner to match prescription angle',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_left_rounded, size: 24, color: AppColors.primary),
            tooltip: 'Rotate 90° Anti-Clockwise',
            onPressed: _isLoading || _isProcessing ? null : _rotateCounterClockwise,
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, size: 24, color: AppColors.primary),
            tooltip: 'Rotate 90° Clockwise',
            onPressed: _isLoading || _isProcessing ? null : _rotateClockwise,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Pro-Tip Guidance Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.crop_rotate_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Drag all 4 corners freely to match the angle of the slip. Perspective is automatically straightened for >95% OCR accuracy.',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Interactive Free Quadrilateral Crop & Preview Area
            Expanded(
              child: Container(
                color: const Color(0xFFE2E8F0), // Neutral slate workbench
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text('Loading prescription photo...', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                              _updateLayout(viewportSize);

                              return GestureDetector(
                                onPanStart: _onPanStart,
                                onPanUpdate: _onPanUpdate,
                                onPanEnd: _onPanEnd,
                                child: Stack(
                                  children: [
                                    // 1. Rendered Image
                                    if (_imageDisplayRect != null && _loadedImage != null)
                                      Positioned.fromRect(
                                        rect: _imageDisplayRect!,
                                        child: RotatedBox(
                                          quarterTurns: (_rotationDegrees ~/ 90) % 4,
                                          child: RawImage(
                                            image: _loadedImage,
                                            fit: BoxFit.fill,
                                          ),
                                        ),
                                      ),

                                    // 2. Custom Painter Scrim & Free Quadrilateral
                                    if (_quad != null && _imageDisplayRect != null)
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _FreeQuadrilateralOverlayPainter(
                                            quad: _quad!,
                                            imageRect: _imageDisplayRect!,
                                            activeCorner: _activeCorner,
                                          ),
                                        ),
                                      ),

                                    // 3. Floating "Perspective Crop" Badge above topmost corner
                                    if (_quad != null)
                                      Positioned(
                                        left: math.min(_quad!.topLeft.dx, _quad!.topRight.dx) + 8,
                                        top: math.max(0.0, math.min(_quad!.topLeft.dy, _quad!.topRight.dy) - 30),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x33000000),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.view_in_ar_rounded, size: 12, color: Colors.white),
                                              SizedBox(width: 4),
                                              Text(
                                                'Perspective Straightening Active',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // Processing Indicator
                                    if (_isProcessing)
                                      Container(
                                        color: Colors.white.withValues(alpha: 0.88),
                                        child: const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(color: AppColors.primary),
                                              SizedBox(height: 16),
                                              Text(
                                                'Straightening Perspective & Extracting Medicines...',
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                'Warping quadrilateral mesh to horizontal text',
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 6,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Option to scan entire uncropped page
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isProcessing || _isLoading ? null : _scanFullPage,
                      child: const Text('Scan Full Slip', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Primary Button to crop & scan
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.crop_rotate_rounded, size: 20),
                      label: const Text(
                        'Scan Cropped Area',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _isProcessing || _isLoading ? null : _scanCroppedArea,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering the frosted translucent scrim around an arbitrary quadrilateral,
/// perspective 3x3 grid guidelines, perimeter boundary, and tactile grab handles.
class _FreeQuadrilateralOverlayPainter extends CustomPainter {
  final QuadrilateralPoints quad;
  final Rect imageRect;
  final _ActiveCorner activeCorner;

  _FreeQuadrilateralOverlayPainter({
    required this.quad,
    required this.imageRect,
    required this.activeCorner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw outer frosted slate scrim outside the arbitrary quadrilateral
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPolygon([quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft], true)
      ..fillType = PathFillType.evenOdd;

    final scrimPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, scrimPaint);

    // 2. Draw 3x3 Perspective Grid Guidelines (bilinear subdivision across edges)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.60)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    Offset interp(double u, double v) {
      final x = (1 - u) * (1 - v) * quad.topLeft.dx +
          u * (1 - v) * quad.topRight.dx +
          u * v * quad.bottomRight.dx +
          (1 - u) * v * quad.bottomLeft.dx;
      final y = (1 - u) * (1 - v) * quad.topLeft.dy +
          u * (1 - v) * quad.topRight.dy +
          u * v * quad.bottomRight.dy +
          (1 - u) * v * quad.bottomLeft.dy;
      return Offset(x, y);
    }

    // Vertical perspective lines at 1/3 and 2/3
    canvas.drawLine(interp(1 / 3, 0), interp(1 / 3, 1), gridPaint);
    canvas.drawLine(interp(2 / 3, 0), interp(2 / 3, 1), gridPaint);

    // Horizontal perspective lines at 1/3 and 2/3
    canvas.drawLine(interp(0, 1 / 3), interp(1, 1 / 3), gridPaint);
    canvas.drawLine(interp(0, 2 / 3), interp(1, 2 / 3), gridPaint);

    // 3. Draw Emerald Teal Quadrilateral Perimeter
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final polyPath = Path()
      ..addPolygon([quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft], true);
    canvas.drawPath(polyPath, borderPaint);

    // 4. Draw 4 Corner Grab Handles
    void drawCornerHandle(Offset pos, bool isActive) {
      final outerRadius = isActive ? 18.0 : 14.0;
      final innerRadius = isActive ? 11.0 : 8.5;

      // Drop shadow for tactile floating appearance
      canvas.drawCircle(
        pos + const Offset(0, 2),
        outerRadius,
        Paint()..color = const Color(0x33000000),
      );

      // Emerald Teal outer handle ring
      canvas.drawCircle(
        pos,
        outerRadius,
        Paint()..color = isActive ? AppColors.primaryLight : AppColors.primary,
      );

      // Crisp White inner grab pad
      canvas.drawCircle(
        pos,
        innerRadius,
        Paint()..color = Colors.white,
      );

      // Center precision bullseye
      canvas.drawCircle(
        pos,
        3.5,
        Paint()..color = AppColors.primary,
      );
    }

    drawCornerHandle(quad.topLeft, activeCorner == _ActiveCorner.topLeft);
    drawCornerHandle(quad.topRight, activeCorner == _ActiveCorner.topRight);
    drawCornerHandle(quad.bottomRight, activeCorner == _ActiveCorner.bottomRight);
    drawCornerHandle(quad.bottomLeft, activeCorner == _ActiveCorner.bottomLeft);
  }

  @override
  bool shouldRepaint(covariant _FreeQuadrilateralOverlayPainter oldDelegate) {
    return oldDelegate.quad != quad ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.activeCorner != activeCorner;
  }
}
