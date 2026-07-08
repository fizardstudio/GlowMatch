import 'package:isar/isar.dart';

part 'standard_shade.g.dart';

@collection
class StandardShade {
  Id id = Isar.autoIncrement;

  late String name;
  late String skinTone; // Fair, Light, Medium, Tan, Deep
  late String undertone; // Warm, Cool, Neutral
  late String hexCode;
  late double l;
  late double a;
  late double b;
}
