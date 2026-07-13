import '../../../../core/utils/face_geometry_helper.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class PhotoMakeupPainter extends CustomPainter {
  final Face? face;
  final int originalImageWidth;
  final int originalImageHeight;
  final ui.Image? backgroundImage;
  
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

  // Glass Skin & Highlighter
  final bool showGlassSkin;

  // Split screen divider X
  final double sliderX;

  // Advanced Try-On Upgrades (Phase 2.5)
  final String selectedLightingPreset; // 'Natural', 'Golden Hour', 'Studio Light', 'Cyber Neon'
  final bool showHarmonyHeatmap;
  final String? undertone;

  PhotoMakeupPainter({
    required this.face,
    required this.originalImageWidth,
    required this.originalImageHeight,
    this.backgroundImage,
    this.foundationColor,
    required this.foundationOpacity,
    this.lipstickColor,
    required this.lipstickOpacity,
    required this.lipstickFinishing,
    this.blushColor,
    required this.blushOpacity,
    required this.showGlassSkin,
    required this.sliderX,
    required this.selectedLightingPreset,
    required this.showHarmonyHeatmap,
    this.undertone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundImage != null) {
      canvas.drawImageRect(
        backgroundImage!,
        Rect.fromLTWH(0, 0, backgroundImage!.width.toDouble(), backgroundImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint(),
      );
    }

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
        final hairlinePts = FaceGeometryHelper.getHairlinePoints(face!);
        faceOffsets.add(mapPoint(Point(hairlinePts[0].x.round(), hairlinePts[0].y.round())));
        faceOffsets.add(mapPoint(Point(hairlinePts[1].x.round(), hairlinePts[1].y.round())));
        faceOffsets.add(mapPoint(Point(hairlinePts[2].x.round(), hairlinePts[2].y.round())));
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
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5); // Blending transisi tepi wajah halus

        canvas.drawPath(finalFoundationPath, paintBase);
      }
    }

    // RENDER BASE MAKEUP LIGHTING PRESETS OVERLAY ON FACE
    if (selectedLightingPreset != 'Natural') {
      final faceContourPoints = face!.contours[FaceContourType.face]?.points;
      if (faceContourPoints != null && faceContourPoints.isNotEmpty) {
        final Path facePath = Path();
        final List<Offset> faceOffsets = faceContourPoints.map((p) => mapPoint(Point(p.x, p.y))).toList();
        
        final hairlinePts = FaceGeometryHelper.getHairlinePoints(face!);
        faceOffsets.add(mapPoint(Point(hairlinePts[0].x.round(), hairlinePts[0].y.round())));
        faceOffsets.add(mapPoint(Point(hairlinePts[1].x.round(), hairlinePts[1].y.round())));
        faceOffsets.add(mapPoint(Point(hairlinePts[2].x.round(), hairlinePts[2].y.round())));
        
        buildSmoothPath(facePath, faceOffsets);
        facePath.close();

        if (selectedLightingPreset == 'Golden Hour') {
          // Warm golden sunset overlay
          final paintLight = Paint()
            ..color = const Color(0xFFFFB74D).withOpacity(0.18)
            ..style = PaintingStyle.fill
            ..blendMode = BlendMode.overlay
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0);
          canvas.drawPath(facePath, paintLight);
        } else if (selectedLightingPreset == 'Studio Light') {
          // Specular white spotlight over dahi & nose
          final foreheadPt = FaceGeometryHelper.getForeheadCoordinate(face!);
          final mappedForehead = mapPoint(Point(foreheadPt.x.round(), foreheadPt.y.round()));
          final double spotlightRadius = faceWidth * 0.4;
          final Paint paintLight = Paint()
            ..style = PaintingStyle.fill
            ..blendMode = BlendMode.softLight
            ..shader = ui.Gradient.radial(
              mappedForehead,
              spotlightRadius,
              [
                Colors.white.withOpacity(0.35),
                Colors.white.withOpacity(0.0),
              ],
            );
          canvas.drawPath(facePath, paintLight);
        } else if (selectedLightingPreset == 'Cyber Neon') {
          // Dual cyan-pink neon exposure from sides
          final cheeks = FaceGeometryHelper.getCheekCoordinates(face!);
          final mappedLeft = mapPoint(Point(cheeks['left']!.x.round(), cheeks['left']!.y.round()));
          final mappedRight = mapPoint(Point(cheeks['right']!.x.round(), cheeks['right']!.y.round()));
          final double neonRadius = faceWidth * 0.6;
          
          final Paint paintNeon = Paint()
            ..style = PaintingStyle.fill
            ..blendMode = BlendMode.screen;

          // Left neon cyan
          paintNeon.shader = ui.Gradient.radial(
            mappedLeft.translate(-faceWidth * 0.3, 0),
            neonRadius,
            [
              const Color(0xFF00E5FF).withOpacity(0.20),
              Colors.transparent,
            ],
          );
          canvas.drawPath(facePath, paintNeon);

          // Right neon pink
          paintNeon.shader = ui.Gradient.radial(
            mappedRight.translate(faceWidth * 0.3, 0),
            neonRadius,
            [
              const Color(0xFFFF007F).withOpacity(0.20),
              Colors.transparent,
            ],
          );
          canvas.drawPath(facePath, paintNeon);
        }
      }
    }

    // Estimasi posisi pipi untuk blush-on
    Offset? estimatedLeftCheek;
    Offset? estimatedRightCheek;

    final cheeks = FaceGeometryHelper.getCheekCoordinates(face!);
    estimatedLeftCheek = mapPoint(Point(cheeks['left']!.x.round(), cheeks['left']!.y.round()));
    estimatedRightCheek = mapPoint(Point(cheeks['right']!.x.round(), cheeks['right']!.y.round()));

    // 2. RENDER DEWY GLASS SKIN GLOW
    if (showGlassSkin && estimatedLeftCheek != null && estimatedRightCheek != null) {
      final double glowRadius = faceWidth * 0.22;
      
      final Paint paintGlow = Paint()
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.screen;

      // Glow Pipi Kiri
      paintGlow.shader = ui.Gradient.radial(
        estimatedLeftCheek,
        glowRadius,
        [
          Colors.white.withOpacity(0.18),
          Colors.white.withOpacity(0.0),
        ],
      );
      canvas.drawCircle(estimatedLeftCheek, glowRadius, paintGlow);

      // Glow Pipi Kanan
      paintGlow.shader = ui.Gradient.radial(
        estimatedRightCheek,
        glowRadius,
        [
          Colors.white.withOpacity(0.18),
          Colors.white.withOpacity(0.0),
        ],
      );
      canvas.drawCircle(estimatedRightCheek, glowRadius, paintGlow);

      // Glow Dahi
      final foreheadPt = FaceGeometryHelper.getForeheadCoordinate(face!);
      final mappedForehead = mapPoint(Point(foreheadPt.x.round(), foreheadPt.y.round()));
      paintGlow.shader = ui.Gradient.radial(
        mappedForehead,
        glowRadius * 1.2,
        [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.0),
        ],
      );
      canvas.drawCircle(mappedForehead, glowRadius * 1.2, paintGlow);
    }

    // 3. RENDER LIPSTIK (BIBIR)
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
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5); // Efek gradasi tepi bibir halus

      canvas.drawPath(upperLipPath, paintLip);
      canvas.drawPath(lowerLipPath, paintLip);

      // Harmony Heatmap outline warning for lips
      if (showHarmonyHeatmap && _isLipstickMismatch()) {
        final paintWarning = Paint()
          ..color = const Color(0xFFFF3D00) // Neon orange-red alert
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0);
        canvas.drawPath(upperLipPath, paintWarning);
        canvas.drawPath(lowerLipPath, paintWarning);
      }
    }

    // 3. RENDER BLUSH-ON (PIPI - Oval Panjang Terputar menyamping mengikuti kontur tulang pipi / cheekbone draping)
    if (blushColor != null && blushOpacity > 0.0) {
      final double blushRadius = faceWidth * 0.16;

      canvas.save();
      // Potong area gambar hanya di dalam garis kontur wajah menggunakan clipPath agar blush-on tidak beleber keluar wajah
      final faceContourPoints = face!.contours[FaceContourType.face]?.points;
      if (faceContourPoints != null && faceContourPoints.isNotEmpty) {
        final Path faceOutlinePath = Path();
        final List<Offset> faceOffsets = faceContourPoints.map((p) => mapPoint(Point(p.x, p.y))).toList();
        faceOutlinePath.moveTo(faceOffsets.first.dx, faceOffsets.first.dy);
        for (int i = 1; i < faceOffsets.length; i++) {
          faceOutlinePath.lineTo(faceOffsets[i].dx, faceOffsets[i].dy);
        }
        faceOutlinePath.close();
        canvas.clipPath(faceOutlinePath);
      }

      void drawCheekBlush(Offset center, bool isLeft) {
        final double rollAngle = (face!.headEulerAngleZ ?? 0.0) * pi / 180.0;
        final double smileProb = face!.smilingProbability ?? 0.0;
        // Penyesuaian senyum: naikkan pipi secara vertikal saat tersenyum
        final double smileShiftY = smileProb * blushRadius * 0.25;

        canvas.save();
        canvas.translate(center.dx, center.dy);
        
        // Kemiringan sapuan (slanted tilt) naik ke arah pelipis/hairline agar berkesan tirus (draping)
        // Kita miringkan ke atas sekitar 13.5 derajat (0.24 radian)
        final double tilt = isLeft ? -0.24 : 0.24;
        canvas.rotate(rollAngle + tilt);
        
        // Ukuran blush-on disesuaikan secara profesional agar meluncur panjang (tidak bulat kerdil)
        final double width = faceWidth * 0.54;  // Sapuan panjang menutupi area pipi hingga luar
        final double height = faceWidth * 0.26; // Ketebalan sapuan yang proporsional
        
        // Pipi kiri disapu ke kiri luar, pipi kanan ke kanan luar (tanpa mirroring karena foto 2D statis)
        final double offsetX = isLeft ? -width * 0.25 : width * 0.25;
        
        final Rect bounds = Rect.fromCenter(
          center: Offset(offsetX, -smileShiftY),
          width: width,
          height: height,
        );
        
        final paintCheek = Paint()
          ..style = PaintingStyle.fill
          // Efek blur/bauran tinggi (airbrush effect) agar tidak terlihat lingkaran kaku di wajah
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 19.5, sigmaY: 15.5)
          ..shader = RadialGradient(
            colors: [
              blushColor!.withOpacity(blushOpacity),
              blushColor!.withOpacity(0.0),
            ],
          ).createShader(bounds);

        canvas.drawOval(bounds, paintCheek);

        // Harmony Heatmap outline warning for cheeks
        if (showHarmonyHeatmap && _isBlushMismatch()) {
          final paintWarning = Paint()
            ..color = const Color(0xFFFF3D00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawOval(bounds.inflate(4.0), paintWarning);
        }

        canvas.restore();
      }

      if (estimatedLeftCheek != null) {
        drawCheekBlush(estimatedLeftCheek, true);
      }
      if (estimatedRightCheek != null) {
        drawCheekBlush(estimatedRightCheek, false);
      }
      canvas.restore();
    }

    canvas.restore();
  }

  bool _isLipstickMismatch() {
    if (undertone == null || lipstickColor == null || lipstickOpacity == 0.0) return false;
    final String und = undertone!.toLowerCase();
    final int value = lipstickColor!.value & 0xFFFFFF;
    bool isCool = false;
    bool isWarm = false;
    if (value == 0xD81B60 || value == 0xAD1457 || value == 0x8E24AA || value == 0xB71C1C) {
      isCool = true;
    } else if (value == 0xFF7043 || value == 0x8D6E63) {
      isWarm = true;
    }
    if (und == 'warm' && isCool) return true;
    if (und == 'cool' && isWarm) return true;
    return false;
  }

  bool _isBlushMismatch() {
    if (undertone == null || blushColor == null || blushOpacity == 0.0) return false;
    final String und = undertone!.toLowerCase();
    final int value = blushColor!.value & 0xFFFFFF;
    bool isCool = false;
    bool isWarm = false;
    if (value == 0xFF80AB || value == 0xE91E63 || value == 0xBA68C8) {
      isCool = true;
    } else if (value == 0xFF8A80 || value == 0xFFB74D || value == 0xFF8F00) {
      isWarm = true;
    }
    if (und == 'warm' && isCool) return true;
    if (und == 'cool' && isWarm) return true;
    return false;
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
        oldDelegate.originalImageHeight != originalImageHeight ||
        oldDelegate.selectedLightingPreset != selectedLightingPreset ||
        oldDelegate.showHarmonyHeatmap != showHarmonyHeatmap ||
        oldDelegate.undertone != undertone;
  }
}
