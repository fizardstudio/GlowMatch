import 'dart:io';
import 'package:image/image.dart' as img;

/// Kelas pembantu untuk pemrosesan citra digital (image processing) wajah.
class ImageProcessor {
  /// Membaca file gambar dari path lokal dan mendecode-nya menjadi objek Image.
  static Future<img.Image?> loadAndDecodeImage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      return img.decodeImage(bytes);
    } catch (e) {
      // Penanganan error pembacaan/decode gambar
      return null;
    }
  }

  /// Menghitung warna rata-rata (RGB) dari area sub-gambar (bounding box) tertentu.
  static List<int> calculateAverageRgb(
    img.Image srcImage, {
    required int startX,
    required int startY,
    required int width,
    required int height,
  }) {
    // Pastikan area koordinat berada di dalam rentang gambar asli
    final int xMin = startX.clamp(0, srcImage.width - 1);
    final int yMin = startY.clamp(0, srcImage.height - 1);
    final int xMax = (startX + width).clamp(0, srcImage.width);
    final int yMax = (startY + height).clamp(0, srcImage.height);

    int sumR = 0;
    int sumG = 0;
    int sumB = 0;
    int pixelCount = 0;

    for (int y = yMin; y < yMax; y++) {
      for (int x = xMin; x < xMax; x++) {
        final pixel = srcImage.getPixel(x, y);
        
        // library 'image' menyimpan nilai RGB di dalam pixel
        // Komponen warna dapat diekstrak menggunakan getter bawaan paket
        sumR += pixel.r.toInt();
        sumG += pixel.g.toInt();
        sumB += pixel.b.toInt();
        pixelCount++;
      }
    }

    if (pixelCount == 0) {
      return [0, 0, 0];
    }

    return [
      (sumR / pixelCount).round(),
      (sumG / pixelCount).round(),
      (sumB / pixelCount).round(),
    ];
  }

  /// Mengekstrak warna kulit berdasarkan beberapa sampel area wajah (pipi kiri, pipi kanan, dahi).
  /// Menerima objek Image dan daftar wilayah koordinat sampel.
  static List<int> extractSkinColor(
    img.Image srcImage,
    List<Map<String, int>> regions,
  ) {
    if (regions.isEmpty) return [0, 0, 0];

    int totalR = 0;
    int totalG = 0;
    int totalB = 0;
    int validRegionsCount = 0;

    for (final region in regions) {
      final int x = region['x'] ?? 0;
      final int y = region['y'] ?? 0;
      final int w = region['w'] ?? 10;
      final int h = region['h'] ?? 10;

      final avgRgb = calculateAverageRgb(
        srcImage,
        startX: x,
        startY: y,
        width: w,
        height: h,
      );

      if (avgRgb[0] != 0 || avgRgb[1] != 0 || avgRgb[2] != 0) {
        totalR += avgRgb[0];
        totalG += avgRgb[1];
        totalB += avgRgb[2];
        validRegionsCount++;
      }
    }

    if (validRegionsCount == 0) {
      return [0, 0, 0];
    }

    return [
      (totalR / validRegionsCount).round(),
      (totalG / validRegionsCount).round(),
      (totalB / validRegionsCount).round(),
    ];
  }
}
