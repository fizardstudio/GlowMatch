import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class PhotoMakeupPainter extends CustomPainter {
  final Face? face;
  final int originalImageWidth;
  final int originalImageHeight;
  
  // Parameter Base Makeup (Foundation)
  final Color? foundationColor;
  final double foundationOpacity;

  // Parameter Lipstik (Bibir)
  final Color? lipstickColor;
  final double lipstickOpacity;
  final String lipstickFinishing; // 'matte' atau 'glossy'

  // Parameter Blush-On (Pipi)
  final Color? blushColor;
  final double blushOpacity;

  // Split screen divider X
  final double sliderX;

  PhotoMakeupPainter({
    required this.face,
    required this.originalImageWidth,
    required this.originalImageHeight,
    this.foundationColor,
    required this.foundationOpacity,
    this.lipstickColor,
    required this.lipstickOpacity,
    required this.lipstickFinishing,
    this.blushColor,
    required this.blushOpacity,
    required this.sliderX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (face == null || originalImageWidth == 0 || originalImageHeight == 0) return;

    // Hitung faktor skala dari koordinat foto asli ke dimensi rendering di layar (fitted)
    final double scaleX = size.width / originalImageWidth;
    final double scaleY = size.height / originalImageHeight;

    Offset mapPoint(Point<int> point) {
      // Foto statis diposisikan normal (tidak dicerminkan seperti kamera depan)
      return Offset(point.x * scaleX, point.y * scaleY);
    }

    final double faceWidth = (face!.boundingBox.right - face!.boundingBox.left) * scaleX;

    // Simpan canvas & lakukan pemotongan klip di sebelah kanan sliderX untuk perbandingan split-screen
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(sliderX, 0, size.width, size.height));

    // Helper untuk membuat garis path kurva halus (Path smoothing)
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

    // 1. RENDER BASE MAKEUP (FOUNDATION)
    if (foundationColor != null && foundationOpacity > 0.0) {
      final faceContourPoints = face!.contours[FaceContourType.face]?.points;
      if (faceContourPoints != null && faceContourPoints.isNotEmpty) {
        final Path facePath = Path();
        final List<Offset> faceOffsets = faceContourPoints.map((p) => mapPoint(Point(p.x, p.y))).toList();
        buildSmoothPath(facePath, faceOffsets);
        facePath.close();

        // Buat path "lubang" agar foundation tidak menutupi mata, alis, dan mulut
        final Path holesPath = Path();

        // Mata Kiri
        final leftEye = face!.contours[FaceContourType.leftEye]?.points;
        if (leftEye != null && leftEye.isNotEmpty) {
          final Path leftEyePath = Path();
          buildSmoothPath(leftEyePath, leftEye.map((p) => mapPoint(Point(p.x, p.y))).toList());
          leftEyePath.close();
          holesPath.addPath(leftEyePath, Offset.zero);
        }

        // Mata Kanan
        final rightEye = face!.contours[FaceContourType.rightEye]?.points;
        if (rightEye != null && rightEye.isNotEmpty) {
          final Path rightEyePath = Path();
          buildSmoothPath(rightEyePath, rightEye.map((p) => mapPoint(Point(p.x, p.y))).toList());
          rightEyePath.close();
          holesPath.addPath(rightEyePath, Offset.zero);
        }

        // Bibir (Mulut luar)
        final upperLipTop = face!.contours[FaceContourType.upperLipTop]?.points;
        final lowerLipBottom = face!.contours[FaceContourType.lowerLipBottom]?.points;
        if (upperLipTop != null && upperLipTop.isNotEmpty && lowerLipBottom != null && lowerLipBottom.isNotEmpty) {
          final Path lipsPath = Path();
          final List<Offset> lipsOffsets = [];
          lipsOffsets.addAll(upperLipTop.map((p) => mapPoint(Point(p.x, p.y))));
          lipsOffsets.addAll(lowerLipBottom.reversed.map((p) => mapPoint(Point(p.x, p.y))));
          buildSmoothPath(lipsPath, lipsOffsets);
          lipsPath.close();
          holesPath.addPath(lipsPath, Offset.zero);
        }

        // Alis Kiri
        final leftEyebrowTop = face!.contours[FaceContourType.leftEyebrowTop]?.points;
        final leftEyebrowBottom = face!.contours[FaceContourType.leftEyebrowBottom]?.points;
        if (leftEyebrowTop != null && leftEyebrowTop.isNotEmpty) {
          final Path eyebrowPath = Path();
          final List<Offset> eyebrowOffsets = [];
          eyebrowOffsets.addAll(leftEyebrowTop.map((p) => mapPoint(Point(p.x, p.y))));
          if (leftEyebrowBottom != null) {
            eyebrowOffsets.addAll(leftEyebrowBottom.reversed.map((p) => mapPoint(Point(p.x, p.y))));
          }
          buildSmoothPath(eyebrowPath, eyebrowOffsets);
          eyebrowPath.close();
          holesPath.addPath(eyebrowPath, Offset.zero);
        }

        // Alis Kanan
        final rightEyebrowTop = face!.contours[FaceContourType.rightEyebrowTop]?.points;
        final rightEyebrowBottom = face!.contours[FaceContourType.rightEyebrowBottom]?.points;
        if (rightEyebrowTop != null && rightEyebrowTop.isNotEmpty) {
          final Path eyebrowPath = Path();
          final List<Offset> eyebrowOffsets = [];
          eyebrowOffsets.addAll(rightEyebrowTop.map((p) => mapPoint(Point(p.x, p.y))));
          if (rightEyebrowBottom != null) {
            eyebrowOffsets.addAll(rightEyebrowBottom.reversed.map((p) => mapPoint(Point(p.x, p.y))));
          }
          buildSmoothPath(eyebrowPath, eyebrowOffsets);
          eyebrowPath.close();
          holesPath.addPath(eyebrowPath, Offset.zero);
        }

        // Kurangkan lubang dari masker wajah utuh
        final Path finalFoundationPath = Path.combine(
          PathOperation.difference,
          facePath,
          holesPath,
        );

        final paintBase = Paint()
          ..color = foundationColor!.withOpacity(foundationOpacity)
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.softLight // Menghasilkan perpaduan warna kulit yang sangat alami
          ..imageFilter = ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5); // Blending transisi tepi wajah halus

        canvas.drawPath(finalFoundationPath, paintBase);
      }
    }

    // Estimasi posisi pipi untuk blush-on
    Offset? estimatedLeftCheek;
    Offset? estimatedRightCheek;

    final leftEyeContours = face!.contours[FaceContourType.leftEye]?.points;
    final rightEyeContours = face!.contours[FaceContourType.rightEye]?.points;
    final noseBridgeContours = face!.contours[FaceContourType.noseBridge]?.points;

    if (leftEyeContours != null && leftEyeContours.isNotEmpty &&
        rightEyeContours != null && rightEyeContours.isNotEmpty &&
        noseBridgeContours != null && noseBridgeContours.isNotEmpty) {
      
      double sumLeftX = 0;
      double sumLeftY = 0;
      for (var p in leftEyeContours) {
        sumLeftX += p.x;
        sumLeftY += p.y;
      }
      final leftEyeCenter = mapPoint(Point((sumLeftX / leftEyeContours.length).round(), (sumLeftY / leftEyeContours.length).round()));

      double sumRightX = 0;
      double sumRightY = 0;
      for (var p in rightEyeContours) {
        sumRightX += p.x;
        sumRightY += p.y;
      }
      final rightEyeCenter = mapPoint(Point((sumRightX / rightEyeContours.length).round(), (sumRightY / rightEyeContours.length).round()));

      final noseTip = mapPoint(Point(noseBridgeContours.last.x, noseBridgeContours.last.y));

      // Hitung pergeseran blush-on ke luar (apples of cheeks / tulang pipi)
      final double shiftX = (rightEyeCenter.dx - leftEyeCenter.dx) * 0.22;

      estimatedLeftCheek = Offset(
        leftEyeCenter.dx - shiftX,
        leftEyeCenter.dy + (noseTip.dy - leftEyeCenter.dy) * 0.65,
      );

      estimatedRightCheek = Offset(
        rightEyeCenter.dx + shiftX,
        rightEyeCenter.dy + (noseTip.dy - rightEyeCenter.dy) * 0.65,
      );
    }

    // 2. RENDER LIPSTIK (BIBIR)
    if (lipstickColor != null && lipstickOpacity > 0.0) {
      final upperLipTop = face!.contours[FaceContourType.upperLipTop]?.points;
      final upperLipBottom = face!.contours[FaceContourType.upperLipBottom]?.points;
      final lowerLipTop = face!.contours[FaceContourType.lowerLipTop]?.points;
      final lowerLipBottom = face!.contours[FaceContourType.lowerLipBottom]?.points;

      final Path upperLipPath = Path();
      final Path lowerLipPath = Path();

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

      final paintLip = Paint()
        ..color = lipstickColor!.withOpacity(lipstickOpacity)
        ..style = PaintingStyle.fill
        ..blendMode = lipstickFinishing == 'glossy' ? BlendMode.color : BlendMode.multiply
        ..imageFilter = ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5); // Efek gradasi tepi bibir halus

      canvas.drawPath(upperLipPath, paintLip);
      canvas.drawPath(lowerLipPath, paintLip);
    }

    // 3. RENDER BLUSH-ON (PIPI)
    if (blushColor != null && blushOpacity > 0.0) {
      final double blushRadius = faceWidth * 0.16;

      void drawCheekBlush(Offset center) {
        final Rect bounds = Rect.fromCircle(center: center, radius: blushRadius);
        
        final paintCheek = Paint()
          ..style = PaintingStyle.fill
          ..imageFilter = ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0)
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
  bool shouldRepaint(covariant PhotoMakeupPainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.foundationColor != foundationColor ||
        oldDelegate.foundationOpacity != foundationOpacity ||
        oldDelegate.lipstickColor != lipstickColor ||
        oldDelegate.lipstickOpacity != lipstickOpacity ||
        oldDelegate.lipstickFinishing != lipstickFinishing ||
        oldDelegate.blushColor != blushColor ||
        oldDelegate.blushOpacity != blushOpacity ||
        oldDelegate.sliderX != sliderX ||
        oldDelegate.originalImageWidth != originalImageWidth ||
        oldDelegate.originalImageHeight != originalImageHeight;
  }
}
