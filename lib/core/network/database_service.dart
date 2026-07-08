import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/standard_shade.dart';
import '../data/models/product_shade.dart';
import '../../features/pouch/data/models/pouch_item.dart';
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
        PouchItemSchema,
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
        // ==========================================
        // === WARDAH: Colorfit Matte Foundation ===
        // ==========================================
        {
          'brand': 'Wardah',
          'product': 'Colorfit Matte Foundation',
          'shade': '11C Pink Fair',
          'hex': '#F8D4C4',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
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
          'shade': '33W Olive Beige',
          'hex': '#C89A7B',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Colorfit Matte Foundation',
          'shade': '42N Neutral Sand',
          'hex': '#BFA08A',
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
        {
          'brand': 'Wardah',
          'product': 'Colorfit Matte Foundation',
          'shade': '52N Almond',
          'hex': '#8D624C',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },

        // ==========================================
        // === WARDAH: Exclusive Liquid Foundation ===
        // ==========================================
        {
          'brand': 'Wardah',
          'product': 'Exclusive Liquid Foundation',
          'shade': '01 Light Beige',
          'hex': '#F5DBC8',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Exclusive Liquid Foundation',
          'shade': '02 Sheer Pink',
          'hex': '#F1CBB5',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Exclusive Liquid Foundation',
          'shade': '03 Sandy Beige',
          'hex': '#E1B395',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Exclusive Liquid Foundation',
          'shade': '04 Natural',
          'hex': '#D8A682',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Exclusive Liquid Foundation',
          'shade': '05 Coffee Beige',
          'hex': '#BC8660',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/wardahofficial'
        },

        // ==========================================
        // === MAYBELLINE: Fit Me Matte + Poreless ===
        // ==========================================
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '110 Porcelain',
          'hex': '#FDF4EF',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '112 Natural Ivory',
          'hex': '#F6E4D9',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '115 Ivory',
          'hex': '#F5ECDE',
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
          'shade': '125 Nude Beige',
          'hex': '#EAC7B2',
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
          'shade': '228 Soft Tan',
          'hex': '#D09F7A',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '230 Natural Buff',
          'hex': '#C59976',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '310 Sun Beige',
          'hex': '#BCA28B',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '320 Natural Tan',
          'hex': '#A37B5C',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Fit Me Matte + Poreless',
          'shade': '322 Warm Honey',
          'hex': '#946D4B',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },

        // ===================================================
        // === MAYBELLINE: Superstay Active Wear 30H Fnd ===
        // ===================================================
        {
          'brand': 'Maybelline',
          'product': 'Superstay Active Wear 30H Foundation',
          'shade': '112 Natural Ivory',
          'hex': '#F5E0D2',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Superstay Active Wear 30H Foundation',
          'shade': '120 Classic Ivory',
          'hex': '#F0D3BE',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Superstay Active Wear 30H Foundation',
          'shade': '128 Warm Nude',
          'hex': '#E3BEA0',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Superstay Active Wear 30H Foundation',
          'shade': '220 Natural Beige',
          'hex': '#D3A884',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Superstay Active Wear 30H Foundation',
          'shade': '310 Sun Beige',
          'hex': '#B28A6D',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },
        {
          'brand': 'Maybelline',
          'product': 'Superstay Active Wear 30H Foundation',
          'shade': '312 Golden',
          'hex': '#9C7557',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/maybellineindonesia'
        },

        // ===================================================
        // === MAKE OVER: Powerstay Weightless Liquid Fnd ===
        // ===================================================
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
          'shade': 'N20 Warm Beige',
          'hex': '#DDC09D',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay Weightless Liquid Foundation',
          'shade': 'W33 Honey Beige',
          'hex': '#D3A279',
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
          'shade': 'W41 Peach Beige',
          'hex': '#C69268',
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
        {
          'brand': 'Make Over',
          'product': 'Powerstay Weightless Liquid Foundation',
          'shade': 'N40 Sand',
          'hex': '#8A6546',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay Weightless Liquid Foundation',
          'shade': 'N50 Tan',
          'hex': '#765337',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay Weightless Liquid Foundation',
          'shade': 'C62 Rich Cocoa',
          'hex': '#5D3E2B',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },

        // ===================================================
        // === MAKE OVER: Ultra Cover Liquid Matte Fnd ===
        // ===================================================
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '01 Ochre',
          'hex': '#F5DCBF',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '02 Pink Shade',
          'hex': '#EDB9A6',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '03 Nude Silk',
          'hex': '#E3C2A3',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '04 Amber Rose',
          'hex': '#D8A78F',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '05 Velvet Nude',
          'hex': '#CCA080',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '06 Beige Blast',
          'hex': '#B88C6C',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '07 Caramel',
          'hex': '#A17859',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '08 Pearl',
          'hex': '#FBF0DF',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Ultra Cover Liquid Matte Foundation',
          'shade': '09 Creme Rose',
          'hex': '#F2D4BB',
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
