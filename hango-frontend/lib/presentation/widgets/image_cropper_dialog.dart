import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../utils/language_manager.dart';

/// A modal dialog that allows users to pan, zoom, rotate and crop an image into a circle or rounded frame (ideal for Avatars).
class ImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String? title;
  final double cropDiameter;
  final double outputSize;
  final bool isCircular;

  const ImageCropperDialog({
    super.key,
    required this.imageBytes,
    this.title,
    this.cropDiameter = 260.0,
    this.outputSize = 512.0,
    this.isCircular = true,
  });

  /// Helper to display the dialog and return the cropped bytes.
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String? title,
    double cropDiameter = 260.0,
    double outputSize = 512.0,
    bool isCircular = true,
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageCropperDialog(
        imageBytes: imageBytes,
        title: title,
        cropDiameter: cropDiameter,
        outputSize: outputSize,
        isCircular: isCircular,
      ),
    );
  }

  @override
  State<ImageCropperDialog> createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  final TransformationController _transformController =
      TransformationController();

  ui.Image? _decodedImage;
  bool _isLoading = true;
  bool _isProcessingCrop = false;
  String? _errorMessage;

  double _currentZoom = 1.0;
  int _rotationQuarterTurns = 0; // 0, 1, 2, 3

  static const double _viewportSize = 320.0;

  @override
  void initState() {
    super.initState();
    _decodeSourceImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _decodeSourceImage() async {
    try {
      final image = await decodeImageFromList(widget.imageBytes);
      if (mounted) {
        setState(() {
          _decodedImage = image;
          _isLoading = false;
        });
        _resetTransform();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = LanguageManager.isVi
              ? 'Không thể xử lý hình ảnh này. Vui lòng thử ảnh khác.'
              : 'Unable to decode this image. Please try another file.';
        });
      }
    }
  }

  double _getBaseScale() {
    if (_decodedImage == null) return 1.0;
    final w = _decodedImage!.width.toDouble();
    final h = _decodedImage!.height.toDouble();
    final rotW = (_rotationQuarterTurns % 2 == 0) ? w : h;
    final rotH = (_rotationQuarterTurns % 2 == 0) ? h : w;
    return math.max(
      widget.cropDiameter / rotW,
      widget.cropDiameter / rotH,
    );
  }

  void _resetTransform() {
    if (_decodedImage == null) return;
    _currentZoom = 1.0;

    final w = _decodedImage!.width.toDouble();
    final h = _decodedImage!.height.toDouble();
    final rotW = (_rotationQuarterTurns % 2 == 0) ? w : h;
    final rotH = (_rotationQuarterTurns % 2 == 0) ? h : w;

    final baseScale = _getBaseScale();
    final renderedW = rotW * baseScale;
    final renderedH = rotH * baseScale;

    final dx = (_viewportSize - renderedW) / 2.0;
    final dy = (_viewportSize - renderedH) / 2.0;

    _transformController.value = Matrix4.identity()
      ..setTranslationRaw(dx, dy, 0.0)
      ..scale(baseScale, baseScale, 1.0);

    setState(() {});
  }

  void _onZoomSliderChanged(double newZoom) {
    if (_decodedImage == null) return;
    final baseScale = _getBaseScale();
    final targetScale = baseScale * newZoom;

    final currentMatrix = _transformController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    if (currentScale <= 0) return;

    final ratio = targetScale / currentScale;
    _currentZoom = newZoom;

    // Zoom relative to center of the crop circle
    const center = Offset(_viewportSize / 2.0, _viewportSize / 2.0);
    final translation = currentMatrix.getTranslation();

    final newDx = center.dx - (center.dx - translation.x) * ratio;
    final newDy = center.dy - (center.dy - translation.y) * ratio;

    _transformController.value = Matrix4.identity()
      ..setTranslationRaw(newDx, newDy, 0.0)
      ..scale(targetScale, targetScale, 1.0);

    setState(() {});
  }

  void _rotateQuarterTurn() {
    if (_decodedImage == null) return;
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
    _resetTransform();
  }

  Future<void> _applyCropAndConfirm() async {
    if (_decodedImage == null || _isProcessingCrop) return;

    setState(() => _isProcessingCrop = true);

    try {
      final croppedBytes = await _renderCroppedImage();
      if (mounted) {
        Navigator.pop(context, croppedBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingCrop = false;
          _errorMessage = LanguageManager.isVi
              ? 'Lỗi khi xuất ảnh: $e'
              : 'Error exporting cropped image: $e';
        });
      }
    }
  }

  Future<Uint8List> _renderCroppedImage() async {
    final uiImage = _decodedImage!;
    final outputSize = widget.outputSize;
    final cropDiameter = widget.cropDiameter;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outputSize, outputSize),
    );

    final scaleToOutput = outputSize / cropDiameter;
    final cropLeft = (_viewportSize - cropDiameter) / 2.0;
    final cropTop = (_viewportSize - cropDiameter) / 2.0;

    final matrix = _transformController.value;

    canvas.save();
    // 1. Scale from crop diameter to output resolution (e.g. 260px -> 512px)
    canvas.scale(scaleToOutput, scaleToOutput);
    // 2. Translate crop center to origin
    canvas.translate(-cropLeft, -cropTop);
    // 3. Apply exact InteractiveViewer transform matrix
    canvas.transform(matrix.storage);

    // 4. Draw image with same rotation
    final w = uiImage.width.toDouble();
    final h = uiImage.height.toDouble();
    final rotW = (_rotationQuarterTurns % 2 == 0) ? w : h;
    final rotH = (_rotationQuarterTurns % 2 == 0) ? h : w;

    _drawImageWithRotation(
      canvas: canvas,
      image: uiImage,
      rotW: rotW,
      rotH: rotH,
      quarterTurns: _rotationQuarterTurns,
    );

    canvas.restore();

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(
      outputSize.toInt(),
      outputSize.toInt(),
    );
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to encode image to PNG byte stream.');
    }
    return byteData.buffer.asUint8List();
  }

  static void _drawImageWithRotation({
    required Canvas canvas,
    required ui.Image image,
    required double rotW,
    required double rotH,
    required int quarterTurns,
  }) {
    canvas.save();
    if (quarterTurns == 1) {
      canvas.translate(rotW, 0);
      canvas.rotate(math.pi / 2.0);
    } else if (quarterTurns == 2) {
      canvas.translate(rotW, rotH);
      canvas.rotate(math.pi);
    } else if (quarterTurns == 3) {
      canvas.translate(0, rotH);
      canvas.rotate(3.0 * math.pi / 2.0);
    }
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
    canvas.drawImage(image, Offset.zero, paint);
    canvas.restore();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageManager.isVi;
    final dialogTitle = widget.title ??
        (isVi ? 'Chỉnh sửa ảnh đại diện' : 'Adjust Avatar Photo');

    double rotW = 100.0;
    double rotH = 100.0;
    if (_decodedImage != null) {
      final w = _decodedImage!.width.toDouble();
      final h = _decodedImage!.height.toDouble();
      rotW = (_rotationQuarterTurns % 2 == 0) ? w : h;
      rotH = (_rotationQuarterTurns % 2 == 0) ? h : w;
    }
    final baseScale = _getBaseScale();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7F4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.crop_rotate_rounded,
                            color: Color(0xFF28B79B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dialogTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Helper Tip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 16,
                      color: Color(0xFF28B79B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isVi
                            ? 'Kéo di chuyển hoặc thu phóng để điều chỉnh khuôn mặt vào giữa khung tròn.'
                            : 'Drag to position or zoom to fit your face inside the circle.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Image Crop Viewport
              Center(
                child: Container(
                  width: _viewportSize,
                  height: _viewportSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF28B79B),
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          : Stack(
                              children: [
                                // Interactive Image Layer
                                Positioned.fill(
                                  child: InteractiveViewer(
                                    transformationController:
                                        _transformController,
                                    boundaryMargin: const EdgeInsets.all(
                                      _viewportSize * 2.0,
                                    ),
                                    minScale: baseScale * 0.4,
                                    maxScale: baseScale * 6.0,
                                    onInteractionEnd: (_) {
                                      if (_decodedImage == null) return;
                                      final currentScale =
                                          _transformController.value
                                              .getMaxScaleOnAxis();
                                      final zoom = (currentScale / baseScale)
                                          .clamp(1.0, 4.0);
                                      setState(() {
                                        _currentZoom = zoom;
                                      });
                                    },
                                    child: SizedBox(
                                      width: rotW,
                                      height: rotH,
                                      child: CustomPaint(
                                        size: Size(rotW, rotH),
                                        painter: _ImageCanvasPainter(
                                          image: _decodedImage!,
                                          quarterTurns: _rotationQuarterTurns,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Circular Mask & Grid Overlay
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _CropMaskPainter(
                                        cropDiameter: widget.cropDiameter,
                                        isCircular: widget.isCircular,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 14),

              // Zoom & Control Tools
              Row(
                children: [
                  const Icon(Icons.zoom_out, color: Color(0xFF64748B), size: 18),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF28B79B),
                        inactiveTrackColor: const Color(0xFFE2E8F0),
                        thumbColor: const Color(0xFF28B79B),
                        overlayColor: const Color(0x3328B79B),
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7.0,
                        ),
                      ),
                      child: Slider(
                        value: _currentZoom.clamp(1.0, 4.0),
                        min: 1.0,
                        max: 4.0,
                        onChanged: _decodedImage != null
                            ? _onZoomSliderChanged
                            : null,
                      ),
                    ),
                  ),
                  const Icon(Icons.zoom_in, color: Color(0xFF64748B), size: 18),
                  const SizedBox(width: 8),

                  // Rotate Button
                  Tooltip(
                    message: isVi ? 'Xoay ảnh 90°' : 'Rotate 90°',
                    child: InkWell(
                      onTap: _decodedImage != null ? _rotateQuarterTurn : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(
                          Icons.rotate_90_degrees_cw_rounded,
                          size: 18,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Reset Button
                  Tooltip(
                    message: isVi ? 'Căn giữa lại' : 'Reset view',
                    child: InkWell(
                      onTap: _decodedImage != null ? _resetTransform : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(
                          Icons.center_focus_strong_rounded,
                          size: 18,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isProcessingCrop
                        ? null
                        : () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      isVi ? 'Hủy' : 'Cancel',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: (_decodedImage != null && !_isProcessingCrop)
                        ? _applyCropAndConfirm
                        : null,
                    icon: _isProcessingCrop
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      isVi ? 'Xác nhận & Cắt ảnh' : 'Crop & Apply',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the decoded ui.Image on the CustomPaint canvas according to the rotation.
class _ImageCanvasPainter extends CustomPainter {
  final ui.Image image;
  final int quarterTurns;

  _ImageCanvasPainter({
    required this.image,
    required this.quarterTurns,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _ImageCropperDialogState._drawImageWithRotation(
      canvas: canvas,
      image: image,
      rotW: size.width,
      rotH: size.height,
      quarterTurns: quarterTurns,
    );
  }

  @override
  bool shouldRepaint(covariant _ImageCanvasPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.quarterTurns != quarterTurns;
  }
}

/// Custom painter for the semi-transparent mask and crop circle frame overlay.
class _CropMaskPainter extends CustomPainter {
  final double cropDiameter;
  final bool isCircular;

  _CropMaskPainter({
    required this.cropDiameter,
    required this.isCircular,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cropCenter = Offset(size.width / 2.0, size.height / 2.0);
    final cropRect = Rect.fromCenter(
      center: cropCenter,
      width: cropDiameter,
      height: cropDiameter,
    );

    // 1. Draw dark background mask outside the crop window
    final bgPath = Path()..addRect(rect);
    final cropPath = Path();
    if (isCircular) {
      cropPath.addOval(cropRect);
    } else {
      cropPath.addRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(16)),
      );
    }

    final maskPath = Path.combine(PathOperation.difference, bgPath, cropPath);
    final maskPaint = Paint()
      ..color = const Color(0xAA0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // 2. Draw border around the crop circle
    final borderPaint = Paint()
      ..color = const Color(0xFF28B79B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (isCircular) {
      canvas.drawCircle(cropCenter, cropDiameter / 2.0, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(16)),
        borderPaint,
      );
    }

    // 3. Subtle grid lines inside crop window (Rule of Thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final oneThird = cropDiameter / 3.0;

    // Clip to crop area so grid lines don't leak outside circle
    canvas.save();
    canvas.clipPath(cropPath);

    // Vertical lines
    canvas.drawLine(
      Offset(cropRect.left + oneThird, cropRect.top),
      Offset(cropRect.left + oneThird, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + oneThird * 2, cropRect.top),
      Offset(cropRect.left + oneThird * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + oneThird),
      Offset(cropRect.right, cropRect.top + oneThird),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + oneThird * 2),
      Offset(cropRect.right, cropRect.top + oneThird * 2),
      gridPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) {
    return oldDelegate.cropDiameter != cropDiameter ||
        oldDelegate.isCircular != isCircular;
  }
}
