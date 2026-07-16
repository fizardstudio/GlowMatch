import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:glowmatch/core/theme/theme_manager.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../data/models/app_settings.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/utils/color_calculator.dart';
import '../widgets/photo_makeup_painter.dart';
import '../../data/models/makeup_preset.dart';
import '../../../../core/utils/face_geometry_helper.dart';
import '../../../../core/utils/widget_helper.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

class PhotoTryOnPage extends StatefulWidget {
  final String? initialFilePath;

  const PhotoTryOnPage({super.key, this.initialFilePath});

  @override
  State<PhotoTryOnPage> createState() => _PhotoTryOnPageState();
}

class _PhotoTryOnPageState extends State<PhotoTryOnPage> with WidgetsBindingObserver {
  bool get isDark => ThemeManager.isDark;
  Color get textColor => ThemeManager.textColor;
  Color get textMutedColor => ThemeManager.textMutedColor;
  Color get cardBgColor => ThemeManager.cardBgColor;
  Color get cardBorderColor => ThemeManager.cardBorderColor;
  Color get primaryColor => ThemeManager.primaryColor;
  final Isar _isar = DatabaseService().isar;
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isPremium = false;
  bool _showPaywall = true;
  bool _showWatermarkSetting = true;

  // ML Kit Face Detector
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // States gambar & analisis
  String? _imagePath;
  bool _isLoadingImage = false;
  bool _isSavingLook = false;
  bool _isCapturing = false;
  Face? _detectedFace;
  ui.Image? _decodedImage;
  int _originalWidth = 0;
  int _originalHeight = 0;

  // Active Category (0 = Looks, 1 = Base, 2 = Bibir, 3 = Pipi)
  int _activeCategoryIndex = 0;
  String? _activePreset = 'Korean Glass Skin';
  bool _isSplitMode = true; // DEFAULT ON!
  bool _showGlassSkin = true;

  // Advanced Try-On Upgrades (Phase 2.5)
  String _selectedLightingPreset = 'Natural'; // 'Natural', 'Golden Hour', 'Studio Light', 'Cyber Neon'
  bool _showHarmonyHeatmap = false;
  bool _showTooltip = false;
  String _activeTooltipComponent = 'base';
  Offset _tooltipOffset = Offset.zero;

  // Boomerang Export Progress
  bool _isExportingBoomerang = false;
  double _exportProgress = 0.0;

  // Filter Parameters - Base Makeup (Foundation)
  Color _selectedFoundationColor = const Color(0xFFF3D3C4); // Fair Nude
  double _foundationOpacity = 0.0; // Default 0% (tidak aktif)
  String _foundationFinishing = 'dewy'; // 'matte', 'satin', 'dewy'
  
  // Data foundation dari database Isar luring
  List<ProductShade> _dbFoundations = [];
  List<ProductShade> _filteredFoundations = [];
  List<String> _brands = ['Semua'];
  String _selectedBrandFilter = 'Semua';
  ProductShade? _selectedFoundationProduct;

  // Filter Parameters - Lipstick (Bibir)
  Color _selectedLipstickColor = const Color(0xFFF98E7B); // Coral pink (Korean Glass Skin default)
  double _lipstickOpacity = 0.45;
  String _lipstickFinishing = 'glossy';

  // Filter Parameters - Blush-On (Pipi)
  Color _selectedBlushColor = const Color(0xFFFF8A80); // Soft Coral
  double _blushOpacity = 0.30;

  // Filter Parameters - Eye Makeup (Mata)
  Color _selectedEyeshadowColor = const Color(0xFFFFCC80); // Champagne Shimmer
  double _eyeshadowOpacity = 0.0;
  bool _hasEyeliner = false;
  double _eyelinerThickness = 0.5; // Default 50%

  // Filter Parameters - Nose Contour (Hidung)
  double _noseHighlightOpacity = 0.0;
  double _noseShadingOpacity = 0.0;

  double _sliderX = 180.0; // Koordinat pembagi horizontal

