import 'dart:math' as math;

/// Kelas model untuk menyimpan representasi warna dalam ruang CIELAB.
class LabColor {
  final double l; // Lightness (0.0 hingga 100.0)
  final double a; // Kroma hijau-merah (-128.0 hingga 127.0)
  final double b; // Kroma biru-kuning (-128.0 hingga 127.0)

  const LabColor(this.l, this.a, this.b);

  @override
  String toString() => 'LabColor(L*: ${l.toStringAsFixed(2)}, a*: ${a.toStringAsFixed(2)}, b*: ${b.toStringAsFixed(2)})';
}

/// Utilitas matematika untuk pemrosesan dan pencocokan warna.
class ColorCalculator {
  // Titik putih referensi D65 (Standard Illuminant)
  static const double _refX = 95.047;
  static const double _refY = 100.000;
  static const double _refZ = 108.883;

  /// Mengonversi nilai komponen sRGB non-linear (0-255) ke sRGB Linear (0.0-1.0).
  static double sRgbToLinear(double val) {
    // Normalisasi nilai ke 0.0 - 1.0
    final double normalized = val / 255.0;
    if (normalized <= 0.04045) {
      return normalized / 12.92;
    } else {
      return math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  /// Mengonversi nilai komponen sRGB Linear (0.0-1.0) kembali ke sRGB non-linear (0-255).
  static double linearToSrgb(double val) {
    double sRgbVal;
    if (val <= 0.0031308) {
      sRgbVal = val * 12.92;
    } else {
      sRgbVal = (1.055 * math.pow(val, 1 / 2.4)) - 0.055;
    }
    return (sRgbVal * 255.0).clamp(0.0, 255.0);
  }

  /// Mengonversi warna RGB (0-255) ke ruang warna XYZ.
  static List<double> rgbToXyz(int r, int g, int b) {
    final double rL = sRgbToLinear(r.toDouble());
    final double gL = sRgbToLinear(g.toDouble());
    final double bL = sRgbToLinear(b.toDouble());

    // Matriks transformasi sRGB ke XYZ (D65)
    final double x = (rL * 0.4124 + gL * 0.3576 + bL * 0.1805) * 100.0;
    final double y = (rL * 0.2126 + gL * 0.7152 + bL * 0.0722) * 100.0;
    final double z = (rL * 0.0193 + gL * 0.1192 + bL * 0.9505) * 100.0;

    return [x, y, z];
  }

  /// Fungsi bantu f(t) untuk konversi XYZ ke CIELAB.
  static double _xyzToLabHelper(double t) {
    if (t > 0.008856) {
      return math.pow(t, 1 / 3).toDouble();
    } else {
      return (7.787 * t) + (16.0 / 116.0);
    }
  }

  /// Mengonversi warna RGB (0-255) ke ruang warna CIELAB (LabColor).
  static LabColor rgbToLab(int r, int g, int b) {
    final xyz = rgbToXyz(r, g, b);
    final double x = xyz[0];
    final double y = xyz[1];
    final double z = xyz[2];

    final double xRatio = _xyzToLabHelper(x / _refX);
    final double yRatio = _xyzToLabHelper(y / _refY);
    final double zRatio = _xyzToLabHelper(z / _refZ);

    final double l = (116.0 * yRatio) - 16.0;
    final double a = 500.0 * (xRatio - yRatio);
    final double bVal = 200.0 * (yRatio - zRatio);

    return LabColor(l, a, bVal);
  }

  /// Menghitung jarak warna Delta E (CIE 1976) antara dua LabColor.
  static double deltaE76(LabColor c1, LabColor c2) {
    return math.sqrt(
      math.pow(c1.l - c2.l, 2) +
      math.pow(c1.a - c2.a, 2) +
      math.pow(c1.b - c2.b, 2)
    );
  }

  /// Mengonversi nilai Delta E menjadi persentase kecocokan warna (0% - 100%).
  static double calculateMatchPercentage(double deltaE) {
    // Berdasarkan rumus: 100 - (Delta E * 10)
    // Jarak Delta E > 10 dianggap 0% kecocokan karena warna sudah sangat berbeda
    final double pct = 100.0 - (deltaE * 10.0);
    return pct.clamp(0.0, 100.0);
  }

  /// Mencampur warna-warna dengan rasio berat tertentu di ruang warna Linear.
  /// Menerima daftar peta warna dengan kunci 'r', 'g', 'b' dan 'weight' (rasio).
  static List<int> blendColors(List<Map<String, dynamic>> colorsWithWeights) {
    double mixedRL = 0.0;
    double mixedGL = 0.0;
    double mixedBL = 0.0;
    double totalWeight = 0.0;

    for (final cw in colorsWithWeights) {
      final int r = cw['r'] as int;
      final int g = cw['g'] as int;
      final int b = cw['b'] as int;
      final double w = cw['weight'] as double;

      mixedRL += sRgbToLinear(r.toDouble()) * w;
      mixedGL += sRgbToLinear(g.toDouble()) * w;
      mixedBL += sRgbToLinear(b.toDouble()) * w;
      totalWeight += w;
    }

    if (totalWeight == 0) {
      return [0, 0, 0];
    }

    // Normalisasi berat jika tidak sama dengan 1.0
    final double finalR = linearToSrgb(mixedRL / totalWeight);
    final double finalG = linearToSrgb(mixedGL / totalWeight);
    final double finalB = linearToSrgb(mixedBL / totalWeight);

    return [finalR.round(), finalG.round(), finalB.round()];
  }
}
