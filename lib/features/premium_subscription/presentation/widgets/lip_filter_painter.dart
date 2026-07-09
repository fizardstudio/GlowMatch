import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class LipFilterPainter extends CustomPainter {
  final Face? face;
  final int imageWidth;
  final int imageHeight;
  final CameraLensDirection lensDirection;
  
  // Parameter Lipstik (Bibir)
  final Color? lipstickColor;
  final double lipstickOpacity;
  final String lipstickFinishing; // 'matte' atau 'glossy'

  // Parameter Blush-On (Pipi)
  final Color? blushColor;
  final double blushOpacity;

  final double sliderX;

  LipFilterPainter({
    required this.face,
    required this.imageWidth,
    required this.imageHeight,
    required this.lensDirection,
    this.lipstickColor,
    required this.lipstickOpacity,
    required this.lipstickFinishing,
    this.blushColor,
    required this.blushOpacity,
    required this.sliderX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (face == null || imageWidth == 0 || imageHeight == 0) return;

    final double scaleX = size.width / imageHeight;
    final double scaleY = size.height / imageWidth;

    Offset mapPoint(Point<int> point) {
      final double mappedX = lensDirection == CameraLensDirection.front
          ? size.width - (point.x * scaleX)
          : point.x * scaleX;
      final double mappedY = point.y * scaleY;
      return Offset(mappedX, mappedY);
    }

    // Ambil lebar wajah berdasarkan bounding box
    final double faceWidth = (face!.boundingBox.right - face!.boundingBox.left) * scaleX;

    // Lakukan clipping canvas di sebelah kanan sliderX untuk efek Split-Screen
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(sliderX, 0, size.width, size.height));

    // Helper untuk menggambar kurva Bezier agar pinggiran kosmetik mulus (Path Smoothing)
    void buildSmoothPath(Path path, List<Offset> pointsList) {
      if (pointsList.isEmpty) return;
      path.moveTo(pointsList.first.dx, pointsList.first.dy);
      for (int i = 0; i < pointsList.length - 1; i++) {
        final p1 = pointsList[i];
        final p2 = pointsList[i + 1];
        final xc = (p1.dx + p2.dx) / 2;
        final yc = (p1.dy + p2.dy) / 2;
        path.quadraticBezierTo(p1.dx, p1.dy, xc, yc);
      }
      path.lineTo(pointsList.last.dx, pointsList.last.dy);
    }

    // Estimasi posisi pipi untuk blush-on dari kontur mata dan hidung (karena contours dan landmarks mutually exclusive)
    Offset? estimatedLeftCheek;
    Offset? estimatedRightCheek;

    final leftEyeContours = face!.contours[FaceContourType.leftEye]?.points;
    final rightEyeContours = face!.contours[FaceContourType.rightEye]?.points;
    final noseBridgeContours = face!.contours[FaceContourType.noseBridge]?.points;

    if (leftEyeContours != null && leftEyeContours.isNotEmpty &&
        rightEyeContours != null && rightEyeContours.isNotEmpty &&
        noseBridgeContours != null && noseBridgeContours.isNotEmpty) {
      
      // Hitung pusat mata kiri
      double sumLeftX = 0;
      double sumLeftY = 0;
      for (var p in leftEyeContours) {
        sumLeftX += p.x;
        sumLeftY += p.y;
      }
      final leftEyeCenter = mapPoint(Point((sumLeftX / leftEyeContours.length).round(), (sumLeftY / leftEyeContours.length).round()));

      // Hitung pusat mata kanan
      double sumRightX = 0;
      double sumRightY = 0;
      for (var p in rightEyeContours) {
        sumRightX += p.x;
        sumRightY += p.y;
      }
      final rightEyeCenter = mapPoint(Point((sumRightX / rightEyeContours.length).round(), (sumRightY / rightEyeContours.length).round()));

      // Ambil ujung hidung (titik terakhir dari batang hidung)
      final noseTip = mapPoint(Point(noseBridgeContours.last.x, noseBridgeContours.last.y));

      // Menggeser posisi blush-on lebih ke samping luar (tulang pipi/apples of the cheeks) secara dinamis
      // Menggunakan jarak antar mata (vektor horizontal) untuk menentukan lebar pergeseran
      final double shiftX = (rightEyeCenter.dx - leftEyeCenter.dx) * 0.22;

      // Pipi kiri berada di bawah mata kiri, digeser ke luar (dx - shiftX)
      estimatedLeftCheek = Offset(
        leftEyeCenter.dx - shiftX,
        leftEyeCenter.dy + (noseTip.dy - leftEyeCenter.dy) * 0.65,
      );

      // Pipi kanan berada di bawah mata kanan, digeser ke luar (dx + shiftX)
      estimatedRightCheek = Offset(
        rightEyeCenter.dx + shiftX,
        rightEyeCenter.dy + (noseTip.dy - rightEyeCenter.dy) * 0.65,
      );
    }

    // 1. GAMBAR FILTER LIPSTIK (BIBIR)
    if (lipstickColor != null && lipstickOpacity > 0.0) {
      final upperLipTop = face!.contours[FaceContourType.upperLipTop]?.points;
      final upperLipBottom = face!.contours[FaceContourType.upperLipBottom]?.points;
      final lowerLipTop = face!.contours[FaceContourType.lowerLipTop]?.points;
      final lowerLipBottom = face!.contours[FaceContourType.lowerLipBottom]?.points;

      debugPrint("DEBUG_PAINTER: upperLipTop points: ${upperLipTop?.length}, upperLipBottom: ${upperLipBottom?.length}, lowerLipTop: ${lowerLipTop?.length}, lowerLipBottom: ${lowerLipBottom?.length}");

      final Path upperLipPath = Path();
      final Path lowerLipPath = Path();

      // Bangun Path untuk bibir atas
      final List<Offset> upperOffsets = [];
      if (upperLipTop != null && upperLipTop.isNotEmpty) {
        upperOffsets.addAll(upperLipTop.map((p) => mapPoint(Point(p.x, p.y))));
      }
      if (upperLipBottom != null && upperLipBottom.isNotEmpty) {
        upperOffsets.addAll(upperLipBottom.reversed.map((p) => mapPoint(Point(p.x, p.y))));
      }
      if (upperOffsets.isNotEmpty) {
        buildSmoothPath(upperLipPath, upperOffsets);
        upperLipPath.close();
      }

      // Bangun Path untuk bibir bawah
      final List<Offset> lowerOffsets = [];
      if (lowerLipTop != null && lowerLipTop.isNotEmpty) {
        lowerOffsets.addAll(lowerLipTop.map((p) => mapPoint(Point(p.x, p.y))));
      }
      if (lowerLipBottom != null && lowerLipBottom.isNotEmpty) {
        lowerOffsets.addAll(lowerLipBottom.reversed.map((p) => mapPoint(Point(p.x, p.y))));
      }
      if (lowerOffsets.isNotEmpty) {
        buildSmoothPath(lowerLipPath, lowerOffsets);
        lowerLipPath.close();
      }

      // Atur blendMode berdasarkan finishing untuk Texture Blending & Specular Preservation
      // Glossy mempertahankan highlights putih alami bibir dengan BlendMode.color
      final paintLip = Paint()
        ..color = lipstickColor!.withOpacity(lipstickOpacity)
        ..style = PaintingStyle.fill
        ..blendMode = lipstickFinishing == 'glossy' ? BlendMode.color : BlendMode.multiply
        ..imageFilter = ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5); // Feathering effect

      canvas.drawPath(upperLipPath, paintLip);
      canvas.drawPath(lowerLipPath, paintLip);
    }

    // 2. GAMBAR FILTER BLUSH-ON (PIPI)
    if (blushColor != null && blushOpacity > 0.0) {
      final double blushRadius = faceWidth * 0.16;

      void drawCheekBlush(Offset center) {
        final Rect bounds = Rect.fromCircle(center: center, radius: blushRadius);
        
        final paintCheek = Paint()
          ..style = PaintingStyle.fill
          ..imageFilter = ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0) // Feathering effect
          ..shader = RadialGradient(
            colors: [
              blushColor!.withOpacity(blushOpacity),
              blushColor!.withOpacity(0.0),
            ],
          ).createShader(bounds);

        canvas.drawCircle(center, blushRadius, paintCheek);
      }

      if (estimatedLeftCheek != null) {
        drawCheekBlush(estimatedLeftCheek);
      }
      if (estimatedRightCheek != null) {
        drawCheekBlush(estimatedRightCheek);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LipFilterPainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.lipstickColor != lipstickColor ||
        oldDelegate.lipstickOpacity != lipstickOpacity ||
        oldDelegate.lipstickFinishing != lipstickFinishing ||
        oldDelegate.blushColor != blushColor ||
        oldDelegate.blushOpacity != blushOpacity ||
        oldDelegate.sliderX != sliderX ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
