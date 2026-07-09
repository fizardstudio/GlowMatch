import 'package:isar/isar.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/data/models/standard_shade.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../domain/repositories/shade_matcher_repository.dart';

class ShadeMatcherRepositoryImpl implements ShadeMatcherRepository {
  final DatabaseService _dbService;

  ShadeMatcherRepositoryImpl(this._dbService);

  @override
  Future<List<Map<String, dynamic>>> matchCommercialProducts(
    LabColor targetColor, {
    String? category,
  }) async {
    final isar = _dbService.isar;

    // Ambil data produk komersial dari Isar
    final List<ProductShade> allShades;
    if (category != null && category.isNotEmpty) {
      allShades = await isar.productShades.filter().categoryEqualTo(category).findAll();
    } else {
      allShades = await isar.productShades.where().findAll();
    }
    final List<Map<String, dynamic>> matches = [];

    for (final shade in allShades) {
      double calibratedL = shade.l;
      final int totalFeedback = shade.perfectCount + shade.tooDarkCount + shade.tooLightCount;
      
      // Mengkalibrasi L (Lightness) secara dinamis berdasarkan ulasan komunitas
      // tanpa memodifikasi data mentah di database (Community Offset Delta L)
      if (totalFeedback > 0) {
        final double offsetL = (shade.tooLightCount - shade.tooDarkCount) * 1.5 / totalFeedback;
        calibratedL = (calibratedL + offsetL).clamp(0.0, 100.0);
      }

      final productLab = LabColor(calibratedL, shade.a, shade.b);
      final double deltaE = ColorCalculator.deltaE00(targetColor, productLab);

      // Hanya masukkan produk yang memiliki kecocokan layak (Delta E <= 5.0)
      if (deltaE <= 5.0) {
        final double matchPercentage = ColorCalculator.calculateMatchPercentage(deltaE);
        matches.add({
          'product': shade,
          'deltaE': deltaE,
          'matchPercentage': matchPercentage,
        });
      }
    }

    // Urutkan berdasarkan Delta E terkecil (kecocokan tertinggi)
    matches.sort((a, b) => (a['deltaE'] as double).compareTo(b['deltaE'] as double));

    return matches;
  }

  @override
  Future<StandardShade?> matchStandardShade(LabColor targetColor) async {
    final isar = _dbService.isar;

    // Ambil semua warna standar
    final allStandards = await isar.standardShades.where().findAll();
    if (allStandards.isEmpty) return null;

    StandardShade? closestShade;
    double minDeltaE = double.infinity;

    for (final std in allStandards) {
      final stdLab = LabColor(std.l, std.a, std.b);
      final double deltaE = ColorCalculator.deltaE00(targetColor, stdLab);

      if (deltaE < minDeltaE) {
        minDeltaE = deltaE;
        closestShade = std;
      }
    }

    return closestShade;
  }

  @override
  Future<List<ProductShade>> getAllProductShades() async {
    return await _dbService.isar.productShades.where().findAll();
  }
}
