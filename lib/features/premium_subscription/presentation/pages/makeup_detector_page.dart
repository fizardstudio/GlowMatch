import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:isar/isar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/database_service.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../../../core/utils/image_processor.dart';
import '../../../../core/utils/widget_helper.dart';
import '../../../premium_subscription/data/models/app_settings.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';

class MakeupDetectorPage extends StatefulWidget {
  const MakeupDetectorPage({super.key});

  @override
  State<MakeupDetectorPage> createState() => _MakeupDetectorPageState();
}

class _MakeupDetectorPageState extends State<MakeupDetectorPage> with WidgetsBindingObserver {
  final Isar _isar = DatabaseService().isar;
  bool _isPremium = false;
  bool _showPaywall = true;
  bool _isDemoActive = false;
  Timer? _demoTimer;
  int _demoSecondsLeft = 60;

  // ML Kit Face Detector
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // States
  String? _imagePath;
  bool _isLoading = false;
  Face? _detectedFace;
  int _originalWidth = 0;
  int _originalHeight = 0;

  // Extracted Colors
  Color? _detectedLipstickColor;
  Color? _detectedBlushColor;
  Color? _detectedSkinColor;

  // Matched Products
  ProductShade? _matchedLipstick;
  double _lipstickMatchPercent = 0.0;

  ProductShade? _matchedBlush;
  double _blushMatchPercent = 0.0;

  ProductShade? _matchedFoundation;
  double _foundationMatchPercent = 0.0;

  // Active Highlight Pin
  String _selectedPin = 'lipstick'; // 'lipstick', 'blush', 'foundation'

  // Standard cosmetics mapping database lists
  final List<Map<String, dynamic>> _presetLipsticks = [
    {"brand": "Wardah", "product": "Everyday Matte Lip Shot", "shade": "05 Classic Red", "hex": "#D81B60", "url": "https://shopee.co.id/wardahofficial"},
    {"brand": "Wardah", "product": "Colorfit Last All Day Lip Paint", "shade": "02 Dear Jenny", "hex": "#AD1457", "url": "https://shopee.co.id/wardahofficial"},
    {"brand": "Maybelline", "product": "Sensational Liquid Matte", "shade": "06 Best Babe", "hex": "#FF7043", "url": "https://shopee.co.id/maybellineindonesia"},
    {"brand": "Make Over", "product": "Intense Matte Lip Cream", "shade": "012 Vampy", "hex": "#8E24AA", "url": "https://shopee.co.id/makeoverofficial"},
    {"brand": "Wardah", "product": "Exclusive Matte Lip Cream", "shade": "11 Oh so Nude", "hex": "#8D6E63", "url": "https://shopee.co.id/wardahofficial"},
    {"brand": "Maybelline", "product": "Superstay Matte Ink", "shade": "118 Dancer", "hex": "#B71C1C", "url": "https://shopee.co.id/maybellineindonesia"},
    {"brand": "Wardah", "product": "Colorfit Last All Day Lip Paint", "shade": "03 Peach Sheen", "hex": "#E57373", "url": "https://shopee.co.id/wardahofficial"},
    {"brand": "Make Over", "product": "Intense Matte Lip Cream", "shade": "004 Vanity", "hex": "#C2185B", "url": "https://shopee.co.id/makeoverofficial"},
  ];

  final List<Map<String, dynamic>> _presetBlushes = [
    {"brand": "Wardah", "product": "Colorfit Cream Blush", "shade": "01 Sand Coral", "hex": "#FF8A80", "url": "https://shopee.co.id/wardahofficial"},
    {"brand": "Wardah", "product": "Exclusive Blush On", "shade": "01 Rosy Pink", "hex": "#FF80AB", "url": "https://shopee.co.id/wardahofficial"},
    {"brand": "Make Over", "product": "Cheek Marquee Blush On", "shade": "04 Tupper Rose", "hex": "#E91E63", "url": "https://shopee.co.id/makeoverofficial"},
    {"brand": "Wardah", "product": "Exclusive Blush On", "shade": "02 Peach", "hex": "#FFB74D", "url": "https://shopee.co.id/wardahofficial"},
    {"brand": "Make Over", "product": "Cheek Marquee Blush On", "shade": "08 Honey Spice", "hex": "#FF8F00", "url": "https://shopee.co.id/makeoverofficial"},
    {"brand": "Make Over", "product": "Cheek Marquee Blush On", "shade": "05 Burgundy", "hex": "#BA68C8", "url": "https://shopee.co.id/makeoverofficial"},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPremiumStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDemoTimer();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _checkPremiumStatus() async {
    final settings = await _isar.appSettings.get(0);
    if (settings != null && settings.isPremium) {
      setState(() {
        _isPremium = true;
        _showPaywall = false;
      });
    }
  }

  void _activatePremium() async {
    final settings = AppSettings()
      ..id = 0
      ..isPremium = true;
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });
    setState(() {
      _isPremium = true;
      _showPaywall = false;
      _isDemoActive = false;
    });
    _stopDemoTimer();
    WidgetHelper.updateExpiryWidget();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selamat! Fitur Premium Berhasil Diaktifkan secara Permanen. 👑'),
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

