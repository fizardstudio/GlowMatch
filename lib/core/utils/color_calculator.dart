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

  /// Menghitung jarak warna Delta E (CIEDE2000) antara dua LabColor.
  /// Ini adalah standar emas industri kecantikan modern karena mengompensasi kelemahan
  /// penglihatan mata manusia terhadap kecerahan dan hue di bagian saturasi tertentu.
  static double deltaE00(LabColor c1, LabColor c2) {
    final double l1 = c1.l;
    final double a1 = c1.a;
    final double b1 = c1.b;
    final double l2 = c2.l;
    final double a2 = c2.a;
    final double b2 = c2.b;

    final double c1Val = math.sqrt(a1 * a1 + b1 * b1);
    final double c2Val = math.sqrt(a2 * a2 + b2 * b2);
    final double cBar = (c1Val + c2Val) / 2.0;

    final double cBar7 = math.pow(cBar, 7).toDouble();
    final double constant25_7 = math.pow(25, 7).toDouble(); // 25^7 = 6103515625
    final double g = 0.5 * (1.0 - math.sqrt(cBar7 / (cBar7 + constant25_7)));

    final double a1Prime = (1.0 + g) * a1;
    final double a2Prime = (1.0 + g) * a2;

    final double c1Prime = math.sqrt(a1Prime * a1Prime + b1 * b1);
    final double c2Prime = math.sqrt(a2Prime * a2Prime + b2 * b2);
    final double cBarPrime = (c1Prime + c2Prime) / 2.0;

    double h1Prime = math.atan2(b1, a1Prime) * 180.0 / math.pi;
    if (h1Prime < 0) h1Prime += 360.0;

    double h2Prime = math.atan2(b2, a2Prime) * 180.0 / math.pi;
    if (h2Prime < 0) h2Prime += 360.0;

    double deltaHPrime = 0.0;
    double deltaHPrimeDiff = h2Prime - h1Prime;
    if (c1Prime * c2Prime != 0.0) {
      if (deltaHPrimeDiff.abs() <= 180.0) {
        deltaHPrime = deltaHPrimeDiff;
      } else if (deltaHPrimeDiff > 180.0) {
        deltaHPrime = deltaHPrimeDiff - 360.0;
      } else {
        deltaHPrime = deltaHPrimeDiff + 360.0;
      }
    }
    final double deltaHBigPrime = 2.0 * math.sqrt(c1Prime * c2Prime) * math.sin((deltaHPrime / 2.0) * math.pi / 180.0);

    final double deltaLPrime = l2 - l1;
    final double deltaCPrime = c2Prime - c1Prime;

    double hBarPrime = 0.0;
    if (c1Prime * c2Prime != 0.0) {
      if (deltaHPrimeDiff.abs() <= 180.0) {
        hBarPrime = (h1Prime + h2Prime) / 2.0;
      } else if ((h1Prime + h2Prime) < 360.0) {
        hBarPrime = (h1Prime + h2Prime + 360.0) / 2.0;
      } else {
        hBarPrime = (h1Prime + h2Prime - 360.0) / 2.0;
      }
    }

    final double t = 1.0 -
        0.17 * math.cos((hBarPrime - 30.0) * math.pi / 180.0) +
        0.24 * math.cos((2.0 * hBarPrime) * math.pi / 180.0) +
        0.32 * math.cos((3.0 * hBarPrime + 6.0) * math.pi / 180.0) -
        0.20 * math.cos((4.0 * hBarPrime - 63.0) * math.pi / 180.0);

    final double lBarPrimeMinus50Sq = math.pow((l1 + l2) / 2.0 - 50.0, 2).toDouble();
    final double sL = 1.0 + (0.015 * lBarPrimeMinus50Sq) / math.sqrt(20.0 + lBarPrimeMinus50Sq);
    final double sC = 1.0 + 0.045 * cBarPrime;
    final double sH = 1.0 + 0.015 * cBarPrime * t;

    final double deltaTheta = 30.0 * math.exp(-math.pow((hBarPrime - 275.0) / 25.0, 2).toDouble());
    final double cBarPrime7 = math.pow(cBarPrime, 7).toDouble();
    final double rC = 2.0 * math.sqrt(cBarPrime7 / (cBarPrime7 + constant25_7));
    final double rT = -math.sin((2.0 * deltaTheta) * math.pi / 180.0) * rC;

    final double termL = deltaLPrime / sL;
    final double termC = deltaCPrime / sC;
    final double termH = deltaHBigPrime / sH;

    return math.sqrt(
      termL * termL +
      termC * termC +
      termH * termH +
      rT * termC * termH
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

  /// Menganalisis warna kulit di ruang warna Lab untuk mengklasifikasikan pengguna ke dalam salah satu dari 12 Musim Warna (Seasonal Color Profile).
  /// Menghasilkan palet warna makeup dan rekomendasi warna hijab yang serasi.
  static Map<String, dynamic> getSeasonalColorProfile(double L, double a, double b) {
    final double chroma = math.sqrt(a * a + b * b);
    double hueAngle = math.atan2(b, a) * 180.0 / math.pi;
    if (hueAngle < 0) hueAngle += 360.0;

    // Menentukan undertone berdasarkan parameter b* (kuning hangat vs cool kemerahan/biru)
    final bool isWarm = b > 2.0;

    String season;
    String description;
    List<String> paletteColors;
    List<String> hijabColors;
    List<String> hijabColorNames;

    if (isWarm) {
      if (L > 62) {
        if (chroma > 20) {
          season = "Light Spring";
          description = "Tipe musim semi yang cerah dan hangat. Kulit Anda memiliki kilau keemasan alami yang segar.";
          paletteColors = ["#FEE2C5", "#FDBA74", "#FB7185", "#F472B6", "#A7F3D0"];
          hijabColors = ["#EEDBB8", "#DB9B70", "#CE6060", "#F0A6B2", "#A6D5C2"];
          hijabColorNames = ["Peach Nude", "Warm Terracotta", "Coral Pink", "Blush Pink", "Sage Green"];
        } else {
          season = "Soft Autumn";
          description = "Tipe musim gugur yang lembut, hangat, dengan saturasi rendah. Warna-warna tanah yang teredam sangat serasi dengan Anda.";
          paletteColors = ["#FFE4C4", "#DDB892", "#B08968", "#7F5539", "#9C6644"];
          hijabColors = ["#CDB4DB", "#D8B2D1", "#E29578", "#83C5BE", "#A3B19B"];
          hijabColorNames = ["Muted Mauve", "Warm Taupe", "Burnt Orange", "Muted Teal", "Olive Drab"];
        }
      } else if (L < 48) {
        season = "Deep Autumn";
        description = "Tipe musim gugur yang pekat, hangat, dan dramatis. Warna-warna gelap yang kaya akan mempertegas keindahan kulit Anda.";
        paletteColors = ["#78350F", "#92400E", "#B45309", "#D97706", "#451A03"];
        hijabColors = ["#4A154B", "#5C2018", "#1E3F20", "#875C36", "#DCA842"];
        hijabColorNames = ["Deep Plum", "Burgundy", "Forest Green", "Dark Mustard", "Warm Bronze"];
      } else {
        if (chroma > 22) {
          season = "True Spring";
          description = "Tipe musim semi murni dengan warna keemasan yang hangat dan kontras yang hidup.";
          paletteColors = ["#F59E0B", "#EF4444", "#10B981", "#3B82F6", "#EC4899"];
          hijabColors = ["#EAB308", "#DC2626", "#059669", "#2563EB", "#DB2777"];
          hijabColorNames = ["Bright Marigold", "True Coral", "Kelly Green", "Royal Blue", "Hot Pink"];
        } else {
          season = "True Autumn";
          description = "Tipe musim gugur murni yang kaya akan warna-warna tanah yang hangat, teduh, dan berkarakter.";
          paletteColors = ["#A16207", "#854D0E", "#A7F3D0", "#15803D", "#78350F"];
          hijabColors = ["#C18C5D", "#7F4F24", "#582F0E", "#4B5320", "#6A4C93"];
          hijabColorNames = ["Caramel", "Mocha", "Dark Chocolate", "Olive Green", "Deep Grape"];
        }
      }
    } else {
      if (L > 62) {
        if (chroma > 20) {
          season = "Clear Winter";
          description = "Tipe musim dingin yang jernih, dingin, dengan kontras yang cerah dan memikat.";
          paletteColors = ["#F43F5E", "#D946EF", "#8B5CF6", "#3B82F6", "#06B6D4"];
          hijabColors = ["#FFFFFF", "#000000", "#C1121F", "#03045E", "#7209B7"];
          hijabColorNames = ["Pure White", "Jet Black", "Ruby Red", "Deep Navy", "Royal Violet"];
        } else {
          season = "Light Summer";
          description = "Tipe musim panas yang ringan, ber-undertone dingin, dan ber-saturasi lembut. Warna-warna pastel yang sejuk akan terlihat sangat elegan.";
          paletteColors = ["#FCE7F3", "#F3E8FF", "#E0F2FE", "#CCFBF1", "#E2E8F0"];
          hijabColors = ["#D8B4FE", "#C084FC", "#93C5FD", "#A5F3FC", "#F472B6"];
          hijabColorNames = ["Lavender", "Orchid Purple", "Sky Blue", "Ice Mint", "Baby Pink"];
        }
      } else if (L < 48) {
        if (chroma > 18) {
          season = "Deep Winter";
          description = "Tipe musim dingin yang pekat, dingin, dan intens. Warna-warna permata yang dingin berpadu kontras menciptakan tampilan eksklusif.";
          paletteColors = ["#4C1D95", "#1E3A8A", "#881337", "#064E3B", "#111827"];
          hijabColors = ["#3B0764", "#172554", "#4C0519", "#022C22", "#0F172A"];
          hijabColorNames = ["Midnight Purple", "Dark Sapphire", "Deep Burgundy", "Emerald Green", "Charcoal Gray"];
        } else {
          season = "Soft Summer";
          description = "Tipe musim panas yang lembut, teduh, dengan tone dingin yang meredup abu-abu hangat.";
          paletteColors = ["#E9D5FF", "#C084FC", "#F472B6", "#93C5FD", "#A5F3FC"];
          hijabColors = ["#9A8C98", "#F0A6CA", "#B5E2FA", "#EDF2F4", "#8D99AE"];
          hijabColorNames = ["Dusty Rose", "Soft Mauve", "Pastel Blue", "Light Gray", "Steel Blue"];
        }
      } else {
        if (chroma > 20) {
          season = "True Winter";
          description = "Tipe musim dingin murni dengan rona warna sangat dingin, kontras tajam, dan jernih.";
          paletteColors = ["#E11D48", "#C026D3", "#7C3AED", "#2563EB", "#0891B2"];
          hijabColors = ["#E11D48", "#000814", "#FFFFFF", "#1E6091", "#4A0E17"];
          hijabColorNames = ["Crimson Red", "Obsidian Black", "Pure Snow", "Cobalt Blue", "Dark Maroon"];
        } else {
          season = "True Summer";
          description = "Tipe musim panas murni yang tenang, lembut, dengan keanggunan tone biru-keabuan yang dingin.";
          paletteColors = ["#F472B6", "#C084FC", "#93C5FD", "#A5F3FC", "#F3F4F6"];
          hijabColors = ["#D1A3C4", "#B8C0FF", "#A9DEF9", "#E8AEB7", "#6D597A"];
          hijabColorNames = ["Dull Orchid", "Periwinkle", "Soft Cerulean", "Blush Gray", "Eggplant Violet"];
        }
      }
    }

    return {
      "season": season,
      "description": description,
      "paletteColors": paletteColors,
      "hijabColors": hijabColors,
      "hijabColorNames": hijabColorNames,
    };
  }
}
