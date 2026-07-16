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
  final String foundationFinishing; // 'matte', 'satin', 'dewy'

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
  
  // Panduan Kontur AR Overlay
  final bool showContourGuide;

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
    required this.showContourGuide,
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

    // 2. RENDER DEWY GLASS SKIN GLOW / SATIN HIGHLIGHTS
    if (showGlassSkin && foundationOpacity > 0.0 && foundationFinishing != 'matte' && estimatedLeftCheek != null && estimatedRightCheek != null) {
      final bool isDewy = foundationFinishing == 'dewy';
      
      final Paint paintGlow = Paint()
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.srcOver;

      // Glow Pipi Kiri & Kanan (Hanya muncul jika blushOpacity > 0.0 dan blushColor != null)
      if (blushColor != null && blushOpacity > 0.0) {
        final double cheekRadius = faceWidth * (isDewy ? 0.18 : 0.22);
        final double baseCheekOpacity = isDewy ? 0.22 : 0.12;
        final double currentCheekOpacity = (baseCheekOpacity * (blushOpacity * 2.0)).clamp(0.0, 1.0);

        paintGlow.shader = ui.Gradient.radial(
          estimatedLeftCheek,
          cheekRadius,
          [
            Colors.white.withOpacity(currentCheekOpacity),
            Colors.white.withOpacity(0.0),
          ],
        );
        canvas.drawCircle(estimatedLeftCheek, cheekRadius, paintGlow);

        paintGlow.shader = ui.Gradient.radial(
          estimatedRightCheek,
          cheekRadius,
          [
            Colors.white.withOpacity(currentCheekOpacity),
            Colors.white.withOpacity(0.0),
          ],
        );
        canvas.drawCircle(estimatedRightCheek, cheekRadius, paintGlow);
      }

      // Glow T-Zone (Dahi & Ujung Hidung) (Hanya muncul jika noseHighlightOpacity > 0.0)
      if (noseHighlightOpacity > 0.0) {
        // Dahi
        final foreheadPt = FaceGeometryHelper.getForeheadCoordinate(face!);
        final mappedForehead = mapPoint(Point(foreheadPt.x.round(), foreheadPt.y.round()));
        final double foreheadRadius = faceWidth * (isDewy ? 0.20 : 0.24);
        final double baseForeheadOpacity = isDewy ? 0.15 : 0.08;
        final double currentForeheadOpacity = (baseForeheadOpacity * noseHighlightOpacity).clamp(0.0, 1.0);

        paintGlow.shader = ui.Gradient.radial(
          mappedForehead,
          foreheadRadius,
          [
            Colors.white.withOpacity(currentForeheadOpacity),
            Colors.white.withOpacity(0.0),
          ],
        );
        canvas.drawCircle(mappedForehead, foreheadRadius, paintGlow);

        // Ujung Hidung
        final noseBridgePoints = face!.contours[FaceContourType.noseBridge]?.points;
        if (noseBridgePoints != null && noseBridgePoints.isNotEmpty) {
          final mappedNoseTip = mapPoint(Point(noseBridgePoints.last.x.round(), noseBridgePoints.last.y.round()));
          final double noseRadius = faceWidth * (isDewy ? 0.04 : 0.06);
          final double baseNoseOpacity = isDewy ? 0.25 : 0.15;
          final double currentNoseOpacity = (baseNoseOpacity * noseHighlightOpacity).clamp(0.0, 1.0);

          paintGlow.shader = ui.Gradient.radial(
            mappedNoseTip,
            noseRadius,
            [
              Colors.white.withOpacity(currentNoseOpacity),
              Colors.white.withOpacity(0.0),
            ],
          );
          canvas.drawCircle(mappedNoseTip, noseRadius, paintGlow);
        }
      }
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

    if (showContourGuide) {
      final String shape = FaceGeometryHelper.classifyFaceShape(face!);
      final eyes = FaceGeometryHelper.getEyeCenters(face!);
      final leftEye = eyes['left']!;
      final rightEye = eyes['right']!;
      final vectors = FaceGeometryHelper.getFaceUnitVectors(face!, leftEye, rightEye);
      final Point<double> unitX = vectors['unitX']!;
      final Point<double> unitY = vectors['unitY']!;
      final double eyeDist = vectors['distance']!.x;
      
      final cheekCoords = FaceGeometryHelper.getCheekCoordinates(face!);
      final foreheadPt = FaceGeometryHelper.getForeheadCoordinate(face!);
      final faceContour = face!.contours[FaceContourType.face]?.points ?? [];

      if (faceContour.length >= 36) {
        final Paint contourFillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0x3B8B5A2B); // Brown 23% opacity

        final Paint contourStrokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0x808B5A2B); // Brown 50% opacity

        final Paint highlightFillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0x3BFFEB3B); // Golden yellow 23% opacity

        final Paint highlightStrokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0x80FFEB3B); // Golden yellow 50% opacity

        void drawOvalGuide(Point<double> center, double rx, double ry, bool isHighlight) {
          final Offset centerOffset = mapPoint(Point(center.x.round(), center.y.round()));
          final double rollRad = (face!.headEulerAngleZ ?? 0.0) * pi / 180.0;
          
          canvas.save();
          canvas.translate(centerOffset.dx, centerOffset.dy);
          canvas.rotate(lensDirection == CameraLensDirection.front ? -rollRad : rollRad);
          
          final rect = Rect.fromLTRB(-rx * scaleX, -ry * scaleY, rx * scaleX, ry * scaleY);
          canvas.drawOval(rect, isHighlight ? highlightFillPaint : contourFillPaint);
          canvas.drawOval(rect, isHighlight ? highlightStrokePaint : contourStrokePaint);
          
          canvas.restore();
        }

        // --- DRAW COMMON HIGHLIGHTS ---
        // 1. Dahi Tengah
        drawOvalGuide(foreheadPt, eyeDist * 0.22, eyeDist * 0.12, true);
        
        // 2. Batang Hidung (Nose Bridge)
        final noseBridgePoints = face!.contours[FaceContourType.noseBridge]?.points ?? [];
        if (noseBridgePoints.isNotEmpty) {
          final List<Point<double>> rawNose = noseBridgePoints.map((p) => Point<double>(p.x.toDouble(), p.y.toDouble())).toList();
          final noseCenter = rawNose[rawNose.length ~/ 2];
          drawOvalGuide(noseCenter, eyeDist * 0.08, eyeDist * 0.35, true);
        }

        // 3. Dagu Tengah (Chin center)
        final chinPoint = Point<double>(faceContour[18].x.toDouble(), faceContour[18].y.toDouble());
        drawOvalGuide(chinPoint - Point<double>(unitY.x * (eyeDist * 0.12), unitY.y * (eyeDist * 0.12)), eyeDist * 0.12, eyeDist * 0.08, true);

        // --- DRAW SHAPE-SPECIFIC CONTOURS & HIGHLIGHTS ---
        if (shape == 'round') {
          // Bulat: shading pipi tajam ke arah sudut bibir + pelipis samping dahi
          final cpLeft = Point<double>(
            cheekCoords['left']!.x + unitY.x * (eyeDist * 0.18) - unitX.x * (eyeDist * 0.12),
            cheekCoords['left']!.y + unitY.y * (eyeDist * 0.18) - unitX.y * (eyeDist * 0.12),
          );
          drawOvalGuide(cpLeft, eyeDist * 0.28, eyeDist * 0.10, false);
          
          final cpRight = Point<double>(
            cheekCoords['right']!.x + unitY.x * (eyeDist * 0.18) + unitX.x * (eyeDist * 0.12),
            cheekCoords['right']!.y + unitY.y * (eyeDist * 0.18) + unitX.y * (eyeDist * 0.12),
          );
          drawOvalGuide(cpRight, eyeDist * 0.28, eyeDist * 0.10, false);

          final templeLeft = Point<double>(
            leftEye.x - unitX.x * (eyeDist * 0.35) - unitY.x * (eyeDist * 0.5),
            leftEye.y - unitX.y * (eyeDist * 0.35) - unitY.y * (eyeDist * 0.5),
          );
          drawOvalGuide(templeLeft, eyeDist * 0.15, eyeDist * 0.10, false);

          final templeRight = Point<double>(
            rightEye.x + unitX.x * (eyeDist * 0.35) - unitY.x * (eyeDist * 0.5),
            rightEye.y + unitX.y * (eyeDist * 0.35) - unitY.y * (eyeDist * 0.5),
          );
          drawOvalGuide(templeRight, eyeDist * 0.15, eyeDist * 0.10, false);

        } else if (shape == 'square') {
          // Kotak: shading di pojok rahang lebar & pojok pelipis dahi samping atas
          final jawLeft = Point<double>(faceContour[12].x.toDouble(), faceContour[12].y.toDouble());
          drawOvalGuide(jawLeft - Point<double>(unitX.x * (eyeDist * 0.1) - unitY.x * (eyeDist * 0.1), unitX.y * (eyeDist * 0.1) - unitY.y * (eyeDist * 0.1)), eyeDist * 0.25, eyeDist * 0.15, false);

          final jawRight = Point<double>(faceContour[24].x.toDouble(), faceContour[24].y.toDouble());
          drawOvalGuide(jawRight + Point<double>(unitX.x * (eyeDist * 0.1) + unitY.x * (eyeDist * 0.1), unitX.y * (eyeDist * 0.1) + unitY.y * (eyeDist * 0.1)), eyeDist * 0.25, eyeDist * 0.15, false);

          final foreheadCornerLeft = Point<double>(faceContour[4].x.toDouble(), faceContour[4].y.toDouble());
          drawOvalGuide(foreheadCornerLeft, eyeDist * 0.2, eyeDist * 0.12, false);

          final foreheadCornerRight = Point<double>(faceContour[32].x.toDouble(), faceContour[32].y.toDouble());
          drawOvalGuide(foreheadCornerRight, eyeDist * 0.2, eyeDist * 0.12, false);

        } else if (shape == 'heart') {
          // Hati: shading di dahi atas samping + dagu paling bawah untuk melembutkan dagu lancip
          final dahiLeft = Point<double>(faceContour[3].x.toDouble(), faceContour[3].y.toDouble());
          drawOvalGuide(dahiLeft, eyeDist * 0.22, eyeDist * 0.12, false);

          final dahiRight = Point<double>(faceContour[33].x.toDouble(), faceContour[33].y.toDouble());
          drawOvalGuide(dahiRight, eyeDist * 0.22, eyeDist * 0.12, false);

          drawOvalGuide(chinPoint, eyeDist * 0.15, eyeDist * 0.08, false);

          final jawLeftMid = Point<double>(faceContour[14].x.toDouble(), faceContour[14].y.toDouble());
          drawOvalGuide(jawLeftMid, eyeDist * 0.15, eyeDist * 0.08, true);

          final jawRightMid = Point<double>(faceContour[22].x.toDouble(), faceContour[22].y.toDouble());
          drawOvalGuide(jawRightMid, eyeDist * 0.15, eyeDist * 0.08, true);

        } else if (shape == 'long') {
          // Panjang: shading horizontal dahi paling atas (batas rambut) & dagu terbawah (efek memendekkan wajah)
          final fhCenter = Point<double>(faceContour[0].x.toDouble(), faceContour[0].y.toDouble());
          drawOvalGuide(fhCenter, eyeDist * 0.45, eyeDist * 0.10, false);

          drawOvalGuide(chinPoint, eyeDist * 0.35, eyeDist * 0.12, false);

          drawOvalGuide(Point<double>(cheekCoords['left']!.x, cheekCoords['left']!.y), eyeDist * 0.20, eyeDist * 0.08, true);
          drawOvalGuide(Point<double>(cheekCoords['right']!.x, cheekCoords['right']!.y), eyeDist * 0.20, eyeDist * 0.08, true);

        } else {
          // Oval: shading standar di bawah tulang pipi
          final cpLeft = Point<double>(
            cheekCoords['left']!.x + unitY.x * (eyeDist * 0.15) - unitX.x * (eyeDist * 0.10),
            cheekCoords['left']!.y + unitY.y * (eyeDist * 0.15) - unitX.y * (eyeDist * 0.10),
          );
          drawOvalGuide(cpLeft, eyeDist * 0.24, eyeDist * 0.08, false);
          
          final cpRight = Point<double>(
            cheekCoords['right']!.x + unitY.x * (eyeDist * 0.15) + unitX.x * (eyeDist * 0.10),
            cheekCoords['right']!.y + unitY.y * (eyeDist * 0.15) + unitX.y * (eyeDist * 0.10),
          );
          drawOvalGuide(cpRight, eyeDist * 0.24, eyeDist * 0.08, false);
        }
      }
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
        oldDelegate.foundationFinishing != foundationFinishing ||
        oldDelegate.sliderX != sliderX ||
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