  Future<void> _pickImage(ImageSource source) async {
    if (!_isPremium && !_isDemoActive) {
      setState(() {
        _showPaywall = true;
      });
      return;
    }

    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(source: source);
      if (file != null) {
        _processAndAnalyzeImage(file.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat gambar: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _processAndAnalyzeImage(String path) async {
    setState(() {
      _isLoading = true;
      _imagePath = path;
      _detectedFace = null;
    });

    try {
      final file = File(path);
      // Baca resolusi asli
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final uiImg = frame.image;
      _originalWidth = uiImg.width;
      _originalHeight = uiImg.height;

      // Deteksi wajah ML Kit
      final inputImage = InputImage.fromFilePath(path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        throw Exception("Tidak ada wajah terdeteksi. Silakan pilih foto dengan wajah yang terlihat jelas.");
      }

      final face = faces.first;
      
      // Decode gambar luring
      final decodedImg = await ImageProcessor.loadAndDecodeImage(path);
      if (decodedImg == null) {
        throw Exception("Gagal memproses detail warna gambar.");
      }

      // 1. Ekstrak warna lipstik
      final lipRgb = _extractLipColor(decodedImg, face);
      final lipstickColor = Color.fromARGB(255, lipRgb[0], lipRgb[1], lipRgb[2]);

      // 2. Ekstrak warna blush-on
      final blushRgb = _extractBlushColor(decodedImg, face);
      final blushColor = Color.fromARGB(255, blushRgb[0], blushRgb[1], blushRgb[2]);

      // 3. Ekstrak warna kulit
      final skinRgb = _extractSkinColor(decodedImg, face);
      final skinColor = Color.fromARGB(255, skinRgb[0], skinRgb[1], skinRgb[2]);

      // --- MENCARI LIPSTIK TERDEKAT (CIEDE2000 luring) ---
      final lipLab = ColorCalculator.rgbToLab(lipRgb[0], lipRgb[1], lipRgb[2]);
      double minLipDelta = double.infinity;
      Map<String, dynamic>? closestLip;
      for (final raw in _presetLipsticks) {
        final hexColor = _parseHexColor(raw['hex']!);
        final pLab = ColorCalculator.rgbToLab(hexColor.red, hexColor.green, hexColor.blue);
        final dist = ColorCalculator.deltaE00(lipLab, pLab);
        if (dist < minLipDelta) {
          minLipDelta = dist;
          closestLip = raw;
        }
      }

      // --- MENCARI BLUSH-ON TERDEKAT (CIEDE2000 luring) ---
      final blushLab = ColorCalculator.rgbToLab(blushRgb[0], blushRgb[1], blushRgb[2]);
      double minBlushDelta = double.infinity;
      Map<String, dynamic>? closestBlush;
      for (final raw in _presetBlushes) {
        final hexColor = _parseHexColor(raw['hex']!);
        final pLab = ColorCalculator.rgbToLab(hexColor.red, hexColor.green, hexColor.blue);
        final dist = ColorCalculator.deltaE00(blushLab, pLab);
        if (dist < minBlushDelta) {
          minBlushDelta = dist;
          closestBlush = raw;
        }
      }

      // --- MENCARI FOUNDATION TERDEKAT (Dari database Isar luring) ---
      final skinLab = ColorCalculator.rgbToLab(skinRgb[0], skinRgb[1], skinRgb[2]);
      double minFoundDelta = double.infinity;
      ProductShade? closestFound;
      final dbFoundations = await _isar.productShades.filter().categoryEqualTo("Foundation").findAll();
      for (final prod in dbFoundations) {
        final dist = ColorCalculator.deltaE00(skinLab, LabColor(prod.l, prod.a, prod.b));
        if (dist < minFoundDelta) {
          minFoundDelta = dist;
          closestFound = prod;
        }
      }

      setState(() {
        _detectedFace = face;
        _detectedLipstickColor = lipstickColor;
        _detectedBlushColor = blushColor;
        _detectedSkinColor = skinColor;

        if (closestLip != null) {
          _matchedLipstick = ProductShade()
            ..brand = closestLip['brand']!
            ..productName = closestLip['product']!
            ..shadeName = closestLip['shade']!
            ..hexCode = closestLip['hex']!
            ..affiliateUrl = closestLip['url']!;
          _lipstickMatchPercent = ColorCalculator.calculateMatchPercentage(minLipDelta);
        }

        if (closestBlush != null) {
          _matchedBlush = ProductShade()
            ..brand = closestBlush['brand']!
            ..productName = closestBlush['product']!
            ..shadeName = closestBlush['shade']!
            ..hexCode = closestBlush['hex']!
            ..affiliateUrl = closestBlush['url']!;
          _blushMatchPercent = ColorCalculator.calculateMatchPercentage(minBlushDelta);
        }

        if (closestFound != null) {
          _matchedFoundation = closestFound;
          _foundationMatchPercent = ColorCalculator.calculateMatchPercentage(minFoundDelta);
        }

        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _imagePath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analisis gagal: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Menerjemahkan format HEX
  Color _parseHexColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // Mengambil sampel warna bibir
  List<int> _extractLipColor(img.Image imgData, Face face) {
    final upperLip = face.contours[FaceContourType.upperLipTop]?.points;
    if (upperLip == null || upperLip.isEmpty) return [200, 50, 60];
    final centerPt = upperLip[upperLip.length ~/ 2];
    return ImageProcessor.calculateAverageRgb(
      imgData,
      startX: centerPt.x - 8,
      startY: centerPt.y - 8,
      width: 16,
      height: 16,
    );
  }

  // Mengambil sampel warna pipi
  List<int> _extractBlushColor(img.Image imgData, Face face) {
    final leftEye = face.contours[FaceContourType.leftEye]?.points;
    final rightEye = face.contours[FaceContourType.rightEye]?.points;
    final noseTip = face.contours[FaceContourType.noseBridge]?.points;

    if (leftEye == null || rightEye == null || noseTip == null || noseTip.isEmpty) {
      return [230, 140, 140];
    }

    double lex = leftEye.map((p) => p.x).reduce((a, b) => a + b) / leftEye.length;
    double ley = leftEye.map((p) => p.y).reduce((a, b) => a + b) / leftEye.length;
    double rex = rightEye.map((p) => p.x).reduce((a, b) => a + b) / rightEye.length;
    double rey = rightEye.map((p) => p.y).reduce((a, b) => a + b) / rightEye.length;

    final nTip = noseTip.last;
    final double shiftX = (rex - (_detectedFace!.contours[FaceContourType.leftEye]!.points.first.x)) * 0.15;
    final int cx = (rex + shiftX).round();
    final int cy = (rey + (nTip.y - rey) * 0.65).round();

    return ImageProcessor.calculateAverageRgb(
      imgData,
      startX: cx - 12,
      startY: cy - 12,
      width: 24,
      height: 24,
    );
  }

  // Mengambil sampel warna kulit (dahi)
  List<int> _extractSkinColor(img.Image imgData, Face face) {
    final rect = face.boundingBox;
    final int fx = (rect.left + rect.width / 2).round();
    final int fy = (rect.top + rect.height * 0.15).round();

    return ImageProcessor.calculateAverageRgb(
      imgData,
      startX: fx - 12,
      startY: fy - 12,
      width: 24,
      height: 24,
    );
  }

  // Translasi letak pin dari foto asli ke koordinat layar fitted
  Offset _mapPointToScreen(int px, int py, Size fittedSize) {
    if (_originalWidth == 0 || _originalHeight == 0) return Offset.zero;
    final double scaleX = fittedSize.width / _originalWidth;
    final double scaleY = fittedSize.height / _originalHeight;
    return Offset(px * scaleX, py * scaleY);
  }

  // Helper mendapatkan ukuran Fitted Contain
  Size _getFittedImageSize(double maxWidth, double maxHeight, double imgWidth, double imgHeight) {
    if (imgWidth == 0 || imgHeight == 0) return Size.zero;
    final double srcAspect = imgWidth / imgHeight;
    final double dstAspect = maxWidth / maxHeight;
    if (srcAspect > dstAspect) {
      return Size(maxWidth, maxWidth / srcAspect);
    } else {
      return Size(maxHeight * srcAspect, maxHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F6),
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          'AI Makeup Detector',
          style: TextStyle(color: Color(0xFF3E3635), fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        backgroundColor: const Color(0xFFFCF9F6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E3635)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Viewport Utama
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
                              color: const Color(0xFFE5A99E).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_camera_rounded, size: 72, color: Color(0xFFE5A99E)),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Deteksi Kosmetik Wajah',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3E3635)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Unggah foto wajah bermakeup dari galeri atau potret langsung untuk memindai lipstik, blush-on, dan foundation yang sedang dipakai.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF8E807E), height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE5A99E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Pilih Galeri', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _pickImage(ImageSource.gallery),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF3E3635),
                                  side: const BorderSide(color: Color(0xFFE5A99E)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Ambil Foto', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _pickImage(ImageSource.camera),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5A99E))),
                            const SizedBox(height: 16),
                            Text('Menganalisis Riasan Wajah secara Luring...', style: TextStyle(color: Color(0xFF3E3635), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final double areaWidth = constraints.maxWidth;
                          final double areaHeight = constraints.maxHeight - 240; // Sisakan ruang card bawah

                          final Size fittedSize = _getFittedImageSize(
                            areaWidth,
                            areaHeight,
                            _originalWidth.toDouble(),
                            _originalHeight.toDouble(),
                          );

                          final double topPadding = (areaHeight - fittedSize.height).clamp(0.0, double.infinity) / 2;

                          // Koordinat Pin
                          Offset? lipOffset;
                          Offset? blushOffset;
                          Offset? skinOffset;

                          if (_detectedFace != null) {
                            // Bibir
                            final lips = _detectedFace!.contours[FaceContourType.upperLipTop]?.points;
                            if (lips != null && lips.isNotEmpty) {
                              final pt = lips[lips.length ~/ 2];
                              lipOffset = _mapPointToScreen(pt.x, pt.y, fittedSize);
                            }

                            // Blush (pipi kanan)
                            final rightEye = _detectedFace!.contours[FaceContourType.rightEye]?.points;
                            final noseTip = _detectedFace!.contours[FaceContourType.noseBridge]?.points;
                            if (rightEye != null && rightEye.isNotEmpty && noseTip != null && noseTip.isNotEmpty) {
                              double rex = rightEye.map((p) => p.x).reduce((a, b) => a + b) / rightEye.length;
                              double rey = rightEye.map((p) => p.y).reduce((a, b) => a + b) / rightEye.length;
                              final nTip = noseTip.last;
                              final double shiftX = (rex - (_detectedFace!.contours[FaceContourType.leftEye]!.points.first.x)) * 0.15;
                              final int cx = (rex + shiftX).round();
                              final int cy = (rey + (nTip.y - rey) * 0.65).round();
                              blushOffset = _mapPointToScreen(cx, cy, fittedSize);
                            }

                            // Kulit (Dahi)
                            final rect = _detectedFace!.boundingBox;
                            final int fx = (rect.left + rect.width / 2).round();
                            final int fy = (rect.top + rect.height * 0.15).round();
                            skinOffset = _mapPointToScreen(fx, fy, fittedSize);
                          }

                          return Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: topPadding),
                              child: SizedBox(
                                width: fittedSize.width,
                                height: fittedSize.height,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Foto utama
                                    Positioned.fill(
                                      child: Image.file(
                                        File(_imagePath!),
                                        fit: BoxFit.fill,
                                      ),
                                    ),

                                    // Pin Lipstik
                                    if (lipOffset != null)
                                      Positioned(
                                        left: lipOffset.dx - 18,
                                        top: lipOffset.dy - 18,
                                        child: _buildInteractivePin(
                                          type: 'lipstick',
                                          color: _detectedLipstickColor ?? Colors.red,
                                          isSelected: _selectedPin == 'lipstick',
                                        ),
                                      ),

                                    // Pin Blush-on
                                    if (blushOffset != null)
                                      Positioned(
                                        left: blushOffset.dx - 18,
                                        top: blushOffset.dy - 18,
                                        child: _buildInteractivePin(
                                          type: 'blush',
                                          color: _detectedBlushColor ?? Colors.pink,
                                          isSelected: _selectedPin == 'blush',
                                        ),
                                      ),

                                    // Pin Foundation
                                    if (skinOffset != null)
                                      Positioned(
                                        left: skinOffset.dx - 18,
                                        top: skinOffset.dy - 18,
                                        child: _buildInteractivePin(
                                          type: 'foundation',
                                          color: _detectedSkinColor ?? Colors.orange,
                                          isSelected: _selectedPin == 'foundation',
                                        ),
                                      ),

                                    // Tombol Kembali melayang di kiri atas
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.white.withOpacity(0.9),
                                        child: IconButton(
                                          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E3635)),
                                          onPressed: () {
                                            setState(() {
                                              _imagePath = null;
                                              _detectedFace = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 2. Card Rekomendasi di Bagian Bawah
          if (_imagePath != null && !_isLoading && _detectedFace != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 230,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 16, spreadRadius: 4),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tab Selector / Header
                    Row(
                      children: [
                        _buildBottomTabButton('lipstick', '💄 Lipstik'),
                        const SizedBox(width: 8),
                        _buildBottomTabButton('blush', '🌸 Blush-On'),
                        const SizedBox(width: 8),
                        _buildBottomTabButton('foundation', '🧴 Dasaran/Base'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Detail produk terdeteksi
                    Expanded(
                      child: _buildMatchedProductView(),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Demo Mode Timer Overlay
          if (_isDemoActive && !_showPaywall && _imagePath != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5A99E).withOpacity(0.5)),
                ),
                child: Text(
                  'Demo: ${_demoSecondsLeft}s',
                  style: const TextStyle(color: Color(0xFFE5A99E), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 4. Paywall Dialog Screen Overlay (Glassmorphism)
          if (_showPaywall)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.94),
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFF2ECE7), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE5A99E).withOpacity(0.06),
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
                              color: const Color(0xFFE5A99E).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_enhance_outlined,
                              color: Color(0xFFE5A99E),
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'AI Makeup Detector',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3E3635)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Unggah foto apa saja (dari medsos, internet, dll) untuk memindai jenis lipstik, blush-on, atau foundation yang sedang dikenakan dan beli produknya secara luring!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF8E807E), height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          // Benefits
                          _buildPaywallBenefit('Deteksi Warna Akurat luring'),
                          _buildPaywallBenefit('Pencarian Shade Komersial Riil'),
                          _buildPaywallBenefit('Tautan Belanja Affiliate E-Commerce'),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5A99E),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: _activatePremium,
                            child: const Text('Aktifkan Premium Permanen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8E807E),
                              side: const BorderSide(color: Color(0xFFF2ECE7)),
                              minimumSize: const Size(double.infinity, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _startDemoMode,
                            child: const Text('Coba Demo Gratis (1 Menit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildPaywallBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFFE5A99E), size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF3E3635), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInteractivePin({
    required String type,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPin = type;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Efek Ring Berdenyut
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isSelected ? 36 : 28,
            height: isSelected ? 36 : 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          // Bulatan Pusat
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabButton(String type, String label) {
    final bool isSelected = _selectedPin == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPin = type;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE5A99E).withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFE5A99E).withOpacity(0.3) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFFE5A99E) : const Color(0xFF8E807E),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchedProductView() {
    ProductShade? prod;
    double matchPercent = 0.0;
    Color? detColor;
    String label = '';

    if (_selectedPin == 'lipstick') {
      prod = _matchedLipstick;
      matchPercent = _lipstickMatchPercent;
      detColor = _detectedLipstickColor;
      label = 'Warna Lipstik';
    } else if (_selectedPin == 'blush') {
      prod = _matchedBlush;
      matchPercent = _blushMatchPercent;
      detColor = _detectedBlushColor;
      label = 'Warna Blush-On';
    } else {
      prod = _matchedFoundation;
      matchPercent = _foundationMatchPercent;
      detColor = _detectedSkinColor;
      label = 'Warna Kulit/Dasaran';
    }

    if (detColor == null) {
      return const Center(child: Text('Data warna belum diekstrak.'));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Swatch warna terdeteksi
        Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: detColor,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF2ECE7), width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '#${detColor.value.toRadixString(16).substring(2).toUpperCase()}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8E807E)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF3E3635)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(width: 20),
        // Rincian produk tercocok
        Expanded(
          child: prod == null
              ? const Center(
                  child: Text(
                    'Tidak ada produk kosmetik yang cukup identik di database Isar.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8E807E)),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              prod.brand,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE5A99E)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5A99E).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${matchPercent.toStringAsFixed(0)}% Match',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5A99E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prod.productName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E3635)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shade: ${prod.shadeName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8E807E)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A99E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: const Text('Beli di Shopee/Tokopedia 🛒', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final uri = Uri.parse(prod!.affiliateUrl);
                        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                          // success
                        } else {
                          // fallback
                        }
                      },
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
