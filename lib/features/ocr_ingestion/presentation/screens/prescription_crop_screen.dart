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
  bottomLeft,
  bottomRight,
  none,
}

/// A focused prescription image cropping screen that lets the user
/// isolate the medicine names and dosage table on a doctor's slip.
/// Eliminates hospital logos, headers, stamps, and footer disclaimers,
/// maximizing OCR reading confidence and precision.
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

  // Coordinates on screen
  Rect? _cropRect;
  Rect? _imageDisplayRect;
  double _scale = 1.0;
  Size _lastViewportSize = Size.zero;

  _ActiveCorner _activeCorner = _ActiveCorner.none;
  bool _isPanningBox = false;

  static const double _minCropSize = 70.0;
  static const double _cornerHitRadius = 38.0;

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
      // Invalidate crop rect so it re-centers on the newly rotated orientation
      _cropRect = null;
    });
  }

  void _resetCrop() {
    setState(() {
      _cropRect = null;
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

    // If crop rect is not initialized or viewport changed significantly
    if (_cropRect == null || viewportSize != _lastViewportSize) {
      _lastViewportSize = viewportSize;

      // Default crop: middle 85% width, middle 20% to 85% height (typical medicine Rx zone)
      final cropW = renderedW * 0.88;
      final cropH = renderedH * 0.65;
      final cropX = offsetX + (renderedW - cropW) / 2.0;
      final cropY = offsetY + (renderedH * 0.18);

      _cropRect = Rect.fromLTWH(
        cropX,
        cropY.clamp(offsetY, offsetY + renderedH - _minCropSize),
        cropW.clamp(_minCropSize, renderedW),
        cropH.clamp(_minCropSize, renderedH),
      );
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_cropRect == null || _imageDisplayRect == null) return;

    final pos = details.localPosition;

    // Check corner handles
    if ((pos - _cropRect!.topLeft).distance <= _cornerHitRadius) {
      _activeCorner = _ActiveCorner.topLeft;
      _isPanningBox = false;
    } else if ((pos - _cropRect!.topRight).distance <= _cornerHitRadius) {
      _activeCorner = _ActiveCorner.topRight;
      _isPanningBox = false;
    } else if ((pos - _cropRect!.bottomLeft).distance <= _cornerHitRadius) {
      _activeCorner = _ActiveCorner.bottomLeft;
      _isPanningBox = false;
    } else if ((pos - _cropRect!.bottomRight).distance <= _cornerHitRadius) {
      _activeCorner = _ActiveCorner.bottomRight;
      _isPanningBox = false;
    } else if (_cropRect!.contains(pos)) {
      _activeCorner = _ActiveCorner.none;
      _isPanningBox = true;
    } else {
      _activeCorner = _ActiveCorner.none;
      _isPanningBox = false;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_cropRect == null || _imageDisplayRect == null) return;
    final img = _imageDisplayRect!;
    final delta = details.delta;

    setState(() {
      if (_activeCorner == _ActiveCorner.topLeft) {
        final newLeft = (details.localPosition.dx).clamp(img.left, _cropRect!.right - _minCropSize);
        final newTop = (details.localPosition.dy).clamp(img.top, _cropRect!.bottom - _minCropSize);
        _cropRect = Rect.fromLTRB(newLeft, newTop, _cropRect!.right, _cropRect!.bottom);
      } else if (_activeCorner == _ActiveCorner.topRight) {
        final newRight = (details.localPosition.dx).clamp(_cropRect!.left + _minCropSize, img.right);
        final newTop = (details.localPosition.dy).clamp(img.top, _cropRect!.bottom - _minCropSize);
        _cropRect = Rect.fromLTRB(_cropRect!.left, newTop, newRight, _cropRect!.bottom);
      } else if (_activeCorner == _ActiveCorner.bottomLeft) {
        final newLeft = (details.localPosition.dx).clamp(img.left, _cropRect!.right - _minCropSize);
        final newBottom = (details.localPosition.dy).clamp(_cropRect!.top + _minCropSize, img.bottom);
        _cropRect = Rect.fromLTRB(newLeft, _cropRect!.top, _cropRect!.right, newBottom);
      } else if (_activeCorner == _ActiveCorner.bottomRight) {
        final newRight = (details.localPosition.dx).clamp(_cropRect!.left + _minCropSize, img.right);
        final newBottom = (details.localPosition.dy).clamp(_cropRect!.top + _minCropSize, img.bottom);
        _cropRect = Rect.fromLTRB(_cropRect!.left, _cropRect!.top, newRight, newBottom);
      } else if (_isPanningBox) {
        final newLeft = (_cropRect!.left + delta.dx).clamp(img.left, img.right - _cropRect!.width);
        final newTop = (_cropRect!.top + delta.dy).clamp(img.top, img.bottom - _cropRect!.height);
        _cropRect = Rect.fromLTWH(newLeft, newTop, _cropRect!.width, _cropRect!.height);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _activeCorner = _ActiveCorner.none;
    _isPanningBox = false;
  }

  Future<void> _scanCroppedArea() async {
    if (_loadedImage == null || _cropRect == null || _imageDisplayRect == null) return;

    setState(() => _isProcessing = true);

    try {
      // Map screen crop rect to rotated image pixels
      final img = _imageDisplayRect!;
      final pixelCropX = (_cropRect!.left - img.left) / _scale;
      final pixelCropY = (_cropRect!.top - img.top) / _scale;
      final pixelCropW = _cropRect!.width / _scale;
      final pixelCropH = _cropRect!.height / _scale;

      final pixelRect = Rect.fromLTWH(pixelCropX, pixelCropY, pixelCropW, pixelCropH);

      final cropper = ref.read(imageCropperServiceProvider);
      final croppedPath = await cropper.cropImage(
        imagePath: widget.imagePath,
        cropRect: pixelRect,
        rotationDegrees: _rotationDegrees,
      );

      if (mounted) {
        Navigator.of(context).pop(croppedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop image: $e')),
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
      backgroundColor: const Color(0xFF0B131A), // Deep dark matte backdrop for optimal preview
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Prescribed Medicines',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Crop out logos & headers for >95% OCR accuracy',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, size: 24),
            tooltip: 'Rotate 90°',
            onPressed: _isLoading || _isProcessing ? null : _rotateClockwise,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, size: 24),
            tooltip: 'Reset Crop Window',
            onPressed: _isLoading || _isProcessing ? null : _resetCrop,
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
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.crop_free_rounded, color: AppColors.primaryLight, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Drag the corner handles around the medicine names and dosages only. Exclude hospital headers & footers.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Interactive Crop & Preview Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primaryLight),
                          SizedBox(height: 16),
                          Text('Loading prescription photo...', style: TextStyle(color: Colors.white70)),
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

                                  // 2. Custom Painter Scrim & Crop Box
                                  if (_cropRect != null && _imageDisplayRect != null)
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _CropOverlayPainter(
                                          cropRect: _cropRect!,
                                          imageRect: _imageDisplayRect!,
                                        ),
                                      ),
                                    ),

                                  // 3. Floating "Medicine List Area" Label
                                  if (_cropRect != null)
                                    Positioned(
                                      left: _cropRect!.left + 8,
                                      top: math.max(0.0, _cropRect!.top - 28),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black45,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.medication_outlined, size: 12, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'Prescribed Medicines Only',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Processing Indicator
                                  if (_isProcessing)
                                    Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(color: AppColors.primaryLight),
                                            SizedBox(height: 16),
                                            Text(
                                              'Cropping & Preparing High-Precision OCR...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
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

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  // Option to scan entire uncropped page
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF334155)),
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
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.crop_free_rounded, size: 20),
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

/// Custom painter rendering the dark stencil cut-out around the crop box,
/// grid guidelines, border outline, and corner bracket handles.
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Rect imageRect;

  _CropOverlayPainter({
    required this.cropRect,
    required this.imageRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw outer dimmed scrim (everywhere outside cropRect)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;

    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.68)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, scrimPaint);

    // 2. Draw 3x3 Rule-of-Thirds Grid Guidelines inside cropRect
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final thirdW = cropRect.width / 3.0;
    final thirdH = cropRect.height / 3.0;

    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + thirdW, cropRect.top),
      Offset(cropRect.left + thirdW, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdW * 2, cropRect.top),
      Offset(cropRect.left + thirdW * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH),
      Offset(cropRect.right, cropRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH * 2),
      Offset(cropRect.right, cropRect.top + thirdH * 2),
      gridPaint,
    );

    // 3. Draw Emerald Teal Crop Border
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(8)), borderPaint);

    // 4. Draw Professional Corner Brackets & Handles
    final cornerBracketPaint = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const armLength = 22.0;

    // Top-Left Corner Bracket
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + armLength),
      Offset(cropRect.left, cropRect.top),
      cornerBracketPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top),
      Offset(cropRect.left + armLength, cropRect.top),
      cornerBracketPaint,
    );

    // Top-Right Corner Bracket
    canvas.drawLine(
      Offset(cropRect.right - armLength, cropRect.top),
      Offset(cropRect.right, cropRect.top),
      cornerBracketPaint,
    );
    canvas.drawLine(
      Offset(cropRect.right, cropRect.top),
      Offset(cropRect.right, cropRect.top + armLength),
      cornerBracketPaint,
    );

    // Bottom-Left Corner Bracket
    canvas.drawLine(
      Offset(cropRect.left, cropRect.bottom - armLength),
      Offset(cropRect.left, cropRect.bottom),
      cornerBracketPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.bottom),
      Offset(cropRect.left + armLength, cropRect.bottom),
      cornerBracketPaint,
    );

    // Bottom-Right Corner Bracket
    canvas.drawLine(
      Offset(cropRect.right - armLength, cropRect.bottom),
      Offset(cropRect.right, cropRect.bottom),
      cornerBracketPaint,
    );
    canvas.drawLine(
      Offset(cropRect.right, cropRect.bottom),
      Offset(cropRect.right, cropRect.bottom - armLength),
      cornerBracketPaint,
    );

    // Center circular touch grab points on corners
    final grabDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final grabBorderPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    void drawHandleDot(Offset center) {
      canvas.drawCircle(center, 7.0, grabDotPaint);
      canvas.drawCircle(center, 7.0, grabBorderPaint);
    }

    drawHandleDot(cropRect.topLeft);
    drawHandleDot(cropRect.topRight);
    drawHandleDot(cropRect.bottomLeft);
    drawHandleDot(cropRect.bottomRight);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.imageRect != imageRect;
  }
}
