import '../../../../core/utils/face_geometry_helper.dart';
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
        
        // Perluas dahi (forehead extension) ke arah hairline menggunakan FaceGeometryHelper
        final leftEyePt = face!.landmarks[FaceLandmarkType.leftEye]?.position;
        final rightEyePt = face!.landmarks[FaceLandmarkType.rightEye]?.position;
        if (leftEyePt != null && rightEyePt != null) {
          final hairlinePts = FaceGeometryHelper.getHairlinePoints(face!);
          faceOffsets.add(mapPoint(Point(hairlinePts[0].x.round(), hairlinePts[0].y.round())));
          faceOffsets.add(mapPoint(Point(hairlinePts[1].x.round(), hairlinePts[1].y.round())));
          faceOffsets.add(mapPoint(Point(hairlinePts[2].x.round(), hairlinePts[2].y.round())));
        }
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



    final cheeks = FaceGeometryHelper.getCheekCoordinates(face!);
    estimatedLeftCheek = mapPoint(Point(cheeks['left']!.x.round(), cheeks['left']!.y.round()));
    estimatedRightCheek = mapPoint(Point(cheeks['right']!.x.round(), cheeks['right']!.y.round()));

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

    // 3. RENDER BLUSH-ON (PIPI - Oval Terputar mengikuti sudut miring wajah)
    if (blushColor != null && blushOpacity > 0.0) {
      final double blushRadius = faceWidth * 0.16;

      void drawCheekBlush(Offset center, bool isLeft) {
        final double rollAngle = (face!.headEulerAngleZ ?? 0.0) * pi / 180.0;
        
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(rollAngle);
        
        final double width = blushRadius * 2.2;
        final double height = blushRadius * 1.3;
        
        // Pipi kiri disapu ke kiri luar, pipi kanan ke kanan luar
        final double offsetX = isLeft ? -width * 0.1 : width * 0.1;
        final Rect bounds = Rect.fromCenter(
          center: Offset(offsetX, 0),
          width: width,
          height: height,
        );
        
        final paintCheek = Paint()
          ..style = PaintingStyle.fill
          ..imageFilter = ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0)
          ..shader = RadialGradient(
            colors: [
              blushColor!.withOpacity(blushOpacity),
              blushColor!.withOpacity(0.0),
            ],
          ).createShader(bounds);

        canvas.drawOval(bounds, paintCheek);
        canvas.restore();
      }

      if (estimatedLeftCheek != null) {
        drawCheekBlush(estimatedLeftCheek, true);
      }
      if (estimatedRightCheek != null) {
        drawCheekBlush(estimatedRightCheek, false);
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
