import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:glowmatch/core/theme/theme_manager.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../data/models/app_settings.dart';
import '../widgets/lip_filter_painter.dart';
import '../../data/models/makeup_preset.dart';
import '../../../../core/utils/widget_helper.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/utils/face_geometry_helper.dart';
import '../../../../core/utils/color_calculator.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

class ArTryOnPage extends StatefulWidget {
  const ArTryOnPage({super.key});

  @override
  State<ArTryOnPage> createState() => _ArTryOnPageState();
}

class _ArTryOnPageState extends State<ArTryOnPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool get isDark => ThemeManager.isDark;
  Color get textColor => ThemeManager.textColor;
  Color get textMutedColor => ThemeManager.textMutedColor;
  Color get cardBgColor => ThemeManager.cardBgColor;
  Color get cardBorderColor => ThemeManager.cardBorderColor;
  Color get primaryColor => ThemeManager.primaryColor;
  final Isar _isar = DatabaseService().isar;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;
  bool _isPremium = false;
  bool _showPaywall = true;

  // ML Kit Face Detector untuk penyejajaran bibir & pipi secara andal
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: false,
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isProcessingFrame = false;
  Face? _detectedFace;
  int _imageWidth = 0;
  int _imageHeight = 0;

  // Active Category (0 = Looks, 1 = Base, 2 = Bibir, 3 = Pipi)
  int _activeCategoryIndex = 0;

  // Filter Parameters - Lipstick (Bibir)
  Color _selectedLipstickColor = const Color(0xFFD81B60); // Cherry Red
  double _lipstickOpacity = 0.40; // Default 40%
  String _lipstickFinishing = 'matte'; // 'matte' atau 'glossy'

  // Filter Parameters - Blush-On (Pipi)
  Color _selectedBlushColor = const Color(0xFFFF8A80); // Soft Coral
  double _blushOpacity = 0.25; // Default 25%

  // Filter Parameters - Eye Makeup (Mata)
  Color _selectedEyeshadowColor = const Color(0xFFFFCC80); // Champagne Shimmer
  double _eyeshadowOpacity = 0.0;
  bool _hasEyeliner = false;
  double _eyelinerThickness = 0.5; // Default 50%

  // Filter Parameters - Nose Contour (Hidung)
  double _noseHighlightOpacity = 0.0;
  double _noseShadingOpacity = 0.0;

  double _sliderX = 180.0; // Koordinat pembagi horizontal (default diatur di didChangeDependencies)
  bool _isSliderInitialized = false;
  bool _showControls = true;
  bool _isCameraDisposed = false;
  bool _canPop = false;

  // Demo Mode
  bool _isDemoActive = false;
  int _demoSecondsLeft = 60;
  Timer? _demoTimer;

  // Advanced Try-On Upgrades (Phase 2.5) State Variables
  String? _activePreset = 'Korean Glass Skin';
  bool _isSplitMode = true; // DEFAULT ON!
  bool _showGlassSkin = true;

  // Foundation/Base fields
  Color _selectedFoundationColor = const Color(0xFFF3D3C4);
  double _foundationOpacity = 0.0;
  String _foundationFinishing = 'dewy'; // 'matte', 'satin', 'dewy'
  List<ProductShade> _dbFoundations = [];
  List<ProductShade> _filteredFoundations = [];
  List<String> _brands = ['Semua Merek'];
  String _selectedBrandFilter = 'Semua Merek';
  ProductShade? _selectedFoundationProduct;

  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isSavingLook = false;
  bool _isCapturing = false;

  String _selectedLightingPreset = 'Natural'; // 'Natural', 'Golden Hour', 'Studio Light', 'Cyber Neon'
  bool _showHarmonyHeatmap = false;
  bool _showTooltip = false;
  String _activeTooltipComponent = 'base';
  Offset _tooltipOffset = Offset.zero;

  bool _isExportingBoomerang = false;
  double _exportProgress = 0.0;
  int _faceLostFrames = 0;
  InputImageRotation? _activeRotation;
  int _lastFrameTimeMs = 0;
  late final Ticker _ticker;
  Rect? _smoothedBox;
  final Map<FaceContourType, List<Point<int>>> _smoothedContours = {};
  double? _smoothedSmiling;
  SmoothedFace? _smoothedFace;

  // Preset Looks List
  final List<Map<String, dynamic>> _presetLooks = [
    {
      'name': 'Clean Girl',
      'lipstickColor': const Color(0xFFDCAE96),
      'lipstickOpacity': 0.35,
      'lipstickFinishing': 'glossy',
      'blushColor': const Color(0xFFE29A86),
      'blushOpacity': 0.25,
      'foundationColor': const Color(0xFFF5D6C8),
      'foundationOpacity': 0.0,
      'showGlassSkin': true,
    },
    {
      'name': 'Korean Glass Skin',
      'lipstickColor': const Color(0xFFF98E7B),
      'lipstickOpacity': 0.45,
      'lipstickFinishing': 'glossy',
      'blushColor': const Color(0xFFFF8A80),
      'blushOpacity': 0.30,
      'foundationColor': const Color(0xFFF5D6C8),
      'foundationOpacity': 0.0,
      'showGlassSkin': true,
    },
    {
      'name': 'Douyin Sweetheart',
      'lipstickColor': const Color(0xFFE23D61),
      'lipstickOpacity': 0.65,
      'lipstickFinishing': 'glossy',
      'blushColor': const Color(0xFFE88A90),
      'blushOpacity': 0.45,
      'foundationColor': const Color(0xFFF5D6C8),
      'foundationOpacity': 0.0,
      'showGlassSkin': false,
    },
    {
      'name': 'Old Money Glam',
      'lipstickColor': const Color(0xFF8B0000),
      'lipstickOpacity': 0.70,
      'lipstickFinishing': 'matte',
      'blushColor': const Color(0xFFC08060),
      'blushOpacity': 0.35,
      'foundationColor': const Color(0xFFF5D6C8),
      'foundationOpacity': 0.0,
      'showGlassSkin': false,
    },
  ];

  // Scanned skin profile history variables
  String? _lastMatchedShadeName;
  String? _lastMatchedUndertone;
  String? _lastMatchedSeasonalColor;
  String? _lastMatchedSkinTone;
  double? _lastMatchedContrast;

  // List Warna Lipstik Eksklusif
  final List<Map<String, dynamic>> _lipstickColors = [
    {'name': 'Cherry Red', 'color': const Color(0xFFD81B60)},
    {'name': 'Matte Rose', 'color': const Color(0xFFAD1457)},
    {'name': 'Peach Coral', 'color': const Color(0xFFFF7043)},
    {'name': 'Plum Berry', 'color': const Color(0xFF8E24AA)},
    {'name': 'Nude Brown', 'color': const Color(0xFF8D6E63)},
    {'name': 'Classic Crimson', 'color': const Color(0xFFB71C1C)},
  ];

  // List Warna Blush-On Eksklusif
  final List<Map<String, dynamic>> _blushColors = [
    {'name': 'Soft Coral', 'color': const Color(0xFFFF8A80)},
    {'name': 'Peach Pink', 'color': const Color(0xFFFF80AB)},
    {'name': 'Dusty Rose', 'color': const Color(0xFFE91E63)},
    {'name': 'Pale Tangerine', 'color': const Color(0xFFFFB74D)},
    {'name': 'Warm Amber', 'color': const Color(0xFFFF8F00)},
    {'name': 'Plum Pink', 'color': const Color(0xFFBA68C8)},
  ];

  // List Warna Eyeshadow Eksklusif
  final List<Map<String, dynamic>> _eyeshadowColors = [
    {'name': 'Champagne Gold', 'color': const Color(0xFFFFCC80)},
    {'name': 'Sunset Bronze', 'color': const Color(0xFFFFA726)},
    {'name': 'Rose Shimmer', 'color': const Color(0xFFF48FB1)},
    {'name': 'Cyber Cyan', 'color': const Color(0xFF00E5FF)},
    {'name': 'Plum Glam', 'color': const Color(0xFFCE93D8)},
    {'name': 'Taupe Nude', 'color': const Color(0xFFB0BEC5)},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPremiumStatus();
    _loadFoundationsFromDb();
    _initializeCamera();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSliderInitialized) {
      // Set sliderX ke tengah layar saat ukuran layar tersedia
      _sliderX = MediaQuery.of(context).size.width / 2;
      _isSliderInitialized = true;
    }
  }

  Color _getHexColor(String hex) {
    final cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    }
    return Colors.transparent;
  }

  Future<void> _loadFoundationsFromDb() async {
    try {
      final foundations = await _isar.productShades
          .filter()
          .categoryEqualTo('Foundation')
          .findAll();
      if (mounted) {
        setState(() {
          _dbFoundations = foundations;
          final uniqueBrands = foundations.map((f) => f.brand).toSet().toList();
          _brands = ['Semua Merek', ...uniqueBrands];
          _applyFoundationFilter();
        });
      }
    } catch (e) {
      debugPrint("Error loading foundations from Isar: $e");
    }
    _tryAutoSelectFoundation();
  }

  void _tryAutoSelectFoundation() {
    if (_lastMatchedShadeName != null && _dbFoundations.isNotEmpty && _selectedFoundationProduct == null) {
      try {
        final match = _dbFoundations.firstWhere(
          (f) => f.shadeName.toLowerCase().trim() == _lastMatchedShadeName!.toLowerCase().trim()
        );
        setState(() {
          _selectedFoundationProduct = match;
          _selectedFoundationColor = _getHexColor(match.hexCode);
          if (_foundationOpacity == 0.0) _foundationOpacity = 0.35; // Default opacity when applied
          _selectedBrandFilter = match.brand;
          _applyFoundationFilter();
        });
        debugPrint("AUTO_SELECT_FOUNDATION: Auto-selected scanned shade: ${match.shadeName}");
      } catch (_) {
        try {
          final match = _dbFoundations.firstWhere(
            (f) => f.shadeName.toLowerCase().contains(_lastMatchedShadeName!.toLowerCase()) ||
                   _lastMatchedShadeName!.toLowerCase().contains(f.shadeName.toLowerCase())
          );
          setState(() {
            _selectedFoundationProduct = match;
            _selectedFoundationColor = _getHexColor(match.hexCode);
            if (_foundationOpacity == 0.0) _foundationOpacity = 0.35;
            _selectedBrandFilter = match.brand;
            _applyFoundationFilter();
          });
          debugPrint("AUTO_SELECT_FOUNDATION: Auto-selected parsed shade: ${match.shadeName}");
        } catch (_) {}
      }
    }
  }

  void _applyFoundationFilter() {
    setState(() {
      if (_selectedBrandFilter == 'Semua Merek') {
        _filteredFoundations = _dbFoundations;
      } else {
        _filteredFoundations = _dbFoundations
            .where((f) => f.brand == _selectedBrandFilter)
            .toList();
      }
    });
  }

  Future<void> _applyAiRecommendation() async {
    if (_lastMatchedUndertone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada riwayat hasil pemindaian kulit. Silakan lakukan pemindaian wajah terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      final und = _lastMatchedUndertone!.toLowerCase();
      final skin = _lastMatchedSkinTone?.toLowerCase() ?? 'light';

      // 1. Tentukan warna lipstik
      if (und == 'warm') {
        _selectedLipstickColor = const Color(0xFFFF7043); // Peach Coral
        _lipstickOpacity = 0.50;
        _lipstickFinishing = 'glossy';
      } else if (und == 'cool') {
        _selectedLipstickColor = const Color(0xFFD81B60); // Cherry Red
        _lipstickOpacity = 0.50;
        _lipstickFinishing = 'glossy';
      } else {
        _selectedLipstickColor = const Color(0xFFAD1457); // Matte Rose
        _lipstickOpacity = 0.45;
        _lipstickFinishing = 'matte';
      }

      // 2. Tentukan warna blush-on
      if (und == 'warm') {
        _selectedBlushColor = const Color(0xFFFF8A80); // Soft Coral
        _blushOpacity = 0.35;
      } else if (und == 'cool') {
        _selectedBlushColor = const Color(0xFFFF80AB); // Peach Pink
        _blushOpacity = 0.35;
      } else {
        _selectedBlushColor = const Color(0xFFFF8A80); // Soft Coral
        _blushOpacity = 0.30;
      }

      // 3. Tentukan warna foundation (Dasaran Base)
      if (skin.contains('fair')) {
        _selectedFoundationColor = const Color(0xFFF5D6C8); // Fair Nude
        _foundationOpacity = 0.35;
      } else if (skin.contains('light')) {
        _selectedFoundationColor = const Color(0xFFEED0BC); // Light Ivory
        _foundationOpacity = 0.35;
      } else if (skin.contains('medium')) {
        _selectedFoundationColor = const Color(0xFFE5C1A7); // Natural Beige
        _foundationOpacity = 0.35;
      } else {
        _selectedFoundationColor = const Color(0xFFC79D7C); // Golden Tan
        _foundationOpacity = 0.40;
      }

      // 4. Cari product foundation dari database
      ProductShade? recommendedProd;
      if (_dbFoundations.isNotEmpty) {
        final baseLab = ColorCalculator.rgbToLab(
          _selectedFoundationColor.red,
          _selectedFoundationColor.green,
          _selectedFoundationColor.blue,
        );
        double minDelta = double.infinity;
        for (final prod in _dbFoundations) {
          final double dist = ColorCalculator.deltaE00(
            baseLab,
            LabColor(prod.l, prod.a, prod.b),
          );
          if (dist < minDelta) {
            minDelta = dist;
            recommendedProd = prod;
          }
        }
      }
      _selectedFoundationProduct = recommendedProd;

      // 5. Tentukan warna eyeshadow & eyeliner
      if (und == 'warm') {
        _selectedEyeshadowColor = const Color(0xFFFFA726); // Sunset Bronze
        _eyeshadowOpacity = 0.45;
        _hasEyeliner = true;
      } else if (und == 'cool') {
        _selectedEyeshadowColor = const Color(0xFFF48FB1); // Rose Shimmer
        _eyeshadowOpacity = 0.40;
        _hasEyeliner = true;
      } else {
        _selectedEyeshadowColor = const Color(0xFFFFCC80); // Champagne Gold
        _eyeshadowOpacity = 0.35;
        _hasEyeliner = false;
      }

      // 6. Tentukan shading & highlight hidung
      if (und == 'warm') {
        _noseHighlightOpacity = 0.40;
        _noseShadingOpacity = 0.35;
      } else if (und == 'cool') {
        _noseHighlightOpacity = 0.45;
        _noseShadingOpacity = 0.30;
      } else {
        _noseHighlightOpacity = 0.35;
        _noseShadingOpacity = 0.25;
      }

      _activePreset = 'Rekomendasi AI (${_lastMatchedSeasonalColor ?? "Personal"})';
      _showGlassSkin = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rekomendasi AI dipoleskan sesuai rona ${_lastMatchedUndertone!.toUpperCase()} Anda! '),
        backgroundColor: primaryColor,
      ),
    );
  }

  Future<void> _checkPremiumStatus() async {
    final settings = await _isar.appSettings.get(0);
    if (settings != null) {
      setState(() {
        if (settings.isPremium) {
          _isPremium = true;
          _showPaywall = false;
        }
        _lastMatchedShadeName = settings.lastMatchedShadeName;
        _lastMatchedUndertone = settings.lastMatchedUndertone;
        _lastMatchedSeasonalColor = settings.lastMatchedSeasonalColor;
        _lastMatchedSkinTone = settings.lastMatchedSkinTone;
        _lastMatchedContrast = settings.lastMatchedContrast;
      });
      _tryAutoSelectFoundation();
    }
  }

  bool _isColorRecommended(String category, String colorName) {
    if (_lastMatchedUndertone == null) return false;
    final String undertone = _lastMatchedUndertone!.toLowerCase();
    final double contrast = _lastMatchedContrast ?? 35.0;
    
    final String contrastTier = contrast < 25.0 
        ? 'low' 
        : (contrast >= 48.0 ? 'high' : 'medium');

    if (category == 'lipstick') {
      if (undertone == 'warm') {
        if (colorName == 'Plum Berry' || colorName == 'Matte Rose' || colorName == 'Cherry Red') return false;
      } else if (undertone == 'cool') {
        if (colorName == 'Nude Brown' || colorName == 'Peach Coral') return false;
      }
      
      if (contrastTier == 'high') {
        return colorName == 'Classic Crimson' || colorName == 'Plum Berry' || colorName == 'Cherry Red' || colorName == 'Matte Rose';
      } else if (contrastTier == 'medium') {
        return colorName == 'Matte Rose' || colorName == 'Peach Coral' || colorName == 'Cherry Red';
      } else {
        return colorName == 'Nude Brown' || colorName == 'Peach Coral';
      }
    } else if (category == 'blush') {
      if (undertone == 'warm') {
        if (colorName == 'Peach Pink' || colorName == 'Plum Pink' || colorName == 'Dusty Rose') return false;
      } else if (undertone == 'cool') {
        if (colorName == 'Pale Tangerine' || colorName == 'Warm Amber' || colorName == 'Soft Coral') return false;
      }
      
      if (contrastTier == 'high') {
        return colorName == 'Warm Amber' || colorName == 'Dusty Rose' || colorName == 'Plum Pink';
      } else if (contrastTier == 'medium') {
        return colorName == 'Soft Coral' || colorName == 'Peach Pink' || colorName == 'Plum Pink' || colorName == 'Dusty Rose';
      } else {
        return colorName == 'Pale Tangerine' || colorName == 'Soft Coral' || colorName == 'Peach Pink';
      }
    } else if (category == 'eyeshadow') {
      if (undertone == 'warm') {
        if (colorName == 'Rose Shimmer' || colorName == 'Plum Glam' || colorName == 'Cyber Cyan') return false;
      } else if (undertone == 'cool') {
        if (colorName == 'Champagne Gold' || colorName == 'Sunset Bronze' || colorName == 'Cyber Cyan') return false;
      }
      
      if (contrastTier == 'high') {
        return colorName == 'Sunset Bronze' || colorName == 'Plum Glam' || colorName == 'Cyber Cyan';
      } else if (contrastTier == 'medium') {
        return colorName == 'Champagne Gold' || colorName == 'Rose Shimmer' || colorName == 'Taupe Nude';
      } else { // low/muted contrast
        return colorName == 'Taupe Nude' || colorName == 'Champagne Gold';
      }
    }
    return false;
  }

  void _handleCameraTap(TapDownDetails details, Size fittedSize) {
    if (_detectedFace == null || _showPaywall || _isExportingBoomerang) return;

    final double tapX = details.localPosition.dx;
    final double tapY = details.localPosition.dy;
    final tapPt = Offset(tapX, tapY);

    final bool isLandscape = fittedSize.width > fittedSize.height;
    final double scaleX = isLandscape ? fittedSize.width / _imageWidth : fittedSize.width / _imageHeight;
    final double scaleY = isLandscape ? fittedSize.height / _imageHeight : fittedSize.height / _imageWidth;

    Offset mapPointToScreen(Point<double> point) {
      final double mappedX = _cameraController!.description.lensDirection == CameraLensDirection.front
          ? fittedSize.width - (point.x * scaleX)
          : point.x * scaleX;
      final double mappedY = point.y * scaleY;
      return Offset(mappedX, mappedY);
    }

    double distance(Offset p1, Offset p2) {
      return sqrt(pow(p1.dx - p2.dx, 2) + pow(p1.dy - p2.dy, 2));
    }

    // 1. Cek Bibir
    final lipCenter = FaceGeometryHelper.getLipCenter(_detectedFace!);
    if (lipCenter != null) {
      final lipScreen = mapPointToScreen(Point(lipCenter.x.toDouble(), lipCenter.y.toDouble()));
      if (distance(tapPt, lipScreen) < fittedSize.width * 0.12) {
        setState(() {
          _activeTooltipComponent = 'bibir';
          _tooltipOffset = details.localPosition;
          _showTooltip = true;
        });
        _autoHideTooltip();
        return;
      }
    }

    // 2. Cek Pipi
    final cheeks = FaceGeometryHelper.getCheekboneCoordinates(_detectedFace!);
    final leftCheek = cheeks['left'];
    final rightCheek = cheeks['right'];
    if (leftCheek != null && rightCheek != null) {
      final leftScreen = mapPointToScreen(Point(leftCheek.x.toDouble(), leftCheek.y.toDouble()));
      final rightScreen = mapPointToScreen(Point(rightCheek.x.toDouble(), rightCheek.y.toDouble()));
      if (distance(tapPt, leftScreen) < fittedSize.width * 0.15 || distance(tapPt, rightScreen) < fittedSize.width * 0.15) {
        setState(() {
          _activeTooltipComponent = 'pipi';
          _tooltipOffset = details.localPosition;
          _showTooltip = true;
        });
        _autoHideTooltip();
        return;
      }
    }

    // 3. Cek Wajah (Base)
    final rect = _detectedFace!.boundingBox;
    final leftTop = mapPointToScreen(Point(rect.left.toDouble(), rect.top.toDouble()));
    final rightBottom = mapPointToScreen(Point(rect.right.toDouble(), rect.bottom.toDouble()));
    final double minX = min(leftTop.dx, rightBottom.dx);
    final double maxX = max(leftTop.dx, rightBottom.dx);
    final double minY = min(leftTop.dy, rightBottom.dy);
    final double maxY = max(leftTop.dy, rightBottom.dy);

    if (tapPt.dx >= minX && tapPt.dx <= maxX && tapPt.dy >= minY && tapPt.dy <= maxY) {
      setState(() {
        _activeTooltipComponent = 'base';
        _tooltipOffset = details.localPosition;
        _showTooltip = true;
      });
      _autoHideTooltip();
    }
  }

  Timer? _tooltipTimer;
  void _autoHideTooltip() {
    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showTooltip = false;
        });
      }
    });
  }

  bool _ArTryOnPageState_isLipstickMismatch() {
    if (_lastMatchedUndertone == null) return false;
    final String und = _lastMatchedUndertone!.toLowerCase();
    final int value = _selectedLipstickColor.value & 0xFFFFFF;
    bool isCool = false;
    bool isWarm = false;
    if (value == 0xD81B60 || value == 0xAD1457 || value == 0x8E24AA || value == 0xB71C1C) {
      isCool = true;
    } else if (value == 0xFFFF7043 || value == 0x8D6E63 || value == 0xF98E7B) {
      isWarm = true;
    }
    if (und == 'warm' && isCool) return true;
    if (und == 'cool' && isWarm) return true;
    return false;
  }

  bool _ArTryOnPageState_isBlushMismatch() {
    if (_lastMatchedUndertone == null) return false;
    final String und = _lastMatchedUndertone!.toLowerCase();
    final int value = _selectedBlushColor.value & 0xFFFFFF;
    bool isCool = false;
    bool isWarm = false;
    if (value == 0xFF80AB || value == 0xE91E63 || value == 0xBA68C8) {
      isCool = true;
    } else if (value == 0xFFFF8A80 || value == 0xFFB74D || value == 0xFFFF8F00) {
      isWarm = true;
    }
    if (und == 'warm' && isCool) return true;
    if (und == 'cool' && isWarm) return true;
    return false;
  }

  Widget _buildHarmonyAlertBanner() {
    final bool isLipMismatch = _ArTryOnPageState_isLipstickMismatch();
    final bool isBlushMismatch = _ArTryOnPageState_isBlushMismatch();

    if (!isLipMismatch && !isBlushMismatch) return const SizedBox.shrink();

    String warningText = '';
    if (isLipMismatch && isBlushMismatch) {
      warningText = 'Warna Lipstik & Blush kurang selaras dengan rona ${_lastMatchedUndertone!.toUpperCase()} Anda.';
    } else if (isLipMismatch) {
      warningText = 'Warna Lipstik kurang selaras dengan rona ${_lastMatchedUndertone!.toUpperCase()} Anda.';
    } else {
      warningText = 'Warna Blush kurang selaras dengan rona ${_lastMatchedUndertone!.toUpperCase()} Anda.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warningText,
              style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltipWidget() {
    String title = '';
    String info = '';
    IconData icon = Icons.info_rounded;
    Color color = primaryColor;

    if (_activeTooltipComponent == 'bibir') {
      title = 'LIPSTIK (LIPS)';
      icon = Icons.opacity_rounded;
      color = _selectedLipstickColor;
      final match = _lastMatchedUndertone == null 
          ? 'Coba Scan Kulit' 
          : (_ArTryOnPageState_isLipstickMismatch() ? 'Rona Kurang Serasi ⚠️' : 'Rona Sangat Serasi ✨');
      info = 'Pulasan: ${(_lipstickOpacity * 100).round()}% | $match';
    } else if (_activeTooltipComponent == 'pipi') {
      title = 'PIPI (BLUSH)';
      icon = Icons.face_rounded;
      color = _selectedBlushColor;
      final match = _lastMatchedUndertone == null 
          ? 'Coba Scan Kulit' 
          : (_ArTryOnPageState_isBlushMismatch() ? 'Rona Kurang Serasi ⚠️' : 'Rona Sangat Serasi ✨');
      info = 'Pulasan: ${(_blushOpacity * 100).round()}% | $match';
    } else {
      title = 'BASE (FOUNDATION)';
      icon = Icons.face_retouching_natural_rounded;
      color = _selectedFoundationColor;
      final shadeInfo = _selectedFoundationProduct != null 
          ? '${_selectedFoundationProduct!.brand} - ${_selectedFoundationProduct!.shadeName}'
          : 'Warna Kustom';
      info = 'Shade: $shadeInfo\nOpasitas: ${(_foundationOpacity * 100).round()}%';
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBgColor.withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorderColor.withOpacity(0.7), width: 1.5),
          boxShadow: ThemeManager.premiumGlowShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 9, 
                    fontWeight: FontWeight.bold, 
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              info,
              style: TextStyle(fontSize: 8, color: textMutedColor),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleLipstickColor() {
    int currentIndex = _lipstickColors.indexWhere((c) => c['color'] == _selectedLipstickColor);
    int nextIndex = (currentIndex + 1) % _lipstickColors.length;
    setState(() {
      _selectedLipstickColor = _lipstickColors[nextIndex]['color'] as Color;
      _activePreset = null;
    });
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kedipan terdeteksi! Mengganti warna lipstik ke: ${_lipstickColors[nextIndex]['name']} 💄'),
        duration: const Duration(milliseconds: 1500),
        backgroundColor: primaryColor,
      ),
    );
  }

  void _toggleLipstickFinishing() {
    setState(() {
      _lipstickFinishing = _lipstickFinishing == 'glossy' ? 'matte' : 'glossy';
      _activePreset = null;
    });
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kedipan terdeteksi! Mengubah tekstur lipstik ke: ${_lipstickFinishing.toUpperCase()} ✨'),
        duration: const Duration(milliseconds: 1500),
        backgroundColor: primaryColor,
      ),
    );
  }

  Map<String, dynamic> _getLookSummaryDetails() {
    ProductShade? activeFoundationProd = _selectedFoundationProduct;
    if (activeFoundationProd == null && _dbFoundations.isNotEmpty) {
      final baseLab = ColorCalculator.rgbToLab(
        _selectedFoundationColor.red,
        _selectedFoundationColor.green,
        _selectedFoundationColor.blue,
      );
      
      double minDelta = double.infinity;
      ProductShade? closestProd;
      for (final prod in _dbFoundations) {
        final double dist = ColorCalculator.deltaE00(
          baseLab,
          LabColor(prod.l, prod.a, prod.b),
        );
        if (dist < minDelta) {
          minDelta = dist;
          closestProd = prod;
        }
      }
      activeFoundationProd = closestProd;
    }

    final String baseName = activeFoundationProd != null
        ? '${activeFoundationProd.brand} - ${activeFoundationProd.productName} (${activeFoundationProd.shadeName})'
        : 'Warna Preset Dasar';
    final String baseAffiliate = activeFoundationProd?.affiliateUrl ?? 'https://shopee.co.id';

    String lipstickProd = 'Tidak Terdeteksi';
    String lipstickUrl = 'https://shopee.co.id';
    
    final lColor = _selectedLipstickColor.value;
    if (lColor == const Color(0xFFD81B60).value) {
      lipstickProd = 'Wardah Everyday Matte Lip Shot - 05 Classic Red & Maybelline Superstay Matte Ink - 20 Pioneer';
      lipstickUrl = 'https://shopee.co.id/wardahofficial';
    } else if (lColor == const Color(0xFFAD1457).value) {
      lipstickProd = 'Wardah Colorfit Last All Day Lip Paint - 02 Dear Jenny & Make Over Intense Matte Lip Cream - 004 Vanity';
      lipstickUrl = 'https://shopee.co.id/makeoverofficial';
    } else if (lColor == const Color(0xFFFF7043).value) {
      lipstickProd = 'Maybelline Sensational Liquid Matte - 06 Best Babe & Wardah Exclusive Matte Lip Cream - 18 Peach Perfect';
      lipstickUrl = 'https://shopee.co.id/maybellineindonesia';
    } else if (lColor == const Color(0xFF8E24AA).value) {
      lipstickProd = 'Make Over Intense Matte Lip Cream - 012 Vampy & Maybelline Superstay Matte Ink - 40 Believer';
      lipstickUrl = 'https://shopee.co.id/makeoverofficial';
    } else if (lColor == const Color(0xFF8D6E63).value) {
      lipstickProd = 'Wardah Exclusive Matte Lip Cream - 11 Oh so Nude & Make Over Intense Matte Lip Cream - 011 Pomposity';
      lipstickUrl = 'https://shopee.co.id/wardahofficial';
    } else if (lColor == const Color(0xFFB71C1C).value) {
      lipstickProd = 'Maybelline Superstay Matte Ink - 118 Dancer & Wardah Colorfit Velvet Matte Lip Crayon - 05 Skylines';
      lipstickUrl = 'https://shopee.co.id/maybellineindonesia';
    } else {
      lipstickProd = 'Wardah Colorfit Last All Day Lip Paint';
      lipstickUrl = 'https://shopee.co.id/wardahofficial';
    }

    String blushProd = 'Tidak Terdeteksi';
    String blushUrl = 'https://shopee.co.id';
    
    final bColor = _selectedBlushColor.value;
    if (bColor == const Color(0xFFFF8A80).value) {
      blushProd = 'Wardah Colorfit Cream Blush - 01 Sand Coral & Make Over Multifix Matte Blusher - 02 Coral Flutter';
      blushUrl = 'https://shopee.co.id/wardahofficial';
    } else if (bColor == const Color(0xFFFF80AB).value) {
      blushProd = 'Wardah Exclusive Blush On - 01 Rosy Pink & Maybelline Fit Me Blush - 30 Peach';
      blushUrl = 'https://shopee.co.id/wardahofficial';
    } else if (bColor == const Color(0xFFE91E63).value) {
      blushProd = 'Make Over Cheek Marquee Blush On - 04 Tupper Rose & Wardah Colorfit Cream Blush - 02 Merry Mauve';
      blushUrl = 'https://shopee.co.id/makeoverofficial';
    } else if (bColor == const Color(0xFFFFB74D).value) {
      blushProd = 'Wardah Exclusive Blush On - 02 Peach & Make Over Cheek Marquee Blush On - 02 Shimmering Peach';
      blushUrl = 'https://shopee.co.id/wardahofficial';
    } else if (bColor == const Color(0xFFFF8F00).value) {
      blushProd = 'Make Over Cheek Marquee Blush On - 08 Honey Spice & Maybelline Fit Me Blush - 40 Golden';
      blushUrl = 'https://shopee.co.id/makeoverofficial';
    } else if (bColor == const Color(0xFFBA68C8).value) {
      blushProd = 'Wardah Exclusive Blush On - 02 Rose Pink & Make Over Cheek Marquee Blush On - 05 Burgundy';
      blushUrl = 'https://shopee.co.id/makeoverofficial';
    } else {
      blushProd = 'Wardah Colorfit Cream Blush';
      blushUrl = 'https://shopee.co.id/wardahofficial';
    }

    return {
      'baseName': baseName,
      'baseAffiliate': baseAffiliate,
      'lipstickProd': lipstickProd,
      'lipstickUrl': lipstickUrl,
      'blushProd': blushProd,
      'blushUrl': blushUrl,
    };
  }

  void _showLookSummarySheet() {
    if (!_isPremium && !_showPaywall) {
      setState(() {
        _showPaywall = true;
      });
      return;
    }

    final summary = _getLookSummaryDetails();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: cardBgColor.withOpacity(0.97),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(color: cardBorderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child:  Icon(Icons.receipt_long_rounded, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                   Text(
                    'Rangkuman Riasan & Belanja',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Dasaran Base (Foundation)
              _buildSummaryItem(
                title: 'Dasaran Base (Foundation)',
                name: _foundationOpacity > 0.0 ? summary['baseName'] : 'Tidak digunakan',
                color: _foundationOpacity > 0.0 ? _selectedFoundationColor : null,
                subtitle: _foundationOpacity > 0.0 ? 'Opasitas: ${(_foundationOpacity * 100).round()}%' : null,
                affiliateUrl: _foundationOpacity > 0.0 ? summary['baseAffiliate'] : null,
              ),

              const SizedBox(height: 16),
              
              // 2. Lipstik (Lips)
              _buildSummaryItem(
                title: 'Riasan Bibir (Lipstick)',
                name: _lipstickOpacity > 0.0 ? 'Preset Warna (${_lipstickFinishing.toUpperCase()})' : 'Tidak digunakan',
                color: _lipstickOpacity > 0.0 ? _selectedLipstickColor : null,
                subtitle: _lipstickOpacity > 0.0 
                    ? 'Rekomendasi Produk:\n${summary['lipstickProd']}' 
                    : null,
                affiliateUrl: _lipstickOpacity > 0.0 ? summary['lipstickUrl'] : null,
              ),

              const SizedBox(height: 16),

              // 3. Rona Pipi (Blush-On)
              _buildSummaryItem(
                title: 'Rona Pipi (Blush-On)',
                name: _blushOpacity > 0.0 ? 'Preset Warna' : 'Tidak digunakan',
                color: _blushOpacity > 0.0 ? _selectedBlushColor : null,
                subtitle: _blushOpacity > 0.0 
                    ? 'Rekomendasi Produk:\n${summary['blushProd']}' 
                    : null,
                affiliateUrl: _blushOpacity > 0.0 ? summary['blushUrl'] : null,
              ),

              const SizedBox(height: 28),

              // Close Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup Rangkuman', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required String name,
    Color? color,
    String? subtitle,
    String? affiliateUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (color != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorderColor, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    color: textMutedColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: textMutedColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (affiliateUrl != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.shopping_bag_outlined, color: primaryColor, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: affiliateUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Tautan belanja Shopee berhasil disalin! 🛍️'),
                    backgroundColor: primaryColor,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _shareCurrentMakeupLook() async {
    if (!_isPremium && !_showPaywall) {
      setState(() {
        _showPaywall = true;
      });
      return;
    }

    setState(() {
      _isSavingLook = true;
      _isCapturing = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 120));

      final RenderRepaintBoundary? boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Gagal mendapatkan rendering area wajah.");
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception("Gagal mengodekan gambar.");
      }

      const platform = MethodChannel("com.fizardstudio.glowmatch/widget");
      final bool success = await platform.invokeMethod<bool>("shareImage", {
        "bytes": pngBytes,
        "filename": "glowmatch_riasan_${DateTime.now().millisecondsSinceEpoch}",
      }) ?? false;

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: const Text('Foto hasil riasan berhasil dibagikan! 📸🌟'),
              backgroundColor: primaryColor,
            ),
          );
        } else {
          throw Exception("Gagal membagikan foto.");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLook = false;
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _saveCurrentMakeupLook() async {
    if (!_isPremium && !_showPaywall) {
      setState(() {
        _showPaywall = true;
      });
      return;
    }

    setState(() {
      _isSavingLook = true;
      _isCapturing = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final RenderRepaintBoundary? boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Gagal mendapatkan rendering area wajah.");
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception("Gagal mengodekan gambar hasil riasan.");
      }

      if (!Platform.isAndroid) {
        throw Exception("Penyimpanan galeri luring saat ini hanya didukung di Android.");
      }

      const platform = MethodChannel("com.fizardstudio.glowmatch/widget");
      final bool success = await platform.invokeMethod<bool>("saveImageToGallery", {
        "bytes": pngBytes,
        "filename": "glowmatch_ar_look_${DateTime.now().millisecondsSinceEpoch}",
      }) ?? false;

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: const Text('Foto hasil riasan kamera berhasil disimpan ke Galeri! 📸💖 (Folder: Pictures/GlowMatch)'),
              backgroundColor: primaryColor,
            ),
          );
        } else {
          throw Exception("Gagal menyimpan foto.");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan ke galeri: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLook = false;
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _exportBoomerangGif() async {
    if (_detectedFace == null || _showPaywall || _isExportingBoomerang) return;

    setState(() {
      _isExportingBoomerang = true;
      _exportProgress = 0.0;
      _isCapturing = true; // Sembunyikan garis slider saat pemotretan
    });

    final List<Uint8List> frames = [];
    final double originalSliderX = _sliderX;
    final bool originalSplitMode = _isSplitMode;

    try {
      setState(() {
        _isSplitMode = true;
      });

      final RenderRepaintBoundary? boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Gagal menginisialisasi area dandan.");
      }

      final double width = boundary.size.width;

      // Ambil 6 frame bertahap dari kiri ke kanan (0% hingga 100%)
      final List<double> steps = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
      for (int i = 0; i < steps.length; i++) {
        setState(() {
          _sliderX = steps[i] * width;
          _isCapturing = false;
        });

        await Future.delayed(const Duration(milliseconds: 150));

        final ui.Image uiImage = await boundary.toImage(pixelRatio: 1.2);
        final ByteData? byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          frames.add(byteData.buffer.asUint8List());
        }

        setState(() {
          _exportProgress = (i + 1) / steps.length * 0.45;
        });
      }

      setState(() {
        _isCapturing = true;
      });

      final int w = boundary.size.width.toInt();
      final int h = boundary.size.height.toInt();
      final int frameW = (w * 1.2).toInt();
      final int frameH = (h * 1.2).toInt();

      await Future.delayed(const Duration(milliseconds: 50));

      final img.Image gifAnim = img.Image(width: frameW, height: frameH, numChannels: 4);
      gifAnim.frameDuration = 150;

      for (int fIndex = 0; fIndex < frames.length; fIndex++) {
        final img.Image frameImg = img.Image.fromBytes(
          width: frameW,
          height: frameH,
          bytes: frames[fIndex].buffer,
          numChannels: 4,
        );
        frameImg.frameDuration = 150;
        if (fIndex == 0) {
          gifAnim.frames[0] = frameImg;
        } else {
          gifAnim.addFrame(frameImg);
        }
        
        setState(() {
          _exportProgress = 0.45 + ((fIndex + 1) / frames.length * 0.45);
        });
      }

      for (int fIndex = frames.length - 2; fIndex > 0; fIndex--) {
        final img.Image frameImg = img.Image.fromBytes(
          width: frameW,
          height: frameH,
          bytes: frames[fIndex].buffer,
          numChannels: 4,
        );
        frameImg.frameDuration = 150;
        gifAnim.addFrame(frameImg);
      }

      final gifEncoder = img.GifEncoder();
      final List<int> gifBytes = gifEncoder.encode(gifAnim);

      setState(() {
        _exportProgress = 0.95;
      });

      const platform = MethodChannel("com.fizardstudio.glowmatch/widget");
      final bool success = await platform.invokeMethod<bool>("shareImage", {
        "bytes": Uint8List.fromList(gifBytes),
        "filename": "glowmatch_ar_boomerang_${DateTime.now().millisecondsSinceEpoch}",
      }) ?? false;

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Animasi Boomerang Kamera berhasil dibagikan! 🎬🌟'),
              backgroundColor: primaryColor,
            ),
          );
        } else {
          throw Exception("Gagal membagikan animasi.");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat Boomerang: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _sliderX = originalSliderX;
        _isSplitMode = originalSplitMode;
        _isCapturing = false;
        _isExportingBoomerang = false;
      });
    }
  }

  Widget _buildFinishingButton(String label, bool isSel) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _lipstickFinishing = label.toLowerCase();
          _activePreset = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSel ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFoundationFinishingButton(String label, bool isSel) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _foundationFinishing = label.toLowerCase();
          _showGlassSkin = label.toLowerCase() != 'matte';
          _activePreset = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSel ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Icon(Icons.opacity_rounded, color: primaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: textColor, fontSize: 11),
        ),
        Expanded(
          child: Slider(
            activeColor: primaryColor,
            inactiveColor: cardBorderColor,
            value: value,
            min: 0.0,
            max: 0.8,
            onChanged: _showPaywall ? null : onChanged,
          ),
        ),
        Text(
          '${(value * 100).round()}%',
          style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildColorCircle(Color color, String name, bool isSelected, VoidCallback onTap, {bool isRecommended = false}) {
    final bool isClear = color == Colors.transparent || color.opacity == 0.0;
    final bool isMatched = _lastMatchedShadeName != null && 
        (name.toLowerCase().trim() == _lastMatchedShadeName!.toLowerCase().trim() ||
         name.toLowerCase().contains(_lastMatchedShadeName!.toLowerCase()) ||
         _lastMatchedShadeName!.toLowerCase().contains(name.toLowerCase()));

    final bool showBadge = (isMatched || isRecommended) && !isClear;

    Widget circle = Container(
      margin: const EdgeInsets.only(right: 14),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isClear ? Colors.grey[800]!.withOpacity(0.4) : color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? primaryColor : cardBorderColor.withOpacity(0.55),
          width: isSelected ? 3 : 1,
        ),
      ),
      child: isClear
          ? Center(
              child: Icon(
                Icons.block_flipped,
                color: isSelected ? primaryColor : textMutedColor,
                size: 18,
              ),
            )
          : (isSelected
              ? const Center(child: Icon(Icons.check_rounded, color: Colors.white, size: 18))
              : null),
    );

    if (showBadge) {
      return GestureDetector(
        onTap: _showPaywall ? null : onTap,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            circle,
            Positioned(
              top: -3,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '✨',
                  style: TextStyle(fontSize: 8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showPaywall ? null : onTap,
      child: circle,
    );
  }

  Future<void> _activatePremium() async {
    final settings = AppSettings()
      ..id = 0
      ..isPremium = true;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    _stopDemoTimer();

    setState(() {
      _isPremium = true;
      _showPaywall = false;
      _isDemoActive = false;
    });

    // Update native widget data
    WidgetHelper.updateExpiryWidget();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selamat! Fitur Premium Berhasil Diaktifkan secara Permanen.'),
        backgroundColor: Color(0xFFE5C185),
      ),
    );
  }

  void _startDemoMode() {
    setState(() {
      _showPaywall = false;
      _isDemoActive = true;
      _demoSecondsLeft = 60;
    });

    _demoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_demoSecondsLeft > 0) {
          _demoSecondsLeft--;
        } else {
          _stopDemoTimer();
          _showPaywall = true;
          _isDemoActive = false;
          _detectedFace = null;
        }
      });
    });
  }

  void _stopDemoTimer() {
    _demoTimer?.cancel();
    _demoTimer = null;
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final targetCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == _cameraLensDirection,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      // Mulai streaming frame kamera untuk Face Mesh Detector dengan Throttling ke ~15 FPS (65ms)
      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessingFrame) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastFrameTimeMs < 65) return;
        _lastFrameTimeMs = now;
        _isProcessingFrame = true;
        _processFrame(image);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat kamera ${_cameraLensDirection == CameraLensDirection.front ? "depan" : "belakang"}.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _toggleCameraDirection() async {
    if (_cameraController == null) return;
    
    // Matikan streaming dan bersihkan controller yang sekarang
    try {
      await _cameraController!.stopImageStream();
    } catch (e) {
      debugPrint("Error stopping image stream: $e");
    }
    await _cameraController!.dispose();
    _cameraController = null;
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
        _activeRotation = null; // Reset kalibrasi rotasi agar dikalibrasi ulang untuk kamera baru!
        _cameraLensDirection = _cameraLensDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;
      });
    }
    
    await _initializeCamera();
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _cameraController == null || !_isCameraInitialized) return;

    if (_detectedFace == null) {
      if (_smoothedFace != null) {
        setState(() {
          _smoothedFace = null;
          _smoothedBox = null;
          _smoothedContours.clear();
          _smoothedSmiling = null;
        });
      }
      return;
    }

    final double lerpFactor = 0.35; // Buttery smooth response factor

    // 1. Lerp bounding box
    final targetBox = _detectedFace!.boundingBox;
    _smoothedBox = _smoothedBox == null
        ? targetBox
        : Rect.fromLTRB(
            ui.lerpDouble(_smoothedBox!.left, targetBox.left, lerpFactor)!,
            ui.lerpDouble(_smoothedBox!.top, targetBox.top, lerpFactor)!,
            ui.lerpDouble(_smoothedBox!.right, targetBox.right, lerpFactor)!,
            ui.lerpDouble(_smoothedBox!.bottom, targetBox.bottom, lerpFactor)!,
          );

    // 2. Lerp contours
    final Map<FaceContourType, FaceContour?> newContours = {};
    for (final type in FaceContourType.values) {
      final targetContour = _detectedFace!.contours[type];
      if (targetContour == null) continue;

      final targetPoints = targetContour.points;
      List<Point<int>> currentPoints = _smoothedContours[type] ?? [];

      if (currentPoints.length != targetPoints.length) {
        currentPoints = List<Point<int>>.from(targetPoints);
      } else {
        for (int i = 0; i < targetPoints.length; i++) {
          final double newX = ui.lerpDouble(currentPoints[i].x.toDouble(), targetPoints[i].x.toDouble(), lerpFactor)!;
          final double newY = ui.lerpDouble(currentPoints[i].y.toDouble(), targetPoints[i].y.toDouble(), lerpFactor)!;
          currentPoints[i] = Point<int>(newX.round(), newY.round());
        }
      }
      _smoothedContours[type] = currentPoints;
      newContours[type] = SmoothedFaceContour(type: type, points: currentPoints);
    }

    // 3. Lerp smiling probability
    final targetSmiling = _detectedFace!.smilingProbability;
    if (targetSmiling != null) {
      _smoothedSmiling = ui.lerpDouble(_smoothedSmiling ?? targetSmiling, targetSmiling, lerpFactor);
    }

    // 4. Construct SmoothedFace
    final newSmoothedFace = SmoothedFace(
      boundingBox: _smoothedBox!,
      contours: newContours,
      smilingProbability: _smoothedSmiling,
      leftEyeOpenProbability: _detectedFace!.leftEyeOpenProbability,
      rightEyeOpenProbability: _detectedFace!.rightEyeOpenProbability,
      headEulerAngleX: _detectedFace!.headEulerAngleX,
      headEulerAngleY: _detectedFace!.headEulerAngleY,
      headEulerAngleZ: _detectedFace!.headEulerAngleZ,
    );

    setState(() {
      _smoothedFace = newSmoothedFace;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    // Jika paywall sedang tampil (bukan premium dan tidak sedang demo), skip pemrosesan ML
    if (_showPaywall) {
      _isProcessingFrame = false;
      return;
    }

    try {
      final camera = _cameraController?.description;
      if (camera == null) {
        _isProcessingFrame = false;
        return;
      }

      // Kalibrasi otomatis sekali saja untuk menemukan rotasi sensor yang benar untuk wajah tegak
      if (_activeRotation == null) {
        final format = InputImageFormatValue.fromRawValue(image.format.raw);
        if (format != null && image.planes.isNotEmpty) {
          final bytes = image.planes.length > 1 ? _combineYuvPlanes(image) : image.planes.first.bytes;
          final rotationsToTry = [
            InputImageRotation.rotation270deg,
            InputImageRotation.rotation90deg,
            InputImageRotation.rotation0deg,
            InputImageRotation.rotation180deg,
          ];
          
          for (final rot in rotationsToTry) {
            final testImage = InputImage.fromBytes(
              bytes: bytes,
              metadata: InputImageMetadata(
                size: Size(image.width.toDouble(), image.height.toDouble()),
                rotation: rot,
                format: image.planes.length > 1 ? InputImageFormat.nv21 : format,
                bytesPerRow: image.planes.first.bytesPerRow,
              ),
            );
            
            final testFaces = await _faceDetector.processImage(testImage);
            if (testFaces.isNotEmpty) {
              debugPrint("DEBUG_AR: Auto-calibration SUCCESS! Face detected at rotation: ${rot.rawValue}");
              _activeRotation = rot; // Kunci rotasi ini!
              break;
            }
          }
        }
      }

      final currentRotation = _activeRotation ?? _getRotationFromSensor(camera.sensorOrientation);

      final inputImage = _inputImageFromCameraImage(image, currentRotation);
      if (inputImage == null) {
        debugPrint("DEBUG_AR: inputImage conversion failed");
        _isProcessingFrame = false;
        return;
      }

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          if (faces.isNotEmpty) {
            _detectedFace = faces.first;
            _imageWidth = image.width;
            _imageHeight = image.height;
            _faceLostFrames = 0; // Reset counter saat wajah terdeteksi
          } else {
            _faceLostFrames++;
            // Hanya sembunyikan make-up jika wajah benar-benar hilang lebih dari 8 frame (~130ms)
            // Ini mencegah efek kedip-kedip (flickering/blink-blink) pada filter kosmetik.
            if (_faceLostFrames >= 8) {
              _detectedFace = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("DEBUG_AR: Exception in processImage: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImageRotation _getRotationFromSensor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation270deg;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, InputImageRotation rotation) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.bgra8888;

    if (image.planes.isEmpty) return null;

    Uint8List bytes;
    if (image.planes.length > 1) {
      bytes = _combineYuvPlanes(image);
    } else {
      bytes = image.planes.first.bytes;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: image.planes.length > 1 ? InputImageFormat.nv21 : format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _combineYuvPlanes(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  @override
  void dispose() {
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _stopDemoTimer();
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } catch (_) {}
      try {
        _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Lepas kamera secara sinkron via setState agar widget CameraPreview langsung dicopot dari widget tree
      if (mounted) {
        setState(() {
          _isCameraDisposed = true;
          _isCameraInitialized = false;
        });
      }
      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isStreamingImages) {
            _cameraController!.stopImageStream();
          }
        } catch (_) {}
        try {
          _cameraController!.dispose();
        } catch (_) {}
        _cameraController = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Inisialisasi ulang kamera saat kembali ke foreground
      if (mounted) {
        setState(() {
          _isCameraDisposed = false;
        });
      }
      if (!_showPaywall) {
        _initializeCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        setState(() {
          _isCameraDisposed = true;
        });
        if (_cameraController != null) {
          try {
            if (_cameraController!.value.isStreamingImages) {
              await _cameraController!.stopImageStream();
            }
            await _cameraController!.dispose();
          } catch (e) {
            debugPrint("Error stopping camera: $e");
          }
        }
        setState(() {
          _canPop = true;
        });
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
      backgroundColor: cardBgColor,
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
             Text(
              'AR Try-On',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            _isPremium
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PREMIUM',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: textMutedColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child:  Text(
                      'FREE',
                      style: TextStyle(color: textMutedColor, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
        backgroundColor: cardBgColor,
        elevation: 0,
        iconTheme:  IconThemeData(color: textColor),
        actions: [
          if (!_showPaywall) ...[
            IconButton(
              icon: Icon(Icons.camera_alt_rounded, color: textColor),
              tooltip: 'Simpan Foto ke Galeri',
              onPressed: _saveCurrentMakeupLook,
            ),
            IconButton(
              icon: Icon(Icons.share_rounded, color: textColor),
              tooltip: 'Bagikan Riasan',
              onPressed: _shareCurrentMakeupLook,
            ),
            IconButton(
              icon: Icon(Icons.videocam_rounded, color: textColor),
              tooltip: 'Buat & Bagikan Boomerang',
              onPressed: _exportBoomerangGif,
            ),
            IconButton(
              icon: Icon(
                _isSplitMode ? Icons.splitscreen_rounded : Icons.crop_free_rounded,
                color: _isSplitMode ? primaryColor : textColor,
              ),
              tooltip: _isSplitMode ? 'Sembunyikan Pembanding' : 'Tampilkan Pembanding',
              onPressed: () {
                setState(() {
                  _isSplitMode = !_isSplitMode;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.flip_camera_ios_rounded, color: textColor),
              tooltip: 'Ganti Kamera',
              onPressed: _toggleCameraDirection,
            ),
          ],
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Wilayah Kamera Preview (Full Screen)
          Positioned.fill(
            child: _isCameraInitialized && _cameraController != null && !_isCameraDisposed
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final double cameraAreaWidth = constraints.maxWidth;
                      final double cameraAreaHeight = constraints.maxHeight;

                      final double rawAspectRatio = _cameraController!.value.aspectRatio; // landscape (e.g. 1.333)
                      final double previewWidth = cameraAreaWidth;
                      final double previewHeight = cameraAreaWidth * rawAspectRatio;

                      // Hitung faktor skala dari BoxFit.cover
                      final double scaleFactor = max(cameraAreaWidth / previewWidth, cameraAreaHeight / previewHeight);

                      // Inisialisasi sliderX ke tengah lebar area jika belum di-set
                      if (!_isSliderInitialized) {
                        _sliderX = cameraAreaWidth / 2;
                        _isSliderInitialized = true;
                      }

                      // Hitung sliderX untuk painter di dalam FittedBox agar posisinya sinkron dengan garis pembagi di layar
                      final double painterSliderX = _isSplitMode 
                          ? (( _sliderX - cameraAreaWidth / 2 ) / scaleFactor + previewWidth / 2)
                          : 0.0;

                      return RepaintBoundary(
                        key: _repaintBoundaryKey,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Camera & Overlays (FittedBox cover)
                              Positioned.fill(
                                child: ClipRect(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: previewWidth,
                                      height: previewHeight,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CameraPreview(_cameraController!),

                                      // Layer Rendering Lipstik & Blush-On CustomPaint
                                      if (!_showPaywall)
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: LipFilterPainter(
                                              face: _smoothedFace,
                                              imageWidth: _imageWidth,
                                              imageHeight: _imageHeight,
                                              lensDirection: _cameraController!.description.lensDirection,
                                              lipstickColor: _selectedLipstickColor,
                                              lipstickOpacity: _lipstickOpacity,
                                              lipstickFinishing: _lipstickFinishing,
                                              blushColor: _selectedBlushColor,
                                              blushOpacity: _detectedFace?.smilingProbability != null
                                                  ? (_blushOpacity * (1.0 + _detectedFace!.smilingProbability! * 0.45)).clamp(0.0, 1.0)
                                                  : _blushOpacity,
                                              foundationColor: _selectedFoundationColor,
                                              foundationOpacity: _foundationOpacity,
                                              showGlassSkin: _showGlassSkin,
                                              foundationFinishing: _foundationFinishing,
                                              sliderX: painterSliderX,
                                              selectedLightingPreset: _selectedLightingPreset,
                                              showHarmonyHeatmap: _showHarmonyHeatmap,
                                              undertone: _lastMatchedUndertone,
                                              eyeshadowColor: _selectedEyeshadowColor,
                                              eyeshadowOpacity: _eyeshadowOpacity,
                                              hasEyeliner: _hasEyeliner,
                                              eyelinerThickness: _eyelinerThickness,
                                              noseHighlightOpacity: _noseHighlightOpacity,
                                              noseShadingOpacity: _noseShadingOpacity,
                                            ),
                                          ),
                                        ),
                                      if (_isCapturing)
                                        Positioned(
                                          bottom: 20,
                                          right: 20,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 12),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'GlowMatch AI - Temukan Shade Wajahmu!',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Handle Slider Pembagi Layar Vertikal yang Bisa Digeser
                          if (!_showPaywall && _isSplitMode)
                            Positioned(
                              left: _sliderX - 25,
                              top: 0,
                              bottom: 0,
                              width: 50,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onPanUpdate: (details) {
                                  setState(() {
                                    _sliderX = (_sliderX + details.delta.dx)
                                        .clamp(0.0, cameraAreaWidth);
                                  });
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 2.0,
                                      color: const Color(0xFFE5C185),
                                    ),
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: const RotatedBox(
                                        quarterTurns: 1,
                                        child: Icon(
                                          Icons.unfold_more_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Watermark & Countdown untuk Mode Uji Coba Demo
                          if (_isDemoActive && !_showPaywall)
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          'Mode Demo',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: cardBgColor.withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: primaryColor.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      'Sisa Waktu: ${_demoSecondsLeft}s',
                                      style:  TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Live Face Shape Badge
                          if (!_showPaywall && _detectedFace != null)
                            Positioned(
                              top: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cardBgColor.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
                                    boxShadow: ThemeManager.premiumGlowShadow,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        FaceGeometryHelper.classifyFaceShape(_detectedFace!) == 'round'
                                            ? Icons.blur_circular_rounded
                                            : FaceGeometryHelper.classifyFaceShape(_detectedFace!) == 'long'
                                                ? Icons.crop_portrait_rounded
                                                : FaceGeometryHelper.classifyFaceShape(_detectedFace!) == 'square'
                                                    ? Icons.crop_square_rounded
                                                    : FaceGeometryHelper.classifyFaceShape(_detectedFace!) == 'heart'
                                                        ? Icons.favorite_rounded
                                                        : Icons.face_rounded,
                                        color: primaryColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Wajah: ${FaceGeometryHelper.classifyFaceShape(_detectedFace!).toUpperCase()}',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Overlay Dialog Paywall Premium Glassmorphism
                          if (_showPaywall)
                            Positioned.fill(
                              child: Container(
                                color: cardBgColor.withOpacity(0.95),
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 24),
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(color: cardBorderColor, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(0.05),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child:  Icon(
                                              Icons.workspace_premium_rounded,
                                              color: primaryColor,
                                              size: 40,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                           Text(
                                            'GlowMatch Premium',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                           Text(
                                            'Uji Coba Filter Make-Up AR Real-Time',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textMutedColor,
                                            ),
                                          ),
                                          const SizedBox(height: 24),

                                          // Checklist Keuntungan
                                          _buildPaywallFeature('Pelacakan 3D Face Mesh Presisi'),
                                          _buildPaywallFeature('Pelacakan Pipi Blush-On Alami'),
                                          _buildPaywallFeature('Perbandingan Split-Screen Dinamis'),
                                          _buildPaywallFeature('Pilihan Warna Premium Lengkap'),
                                          _buildPaywallFeature('Bebas Watermark & Bebas Batasan Waktu'),
                                          
                                          const SizedBox(height: 28),

                                          // Tombol Beli Premium
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(double.infinity, 48),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              elevation: 0,
                                            ),
                                            onPressed: _activatePremium,
                                            child: const Text(
                                              'Aktifkan Premium — Rp 29.000',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Tombol Coba Demo Gratis
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: textColor,
                                              side:  BorderSide(color: cardBorderColor),
                                              minimumSize: const Size(double.infinity, 46),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: _startDemoMode,
                                            child: const Text(
                                              'Coba Uji Coba Gratis (1 Menit)',
                                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Tombol Batal / Keluar
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child:  Text(
                                              'Kembali',
                                              style: TextStyle(color: textMutedColor, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ],
                          ),
                        );
                    },
                  )
                :  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
          ),

          // 2. Tombol Show/Hide Floating Panel
          if (_isCameraInitialized && _cameraController != null && !_showPaywall)
            Positioned(
              bottom: _showControls ? 300 : 24,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'toggle_controls_fab',
                onPressed: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                backgroundColor: cardBgColor.withOpacity(0.95),
                mini: true,
                shape: CircleBorder(
                  side: BorderSide(
                    color: primaryColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _showControls ? Icons.keyboard_arrow_down_rounded : Icons.palette_outlined,
                  color: textColor,
                  size: 20,
                ),
              ),
            ),

          // 3. Wilayah Kontrol Filter Bawah (Floats at bottom with premium card styling)
          if (_showControls && _isCameraInitialized && _cameraController != null && !_showPaywall)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardBgColor.withOpacity(0.95),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: cardBorderColor,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Selector Tab Kategori (Looks vs Dasaran Base vs Lipstik vs Blush-On)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeCategoryIndex = 0),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeCategoryIndex == 0 ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'LOOKS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _activeCategoryIndex == 0 ? Colors.white : textMutedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeCategoryIndex = 1),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeCategoryIndex == 1 ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'BASE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _activeCategoryIndex == 1 ? Colors.white : textMutedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeCategoryIndex = 2),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeCategoryIndex == 2 ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'BIBIR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _activeCategoryIndex == 2 ? Colors.white : textMutedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeCategoryIndex = 3),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeCategoryIndex == 3 ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'PIPI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _activeCategoryIndex == 3 ? Colors.white : textMutedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeCategoryIndex = 4),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeCategoryIndex == 4 ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'HIDUNG',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _activeCategoryIndex == 4 ? Colors.white : textMutedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeCategoryIndex = 5),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeCategoryIndex == 5 ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'MATA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _activeCategoryIndex == 5 ? Colors.white : textMutedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sliders & Toggles khusus Tab Aktif
                    if (_activeCategoryIndex == 0) ...[
                      // Pilihan Preset Looks & AI Recommendation
                      Text(
                        'PILIH PRESET LOOKS:',
                        style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: MakeupPreset.presets.length + (_lastMatchedUndertone != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_lastMatchedUndertone != null && index == 0) {
                              final isSelected = _activePreset?.startsWith('Rekomendasi AI') ?? false;
                              return GestureDetector(
                                onTap: _showPaywall ? null : _applyAiRecommendation,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFBF953F),
                                        Color(0xFFFCF6BA),
                                        Color(0xFFB38728),
                                        Color(0xFFFBF5B7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: ThemeManager.premiumGlowShadow,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Rekomendasi AI',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final presetList = MakeupPreset.presets;
                            final presetIndex = _lastMatchedUndertone != null ? index - 1 : index;
                            final preset = presetList[presetIndex];
                            final String name = preset.name;
                            final isSelected = _activePreset == name;

                            return GestureDetector(
                              onTap: _showPaywall
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedLipstickColor = preset.lipstickColor;
                                        _lipstickOpacity = preset.lipstickOpacity;
                                        _lipstickFinishing = preset.lipstickFinishing;
                                        _selectedBlushColor = preset.blushColor;
                                        _blushOpacity = preset.blushOpacity;
                                        _selectedFoundationColor = preset.foundationColor;
                                        _foundationOpacity = preset.foundationOpacity;
                                        _showGlassSkin = preset.showGlassSkin;
                                        _foundationFinishing = preset.showGlassSkin ? 'dewy' : 'matte';
                                        _selectedEyeshadowColor = preset.eyeshadowColor;
                                        _eyeshadowOpacity = preset.eyeshadowOpacity;
                                        _hasEyeliner = preset.hasEyeliner;
                                        _eyelinerThickness = preset.eyelinerThickness;
                                        _selectedLightingPreset = preset.lightingPreset;
                                        _noseHighlightOpacity = preset.noseHighlightOpacity;
                                        _noseShadingOpacity = preset.noseShadingOpacity;
                                        _activePreset = name;
                                      });
                                    },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? primaryColor : cardBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? primaryColor : cardBorderColor.withOpacity(0.55),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected ? ThemeManager.premiumGlowShadow : null,
                                ),
                                child: Text(
                                  '${preset.icon} $name',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : textColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else if (_activeCategoryIndex == 1) ...[
                      // Opacity Foundation (Dasaran Base)
                      Row(
                        children: [
                          Icon(Icons.face_retouching_natural_rounded, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Opasitas Base', style: TextStyle(color: textColor, fontSize: 11)),
                          Expanded(
                            child: Slider(
                              activeColor: primaryColor,
                              inactiveColor: cardBorderColor,
                              value: _foundationOpacity,
                              min: 0.0,
                              max: 0.8,
                              onChanged: _showPaywall
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _foundationOpacity = val;
                                        _activePreset = null;
                                      });
                                    },
                            ),
                          ),
                          Text(
                            '${(_foundationOpacity * 100).round()}%',
                            style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Finishing Foundation
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Finishing:',
                            style: TextStyle(fontSize: 11, color: textColor),
                          ),
                          const SizedBox(width: 12),
                          _buildFoundationFinishingButton('Matte', _foundationFinishing == 'matte'),
                          const SizedBox(width: 6),
                          _buildFoundationFinishingButton('Satin', _foundationFinishing == 'satin'),
                          const SizedBox(width: 6),
                          _buildFoundationFinishingButton('Dewy', _foundationFinishing == 'dewy'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Dropdown filter Merek Foundation
                      Row(
                        children: [
                           Text(
                            'Merek:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: cardBorderColor.withOpacity(0.55), width: 1.5),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedBrandFilter,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                                  style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold),
                                  items: _brands.map((String b) {
                                    return DropdownMenuItem<String>(
                                      value: b,
                                      child: Text(b),
                                    );
                                  }).toList(),
                                  onChanged: (String? val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedBrandFilter = val;
                                        _applyFoundationFilter();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (_selectedFoundationProduct != null && _foundationOpacity > 0) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${_selectedFoundationProduct!.brand} - ${_selectedFoundationProduct!.shadeName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Palet Warna Foundation dari DB
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            _buildColorCircle(Colors.transparent, 'Tidak Pakai', _foundationOpacity == 0.0, () {
                              setState(() {
                                _foundationOpacity = 0.0;
                                _selectedFoundationProduct = null;
                                _activePreset = null;
                              });
                            }),
                            Expanded(
                              child: _filteredFoundations.isEmpty
                                  ? const Center(child: Text('Memuat data...', style: TextStyle(fontSize: 11, color: Colors.grey)))
                                  : ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _filteredFoundations.length,
                                      itemBuilder: (context, index) {
                                        final fProd = _filteredFoundations[index];
                                        final hexColor = _getHexColor(fProd.hexCode);
                                        final isSel = _selectedFoundationProduct?.id == fProd.id && _foundationOpacity > 0.0;
                                        return _buildColorCircle(hexColor, fProd.shadeName, isSel, () {
                                          setState(() {
                                            _selectedFoundationProduct = fProd;
                                            _selectedFoundationColor = hexColor;
                                            if (_foundationOpacity == 0.0) _foundationOpacity = 0.35;
                                            _activePreset = null;
                                          });
                                        });
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_activeCategoryIndex == 2) ...[
                      // Opacity Lipstick & Finishing Toggle
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.opacity_rounded, color: primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text('Transparansi Bibir', style: TextStyle(color: textColor, fontSize: 11)),
                                Expanded(
                                  child: Slider(
                                    activeColor: primaryColor,
                                    inactiveColor: cardBorderColor,
                                    value: _lipstickOpacity,
                                    min: 0.0,
                                    max: 0.8,
                                    onChanged: _showPaywall
                                        ? null
                                        : (val) {
                                            setState(() {
                                              _lipstickOpacity = val;
                                              _activePreset = null;
                                            });
                                          },
                                  ),
                                ),
                                Text(
                                  '${(_lipstickOpacity * 100).round()}%',
                                  style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Glossy vs Matte
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cardBorderColor.withOpacity(0.55), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                _buildFinishingButton('Matte', _lipstickFinishing == 'matte'),
                                _buildFinishingButton('Glossy', _lipstickFinishing == 'glossy'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Palet Warna Lipstick
                      Text(
                        'WARNA LIPSTIK:',
                        style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            _buildColorCircle(Colors.transparent, 'Tidak Pakai', _lipstickOpacity == 0.0, () {
                              setState(() {
                                _lipstickOpacity = 0.0;
                                _activePreset = null;
                              });
                            }),
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _lipstickColors.length,
                                itemBuilder: (context, index) {
                                  final lColor = _lipstickColors[index];
                                  final isSel = _selectedLipstickColor == lColor['color'] && _lipstickOpacity > 0.0;
                                  return _buildColorCircle(
                                    lColor['color'],
                                    lColor['name'],
                                    isSel,
                                    () {
                                      setState(() {
                                        _selectedLipstickColor = lColor['color'];
                                        if (_lipstickOpacity == 0.0) _lipstickOpacity = 0.40;
                                        _activePreset = null;
                                      });
                                    },
                                    isRecommended: _isColorRecommended('lipstick', lColor['name']),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_activeCategoryIndex == 3) ...[
                      // Opacity Blush-On
                      Row(
                        children: [
                          Icon(Icons.opacity_rounded, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Transparansi Pipi', style: TextStyle(color: textColor, fontSize: 11)),
                          Expanded(
                            child: Slider(
                              activeColor: primaryColor,
                              inactiveColor: cardBorderColor,
                              value: _blushOpacity,
                              min: 0.0,
                              max: 0.8,
                              onChanged: _showPaywall
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _blushOpacity = val;
                                        _activePreset = null;
                                      });
                                    },
                            ),
                          ),
                          Text(
                            '${(_blushOpacity * 100).round()}%',
                            style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Palet Warna Blush-On
                      Text(
                        'WARNA BLUSH-ON:',
                        style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            _buildColorCircle(Colors.transparent, 'Tidak Pakai', _blushOpacity == 0.0, () {
                              setState(() {
                                _blushOpacity = 0.0;
                                _activePreset = null;
                              });
                            }),
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _blushColors.length,
                                itemBuilder: (context, index) {
                                  final bColor = _blushColors[index];
                                  final isSel = _selectedBlushColor == bColor['color'] && _blushOpacity > 0.0;
                                  return _buildColorCircle(
                                    bColor['color'],
                                    bColor['name'],
                                    isSel,
                                    () {
                                      setState(() {
                                        _selectedBlushColor = bColor['color'];
                                        if (_blushOpacity == 0.0) _blushOpacity = 0.25;
                                        _activePreset = null;
                                      });
                                    },
                                    isRecommended: _isColorRecommended('blush', bColor['name']),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_activeCategoryIndex == 4) ...[
                      // Opacity Nose Highlight Slider
                      Row(
                        children: [
                          Icon(Icons.light_mode_rounded, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Highlight Hidung', style: TextStyle(color: textColor, fontSize: 11)),
                          Expanded(
                            child: Slider(
                              activeColor: primaryColor,
                              inactiveColor: cardBorderColor,
                              value: _noseHighlightOpacity,
                              min: 0.0,
                              max: 1.0,
                              onChanged: _showPaywall
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _noseHighlightOpacity = val;
                                        _activePreset = null;
                                      });
                                    },
                            ),
                          ),
                          Text(
                            '${(_noseHighlightOpacity * 100).round()}%',
                            style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Opacity Nose Shading Slider
                      Row(
                        children: [
                          Icon(Icons.brush_rounded, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Shading Hidung  ', style: TextStyle(color: textColor, fontSize: 11)),
                          Expanded(
                            child: Slider(
                              activeColor: primaryColor,
                              inactiveColor: cardBorderColor,
                              value: _noseShadingOpacity,
                              min: 0.0,
                              max: 1.0,
                              onChanged: _showPaywall
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _noseShadingOpacity = val;
                                        _activePreset = null;
                                      });
                                    },
                            ),
                          ),
                          Text(
                            '${(_noseShadingOpacity * 100).round()}%',
                            style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Opacity Eyeshadow & Eyeliner Toggle
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.opacity_rounded, color: primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text('Transparansi Mata', style: TextStyle(color: textColor, fontSize: 11)),
                                Expanded(
                                  child: Slider(
                                    activeColor: primaryColor,
                                    inactiveColor: cardBorderColor,
                                    value: _eyeshadowOpacity,
                                    min: 0.0,
                                    max: 0.8,
                                    onChanged: _showPaywall
                                        ? null
                                        : (val) {
                                            setState(() {
                                              _eyeshadowOpacity = val;
                                              _activePreset = null;
                                            });
                                          },
                                  ),
                                ),
                                Text(
                                  '${(_eyeshadowOpacity * 100).round()}%',
                                  style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Eyeliner Toggle
                          Row(
                            children: [
                              Text('Eyeliner', style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              Switch(
                                activeColor: primaryColor,
                                value: _hasEyeliner,
                                onChanged: _showPaywall
                                    ? null
                                    : (val) {
                                        setState(() {
                                          _hasEyeliner = val;
                                          _activePreset = null;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_hasEyeliner) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.line_weight_rounded, color: primaryColor, size: 18),
                            const SizedBox(width: 8),
                            Text('Ketebalan Eyeliner', style: TextStyle(color: textColor, fontSize: 11)),
                            Expanded(
                              child: Slider(
                                activeColor: primaryColor,
                                inactiveColor: cardBorderColor,
                                value: _eyelinerThickness,
                                min: 0.0,
                                max: 1.0,
                                onChanged: _showPaywall
                                    ? null
                                    : (val) {
                                        setState(() {
                                          _eyelinerThickness = val;
                                          _activePreset = null;
                                        });
                                      },
                              ),
                            ),
                            Text(
                              '${(_eyelinerThickness * 100).round()}%',
                              style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Palet Warna Eyeshadow
                      Text(
                        'WARNA EYESHADOW:',
                        style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            _buildColorCircle(Colors.transparent, 'Tidak Pakai', _eyeshadowOpacity == 0.0, () {
                              setState(() {
                                _eyeshadowOpacity = 0.0;
                                _activePreset = null;
                              });
                            }),
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _eyeshadowColors.length,
                                itemBuilder: (context, index) {
                                  final eColor = _eyeshadowColors[index];
                                  final isSel = _selectedEyeshadowColor == eColor['color'] && _eyeshadowOpacity > 0.0;
                                  return _buildColorCircle(
                                    eColor['color'],
                                    eColor['name'],
                                    isSel,
                                    () {
                                      setState(() {
                                        _selectedEyeshadowColor = eColor['color'];
                                        if (_eyeshadowOpacity == 0.0) _eyeshadowOpacity = 0.40;
                                        _activePreset = null;
                                      });
                                    },
                                    isRecommended: _isColorRecommended('eyeshadow', eColor['name']),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildPaywallFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
           Icon(Icons.check_circle_outline_rounded, color: primaryColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style:  TextStyle(color: textMutedColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class SmoothedFace implements Face {
  @override
  final Rect boundingBox;
  
  @override
  final Map<FaceContourType, FaceContour?> contours;
  
  @override
  final Map<FaceLandmarkType, FaceLandmark?> landmarks;
  
  @override
  final double? smilingProbability;
  
  @override
  final double? leftEyeOpenProbability;
  
  @override
  final double? rightEyeOpenProbability;
  
  @override
  final double? headEulerAngleX;
  
  @override
  final double? headEulerAngleY;
  
  @override
  final double? headEulerAngleZ;
  
  @override
  final int? trackingId;

  SmoothedFace({
    required this.boundingBox,
    required this.contours,
    this.landmarks = const {},
    this.smilingProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.trackingId,
  });
}

class SmoothedFaceContour implements FaceContour {
  @override
  final FaceContourType type;
  
  @override
  final List<Point<int>> points;

  SmoothedFaceContour({required this.type, required this.points});
}
