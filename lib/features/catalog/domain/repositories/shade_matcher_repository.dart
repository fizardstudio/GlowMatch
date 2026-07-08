import '../../../../core/data/models/standard_shade.dart';
import '../../../../core/utils/color_calculator.dart';

abstract class ShadeMatcherRepository {
  /// Mencocokkan warna kulit target (LabColor) dengan database produk komersial.
  /// Mengembalikan daftar produk terdekat yang terurut berdasarkan persentase kecocokan.
  Future<List<Map<String, dynamic>>> matchCommercialProducts(
    LabColor targetColor, {
    String? category,
  });

  /// Mencocokkan warna kulit target (LabColor) dengan kategori warna teoretis standar.
  Future<StandardShade?> matchStandardShade(LabColor targetColor);
}
