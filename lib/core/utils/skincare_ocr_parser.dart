import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../data/models/skincare_ingredient.dart';
import '../data/skincare_ingredients_data.dart';

class SkincareOcrParser {
  // Melakukan ekstraksi teks menggunakan ML Kit OCR secara offline
  static Future<String> extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (_) {
      return '';
    } finally {
      textRecognizer.close();
    }
  }

  // Menganalisis teks kemasan untuk mencari bahan aktif dalam database
  static List<SkincareIngredient> parseIngredients(String rawText) {
    if (rawText.isEmpty) return [];

    final List<SkincareIngredient> matchedIngredients = [];
    final String cleanText = rawText.toLowerCase().replaceAll('\n', ' ').replaceAll(RegExp(r'[.,;:]'), ' ');

    for (final ingredient in skincareIngredientsDb) {
      bool isMatched = false;
      for (final alias in ingredient.aliases) {
        // Cocokkan alias bahan dengan memeriksa keberadaan kata/frasa
        if (cleanText.contains(alias.toLowerCase())) {
          isMatched = true;
          break;
        }
      }
      if (isMatched) {
        matchedIngredients.add(ingredient);
      }
    }

    return matchedIngredients;
  }

  // Menganalisis semua kandungan komposisi yang ada di label secara menyeluruh
  static List<Map<String, dynamic>> parseAllIngredientsWithMatches(String rawText) {
    if (rawText.isEmpty) return [];

    // Cari kata kunci pembuka daftar bahan
    String targetText = rawText;
    final lowercaseText = rawText.toLowerCase();

    final RegExp headerRegex = RegExp(
      r'(ingredients|composition|komposisi|bahan-bahan|ingredients\/coctab|active ingredients)\s*[:;]?',
      caseSensitive: false
    );

    final match = headerRegex.firstMatch(lowercaseText);
    if (match != null) {
      targetText = rawText.substring(match.end);
    }

    // Bersihkan spasi ganda dan baris baru
    String cleanText = targetText.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

    // Pecahkan berdasarkan tanda koma/titik koma
    List<String> rawItems = cleanText.split(RegExp(r'[,;]'));
    List<Map<String, dynamic>> results = [];

    for (String item in rawItems) {
      String trimmed = item.trim();
      trimmed = trimmed.replaceAll(RegExp(r'[.()]+$'), '').trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length < 3 || trimmed.length > 50) continue;

      final lowerTrimmed = trimmed.toLowerCase();
      if (lowerTrimmed.contains('distributed by') || 
          lowerTrimmed.contains('made in') || 
          lowerTrimmed.contains('exp:') || 
          lowerTrimmed.contains('net wt') ||
          lowerTrimmed.contains('directions') ||
          lowerTrimmed.contains('how to use')) {
        continue;
      }

      SkincareIngredient? matchedDb;
      for (final ingredient in skincareIngredientsDb) {
        for (final alias in ingredient.aliases) {
          if (lowerTrimmed == alias.toLowerCase() || 
              lowerTrimmed.contains(alias.toLowerCase()) || 
              alias.toLowerCase().contains(lowerTrimmed)) {
            if (alias.length >= 4 || lowerTrimmed == alias.toLowerCase()) {
              matchedDb = ingredient;
              break;
            }
          }
        }
        if (matchedDb != null) break;
      }

      String formattedName = trimmed;
      if (trimmed.isNotEmpty) {
        // Kapitalisasi kata pertama
        formattedName = trimmed[0].toUpperCase() + trimmed.substring(1);
      }

      results.add({
        'name': formattedName,
        'matched': matchedDb,
      });
    }

    // Fallback pencarian langsung jika hasil pemisahan terlalu sedikit
    if (results.length < 3) {
      results.clear();
      for (final ingredient in skincareIngredientsDb) {
        for (final alias in ingredient.aliases) {
          if (lowercaseText.contains(alias.toLowerCase())) {
            results.add({
              'name': ingredient.name,
              'matched': ingredient,
            });
            break;
          }
        }
      }
    }

    return results;
  }

  // Menghitung Skor Kecocokan Kulit (Skin Compatibility Score)
  static Map<String, dynamic> calculateCompatibility({
    required List<SkincareIngredient> matchedIngredients,
    required String skinTypeKey, // 'dry', 'oily', 'normal', 'sensitive', 'acne_prone'
  }) {
    if (matchedIngredients.isEmpty) {
      return {
        'score': 100,
        'status': 'Sangat Cocok ✅',
        'statusColor': 0xFF2ECC71, // Green
        'recommendation': 'Tidak terdeteksi bahan aktif yang berisiko iritasi tinggi. Produk aman digunakan.',
      };
    }

    double baseScore = 80.0; // Mulai dari nilai dasar 80%
    int highIrritationCount = 0;
    int badMatchCount = 0;

    for (final ingredient in matchedIngredients) {
      final double compatibility = ingredient.compatibility[skinTypeKey] ?? 0.0;
      
      // Hitung dampak kecocokan tipe kulit
      if (compatibility > 0) {
        baseScore += (compatibility * 6.0); // Kontribusi positif
      } else if (compatibility < 0) {
        baseScore += (compatibility * 12.0); // Penalti kecocokan buruk
        badMatchCount++;
      }

      // Penalti iritasi untuk kulit sensitif
      if (skinTypeKey == 'sensitive' && ingredient.irritationScore >= 3) {
        highIrritationCount++;
        baseScore -= (ingredient.irritationScore * 6.0);
      }
    }

    final int finalScore = baseScore.clamp(0.0, 100.0).round();

    String status = 'Sangat Cocok ✅';
    int statusColor = 0xFF2ECC71; // Hijau
    String recommendation = 'Kombinasi bahan aktif sangat serasi untuk tipe kulit Anda.';

    if (finalScore < 50) {
      status = 'Hindari / Risiko Tinggi ❌';
      statusColor = 0xFFE74C3C; // Merah
      recommendation = 'Mengandung beberapa bahan aktif yang berpotensi memicu reaksi negatif pada tipe kulit Anda. Disarankan cari alternatif lain.';
    } else if (finalScore < 75 || highIrritationCount > 0 || badMatchCount > 0) {
      status = 'Aman dengan Catatan ⚠️';
      statusColor = 0xFFF39C12; // Jingga / Kuning
      recommendation = 'Aman digunakan, namun perhatikan hidrasi kulit dan batasi frekuensi pemakaian jika dirasa memicu kemerahan.';
    }

    return {
      'score': finalScore,
      'status': status,
      'statusColor': statusColor,
      'recommendation': recommendation,
    };
  }
}
