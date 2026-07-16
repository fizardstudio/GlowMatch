import 'package:isar/isar.dart';

part 'product_shade.g.dart';

@collection
class ProductShade {
  Id id = Isar.autoIncrement;

  late String brand;
  late String productName;
  late String shadeName;
  late String hexCode;
  late double l;
  late double a;
  late double b;
  late String category; // Foundation, Concealer, Lipstick, etc.
  late String affiliateUrl;

  int perfectCount = 0;
  int tooDarkCount = 0;
  int tooLightCount = 0;

  double deltaLOffset = 0.0;
}
