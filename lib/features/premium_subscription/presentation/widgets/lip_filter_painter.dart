import '../../../../core/utils/face_geometry_helper.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Parameter Base Makeup (Foundation)
  final Color? foundationColor;
  final double foundationOpacity;

  // Glass Skin & Highlighter
  final bool showGlassSkin;

  final double sliderX;

  // Advanced Try-On Upgrades (Phase 2.5)
  final String selectedLightingPreset; // 'Natural', 'Golden Hour', 'Studio Light', 'Cyber Neon'
  final bool showHarmonyHeatmap;
  final String? undertone;

  // Parameter Riasan Mata
  final Color? eyeshadowColor;
  final double eyeshadowOpacity;
  final bool hasEyeliner;

  // Parameter Hidung (Contour & Highlight)
  final double noseHighlightOpacity;
  final double noseShadingOpacity;

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
    this.foundationColor,
    required this.foundationOpacity,
    required this.showGlassSkin,
    required this.sliderX,
    required this.selectedLightingPreset,
    required this.showHarmonyHeatmap,
    this.undertone,
    this.eyeshadowColor,
    required this.eyeshadowOpacity,
    required this.hasEyeliner,
    required this.noseHighlightOpacity,
    required this.noseShadingOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (face == null || imageWidth == 0 || imageHeight == 0) return;

    final bool isLandscape = size.width > size.height;
    final double scaleX = isLandscape ? size.width / imageWidth : size.width / imageHeight;
    final double scaleY = isLandscape ? size.height / imageHeight : size.height / imageWidth;

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

    // Estimasi posisi pipi untuk blush-on (menggunakan logika 100% identik dengan uji rias 2D yang sangat bagus)
    Offset? estimatedLeftCheek;
    Offset? estimatedRightCheek;

    final cheeks = FaceGeometryHelper.getCheekboneCoordinates(face!);
    estimatedLeftCheek = mapPoint(Point(cheeks['left']!.x.round(), cheeks['left']!.y.round()));
    estimatedRightCheek = mapPoint(Point(cheeks['right']!.x.round(), cheeks['right']!.y.round()));

    // 1. RENDER BASE MAKEUP (LIVE FOUNDATION)
    if (foundationColor != null && foundationOpacity > 0.0) {
      final faceContourPoints = face!.contours[FaceContourType.face]?.points;
      if (faceContourPoints != null && faceContourPoints.isNotEmpty) {
        final Path facePath = Path();
        final List<Offset> faceOffsets = faceContourPoints.map((p) => mapPoint(Point(p.x, p.y))).toList();
        
        // Perluas dahi ke arah hairline
        final hairlinePts = FaceGeometryHelper.getHairlinePoints(face!);
        faceOffsets.add(mapPoint(Point(hairlinePts[0].x.round(), hairlinePts[0].y.round())));
        faceOffsets.add(mapPoint(Point(hairlinePts[1].x.round(), hairlinePts[1].y.round())));
        faceOffsets.add(mapPoint(Point(hairlinePts[2].x.round(), hairlinePts[2].y.round())));
        
        buildSmoothPath(facePath, faceOffsets);
        facePath.close();

        // Buat lubang cutout agar tidak menutupi mata, alis, dan mulut
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
          ..blendMode = BlendMode.srcOver
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5);

        canvas.drawPath(finalFoundationPath, paintBase);
      }
    }

    // 1.5 RENDER EYE MAKEUP (EYESHADOW & EYELINER)
    if ((eyeshadowColor != null && eyeshadowOpacity > 0.0) || hasEyeliner) {
      final leftEyePoints = face!.contours[FaceContourType.leftEye]?.points;
      final rightEyePoints = face!.contours[FaceContourType.rightEye]?.points;

      final eyes = FaceGeometryHelper.getEyeCenters(face!);
      final leftEyeCenter = eyes['left']!;
      final rightEyeCenter = eyes['right']!;
      
      final vectors = FaceGeometryHelper.getFaceUnitVectors(face!, leftEyeCenter, rightEyeCenter);
      final unitX = vectors['unitX']!;
      final unitY = vectors['unitY']!;
      final Offset leftScreenEye = mapPoint(Point(leftEyeCenter.x.round(), leftEyeCenter.y.round()));
      final Offset rightScreenEye = mapPoint(Point(rightEyeCenter.x.round(), rightEyeCenter.y.round()));
      final double eyeDistance = (rightScreenEye - leftScreenEye).distance;

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
            
            final double sx = upperLid[i].dx - unitY.x * shiftAmount;
            final double sy = upperLid[i].dy - unitY.y * shiftAmount;
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

          final Paint paintEyeshadow = Paint()
            ..style = PaintingStyle.fill
            ..shader = ui.Gradient.linear(
              Offset(leftScreenEye.dx, leftScreenEye.dy),
              Offset(rightScreenEye.dx, rightScreenEye.dy),
              [
                eyeshadowColor!.withOpacity(eyeshadowOpacity),
                eyeshadowColor!.withOpacity(0.0),
              ],
            )
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0);

          canvas.drawPath(eyeshadowPath, paintEyeshadow);
        }

        // 2. EYELINER RENDER
        if (hasEyeliner) {
          final Path eyelinerPath = Path();
          
          // Pastikan wingUnitX selalu mengarah ke kanan layar (dx > 0)
          Offset wingUnitX = Offset(unitX.x, unitX.y);
          if (wingUnitX.dx < 0) {
            wingUnitX = -wingUnitX;
          }

          // Geser titik lash line sedikit ke atas (menjauhi bola mata, menuju kelopak mata)
          final Offset unitYOffset = Offset(unitY.x, unitY.y) * (eyeDistance * 0.012);

          // Tentukan apakah urutan koordinat Point 0 berada di sebelah kiri Point 8 pada layar
          final bool isP0OnLeft = upperLid[0].dx < upperLid[8].dx;

          // Urutkan titik kelopak mata atas dari kiri ke kanan layar (indeks 1 s.d. 7)
          final List<Offset> sortedLash = [];
          if (isP0OnLeft) {
            for (int i = 1; i <= 7; i++) {
              sortedLash.add(upperLid[i] - unitYOffset);
            }
          } else {
            for (int i = 7; i >= 1; i--) {
              sortedLash.add(upperLid[i] - unitYOffset);
            }
          }

          // Hitung posisi sudut dalam mata (dekat hidung) secara presisi dengan Y-clamping untuk mencegah lekukan kail ke bawah
          final Offset p0Shifted = upperLid[0] - unitYOffset;
          final Offset p1Shifted = upperLid[1] - unitYOffset;
          final Offset p7Shifted = upperLid[7] - unitYOffset;
          final Offset p8Shifted = upperLid[8] - unitYOffset;

          final Offset leftInnerCorner = isP0OnLeft
              ? Offset(p0Shifted.dx, min(p0Shifted.dy, p1Shifted.dy))
              : Offset(p8Shifted.dx, min(p8Shifted.dy, p7Shifted.dy));

          final Offset rightInnerCorner = isP0OnLeft
              ? Offset(p8Shifted.dx, min(p8Shifted.dy, p7Shifted.dy))
              : Offset(p0Shifted.dx, min(p0Shifted.dy, p1Shifted.dy));

          if (isEyeOnLeftOfScreen) {
            // Mata di sebelah kiri layar: Sudut luar di kiri (sortedLash.first), sayap ditarik ke kiri (-wingUnitX)
            final Offset outerCorner = sortedLash.first;
            final double wingX = outerCorner.dx - wingUnitX.dx * (eyeDistance * 0.08) - unitY.x * (eyeDistance * 0.015);
            final double wingY = outerCorner.dy - wingUnitX.dy * (eyeDistance * 0.08) - unitY.y * (eyeDistance * 0.015);

            eyelinerPath.moveTo(wingX, wingY);
            eyelinerPath.lineTo(outerCorner.dx, outerCorner.dy);

            // Sambungkan garis kelopak mata halus hingga ke sudut dalam dekat hidung (rightInnerCorner)
            final List<Offset> pointsToSmooth = [...sortedLash, rightInnerCorner];
            final Path smoothLashPath = Path();
            buildSmoothPath(smoothLashPath, pointsToSmooth);
            eyelinerPath.addPath(smoothLashPath, Offset.zero);
          } else {
            // Mata di sebelah kanan layar: Sudut luar di kanan (sortedLash.last), sayap ditarik ke kanan (+wingUnitX)
            final Offset outerCorner = sortedLash.last;
            final double wingX = outerCorner.dx + wingUnitX.dx * (eyeDistance * 0.08) - unitY.x * (eyeDistance * 0.015);
            final double wingY = outerCorner.dy + wingUnitX.dy * (eyeDistance * 0.08) - unitY.y * (eyeDistance * 0.015);

            // Gambar kelopak mata halus dimulai dari sudut dalam dekat hidung (leftInnerCorner) hingga ke sudut luar
            final List<Offset> pointsToSmooth = [leftInnerCorner, ...sortedLash];
            final Path smoothLashPath = Path();
            buildSmoothPath(smoothLashPath, pointsToSmooth);
            eyelinerPath.addPath(smoothLashPath, Offset.zero);

            // Tarik garis sayap luar
            eyelinerPath.lineTo(wingX, wingY);
          }

          final Paint paintEyeliner = Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF1A1A1A) // Charcoal black
            ..strokeWidth = (eyeDistance * 0.020).clamp(1.2, 2.5) // Dipersempit agar lebih presisi dan natural
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

          canvas.drawPath(eyelinerPath, paintEyeliner);
        }
      }

      // Deteksi posisi mata relatif terhadap layar untuk wing direction yang konsisten dan akurat
      final bool isLeftEyeOnLeft = leftScreenEye.dx < rightScreenEye.dx;
      drawEyeMakeup(leftEyePoints, isLeftEyeOnLeft);
      drawEyeMakeup(rightEyePoints, !isLeftEyeOnLeft);
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
            ..blendMode = BlendMode.srcOver
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0);
          canvas.drawPath(facePath, paintLight);
        } else if (selectedLightingPreset == 'Studio Light') {
          // Specular white spotlight over dahi & nose
          final foreheadPt = FaceGeometryHelper.getForeheadCoordinate(face!);
          final mappedForehead = mapPoint(Point(foreheadPt.x.round(), foreheadPt.y.round()));
          final double spotlightRadius = faceWidth * 0.4;
          final Paint paintLight = Paint()
            ..style = PaintingStyle.fill
            ..blendMode = BlendMode.srcOver
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
            ..blendMode = BlendMode.srcOver;

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

    // 2. RENDER DEWY GLASS SKIN GLOW
    if (showGlassSkin && estimatedLeftCheek != null && estimatedRightCheek != null) {
      final double glowRadius = faceWidth * 0.22;
      
      final Paint paintGlow = Paint()
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.srcOver;

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

    // 3. GAMBAR FILTER LIPSTIK (BIBIR)
    if (lipstickColor != null && lipstickOpacity > 0.0) {
      final upperLipTop = face!.contours[FaceContourType.upperLipTop]?.points;
      final upperLipBottom = face!.contours[FaceContourType.upperLipBottom]?.points;
      final lowerLipTop = face!.contours[FaceContourType.lowerLipTop]?.points;
      final lowerLipBottom = face!.contours[FaceContourType.lowerLipBottom]?.points;

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

      // Atur finishing lipstik (Matte vs Glossy) dengan gradien warna alami untuk efek 3D
      final paintLip = Paint()
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.srcOver
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4);

      if (lipstickFinishing == 'glossy') {
        // Glossy: Menggunakan Shader Gradien Vertikal terintegrasi untuk mensimulasikan kilap cahaya di tengah bibir secara natural
        final Rect upperBounds = upperLipPath.getBounds();
        final Rect lowerBounds = lowerLipPath.getBounds();
        final Rect combinedBounds = upperBounds.expandToInclude(lowerBounds);
        
        paintLip.shader = ui.Gradient.linear(
          Offset(combinedBounds.left + combinedBounds.width / 2, combinedBounds.top),
          Offset(combinedBounds.left + combinedBounds.width / 2, combinedBounds.bottom),
          [
            lipstickColor!.withOpacity(lipstickOpacity * 0.70),
            Color.lerp(lipstickColor, Colors.white, 0.38)!.withOpacity(lipstickOpacity * 0.95), // Pantulan kilap putih-pink lembut di tengah
            lipstickColor!.withOpacity(lipstickOpacity * 0.70),
          ],
          [0.0, 0.6, 1.0],
        );
      } else {
        // Matte: Warna velvet solid pekat yang rata dari atas sampai bawah
        paintLip.color = lipstickColor!.withOpacity(lipstickOpacity * 1.15);
      }

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

    // 4. GAMBAR FILTER BLUSH-ON (PIPI - Oval Panjang Terputar menyamping mengikuti kontur tulang pipi / cheekbone draping)
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
        
        // Arah pergeseran luar (outward) dengan memperhitungkan pencerminan kamera depan
        final bool isFrontCamera = lensDirection == CameraLensDirection.front;
        final double offsetX = isFrontCamera
            ? (isLeft ? width * 0.20 : -width * 0.20)
            : (isLeft ? -width * 0.20 : width * 0.20);
        
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
    } else if (value == 0xFFFF7043 || value == 0x8D6E63 || value == 0xF98E7B) {
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
    } else if (value == 0xFFFF8A80 || value == 0xFFB74D || value == 0xFFFF8F00) {
      isWarm = true;
    }
    if (und == 'warm' && isCool) return true;
    if (und == 'cool' && isWarm) return true;
    return false;
  }

  @override
  bool shouldRepaint(covariant LipFilterPainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.lipstickColor != lipstickColor ||
        oldDelegate.lipstickOpacity != lipstickOpacity ||
        oldDelegate.lipstickFinishing != lipstickFinishing ||
        oldDelegate.blushColor != blushColor ||
        oldDelegate.blushOpacity != blushOpacity ||
        oldDelegate.foundationColor != foundationColor ||
        oldDelegate.foundationOpacity != foundationOpacity ||
        oldDelegate.showGlassSkin != showGlassSkin ||
        oldDelegate.sliderX != sliderX ||
        oldDelegate.selectedLightingPreset != selectedLightingPreset ||
        oldDelegate.showHarmonyHeatmap != showHarmonyHeatmap ||
        oldDelegate.undertone != undertone ||
        oldDelegate.eyeshadowColor != eyeshadowColor ||
        oldDelegate.eyeshadowOpacity != eyeshadowOpacity ||
        oldDelegate.hasEyeliner != hasEyeliner ||
        oldDelegate.noseHighlightOpacity != noseHighlightOpacity ||
        oldDelegate.noseShadingOpacity != noseShadingOpacity;
  }
}
