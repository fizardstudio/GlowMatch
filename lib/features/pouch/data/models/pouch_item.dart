import 'package:isar/isar.dart';

part 'pouch_item.g.dart';

@collection
class PouchItem {
  Id id = Isar.autoIncrement;

  late String brand;
  late String productName;
  late String shadeName;
  late String hexCode;
  late DateTime openedDate;
  late int paoMonths; // Masa PAO dalam bulan (misal: 12)
  late String category; // Foundation, Concealer, Lipstick, dll.

  bool isReviewSynced = true;
  int? feedbackScore; // null = no review, 0 = perfect, -1 = too dark, 1 = too light
}
