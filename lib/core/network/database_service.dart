import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/standard_shade.dart';
import '../data/models/product_shade.dart';
import '../../features/pouch/data/models/pouch_item.dart';
import '../../features/premium_subscription/data/models/app_settings.dart';
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
        AppSettingsSchema,
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
    if (productCount < 213) {
      await isar.writeTxn(() async {
        await isar.productShades.clear();
      });
            final List<Map<String, String>> rawProducts = [
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
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W12 Warm Marble',
          'hex': '#F1D4BA',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W21 Coral Ivory',
          'hex': '#EBC1A2',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W22 Warm Ivory',
          'hex': '#ECC4A3',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W30 Creme Beige',
          'hex': '#E4B898',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W32 Warm Beige',
          'hex': '#E5BB9D',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W33 Honey Beige',
          'hex': '#DCB191',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W40 Creme Sand',
          'hex': '#D0A281',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W41 Coral Sand',
          'hex': '#CE9D7B',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W42 Warm Sand',
          'hex': '#D1A382',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W50 Creme Tan',
          'hex': '#C19271',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'W60 Creme Cocoa',
          'hex': '#8E5A3D',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'N00 Porcelain',
          'hex': '#FAEBD7',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'N10 Marble',
          'hex': '#ECC2A5',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'N20 Ivory',
          'hex': '#EABCA0',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'N30 Natural Beige',
          'hex': '#E2B395',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'N40 Sand',
          'hex': '#CFA081',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'N50 Tan',
          'hex': '#BA8E70',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'N70 Ebony',
          'hex': '#5B3B2B',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'C11 Pink Marble',
          'hex': '#E9BDAB',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'C21 Pink Ivory',
          'hex': '#E3B4A2',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'C31 Pink Beige',
          'hex': '#DCA794',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'C41 Cool Sand',
          'hex': '#C69480',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'C51 Cool Tan',
          'hex': '#A9715E',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Make Over',
          'product': 'Powerstay 24H Weightless Liquid Foundation',
          'shade': 'C62 Rich Cocoa',
          'hex': '#754B3A',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/makeoverofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '01 Caramel Coat',
          'hex': '#C4795E',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '02 Peach Polish',
          'hex': '#D47A6B',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '03 Dazzle Maple',
          'hex': '#AD4B39',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '04 Rosewood Radiance',
          'hex': '#A45C60',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '05 Glazing Berry',
          'hex': '#87364B',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '06 Ruby Sparks',
          'hex': '#9E1925',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '07 Rouge Flare',
          'hex': '#B31E20',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '08 Plush Pome',
          'hex': '#911F35',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '09 Fudgy Toffee',
          'hex': '#823E2A',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '10 Ombre Sheen',
          'hex': '#E29986',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '11 Petal Blush',
          'hex': '#D18386',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '12 Shine Sorbet',
          'hex': '#BF4C66',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Wardah',
          'product': 'Glasting Liquid Lip',
          'shade': '13 Pumpkin Drip',
          'hex': '#C25034',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/wardahofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'C00 Cotton',
          'hex': '#FAEBD7',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'C01 Perle',
          'hex': '#FAD3C4',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'W01 Bijoux',
          'hex': '#F5CBA7',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'C01.5 Butter',
          'hex': '#F4C2C2',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'N01 Nina',
          'hex': '#F3C3A0',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'C02 Serene',
          'hex': '#ECC4A8',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'W01.5 Cashew',
          'hex': '#E5BE9E',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'N02 Charlotte',
          'hex': '#DFB091',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'C03 Éclair',
          'hex': '#D29A7F',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'W02 Coco',
          'hex': '#CD9A74',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'N02.5 Linen',
          'hex': '#C39276',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'N03 Alter',
          'hex': '#B58466',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'W03 Goddess',
          'hex': '#B1835F',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'W04 Tiffany',
          'hex': '#9E7453',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'N04 Fawn',
          'hex': '#8C6246',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'Somethinc',
          'product': 'Copy Paste Breathable Mesh Cushion',
          'shade': 'W05 Penny',
          'hex': '#7A5338',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/somethincofficial'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Milkshake',
          'hex': '#F2ECDE',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Vanilla',
          'hex': '#F4E6D0',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Custard',
          'hex': '#F3D19B',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Granola',
          'hex': '#E0B997',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Caramel',
          'hex': '#E9BD7A',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Biscuit',
          'hex': '#D6AD91',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Pancake',
          'hex': '#EBBE88',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Truffle',
          'hex': '#C79165',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Toffee',
          'hex': '#E1AB6B',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'ESQA',
          'product': 'Flawless Liquid Concealer',
          'shade': 'Latte',
          'hex': '#A05937',
          'cat': 'Concealer',
          'url': 'https://shopee.co.id/esqacosmetics'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Fair',
          'hex': '#FADDC4',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Light',
          'hex': '#ECC5AA',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Beige',
          'hex': '#DFBA9E',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Warm Beige',
          'hex': '#DEB594',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Sage',
          'hex': '#CEAE93',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Medium Neutral',
          'hex': '#CFA68F',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Honey',
          'hex': '#C69A83',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Sand',
          'hex': '#C7977A',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Warm Honey',
          'hex': '#B8896D',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Rosé All Day',
          'product': 'The Realest Airyfit Glow Cushion',
          'shade': 'Caramel',
          'hex': '#9C6F55',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/roseallday.co'
        },
        {
          'brand': 'Luxcrime',
          'product': 'Blur & Cover Two Way Cake',
          'shade': 'Cream Puff',
          'hex': '#F7E3CE',
          'cat': 'Two Way Cake',
          'url': 'https://shopee.co.id/luxcrime.official'
        },
        {
          'brand': 'Luxcrime',
          'product': 'Blur & Cover Two Way Cake',
          'shade': 'Buttercream',
          'hex': '#F5DAB3',
          'cat': 'Two Way Cake',
          'url': 'https://shopee.co.id/luxcrime.official'
        },
        {
          'brand': 'Luxcrime',
          'product': 'Blur & Cover Two Way Cake',
          'shade': 'Custard',
          'hex': '#E6C29E',
          'cat': 'Two Way Cake',
          'url': 'https://shopee.co.id/luxcrime.official'
        },
        {
          'brand': 'Luxcrime',
          'product': 'Blur & Cover Two Way Cake',
          'shade': 'Honeycomb',
          'hex': '#DBB28C',
          'cat': 'Two Way Cake',
          'url': 'https://shopee.co.id/luxcrime.official'
        },
        {
          'brand': 'Luxcrime',
          'product': 'Blur & Cover Two Way Cake',
          'shade': 'Opera',
          'hex': '#C69C75',
          'cat': 'Two Way Cake',
          'url': 'https://shopee.co.id/luxcrime.official'
        },
        {
          'brand': 'Luxcrime',
          'product': 'Blur & Cover Two Way Cake',
          'shade': 'Cinnamon',
          'hex': '#9C7053',
          'cat': 'Two Way Cake',
          'url': 'https://shopee.co.id/luxcrime.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '01 Light',
          'hex': '#EFCBB1',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '02 Natural',
          'hex': '#ECC5A8',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '03 Medium',
          'hex': '#DFB395',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '04 Pinkish',
          'hex': '#E9BDAB',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '05 Fairy Pinkish',
          'hex': '#F6D0BE',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '06 Porcelain',
          'hex': '#FAD9C3',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '07 Light Ivory',
          'hex': '#E9C0A4',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '08 Creamy Beige',
          'hex': '#E4BA9C',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '09 Warm Sand',
          'hex': '#D2A281',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Hanasui',
          'product': 'Serum Cushion',
          'shade': '10 Classic Ivory',
          'hex': '#E8BEA5',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/hanasui.official'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '01 Paradise Found',
          'hex': '#D44347',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '02 Pretty Please',
          'hex': '#DE6455',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '03 Take Change',
          'hex': '#BD1C2A',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '04 Never Settle',
          'hex': '#87182E',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '05 Good Vibes',
          'hex': '#96382D',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '06 Brave Enough',
          'hex': '#E68A8E',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '07 Love Always',
          'hex': '#BD7C6F',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '08 Peace Out',
          'hex': '#E38676',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '09 Enjoy Today',
          'hex': '#8A4132',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '10 Stay Classy',
          'hex': '#9E131C',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '11 Fairy Tale',
          'hex': '#B57B7F',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '12 Fly High',
          'hex': '#A36971',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Barenbliss',
          'product': 'Peach Makes Perfect Lip Tint',
          'shade': '13 Rise Up',
          'hex': '#C73420',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/barenbliss.id'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'C10 Pearl',
          'hex': '#F9E5D2',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'N10 Lace',
          'hex': '#F3DCBF',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'N15',
          'hex': '#EDCFA9',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'O15 Soy',
          'hex': '#ECC1A3',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'W20 Cinnamon',
          'hex': '#E4BA97',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'O20 Cinnamon',
          'hex': '#DBAF8E',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'N21 Eclair',
          'hex': '#DFB494',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'N23 Toffee',
          'hex': '#D6AA8B',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'W00 Chiffon',
          'hex': '#FDEBD2',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Mother of Pearl',
          'product': 'Unbothered Demi-Matte Cushion',
          'shade': 'W31 Caramel',
          'hex': '#C29679',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/mopbeauty'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '01 Autumn Bell',
          'hex': '#843247',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '02 Apple Shower',
          'hex': '#A31E2A',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '03 Candy Rain / Rainy Hazelrose',
          'hex': '#CF4E66',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '04 Peach Sprinkles',
          'hex': '#D47B6A',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '05 Spring Dazzle',
          'hex': '#E55C3E',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '06 Coffee Drop',
          'hex': '#7A4232',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '07 French Vanilla',
          'hex': '#D69784',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '08 Pouring Tea',
          'hex': '#8A464B',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '09 Red Bean',
          'hex': '#8F3131',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Emina',
          'product': 'Glossy Stain',
          'shade': '10 Choco Praline',
          'hex': '#693326',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/eminaofficial'
        },
        {
          'brand': 'Pixy',
          'product': 'Make It Glow Techno-Fixed Matte Cushion',
          'shade': '101 Light Beige',
          'hex': '#ECC7AD',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/pixyindonesia'
        },
        {
          'brand': 'Pixy',
          'product': 'Make It Glow Techno-Fixed Matte Cushion',
          'shade': '201 Neutral Beige',
          'hex': '#E4BA9A',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/pixyindonesia'
        },
        {
          'brand': 'Pixy',
          'product': 'Make It Glow Techno-Fixed Matte Cushion',
          'shade': '301 Medium Beige',
          'hex': '#D5AA88',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/pixyindonesia'
        },
        {
          'brand': 'Pixy',
          'product': 'Make It Glow Techno-Fixed Matte Cushion',
          'shade': '401 Sandy Beige',
          'hex': '#C29574',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/pixyindonesia'
        },
        {
          'brand': 'Skintific',
          'product': 'Cover All Perfect Cushion',
          'shade': '01 Porcelain',
          'hex': '#F9DEC7',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/skintific.id'
        },
        {
          'brand': 'Skintific',
          'product': 'Cover All Perfect Cushion',
          'shade': '02 Ivory',
          'hex': '#ECC2A8',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/skintific.id'
        },
        {
          'brand': 'Skintific',
          'product': 'Cover All Perfect Cushion',
          'shade': '03 Petal',
          'hex': '#EABCA0',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/skintific.id'
        },
        {
          'brand': 'Skintific',
          'product': 'Cover All Perfect Cushion',
          'shade': '04 Beige',
          'hex': '#DFB395',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/skintific.id'
        },
        {
          'brand': 'Skintific',
          'product': 'Cover All Perfect Cushion',
          'shade': '05 Sand',
          'hex': '#CFA081',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/skintific.id'
        },
        {
          'brand': 'Skintific',
          'product': 'Cover All Perfect Cushion',
          'shade': '06 Honey',
          'hex': '#BF9173',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/skintific.id'
        },
        {
          'brand': 'Glad2Glow',
          'product': 'Perfect Cover Cushion',
          'shade': '01 Porcelain',
          'hex': '#F8DEC5',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/glad2glow.id'
        },
        {
          'brand': 'Glad2Glow',
          'product': 'Perfect Cover Cushion',
          'shade': '02 Ivory',
          'hex': '#ECC1A6',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/glad2glow.id'
        },
        {
          'brand': 'Glad2Glow',
          'product': 'Perfect Cover Cushion',
          'shade': '03 Natural',
          'hex': '#DFA98F',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/glad2glow.id'
        },
        {
          'brand': 'Glad2Glow',
          'product': 'Perfect Cover Cushion',
          'shade': '04 Beige',
          'hex': '#D29A81',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/glad2glow.id'
        },
        {
          'brand': 'Instaperfect',
          'product': 'Skincover Air Cushion',
          'shade': '11 Fair Pink',
          'hex': '#E9BDAB',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/instaperfect.official'
        },
        {
          'brand': 'Instaperfect',
          'product': 'Skincover Air Cushion',
          'shade': '22 Light Ivory',
          'hex': '#E5BEA3',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/instaperfect.official'
        },
        {
          'brand': 'Instaperfect',
          'product': 'Skincover Air Cushion',
          'shade': '32 True Beige',
          'hex': '#DCB395',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/instaperfect.official'
        },
        {
          'brand': 'Instaperfect',
          'product': 'Skincover Air Cushion',
          'shade': '33 Warm Olive',
          'hex': '#D4AF92',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/instaperfect.official'
        },
        {
          'brand': 'Instaperfect',
          'product': 'Skincover Air Cushion',
          'shade': '43 Creme Sand',
          'hex': '#CFA180',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/instaperfect.official'
        },
        {
          'brand': 'Instaperfect',
          'product': 'Skincover Air Cushion',
          'shade': '52 Almond',
          'hex': '#BA8E6E',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/instaperfect.official'
        },
        {
          'brand': 'Dear Me Beauty',
          'product': 'Airy Poreless Powder Foundation',
          'shade': 'C00 Creme Porcelain',
          'hex': '#FAE3CE',
          'cat': 'Powder Foundation',
          'url': 'https://shopee.co.id/dearmebeauty'
        },
        {
          'brand': 'Dear Me Beauty',
          'product': 'Airy Poreless Powder Foundation',
          'shade': 'C01 Creme Ivory',
          'hex': '#F2D5BD',
          'cat': 'Powder Foundation',
          'url': 'https://shopee.co.id/dearmebeauty'
        },
        {
          'brand': 'Dear Me Beauty',
          'product': 'Airy Poreless Powder Foundation',
          'shade': 'N00 Nude Porcelain',
          'hex': '#F5DCC8',
          'cat': 'Powder Foundation',
          'url': 'https://shopee.co.id/dearmebeauty'
        },
        {
          'brand': 'Dear Me Beauty',
          'product': 'Airy Poreless Powder Foundation',
          'shade': 'N01 Nude Ivory',
          'hex': '#ECC2AB',
          'cat': 'Powder Foundation',
          'url': 'https://shopee.co.id/dearmebeauty'
        },
        {
          'brand': 'Dear Me Beauty',
          'product': 'Airy Poreless Powder Foundation',
          'shade': 'N02 Nude Beige',
          'hex': '#DFA88D',
          'cat': 'Powder Foundation',
          'url': 'https://shopee.co.id/dearmebeauty'
        },
        {
          'brand': 'Guele',
          'product': 'Bare Cushion',
          'shade': '01 Luzè',
          'hex': '#FDEBD2',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/guelecosmetics'
        },
        {
          'brand': 'Guele',
          'product': 'Bare Cushion',
          'shade': '02 Marè',
          'hex': '#F5DCBF',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/guelecosmetics'
        },
        {
          'brand': 'Guele',
          'product': 'Bare Cushion',
          'shade': '03 Dunnè',
          'hex': '#EDCFA9',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/guelecosmetics'
        },
        {
          'brand': 'Guele',
          'product': 'Bare Cushion',
          'shade': '04 Sandè',
          'hex': '#E4BA97',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/guelecosmetics'
        },
        {
          'brand': 'Guele',
          'product': 'Bare Cushion',
          'shade': '05 Lumbrè',
          'hex': '#DBAF8E',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/guelecosmetics'
        },
        {
          'brand': 'Guele',
          'product': 'Bare Cushion',
          'shade': '06 Sunnè',
          'hex': '#D6AA8B',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/guelecosmetics'
        },
        {
          'brand': 'Guele',
          'product': 'Bare Cushion',
          'shade': '07 Ambrè',
          'hex': '#C29679',
          'cat': 'Cushion',
          'url': 'https://shopee.co.id/guelecosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Coverlast Liquid Foundation',
          'shade': '01 Light',
          'hex': '#F5D3B3',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/omgcosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Coverlast Liquid Foundation',
          'shade': '02 Natural',
          'hex': '#ECC0AE',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/omgcosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Coverlast Liquid Foundation',
          'shade': '03 Caramel',
          'hex': '#D59F7C',
          'cat': 'Foundation',
          'url': 'https://shopee.co.id/omgcosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Matte Kiss Lip Cream',
          'shade': '01 Dreamy',
          'hex': '#D47B6A',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/omgcosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Matte Kiss Lip Cream',
          'shade': '02 Juicy',
          'hex': '#C45034',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/omgcosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Matte Kiss Lip Cream',
          'shade': '03 Flame',
          'hex': '#BD1C2A',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/omgcosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Matte Kiss Lip Cream',
          'shade': '04 Fancy',
          'hex': '#8A4132',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/omgcosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Matte Kiss Lip Cream',
          'shade': '05 Beverly',
          'hex': '#911F35',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/omgcosmetics'
        },
        {
          'brand': 'OMG (Oh My Glam)',
          'product': 'Matte Kiss Lip Cream',
          'shade': '06 Classic',
          'hex': '#9E131C',
          'cat': 'Lip Color',
          'url': 'https://shopee.co.id/omgcosmetics'
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