  // Scanned history data
  String? _lastMatchedShadeName;
  String? _lastMatchedUndertone;
  String? _lastMatchedSeasonalColor;
  String? _lastMatchedSkinTone;
  double? _lastMatchedContrast;
  List<int>? _lastMatchedCommercialShadeIds;

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
  bool _isSliderInitialized = false;
  bool _showControls = true;

  // Demo Mode
  bool _isDemoActive = false;
  int _demoSecondsLeft = 60;
  Timer? _demoTimer;

  // List Warna Foundation Eksklusif
  final List<Map<String, dynamic>> _foundationColors = [
    {'name': 'Fair Nude', 'color': const Color(0xFFF5D6C8)},
    {'name': 'Light Ivory', 'color': const Color(0xFFEED0BC)},
    {'name': 'Natural Beige', 'color': const Color(0xFFE5C1A7)},
    {'name': 'Warm Sand', 'color': const Color(0xFFD8B092)},
    {'name': 'Golden Tan', 'color': const Color(0xFFC79D7C)},
    {'name': 'Deep Amber', 'color': const Color(0xFFB08461)},
  ];

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

    // Muat foto awal jika dilewatkan lewat argumen navigasi
    if (widget.initialFilePath != null) {
      _processImageFile(widget.initialFilePath!);
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
          _brands = ['Semua', ...uniqueBrands];
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
      if (_selectedBrandFilter == 'Semua') {
        _filteredFoundations = _dbFoundations;
      } else {
        _filteredFoundations = _dbFoundations
            .where((f) => f.brand == _selectedBrandFilter)
            .toList();
      }
    });
  }

  Map<String, dynamic> _getLookSummaryDetails() {
    // 1. Foundation Recommendation (Cari terdekat jika null dari database Isar)
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

    // 2. Lipstick Recommendation
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

    // 3. Blush-On Recommendation
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
      blushUrl = 'https://shopee.co.id/wardahofficial';
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
    if (!_isPremium && !_isDemoActive) {
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC89E88)),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style:  TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style:  TextStyle(fontSize: 11, color: textMutedColor, height: 1.4),
                  ),
                ],
                if (affiliateUrl != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(affiliateUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children:  [
                        Icon(Icons.shopping_bag_outlined, size: 12, color: primaryColor),
                        SizedBox(width: 4),
                        Text(
                          'Beli Sekarang 🛒',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLookSummarySheetWrapper() {
    _showLookSummarySheet();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSliderInitialized) {
      _sliderX = MediaQuery.of(context).size.width / 2;
      _isSliderInitialized = true;
    }
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
        _lastMatchedCommercialShadeIds = settings.lastMatchedCommercialShadeIds;
        _showWatermarkSetting = settings.showWatermark;
      });
      _tryAutoSelectFoundation();
    }
  }

  Future<void> _saveWatermarkSetting(bool value) async {
    await _isar.writeTxn(() async {
      final settings = await _isar.appSettings.get(0) ?? (AppSettings()..id = 0..isPremium = _isPremium);
      settings.showWatermark = value;
      await _isar.appSettings.put(settings);
    });
    setState(() {
      _showWatermarkSetting = value;
    });
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



  Widget _buildFinishingButton(String label, bool isSel) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _lipstickFinishing = label.toLowerCase();
          _activePreset = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? primaryColor : cardBgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.white : textMutedColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? primaryColor : cardBgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.white : textMutedColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _applyAiRecommendation() {
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

      _activePreset = 'Rekomendasi AI (${_lastMatchedSeasonalColor ?? "Personal"})';
      _showGlassSkin = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rekomendasi AI dipoleskan sesuai rona ${_lastMatchedUndertone!.toUpperCase()} Anda! 🌟'),
        backgroundColor: primaryColor,
      ),
    );
  }

  void _handleImageTap(TapDownDetails details, Size fittedSize) {
    if (_detectedFace == null || _showPaywall || _isExportingBoomerang) return;
    
    // Konversi koordinat sentuhan lokal ke koordinat foto asli
    final double tapX = (details.localPosition.dx / fittedSize.width) * _originalWidth;
    final double tapY = (details.localPosition.dy / fittedSize.height) * _originalHeight;
    final tapPt = Point<double>(tapX, tapY);

    double distance(Point<double> p1, Point<num> p2) {
      return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
    }

    // 1. Cek kedekatan dengan Bibir (Lipstik)
    final lipCenter = FaceGeometryHelper.getLipCenter(_detectedFace!);
    if (lipCenter != null) {
      final dLip = distance(tapPt, lipCenter);
      if (dLip < _originalWidth * 0.08) {
        setState(() {
          _activeTooltipComponent = 'bibir';
          _tooltipOffset = details.localPosition;
          _showTooltip = true;
        });
        _autoHideTooltip();
        return;
      }
    }

    // 2. Cek kedekatan dengan Pipi (Blush-On)
    final cheeks = FaceGeometryHelper.getCheekboneCoordinates(_detectedFace!);
    final leftCheek = cheeks['left'];
    final rightCheek = cheeks['right'];
    if (leftCheek != null && rightCheek != null) {
      final dLeft = distance(tapPt, leftCheek);
      final dRight = distance(tapPt, rightCheek);
      if (dLeft < _originalWidth * 0.12 || dRight < _originalWidth * 0.12) {
        setState(() {
          _activeTooltipComponent = 'pipi';
          _tooltipOffset = details.localPosition;
          _showTooltip = true;
        });
        _autoHideTooltip();
        return;
      }
    }

    // 3. Cek apakah ketukan berada di dalam kontur wajah (Base Foundation)
    final rect = _detectedFace!.boundingBox;
    if (tapX >= rect.left && tapX <= rect.right && tapY >= rect.top && tapY <= rect.bottom) {
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

  bool _PhotoTryOnPageState_isLipstickMismatch() {
    if (_lastMatchedUndertone == null) return false;
    final String und = _lastMatchedUndertone!.toLowerCase();
    final int value = _selectedLipstickColor.value & 0xFFFFFF;
    bool isCool = false;
    bool isWarm = false;
    if (value == 0xD81B60 || value == 0xAD1457 || value == 0x8E24AA || value == 0xB71C1C) {
      isCool = true;
    } else if (value == 0xFF7043 || value == 0x8D6E63) {
      isWarm = true;
    }
    if (und == 'warm' && isCool) return true;
    if (und == 'cool' && isWarm) return true;
    return false;
  }

  bool _PhotoTryOnPageState_isBlushMismatch() {
    if (_lastMatchedUndertone == null) return false;
    final String und = _lastMatchedUndertone!.toLowerCase();
    final int value = _selectedBlushColor.value & 0xFFFFFF;
    bool isCool = false;
    bool isWarm = false;
    if (value == 0xFF80AB || value == 0xE91E63 || value == 0xBA68C8) {
      isCool = true;
    } else if (value == 0xFF8A80 || value == 0xFFB74D || value == 0xFF8F00) {
      isWarm = true;
    }
    if (und == 'warm' && isCool) return true;
    if (und == 'cool' && isWarm) return true;
    return false;
  }

  Widget _buildHarmonyAlertBanner() {
    final bool isLipMismatch = _PhotoTryOnPageState_isLipstickMismatch();
    final bool isBlushMismatch = _PhotoTryOnPageState_isBlushMismatch();

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
          : (_PhotoTryOnPageState_isLipstickMismatch() ? 'Rona Kurang Serasi ⚠️' : 'Rona Sangat Serasi ✨');
      info = 'Pulasan: ${(_lipstickOpacity * 100).round()}% | $match';
    } else if (_activeTooltipComponent == 'pipi') {
      title = 'PIPI (BLUSH)';
      icon = Icons.face_rounded;
      color = _selectedBlushColor;
      final match = _lastMatchedUndertone == null 
          ? 'Coba Scan Kulit' 
          : (_PhotoTryOnPageState_isBlushMismatch() ? 'Rona Kurang Serasi ⚠️' : 'Rona Sangat Serasi ✨');
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
          _isCapturing = false; // Tampilkan garis slider/split line di frame
        });

        await Future.delayed(const Duration(milliseconds: 150));

        final ui.Image uiImage = await boundary.toImage(pixelRatio: 1.2);
        final ByteData? byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          frames.add(byteData.buffer.asUint8List());
        }

        setState(() {
          _exportProgress = (i + 1) / steps.length * 0.45; // 0% - 45%
        });
      }

      setState(() {
        _isCapturing = true;
      });

      // Proses konversi dan pengodean GIF anim menggunakan package:image
      final int w = boundary.size.width.toInt();
      final int h = boundary.size.height.toInt();
      final int frameW = (w * 1.2).toInt();
      final int frameH = (h * 1.2).toInt();

      // Tunggu agar CPU bebas
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
          _exportProgress = 0.45 + ((fIndex + 1) / frames.length * 0.45); // 45% - 90%
        });
      }

      // Ping-pong frames untuk efek Boomerang
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
        "filename": "glowmatch_boomerang_${DateTime.now().millisecondsSinceEpoch}",
        "mimeType": "image/gif",
      }) ?? false;

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Animasi Boomerang berhasil dibagikan! 🎬🌟'),
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
      if (mounted) {
        setState(() {
          if (_demoSecondsLeft > 0) {
            _demoSecondsLeft--;
          } else {
            _stopDemoTimer();
            _showPaywall = true;
            _isDemoActive = false;
          }
        });
      }
    });
  }

  void _stopDemoTimer() {
    _demoTimer?.cancel();
    _demoTimer = null;
  }

  Future<void> _processImageFile(String path) async {
    setState(() {
      _isLoadingImage = true;
      _detectedFace = null;
      _imagePath = path;
    });

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception("File does not exist");
      }

      // Dapatkan resolusi gambar asli menggunakan dart:ui secara instan
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;

      _originalWidth = uiImage.width;
      _originalHeight = uiImage.height;

      // Deteksi wajah ML Kit
      final inputImage = InputImage.fromFilePath(path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _decodedImage = uiImage;
          if (faces.isNotEmpty) {
            _detectedFace = faces.first;
          } else {
            _detectedFace = null;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Wajah tidak terdeteksi pada foto. Silakan pilih foto selfie dengan wajah menghadap lurus ke depan.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading image for PhotoTryOn: $e");
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? selectedFile = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (selectedFile != null) {
        _processImageFile(selectedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Fungsi untuk menyimpan gambar hasil riasan langsung ke galeri ponsel
  Future<void> _saveCurrentMakeupLook() async {
    if (!_isPremium && !_isDemoActive) {
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
      // Tunggu frame selesai dirender tanpa tombol dan garis slider
      await Future.delayed(const Duration(milliseconds: 100));

      final RenderRepaintBoundary? boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Gagal mendapatkan rendering area wajah.");
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 1.8);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception("Gagal mengodekan gambar hasil riasan.");
      }

      if (!Platform.isAndroid) {
        throw Exception("Penyimpanan galeri luring saat ini hanya didukung di Android.");
      }

      // Gunakan platform channel untuk menyimpan di galeri Android native luring
      const platform = MethodChannel("com.fizardstudio.glowmatch/widget");
      final bool success = await platform.invokeMethod<bool>("saveImageToGallery", {
        "bytes": pngBytes,
        "filename": "glowmatch_look_${DateTime.now().millisecondsSinceEpoch}",
        "mimeType": "image/png",
      }) ?? false;

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text('Foto hasil riasan berhasil disimpan ke Galeri! 📸💖 (Folder: Pictures/GlowMatch)'),
              backgroundColor: primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan foto ke Galeri.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error saving look to gallery: $e");
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

  Future<void> _shareCurrentMakeupLook() async {
    if (!_isPremium && !_isDemoActive) {
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

      final ui.Image image = await boundary.toImage(pixelRatio: 1.8);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception("Gagal mengodekan gambar.");
      }

      const platform = MethodChannel("com.fizardstudio.glowmatch/widget");
      final bool success = await platform.invokeMethod<bool>("shareImage", {
        "bytes": pngBytes,
        "filename": "glowmatch_riasan_${DateTime.now().millisecondsSinceEpoch}",
        "mimeType": "image/png",
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

  // Menghitung ukuran Fitted Image (BoxFit.contain)
  Size _getFittedImageSize(double maxWidth, double maxHeight, double imgWidth, double imgHeight) {
    if (imgWidth == 0 || imgHeight == 0) return Size.zero;
    final double srcAspect = imgWidth / imgHeight;
    final double dstAspect = maxWidth / maxHeight;
    
    if (srcAspect > dstAspect) {
      final double fittedWidth = maxWidth;
      final double fittedHeight = maxWidth / srcAspect;
      return Size(fittedWidth, fittedHeight);
    } else {
      final double fittedHeight = maxHeight;
      final double fittedWidth = maxHeight * srcAspect;
      return Size(fittedWidth, fittedHeight);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDemoTimer();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: cardBgColor,
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
             Text(
              'Uji Riasan 2D Foto',
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
          if (_imagePath != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Riasan',
              onPressed: () {
                setState(() {
                  _foundationOpacity = 0.0;
                  _lipstickOpacity = 0.0;
                  _blushOpacity = 0.0;
                });
              },
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Wilayah Tampilan Utama Foto & Paint Overlay
          Positioned.fill(
            child: _imagePath == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child:  Icon(Icons.add_photo_alternate_rounded, size: 72, color: primaryColor),
                          ),
                          const SizedBox(height: 24),
                           Text(
                            'Belum Ada Foto Terpilih',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(height: 8),
                           Text(
                            'Ambil foto selfie baru menggunakan kamera ponsel atau unggah foto dari galeri untuk memulai simulasi riasan statis.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: textMutedColor, height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Galeri 🖼️', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _pickImage(ImageSource.gallery),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textColor,
                                  side:  BorderSide(color: primaryColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Kamera 📸', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _pickImage(ImageSource.camera),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : _isLoadingImage
                    ?  Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
                            SizedBox(height: 16),
                            Text('Menganalisis Face Mesh Foto...', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final double areaWidth = constraints.maxWidth;
                          final double areaHeight = constraints.maxHeight - (_showControls ? 300 : 0);

                          final Size fittedSize = _getFittedImageSize(
                            areaWidth,
                            areaHeight,
                            _originalWidth.toDouble(),
                            _originalHeight.toDouble(),
                          );

                          if (!_isSliderInitialized) {
                            _sliderX = fittedSize.width / 2;
                            _isSliderInitialized = true;
                          }

                          final double topPadding = (constraints.maxHeight - (_showControls ? 300 : 0) - fittedSize.height).clamp(0.0, double.infinity) / 2;
                          return Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: topPadding),
                              child: RepaintBoundary(
                                key: _repaintBoundaryKey,
                                child: GestureDetector(
                                  onTapDown: (details) => _handleImageTap(details, fittedSize),
                                  child: SizedBox(
                                    width: fittedSize.width,
                                    height: fittedSize.height,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                      child: Image.file(
                                        File(_imagePath!),
                                        fit: BoxFit.fill,
                                      ),
                                    ),
// Layer Gambar Riasan (CustomPaint)
                                  if (!_showPaywall)
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: PhotoMakeupPainter(
                                          face: _detectedFace,
                                          originalImageWidth: _originalWidth,
                                          originalImageHeight: _originalHeight,
                                          backgroundImage: _decodedImage,
                                          foundationColor: _selectedFoundationColor,
                                          foundationOpacity: _foundationOpacity,
                                          lipstickColor: _selectedLipstickColor,
                                          lipstickOpacity: _lipstickOpacity,
                                          lipstickFinishing: _lipstickFinishing,
                                          blushColor: _selectedBlushColor,
                                          blushOpacity: _blushOpacity,
                                          showGlassSkin: _showGlassSkin,
                                          foundationFinishing: _foundationFinishing,
                                          sliderX: _isCapturing || !_isSplitMode ? 0.0 : _sliderX,
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

                                  // Watermark (GlowMatch AI - Tergambar di atas CustomPaint agar tidak tertutup gambar latar)
                                  if (_isCapturing && _showWatermarkSetting)
                                    Positioned(
                                      bottom: 16,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.auto_awesome, color: primaryColor, size: 10),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'GlowMatch AI - Temukan Shade Wajahmu!',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Slider Garis Pembagi
                                  if (!_showPaywall && !_isCapturing)
                                    Positioned(
                                      left: _sliderX - 25,
                                      top: 0,
                                      bottom: 0,
                                      width: 50,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onPanUpdate: (details) {
                                          setState(() {
                                            _sliderX = (_sliderX + details.delta.dx).clamp(0.0, fittedSize.width);
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
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: primaryColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 4,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: const RotatedBox(
                                                quarterTurns: 1,
                                                child: Icon(
                                                  Icons.unfold_more_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Live Face Shape Badge
                                  if (!_showPaywall && _detectedFace != null && !_isCapturing)
                                    Positioned(
                                      top: 16,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Wajah: ${FaceGeometryHelper.classifyFaceShape(_detectedFace!).toUpperCase()}',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Floating Actions Ganti/Ambil Foto di Pojok Kiri Atas
                                  if (!_isCapturing)
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Row(
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: cardBgColor.withOpacity(0.9),
                                            foregroundColor: textColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            elevation: 2,
                                          ),
                                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                                          label: const Text('Ganti', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () => _pickImage(ImageSource.gallery),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: cardBgColor.withOpacity(0.9),
                                            foregroundColor: textColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            elevation: 2,
                                          ),
                                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                          label: const Text('Foto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () => _pickImage(ImageSource.camera),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      );
                    },
                  ),
          ),

          // 2. Demo Mode Overlay
          if (_isDemoActive && !_showPaywall && _imagePath != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cardBgColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.5)),
                ),
                child: Text(
                  'Demo: ${_demoSecondsLeft}s',
                  style:  TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 3. Toggle Panel Kontrol
          if (_imagePath != null && !_showPaywall)
            Positioned(
              bottom: _showControls ? 300 : 24,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'photo_toggle_controls_fab',
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
                  _showControls ? Icons.keyboard_arrow_down_rounded : Icons.tune_rounded,
                  color: textColor,
                  size: 20,
                ),
              ),
            ),

          // 4. Panel Kontrol Bawah (Makeup Editor Panel)
          if (_showControls && _imagePath != null && !_showPaywall)
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
                  border: Border.all(color: cardBorderColor, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tab Selector Kategori
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTabButton('Looks', 0),
                            _buildTabButton('Base', 1),
                            _buildTabButton('Lipstik', 2),
                            _buildTabButton('Pipi', 3),
                            _buildTabButton('Hidung', 4),
                            _buildTabButton('Mata', 5),
                            _buildTabButton('Pengaturan', 6),
                          ],
                        ),
                      ),
                    ),

                    // Sliders & Toggles khusus Tab Aktif
                    if (_activeCategoryIndex == 0) ...[
                      // Pilihan Preset Looks & AI Recommendation
                      const Text(
                        'PILIH PRESET LOOKS:',
                        style: TextStyle(color: Color(0xFFC89E88), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
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
                                onTap: _applyAiRecommendation,
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
                              onTap: () {
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
                      // Opacity Foundation
                      _buildSliderRow('Opasitas Base', _foundationOpacity, (val) {
                        setState(() {
                          _foundationOpacity = val;
                        });
                      }),
                      const SizedBox(height: 6),
                      // Finishing Foundation
                      Row(
                        children: [
                          Text(
                            'Finishing:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(width: 8),
                          _buildFoundationFinishingButton('Matte', _foundationFinishing == 'matte'),
                          const SizedBox(width: 6),
                          _buildFoundationFinishingButton('Satin', _foundationFinishing == 'satin'),
                          const SizedBox(width: 6),
                          _buildFoundationFinishingButton('Dewy', _foundationFinishing == 'dewy'),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedBrandFilter,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                                  style:  TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold),
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
                                style:  TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryColor),
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
                                        final bool isMatched = _lastMatchedCommercialShadeIds != null &&
                                            _lastMatchedCommercialShadeIds!.contains(fProd.id);
                                        return _buildColorCircle(
                                          hexColor,
                                          fProd.shadeName,
                                          isSel,
                                          () {
                                            setState(() {
                                              _selectedFoundationProduct = fProd;
                                              _selectedFoundationColor = hexColor;
                                              if (_foundationOpacity == 0.0) _foundationOpacity = 0.35; // Aktifkan ke 35%
                                              _activePreset = null;
                                            });
                                          },
                                          isRecommended: isMatched,
                                        );
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
                            child: _buildSliderRow('Opasitas Bibir', _lipstickOpacity, (val) {
                              setState(() {
                                _lipstickOpacity = val;
                              });
                            }),
                          ),
                          const SizedBox(width: 12),
                          // Glossy vs Matte
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cardBorderColor),
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
                      _buildSliderRow('Opasitas Pipi', _blushOpacity, (val) {
                        setState(() {
                          _blushOpacity = val;
                        });
                      }),
                      const SizedBox(height: 8),
                      // Palet Warna Blush-On
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
                      _buildSliderRow('Highlight Hidung', _noseHighlightOpacity, (val) {
                        setState(() {
                          _noseHighlightOpacity = val;
                        });
                      }),
                      const SizedBox(height: 8),
                      // Opacity Nose Shading Slider
                      _buildSliderRow('Shading Hidung', _noseShadingOpacity, (val) {
                        setState(() {
                          _noseShadingOpacity = val;
                        });
                      }),
                    ] else if (_activeCategoryIndex == 5) ...[
                      // Opacity Eyeshadow & Eyeliner Toggle
                      Row(
                        children: [
                          Expanded(
                            child: _buildSliderRow('Opasitas Mata', _eyeshadowOpacity, (val) {
                              setState(() {
                                _eyeshadowOpacity = val;
                              });
                            }),
                          ),
                          const SizedBox(width: 12),
                          // Eyeliner Toggle
                          Row(
                            children: [
                              Text('Eyeliner', style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              Switch(
                                activeColor: primaryColor,
                                value: _hasEyeliner,
                                onChanged: (val) {
                                  setState(() {
                                    _hasEyeliner = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_hasEyeliner) ...[
                        const SizedBox(height: 8),
                        _buildSliderRow('Ketebalan Eyeliner', _eyelinerThickness, (val) {
                          setState(() {
                            _eyelinerThickness = val;
                          });
                        }),
                      ],
                      const SizedBox(height: 8),
                      // Palet Warna Eyeshadow
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
                    ] else if (_activeCategoryIndex == 6) ...[
                      // Settings Tab
                      Text(
                        'PENGATURAN EKSPOR:',
                        style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardBgColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorderColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.branding_watermark_rounded, color: primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tampilkan Watermark AI',
                                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Matikan untuk mengekspor gambar bersih tanpa watermark (Khusus Premium)',
                                    style: TextStyle(color: textMutedColor, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              activeColor: primaryColor,
                              value: _showWatermarkSetting,
                              onChanged: (val) {
                                if (!_isPremium) {
                                  // Lock to premium! Show paywall.
                                  setState(() {
                                    _showPaywall = true;
                                  });
                                } else {
                                  _saveWatermarkSetting(val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 18),
                            label: const Text('Detail & Belanja 📃', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: _showLookSummarySheet,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side:  BorderSide(color: primaryColor),
                              minimumSize: const Size(0, 44),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon:  Icon(Icons.save_alt_rounded, size: 14, color: primaryColor),
                            label: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            onPressed: _saveCurrentMakeupLook,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side:  BorderSide(color: primaryColor),
                              minimumSize: const Size(0, 44),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon:  Icon(Icons.share_rounded, size: 14, color: primaryColor),
                            label: const Text('Bagikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            onPressed: _shareCurrentMakeupLook,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 4.5. Spinner Overlay untuk Menyimpan Gambar ke Galeri
          if (_isSavingLook)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child:  Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
                      SizedBox(height: 16),
                      Text(
                        'Menyimpan Gambar ke Galeri...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4.6. Boomerang GIF Exporter Progress Overlay
          if (_isExportingBoomerang)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorderColor, width: 1.5),
                      boxShadow: ThemeManager.premiumGlowShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: _exportProgress,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          backgroundColor: cardBorderColor,
                          strokeWidth: 4,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Membuat Animasi Boomerang...',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_exportProgress * 100).round()}% Selesai',
                          style: TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 5. Paywall Dialog Screen Overlay (Glassmorphism)
          if (_showPaywall)
            Positioned.fill(
              child: Container(
                color: cardBgColor.withOpacity(0.94),
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
                            color: primaryColor.withOpacity(0.06),
                            blurRadius: 20,
                            spreadRadius: 4,
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
                              Icons.face_retouching_natural_rounded,
                              color: primaryColor,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                           Text(
                            'Uji Riasan 2D Statis',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                           Text(
                            'Eksperimen shade dasar makeup, lipstick, dan blush-on interaktif langsung pada foto selfie Anda!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: textMutedColor,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Fitur Unggulan
                          _buildPaywallFeature('Pemetaan Face Mesh Presisi di Atas Foto'),
                          _buildPaywallFeature('Overlay Shade Dasaran (Foundation) Nyata'),
                          _buildPaywallFeature('Lipstik Custom (Matte & Glossy Finishing)'),
                          _buildPaywallFeature('Rona Pipi (Blush-on) Terkalibrasi'),
                          _buildPaywallFeature('Bebas Batasan Uji Coba & Iklan'),

                          const SizedBox(height: 28),

                          // Beli Premium
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

                          // Demo Gratis
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

                          // Tombol Kembali
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
  }





  Widget _buildTabButton(String label, int index) {
    final bool isAct = _activeCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeCategoryIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isAct ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isAct ? FontWeight.bold : FontWeight.normal,
            color: isAct ? Colors.white : textMutedColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double val, ValueChanged<double> onChg) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style:  TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: cardBorderColor,
              thumbColor: primaryColor,
              trackHeight: 3,
            ),
            child: Slider(
              value: val,
              min: 0.0,
              max: 1.0,
              onChanged: onChg,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${(val * 100).round()}%',
            textAlign: TextAlign.right,
            style:  TextStyle(color: textMutedColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildColorCircle(Color color, String name, bool isSel, VoidCallback onTap, {bool isRecommended = false}) {
    final bool isClear = color == Colors.transparent || color.opacity == 0.0;
    final bool isMatched = _lastMatchedShadeName != null && 
        (name.toLowerCase().trim() == _lastMatchedShadeName!.toLowerCase().trim() ||
         name.toLowerCase().contains(_lastMatchedShadeName!.toLowerCase()) ||
         _lastMatchedShadeName!.toLowerCase().contains(name.toLowerCase()));

    final bool showBadge = (isMatched || isRecommended) && !isClear;

    Widget circle = Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isClear ? Colors.grey[200] : color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSel ? textColor : (isClear ? Colors.grey[400]!.withOpacity(0.3) : Colors.transparent),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: isClear
          ? Center(
              child: Icon(
                Icons.block_flipped,
                color: isSel ? textColor : Colors.grey[600],
                size: 16,
              ),
            )
          : (isSel
              ? Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: ThemeData.estimateBrightnessForColor(color) == Brightness.light ? Colors.black : Colors.white,
                    size: 16,
                  ),
                )
              : null),
    );

    if (showBadge) {
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            circle,
            Positioned(
              top: -2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(1),
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
      onTap: onTap,
      child: circle,
    );
  }

  Widget _buildPaywallFeature(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
           Icon(Icons.check_circle_rounded, color: primaryColor, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style:  TextStyle(color: textMutedColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
