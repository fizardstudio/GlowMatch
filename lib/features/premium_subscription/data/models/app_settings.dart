import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = 0; // Kunci tunggal untuk pengaturan tunggal

  late bool isPremium;
  bool hasUsedCoupleTrial = false;

  String? lastMatchedShadeName;
  String? lastMatchedUndertone;
  String? lastMatchedSeasonalColor;
  String? lastMatchedSkinTone;
  String? lastMatchedFaceShape;
  double lastMatchedContrast = 35.0;
  List<int> lastMatchedCommercialShadeIds = [];
  bool showWatermark = true;
  String? lastSelectedSkinType;
}
