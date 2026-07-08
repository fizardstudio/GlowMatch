import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/standard_shade.dart';
import '../data/models/product_shade.dart';
import '../utils/color_calculator.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  late final Isar isar;
  bool _isInitialized = false;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// Menginisialisasi Isar database dan melakukan seeding data jika kosong.
  Future<void> init({String? directoryPath}) async {
    if (_isInitialized) return;

    final String path;
    if (directoryPath != null) {
      path = directoryPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = dir.path;
    }

    isar = await Isar.open(
      [
        StandardShadeSchema,
        ProductShadeSchema,
      ],
      directory: path,
    );

    _isInitialized = true;
    await _seedDataIfNeeded();
  }

  /// Membantu melakukan parsing HEX string ke RGB dan menyimpannya ke koordinat Lab.
  Map<String, double> _hexToLab(String hex) {
    final cleanHex = hex.replaceAll('#', '');
    final int r = int.parse(cleanHex.substring(0, 2), radix: 16);
    final int g = int.parse(cleanHex.substring(2, 4), radix: 16);
    final int b = int.parse(cleanHex.substring(4, 6), radix: 16);

    final lab = ColorCalculator.rgbToLab(r, g, b);
    return {'l': lab.l, 'a': lab.a, 'b': lab.b};
  }

  Future<void> _seedDataIfNeeded() async {
    // Seeding warna standar teoretis
    final standardCount = await isar.standardShades.count();
    if (standardCount == 0) {
      final List<Map<String, String>> rawStandards = [
        {'name': 'Fair Cool', 'skin': 'Fair', 'under': 'Cool', 'hex': '#FDF5F2'},
        {'name': 'Fair Neutral', 'skin': 'Fair', 'under': 'Neutral', 'hex': '#FAF0E6'},
        {'name': 'Fair Warm', 'skin': 'Fair', 'under': 'Warm', 'hex': '#F5ECDE'},
        {'name': 'Light Cool', 'skin': 'Light', 'under': 'Cool', 'hex': '#F5D6C6'},
        {'name': 'Light Neutral', 'skin': 'Light', 'under': 'Neutral', 'hex': '#EED0BD'},
        {'name': 'Light Warm', 'skin': 'Light', 'under': 'Warm', 'hex': '#E6C5AC'},
        {'name': 'Medium Cool', 'skin': 'Medium', 'under': 'Cool', 'hex': '#DFB19B'},
        {'name': 'Medium Neutral', 'skin': 'Medium', 'under': 'Neutral', 'hex': '#D4A286'},
        {'name': 'Medium Warm', 'skin': 'Medium', 'under': 'Warm', 'hex': '#CBA37D'},
        {'name': 'Tan Cool', 'skin': 'Tan', 'under': 'Cool', 'hex': '#B2856E'},
        {'name': 'Tan Neutral', 'skin': 'Tan', 'under': 'Neutral', 'hex': '#A87C64'},
        {'name': 'Tan Warm', 'skin': 'Tan', 'under': 'Warm', 'hex': '#A27557'},
        {'name': 'Deep Cool', 'skin': 'Deep', 'under': 'Cool', 'hex': '#7D5745'},
        {'name': 'Deep Neutral', 'skin': 'Deep', 'under': 'Neutral', 'hex': '#734B3B'},
        {'name': 'Deep Warm', 'skin': 'Deep', 'under': 'Warm', 'hex': '#694432'},
      ];

      final List<StandardShade> shadesToInsert = [];
      for (final raw in rawStandards) {
        final labCoords = _hexToLab(raw['hex']!);
        final shade = StandardShade()
          ..name = raw['name']!
          ..skinTone = raw['skin']!
          ..undertone = raw['under']!
          ..hexCode = raw['hex']!
          ..l = labCoords['l']!
          ..a = labCoords['a']!
          ..b = labCoords['b']!;
        shadesToInsert.add(shade);
      }

      await isar.writeTxn(() async {
        await isar.standardShades.putAll(shadesToInsert);
      });
    }

    // Seeding data produk komersial
    final productCount = await isar.productShades.count();
    if (productCount == 0) {
      final List<Map<String, String>> rawProducts = [
        // Wardah
        {
          'brand': 'Wardah',
          'product': 'Colorfit Matte Foundation',
          'shade': '22N Light Ivory',
          'hex': '#EED0BD',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Colorfit Matte Foundation',
          'shade': '23W Warm Ivory',
          'hex': '#E6C5AC',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Colorfit Matte Foundation',
          'shade': '32N Neutral Beige',
          'hex': '#D4A286',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Colorfit Matte Foundation',
          'shade': '43W Golden Sand',
          'hex': '#A27557',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        // Maybelline
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '115 Ivory',
          'hex': '#FDF5F2',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '120 Classic Ivory',
          'hex': '#FAF0E6',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '128 Warm Nude',
          'hex': '#E8C6A5',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '220 Natural Beige',
          'hex': '#D9AB85',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '310 Sun Beige',
          'hex': '#C59976',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        // Make Over
        {
          'brand': 'Make Over',
          'product': 'Powerstay Weightless Liquid Foundation',
          'shade': 'N10 Marble',
          'hex': '#FBF1E8',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay Weightless Liquid Foundation',
          'shade': 'W22 Warm Ivory',
          'hex': '#E3BF9F',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay Weightless Liquid Foundation',
          'shade': 'N30 Natural Beige',
          'hex': '#CFA07C',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay Weightless Liquid Foundation',
          'shade': 'W42 Warm Sand',
          'hex': '#9B7051',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
      ];

      final List<ProductShade> productsToInsert = [];
      for (final raw in rawProducts) {
        final labCoords = _hexToLab(raw['hex']!);
        final prod = ProductShade()
          ..brand = raw['brand']!
          ..productName = raw['product']!
          ..shadeName = raw['shade']!
          ..hexCode = raw['hex']!
          ..l = labCoords['l']!
          ..a = labCoords['a']!
          ..b = labCoords['b']!
          ..category = raw['cat']!
          ..affiliateUrl = raw['url']!;
        productsToInsert.add(prod);
      }

      await isar.writeTxn(() async {
        await isar.productShades.putAll(productsToInsert);
      });
    }
  }
}
