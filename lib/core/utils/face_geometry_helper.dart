import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceGeometryHelper {
  /// Mendapatkan titik pusat mata kiri dan kanan secara robust dari Face.
  /// Mengutamakan contours (karena merupakan daftar titik yang sangat rapat), 
  /// jika tidak ada maka menggunakan landmarks, dan fallback terakhir menggunakan bounding box.
  static Map<String, Point<double>> getEyeCenters(Face face) {
    Point<double>? leftCenter;
    Point<double>? rightCenter;

    final rect = face.boundingBox;

    // 1. Coba menggunakan Contours (paling detail)
    final leftContour = face.contours[FaceContourType.leftEye]?.points;
    final rightContour = face.contours[FaceContourType.rightEye]?.points;

    if (leftContour != null && leftContour.isNotEmpty) {
      double sumX = 0;
      double sumY = 0;
      for (var p in leftContour) {
        sumX += p.x;
        sumY += p.y;
      }
      leftCenter = Point(sumX / leftContour.length, sumY / leftContour.length);
    }

    if (rightContour != null && rightContour.isNotEmpty) {
      double sumX = 0;
      double sumY = 0;
      for (var p in rightContour) {
        sumX += p.x;
        sumY += p.y;
      }
      rightCenter = Point(sumX / rightContour.length, sumY / rightContour.length);
    }

    // 2. Jika Contours gagal/null, coba Landmarks (landmark base)
    if (leftCenter == null) {
      final leftLandmark = face.landmarks[FaceLandmarkType.leftEye]?.position;
      if (leftLandmark != null) {
        leftCenter = Point(leftLandmark.x.toDouble(), leftLandmark.y.toDouble());
      }
    }
    if (rightCenter == null) {
      final rightLandmark = face.landmarks[FaceLandmarkType.rightEye]?.position;
      if (rightLandmark != null) {
        rightCenter = Point(rightLandmark.x.toDouble(), rightLandmark.y.toDouble());
      }
    }

    // 3. Jika keduanya gagal, gunakan fallback bounding box
    if (leftCenter == null) {
      leftCenter = Point(rect.left + rect.width * 0.35, rect.top + rect.height * 0.35);
    }
    if (rightCenter == null) {
      rightCenter = Point(rect.left + rect.width * 0.65, rect.top + rect.height * 0.35);
    }

    return {
      'left': leftCenter,
      'right': rightCenter,
    };
  }

  /// Menghitung vektor sumbu wajah terputar (unitX dan unitY) berdasarkan posisi mata.
  /// unitX: arah horizontal wajah (kiri ke kanan mata).
  /// unitY: arah vertikal wajah ke bawah (selalu menunjuk ke arah pipi/dagu, bukan alis).
  static Map<String, Point<double>> getFaceUnitVectors(Point<double> leftEye, Point<double> rightEye) {
    final double dx = rightEye.x - leftEye.x;
    final double dy = rightEye.y - leftEye.y;
    final double dist = sqrt(dx * dx + dy * dy);

    // Hindari pembagian dengan nol
    final double unitX_x = dist > 0 ? dx / dist : 1.0;
    final double unitX_y = dist > 0 ? dy / dist : 0.0;

    // unitY tegak lurus terhadap unitX (orthogonal)
    double unitY_x = -unitX_y;
    double unitY_y = unitX_x;

    // Pastikan unitY selalu mengarah ke bawah (Y positif di layar)
    if (unitY_y < 0) {
      unitY_x = -unitY_x;
      unitY_y = -unitY_y;
    }

    return {
      'unitX': Point(unitX_x, unitX_y),
      'unitY': Point(unitY_x, unitY_y),
      'distance': Point(dist, dist),
    };
  }

  /// Menghitung letak koordinat pipi kiri dan kanan terputar yang akurat.
  static Map<String, Point<double>> getCheekCoordinates(Face face) {
    final eyes = getEyeCenters(face);
    final leftEye = eyes['left']!;
    final rightEye = eyes['right']!;
    
    final vectors = getFaceUnitVectors(leftEye, rightEye);
    final unitX = vectors['unitX']!;
    final unitY = vectors['unitY']!;
    final double eyeDistance = vectors['distance']!.x;

    // Pipi kiri: geser ke bawah along unitY, dan ke luar along -unitX
    final double leftCheekX = leftEye.x + unitY.x * (eyeDistance * 0.45) - unitX.x * (eyeDistance * 0.15);
    final double leftCheekY = leftEye.y + unitY.y * (eyeDistance * 0.45) - unitX.y * (eyeDistance * 0.15);

    // Pipi kanan: geser ke bawah along unitY, dan ke luar along unitX
    final double rightCheekX = rightEye.x + unitY.x * (eyeDistance * 0.45) + unitX.x * (eyeDistance * 0.15);
    final double rightCheekY = rightEye.y + unitY.y * (eyeDistance * 0.45) + unitX.y * (eyeDistance * 0.15);

    return {
      'left': Point(leftCheekX, leftCheekY),
      'right': Point(rightCheekX, rightCheekY),
    };
  }

  /// Menghitung letak koordinat dahi terputar yang akurat.
  static Point<double> getForeheadCoordinate(Face face) {
    final eyes = getEyeCenters(face);
    final leftEye = eyes['left']!;
    final rightEye = eyes['right']!;
    
    final vectors = getFaceUnitVectors(leftEye, rightEye);
    final unitY = vectors['unitY']!;
    final double eyeDistance = vectors['distance']!.x;

    // Dahi: titik tengah mata digeser ke atas (berlawanan arah unitY)
    final double midX = (leftEye.x + rightEye.x) / 2.0;
    final double midY = (leftEye.y + rightEye.y) / 2.0;

    final double foreheadX = midX - unitY.x * (eyeDistance * 0.85);
    final double foreheadY = midY - unitY.y * (eyeDistance * 0.85);

    return Point(foreheadX, foreheadY);
  }

  /// Mendapatkan 3 titik hairline terputar untuk perluasan dasar makeup dahi (forehead extension).
  static List<Point<double>> getHairlinePoints(Face face) {
    final eyes = getEyeCenters(face);
    final leftEye = eyes['left']!;
    final rightEye = eyes['right']!;
    
    final vectors = getFaceUnitVectors(leftEye, rightEye);
    final unitX = vectors['unitX']!;
    final unitY = vectors['unitY']!;
    final double eyeDistance = vectors['distance']!.x;

    final double midX = (leftEye.x + rightEye.x) / 2.0;
    final double midY = (leftEye.y + rightEye.y) / 2.0;

    final double fhLeftX = leftEye.x - unitX.x * (eyeDistance * 0.15) - unitY.x * (eyeDistance * 0.85);
    final double fhLeftY = leftEye.y - unitX.y * (eyeDistance * 0.15) - unitY.y * (eyeDistance * 0.85);

    final double fhCenterX = midX - unitY.x * (eyeDistance * 0.95);
    final double fhCenterY = midY - unitY.y * (eyeDistance * 0.95);

    final double fhRightX = rightEye.x + unitX.x * (eyeDistance * 0.15) - unitY.x * (eyeDistance * 0.85);
    final double fhRightY = rightEye.y + unitX.y * (eyeDistance * 0.15) - unitY.y * (eyeDistance * 0.85);

    return [
      Point(fhLeftX, fhLeftY),
      Point(fhCenterX, fhCenterY),
      Point(fhRightX, fhRightY),
    ];
  }

  /// Mendapatkan titik pusat bibir (lip center) secara robust.
  static Point<double>? getLipCenter(Face face) {
    final lipPoints = face.contours[FaceContourType.upperLipTop]?.points;
    if (lipPoints != null && lipPoints.isNotEmpty) {
      double sumX = 0;
      double sumY = 0;
      for (var p in lipPoints) {
        sumX += p.x;
        sumY += p.y;
      }
      return Point(sumX / lipPoints.length, sumY / lipPoints.length);
    }
    // Fallback using bounding box math
    final rect = face.boundingBox;
    return Point(rect.left + rect.width / 2.0, rect.top + rect.height * 0.75);
  }
}
