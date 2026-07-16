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
  final String foundationFinishing; // 'matte', 'satin', 'dewy'

  // Split screen divider X
  final double sliderX;

  // Advanced Try-On Upgrades (Phase 2.5)
  final String selectedLightingPreset; // 'Natural', 'Golden Hour', 'Studio Light', 'Cyber Neon'
  final bool showHarmonyHeatmap;
  final String? undertone;

  // Parameter Riasan Mata
  final Color? eyeshadowColor;
  final double eyeshadowOpacity;
  final bool hasEyeliner;
  final double eyelinerThickness;

  // Parameter Hidung (Contour & Highlight)
  final double noseHighlightOpacity;
  final double noseShadingOpacity;

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
    this.foundationFinishing = 'dewy',
    required this.sliderX,
    required this.selectedLightingPreset,
    required this.showHarmonyHeatmap,
    this.undertone,
    this.eyeshadowColor,
    required this.eyeshadowOpacity,
    required this.hasEyeliner,
    required this.eyelinerThickness,
    required this.noseHighlightOpacity,
    required this.noseShadingOpacity,
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

    // 1.5 RENDER EYE MAKEUP (EYESHADOW & EYELINER)
    if ((eyeshadowColor != null && eyeshadowOpacity > 0.0) || hasEyeliner) {
      final leftEyePoints = face!.contours[FaceContourType.leftEye]?.points;
      final rightEyePoints = face!.contours[FaceContourType.rightEye]?.points;

      final eyes = FaceGeometryHelper.getEyeCenters(face!);
      final leftEyeCenter = eyes['left'];
      final rightEyeCenter = eyes['right'];
      
      if (leftEyeCenter != null && rightEyeCenter != null) {
        final vectors = FaceGeometryHelper.getFaceUnitVectors(face!, leftEyeCenter, rightEyeCenter);
        final unitX = vectors['unitX']!;
        final unitY = vectors['unitY']!;
        final Offset leftScreenEye = mapPoint(Point(leftEyeCenter.x.round(), leftEyeCenter.y.round()));
        final Offset rightScreenEye = mapPoint(Point(rightEyeCenter.x.round(), rightEyeCenter.y.round()));
        final double eyeDistance = (rightScreenEye - leftScreenEye).distance;

        // Hitung unit vector absolute di layar (screen space) untuk mengatasi mirroring & rotasi kamera
        final Offset screenOrigin = mapPoint(const Point(0, 0));
        final Offset rawScreenUnitX = (mapPoint(Point((unitX.x * 100).round(), (unitX.y * 100).round())) - screenOrigin) / 100.0;
        final Offset rawScreenUnitY = (mapPoint(Point((unitY.x * 100).round(), (unitY.y * 100).round())) - screenOrigin) / 100.0;
        
        final double lenX = rawScreenUnitX.distance;
        final double lenY = rawScreenUnitY.distance;
        
        final Offset screenUnitX = lenX > 0 ? rawScreenUnitX / lenX : const Offset(1, 0);
        final Offset screenUnitY = lenY > 0 ? rawScreenUnitY / lenY : const Offset(0, 1);

        void drawEyeMakeup(List<Point<int>>? eyePoints, bool isEyeOnLeftOfScreen) {
          if (eyePoints == null || eyePoints.length < 9) return;

          // Kita map semua titik kontur mata ke screen space
          final List<Offset> mappedEye = eyePoints.map((p) => mapPoint(Point(p.x, p.y))).toList();

          // Titik 0 s.d. 8 adalah kelopak mata atas
          final List<Offset> upperLid = mappedEye.sublist(0, 9);

          // 1. EYESHADOW RENDER
          if (eyeshadowColor != null && eyeshadowOpacity > 0.0) {
            final Path eyeshadowPath = Path();
            final List<Offset> shiftedPoints = [];

            for (int i = 0; i < upperLid.length; i++) {
              // Hitung faktor bell-curve untuk ketebalan di tengah kelopak
              final double bellFactor = sin(i / 8.0 * pi);
              final double shiftAmount = eyeDistance * 0.16 * bellFactor;
              
              final double sx = upperLid[i].dx - screenUnitY.dx * shiftAmount;
              final double sy = upperLid[i].dy - screenUnitY.dy * shiftAmount;
              shiftedPoints.add(Offset(sx, sy));
            }

            // Gabungkan kelopak mata atas dengan titik yang digeser ke atas (dalam urutan terbalik)
            eyeshadowPath.moveTo(upperLid.first.dx, upperLid.first.dy);
            for (int i = 1; i < upperLid.length; i++) {
              eyeshadowPath.lineTo(upperLid[i].dx, upperLid[i].dy);
            }
            for (int i = shiftedPoints.length - 1; i >= 0; i--) {
              eyeshadowPath.lineTo(shiftedPoints[i].dx, shiftedPoints[i].dy);
            }
            eyeshadowPath.close();

            // Gradient linear vertikal lokal untuk masing-masing kelopak mata (memudar ke atas)
            final Paint paintEyeshadow = Paint()
              ..style = PaintingStyle.fill
              ..shader = ui.Gradient.linear(
                upperLid[4], // Tengah kelopak mata bawah
                shiftedPoints[4], // Tengah kelopak mata atas yang digeser
                [
                  eyeshadowColor!.withOpacity(eyeshadowOpacity),
                  eyeshadowColor!.withOpacity(0.0),
                ],
              )
              ..imageFilter = ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0); // Blurring halus agar menyatu alami

            // Buat clip path agar tidak menembus bola mata di bawah lash line
            final Path clipPath = Path();
            clipPath.moveTo(upperLid.first.dx, upperLid.first.dy);
            for (int i = 1; i < upperLid.length; i++) {
              clipPath.lineTo(upperLid[i].dx, upperLid[i].dy);
            }
            final Offset farUp1 = upperLid.last - screenUnitY * (eyeDistance * 2.0);
            final Offset farUp2 = upperLid.first - screenUnitY * (eyeDistance * 2.0);
            clipPath.lineTo(farUp1.dx, farUp1.dy);
            clipPath.lineTo(farUp2.dx, farUp2.dy);
            clipPath.close();

            canvas.save();
            canvas.clipPath(clipPath);
            canvas.drawPath(eyeshadowPath, paintEyeshadow);
            canvas.restore();
          }

          // 2. EYELINER RENDER
          if (hasEyeliner) {
            final Path eyelinerPath = Path();
            
            // Pastikan wingUnitX selalu mengarah ke kanan layar (dx > 0)
            Offset wingUnitX = screenUnitX;
            if (wingUnitX.dx < 0) {
              wingUnitX = -wingUnitX;
            }

            // Tentukan apakah urutan koordinat Point 0 berada di sebelah kiri Point 8 pada layar
            final bool isP0OnLeft = upperLid[0].dx < upperLid[8].dx;
            final List<Offset> sortedUpperLid = isP0OnLeft ? upperLid : upperLid.reversed.toList();

            // Ketebalan maksimum eyeliner berdasarkan ukuran mata dan slider kustom ketebalan
            final double maxThickness = eyeDistance * 0.012 * (1.0 + eyelinerThickness * 2.5);

            // Buat batas atas eyeliner yang digeser ke atas secara progresif (tapering ke 0 di sudut dalam)
            final List<Offset> upperBoundary = [];
            for (int i = 0; i < sortedUpperLid.length; i++) {
              double t;
              if (isEyeOnLeftOfScreen) {
                t = 1.0 - (i / (sortedUpperLid.length - 1)); // 1.0 di kiri (outer), 0.0 di kanan (inner)
              } else {
                t = i / (sortedUpperLid.length - 1); // 0.0 di kiri (inner), 1.0 di kanan (outer)
              }
              final double shiftAmount = maxThickness * t;
              upperBoundary.add(sortedUpperLid[i] - screenUnitY * shiftAmount);
            }

            if (isEyeOnLeftOfScreen) {
              // Mata di sebelah kiri layar: Sudut luar di kiri (sortedUpperLid.first), sayap ditarik ke kiri (-wingUnitX)
              final Offset outerCorner = sortedUpperLid.first;
              final double wingX = outerCorner.dx - wingUnitX.dx * (eyeDistance * 0.08) - screenUnitY.dx * (eyeDistance * 0.015);
              final double wingY = outerCorner.dy - wingUnitX.dy * (eyeDistance * 0.08) - screenUnitY.dy * (eyeDistance * 0.015);

              // Path poligon eyeliner terisi (mengikuti persis lekukan kelopak mata tanpa meluberi eyeball)
              eyelinerPath.moveTo(wingX, wingY);
              eyelinerPath.lineTo(upperBoundary.first.dx, upperBoundary.first.dy);
              for (int i = 1; i < upperBoundary.length; i++) {
                eyelinerPath.lineTo(upperBoundary[i].dx, upperBoundary[i].dy);
              }
              for (int i = sortedUpperLid.length - 1; i >= 0; i--) {
                eyelinerPath.lineTo(sortedUpperLid[i].dx, sortedUpperLid[i].dy);
              }
              eyelinerPath.close();
            } else {
              // Mata di sebelah kanan layar: Sudut luar di kanan (sortedUpperLid.last), sayap ditarik ke kanan (+wingUnitX)
              final Offset outerCorner = sortedUpperLid.last;
              final double wingX = outerCorner.dx + wingUnitX.dx * (eyeDistance * 0.08) - screenUnitY.dx * (eyeDistance * 0.015);
              final double wingY = outerCorner.dy + wingUnitX.dy * (eyeDistance * 0.08) - screenUnitY.dy * (eyeDistance * 0.015);

              // Mulai dari sudut dalam di kiri (sortedUpperLid.first)
              eyelinerPath.moveTo(sortedUpperLid.first.dx, sortedUpperLid.first.dy);
              for (int i = 0; i < upperBoundary.length; i++) {
                eyelinerPath.lineTo(upperBoundary[i].dx, upperBoundary[i].dy);
              }
              eyelinerPath.lineTo(wingX, wingY);
              for (int i = sortedUpperLid.length - 1; i >= 0; i--) {
                eyelinerPath.lineTo(sortedUpperLid[i].dx, sortedUpperLid[i].dy);
              }
              eyelinerPath.close();
            }

            final Paint paintEyeliner = Paint()
              ..style = PaintingStyle.fill
              ..color = const Color(0xFF1A1A1A) // Charcoal black
              ..imageFilter = ui.ImageFilter.blur(sigmaX: 0.3, sigmaY: 0.3); // Anti-aliasing halus

            canvas.drawPath(eyelinerPath, paintEyeliner);
          }
        }

        // Deteksi posisi mata relatif terhadap layar untuk wing direction yang konsisten dan akurat
        final bool isLeftEyeOnLeft = leftScreenEye.dx < rightScreenEye.dx;
        drawEyeMakeup(leftEyePoints, isLeftEyeOnLeft);
        drawEyeMakeup(rightEyePoints, !isLeftEyeOnLeft);
      }
    }

    // 1.7 RENDER NOSE MAKEUP (SHADING & HIGHLIGHT)
    if (noseHighlightOpacity > 0.0 || noseShadingOpacity > 0.0) {
      final noseBridgePoints = face!.contours[FaceContourType.noseBridge]?.points;
      if (noseBridgePoints != null && noseBridgePoints.isNotEmpty) {
        // Map all nose bridge points to screen space
        final List<Offset> mappedBridge = noseBridgePoints.map((p) => mapPoint(Point(p.x, p.y))).toList();

        // Calculate face geometry metrics to make rendering relative
        final double bridgeLength = (mappedBridge.last - mappedBridge.first).distance;
        final double strokeW = faceWidth * 0.024;

        // Obtain horizontal orientation vector of the face (unitX)
        Offset unitX = const Offset(1, 0);
        final eyes = FaceGeometryHelper.getEyeCenters(face!);
        final leftEyeCenter = eyes['left'];
        final rightEyeCenter = eyes['right'];
        if (leftEyeCenter != null && rightEyeCenter != null) {
          final vectors = FaceGeometryHelper.getFaceUnitVectors(face!, leftEyeCenter, rightEyeCenter);
          if (vectors['unitX'] != null) {
            unitX = Offset(vectors['unitX']!.x, vectors['unitX']!.y);
          }
        }

        // 1. NOSE SHADING (CONTOUR)
        if (noseShadingOpacity > 0.0) {
          final Path leftShadingPath = Path();
          final Path rightShadingPath = Path();

          final double sideShift = faceWidth * 0.040; // distance from center line to sides

          // Draw the parallel lines down the sides of the bridge
          leftShadingPath.moveTo(
            mappedBridge.first.dx - unitX.dx * sideShift,
            mappedBridge.first.dy - unitX.dy * sideShift,
          );
          rightShadingPath.moveTo(
            mappedBridge.first.dx + unitX.dx * sideShift,
            mappedBridge.first.dy + unitX.dy * sideShift,
          );

          for (int i = 1; i < mappedBridge.length; i++) {
            leftShadingPath.lineTo(
              mappedBridge[i].dx - unitX.dx * sideShift,
              mappedBridge[i].dy - unitX.dy * sideShift,
            );
            rightShadingPath.lineTo(
              mappedBridge[i].dx + unitX.dx * sideShift,
              mappedBridge[i].dy + unitX.dy * sideShift,
            );
          }

          // Shading Paint: Cool-toned soft contour brown with strong blur filter
          final Paint paintShading = Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF7D5F52).withOpacity(noseShadingOpacity * 0.75)
            ..strokeWidth = faceWidth * 0.038
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

          // Apply Gaussian Blur to blend the shading smoothly
          paintShading.imageFilter = ui.ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5);

          canvas.drawPath(leftShadingPath, paintShading);
          canvas.drawPath(rightShadingPath, paintShading);
        }

        // 2. NOSE HIGHLIGHT
        if (noseHighlightOpacity > 0.0) {
          // A. Nose Bridge Highlight Line
          final Path highlightPath = Path();
          highlightPath.moveTo(mappedBridge.first.dx, mappedBridge.first.dy);
          for (int i = 1; i < mappedBridge.length - 1; i++) {
            highlightPath.lineTo(mappedBridge[i].dx, mappedBridge[i].dy);
          }

          // Creamy warm-white bright highlight
          final Paint paintHighlightLine = Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFFFFFDF5).withOpacity(noseHighlightOpacity * 0.5)
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5);

          canvas.drawPath(highlightPath, paintHighlightLine);

          // B. Nose Tip Highlight (The button/dot highlight at the tip of the nose)
          final Offset noseTip = mappedBridge.last;
          
          final Paint paintTipCircle = Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFFFFDF5).withOpacity(noseHighlightOpacity * 0.65)
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5);

          canvas.drawCircle(noseTip, faceWidth * 0.009, paintTipCircle);
        }
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

    final cheeks = FaceGeometryHelper.getCheekboneCoordinates(face!);
    estimatedLeftCheek = mapPoint(Point(cheeks['left']!.x.round(), cheeks['left']!.y.round()));
    estimatedRightCheek = mapPoint(Point(cheeks['right']!.x.round(), cheeks['right']!.y.round()));

    // 2. RENDER DEWY GLASS SKIN GLOW / SATIN HIGHLIGHTS
    if (showGlassSkin && foundationOpacity > 0.0 && foundationFinishing != 'matte' && estimatedLeftCheek != null && estimatedRightCheek != null) {
      final bool isDewy = foundationFinishing == 'dewy';
      
      final double cheekRadius = faceWidth * (isDewy ? 0.18 : 0.22);
      final double cheekOpacity = isDewy ? 0.22 : 0.12;

      final double foreheadRadius = faceWidth * (isDewy ? 0.20 : 0.24);
      final double foreheadOpacity = isDewy ? 0.15 : 0.08;

      final double noseRadius = faceWidth * (isDewy ? 0.04 : 0.06);
      final double noseOpacity = isDewy ? 0.25 : 0.15;

      final double chinRadius = faceWidth * (isDewy ? 0.08 : 0.10);
      final double chinOpacity = isDewy ? 0.12 : 0.08;

      final Paint paintGlow = Paint()
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.screen;

      // Glow Pipi Kiri
      paintGlow.shader = ui.Gradient.radial(
        estimatedLeftCheek,
        cheekRadius,
        [
          Colors.white.withOpacity(cheekOpacity),
          Colors.white.withOpacity(0.0),
        ],
      );
      canvas.drawCircle(estimatedLeftCheek, cheekRadius, paintGlow);

      // Glow Pipi Kanan
      paintGlow.shader = ui.Gradient.radial(
        estimatedRightCheek,
        cheekRadius,
        [
          Colors.white.withOpacity(cheekOpacity),
          Colors.white.withOpacity(0.0),
        ],
      );
      canvas.drawCircle(estimatedRightCheek, cheekRadius, paintGlow);

      // Glow Dahi
      final foreheadPt = FaceGeometryHelper.getForeheadCoordinate(face!);
      final mappedForehead = mapPoint(Point(foreheadPt.x.round(), foreheadPt.y.round()));
      paintGlow.shader = ui.Gradient.radial(
        mappedForehead,
        foreheadRadius,
        [
          Colors.white.withOpacity(foreheadOpacity),
          Colors.white.withOpacity(0.0),
        ],
      );
      canvas.drawCircle(mappedForehead, foreheadRadius, paintGlow);

      // Glow Ujung Hidung
      final noseBridgePoints = face!.contours[FaceContourType.noseBridge]?.points;
      if (noseBridgePoints != null && noseBridgePoints.isNotEmpty) {
        final mappedNoseTip = mapPoint(Point(noseBridgePoints.last.x.round(), noseBridgePoints.last.y.round()));
        paintGlow.shader = ui.Gradient.radial(
          mappedNoseTip,
          noseRadius,
          [
            Colors.white.withOpacity(noseOpacity),
            Colors.white.withOpacity(0.0),
          ],
        );
        canvas.drawCircle(mappedNoseTip, noseRadius, paintGlow);
      }

      // Glow Dagu
      final facePoints = face!.contours[FaceContourType.face]?.points;
      if (facePoints != null && facePoints.length > 18) {
        final mappedChin = mapPoint(Point(facePoints[18].x.round(), facePoints[18].y.round()));
        paintGlow.shader = ui.Gradient.radial(
          mappedChin,
          chinRadius,
          [
            Colors.white.withOpacity(chinOpacity),
            Colors.white.withOpacity(0.0),
          ],
        );
        canvas.drawCircle(mappedChin, chinRadius, paintGlow);
      }
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
        
        // Deteksi bentuk wajah dinamis dari bounding box ratio
        final double boxW = face!.boundingBox.width.toDouble();
        final double boxH = face!.boundingBox.height.toDouble();
        final double ratio = boxH / boxW;

        double tilt;
        double width;
        double height;

        if (ratio < 1.13) {
          // Wajah bulat/lebar: sapuan sangat miring (tirus) ke atas
          tilt = isLeft ? -0.32 : 0.32;
          width = faceWidth * 0.54;
          height = faceWidth * 0.23;
        } else if (ratio > 1.25) {
          // Wajah lonjong/panjang: sapuan mendatar (horizontal) untuk melebarkan wajah
          tilt = 0.0;
          width = faceWidth * 0.56;
          height = faceWidth * 0.28;
        } else {
          // Wajah oval (default): sapuan miring proporsional
          tilt = isLeft ? -0.20 : 0.20;
          width = faceWidth * 0.54;
          height = faceWidth * 0.26;
        }

        canvas.rotate(rollAngle + tilt);
        
        // Pipi kiri disapu ke kiri luar, pipi kanan ke kanan luar (tanpa mirroring karena foto 2D statis)
        final double offsetX = isLeft ? -width * 0.20 : width * 0.20;
        
        final Rect bounds = Rect.fromCenter(
          center: Offset(offsetX, -smileShiftY),
          width: width,
          height: height,
        );
        
        final paintCheek = Paint()
          ..style = PaintingStyle.fill
          // Menggunakan blur terkalibrasi (sigma 9.5) agar warna tidak larut/hilang, tetapi tepi tetap halus airbrush
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 9.5, sigmaY: 8.0)
          ..shader = RadialGradient(
            colors: [
              blushColor!.withOpacity((blushOpacity * 2.2).clamp(0.0, 1.0)),
              blushColor!.withOpacity((blushOpacity * 1.1).clamp(0.0, 1.0)),
              blushColor!.withOpacity(0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
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
        oldDelegate.showGlassSkin != showGlassSkin ||
        oldDelegate.foundationFinishing != foundationFinishing ||
        oldDelegate.originalImageWidth != originalImageWidth ||
        oldDelegate.originalImageHeight != originalImageHeight ||
        oldDelegate.selectedLightingPreset != selectedLightingPreset ||
        oldDelegate.showHarmonyHeatmap != showHarmonyHeatmap ||
        oldDelegate.undertone != undertone ||
        oldDelegate.eyeshadowColor != eyeshadowColor ||
        oldDelegate.eyeshadowOpacity != eyeshadowOpacity ||
        oldDelegate.hasEyeliner != hasEyeliner ||
        oldDelegate.eyelinerThickness != eyelinerThickness ||
        oldDelegate.noseHighlightOpacity != noseHighlightOpacity ||
        oldDelegate.noseShadingOpacity != noseShadingOpacity;
  }
}
