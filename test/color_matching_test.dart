import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:glowmatch/core/data/models/standard_shade.dart';
import 'package:glowmatch/core/data/models/product_shade.dart';
import 'package:glowmatch/core/network/database_service.dart';
import 'package:glowmatch/core/utils/color_calculator.dart';
import 'package:glowmatch/features/catalog/data/repositories/shade_matcher_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Override HttpOverrides to allow downloading isar.dll from GitHub
    HttpOverrides.global = null;
    await Isar.initializeIsarCore(download: true);
  });

  test('Test Isar Database Initialization, Seeding, and Shade Matching', () async {
    final tempDir = Directory.systemTemp.createTempSync('glowmatch_test_db');
    
    final dbService = DatabaseService();
    // Gunakan parameter directoryPath untuk unit testing
    await dbService.init(directoryPath: tempDir.path);

    // 1. Pastikan seeding data teoretis dan komersial masuk
    final stdCount = await dbService.isar.standardShades.count();
    final prodCount = await dbService.isar.productShades.count();

    expect(stdCount, greaterThan(0));
    expect(prodCount, greaterThan(0));

    final repository = ShadeMatcherRepositoryImpl(dbService);

    // 2. Ambil koordinat eksak dari database Isar untuk Light Neutral
    final lightNeutralStandard = await dbService.isar.standardShades
        .filter()
        .nameEqualTo('Light Neutral')
        .findFirst();
    expect(lightNeutralStandard, isNotNull);
    final targetColor = LabColor(
      lightNeutralStandard!.l,
      lightNeutralStandard.a,
      lightNeutralStandard.b,
    );

    // 3. Uji kecocokan dengan katalog standar teoretis
    final standardMatch = await repository.matchStandardShade(targetColor);
    expect(standardMatch, isNotNull);
    expect(standardMatch!.name, equals('Light Neutral'));

    // 4. Uji kecocokan dengan produk komersial
    final commercialMatches = await repository.matchCommercialProducts(targetColor);
    expect(commercialMatches, isNotEmpty);

    // Produk teratas harus memiliki kecocokan yang sangat tinggi (Delta E mendekati 0)
    final bestMatch = commercialMatches.first;
    expect(bestMatch['matchPercentage'], greaterThan(95.0));

    final matchedProduct = bestMatch['product'];
    expect(matchedProduct.brand, equals('Wardah'));
    expect(matchedProduct.shadeName, equals('22N Light Ivory'));

    // Tutup database dan bersihkan direktori temp
    await dbService.isar.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });
}
