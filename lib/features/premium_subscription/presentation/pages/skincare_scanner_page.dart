import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import '../../../../../core/network/database_service.dart';
import '../../../../../core/theme/theme_manager.dart';
import '../../data/models/app_settings.dart';
import '../../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../../../../core/utils/skincare_ocr_parser.dart';
import '../../../../core/data/models/skincare_ingredient.dart';

class SkincareScannerPage extends StatefulWidget {
  const SkincareScannerPage({super.key});

  @override
  State<SkincareScannerPage> createState() => _SkincareScannerPageState();
}

class _SkincareScannerPageState extends State<SkincareScannerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final Isar _isar = DatabaseService().isar;
  final ImagePicker _picker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraPermissionDenied = false;
  bool _isAnalyzing = false;

  // Animation for scanner laser line
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  // Selected Skin Type
  String _selectedSkinType = 'normal'; // default
  bool _isPremium = false;

  final Map<String, String> _skinTypes = {
    'dry': 'Kering (Dry)',
    'oily': 'Berminyak (Oily)',
    'normal': 'Normal',
    'sensitive': 'Sensitif',
    'acne_prone': 'Berjerawat',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _initializeCamera();

    // Laser scanning animation setup
    _laserController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_laserController);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _loadSettings() async {
    final settings = await _isar.appSettings.get(0);
    if (settings != null) {
      setState(() {
        _isPremium = settings.isPremium;
        if (settings.lastSelectedSkinType != null) {
          _selectedSkinType = settings.lastSelectedSkinType!;
        }
      });
    }
  }

  Future<void> _saveSkinType(String skinType) async {
    await _isar.writeTxn(() async {
      final settings = await _isar.appSettings.get(0) ?? (AppSettings()..id = 0..isPremium = _isPremium);
      settings.lastSelectedSkinType = skinType;
      await _isar.appSettings.put(settings);
    });
    setState(() {
      _selectedSkinType = skinType;
    });
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Gunakan kamera belakang untuk pemindaian teks kosmetik
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraPermissionDenied = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraPermissionDenied = true;
        });
      }
    }
  }

  // Menjalankan OCR dan parsing pada berkas gambar hasil jepret/pilihan galeri
  Future<void> _processImageOcr(String imagePath) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      // 1. Ekstrak teks secara luring
      final String extractedText = await SkincareOcrParser.extractTextFromImage(imagePath);
      
      // 2. Parse kandungan bahan aktif
      final List<SkincareIngredient> matched = SkincareOcrParser.parseIngredients(extractedText);
      
      // 3. Hitung skor kecocokan
      final Map<String, dynamic> result = SkincareOcrParser.calculateCompatibility(
        matchedIngredients: matched,
        skinTypeKey: _selectedSkinType,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        _showAnalysisResultSheet(matched, result);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menganalisis kemasan skincare. Coba lagi.')),
        );
      }
    }
  }

  // Mengambil gambar dari Kamera
  Future<void> _captureAndScan() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      await _processImageOcr(imageFile.path);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil gambar dari kamera.')),
      );
    }
  }

  // Memilih gambar dari Galeri
  Future<void> _pickAndScanFromGallery() async {
    try {
      final XFile? imageFile = await _picker.pickImage(source: ImageSource.gallery);
      if (imageFile != null) {
        await _processImageOcr(imageFile.path);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil gambar dari galeri.')),
      );
    }
  }

  // Tampilkan Bottom Sheet dengan Hasil Analisis Premium
  void _showAnalysisResultSheet(List<SkincareIngredient> ingredients, Map<String, dynamic> analysis) {
    final isDark = ThemeManager.isDark;
    final textColor = ThemeManager.textColor;
    final textMutedColor = ThemeManager.textMutedColor;
    final cardBgColor = ThemeManager.cardBgColor;
    final primaryColor = ThemeManager.primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFF7F5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF2ECE7),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                child: Column(
                  children: [
                    // Handle Bar Atas
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: textMutedColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Header Skor Kecocokan
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'HASIL ANALISIS KANDUNGAN',
                                    style: TextStyle(
                                      color: textMutedColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Radial Progress Chart
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 110,
                                        height: 110,
                                        child: CircularProgressIndicator(
                                          value: analysis['score'] / 100,
                                          strokeWidth: 10,
                                          backgroundColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF2ECE7),
                                          color: Color(analysis['statusColor']),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${analysis['score']}%',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            'Kecocokan',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: textMutedColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(analysis['statusColor']).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Color(analysis['statusColor']).withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      analysis['status'].toString().toUpperCase(),
                                      style: TextStyle(
                                        color: Color(analysis['statusColor']),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 2. Rekomendasi Deskripsi
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBgColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ThemeManager.cardBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: primaryColor, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Rekomendasi GlowMatch AI:',
                                        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    analysis['recommendation'],
                                    style: TextStyle(color: textMutedColor, fontSize: 11, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            // 3. Daftar Kandungan Terdeteksi
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kandungan Bahan Aktif (${ingredients.length})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _skinTypes[_selectedSkinType] ?? '',
                                    style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (ingredients.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 32),
                                  child: Column(
                                    children: [
                                      Icon(Icons.search_off_rounded, color: textMutedColor.withOpacity(0.4), size: 48),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tidak ada bahan aktif utama terdeteksi.\nKemungkinan produk ini berbahan dasar hidrasi ringan.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: textMutedColor, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: ingredients.length,
                                itemBuilder: (context, index) {
                                  final ing = ingredients[index];
                                  final double comp = ing.compatibility[_selectedSkinType] ?? 0.0;
                                  
                                  Color compColor = textMutedColor;
                                  String compSign = 'Netral';
                                  if (comp > 0) {
                                    compColor = Colors.green;
                                    compSign = '+${(comp * 100).round()}% Cocok';
                                  } else if (comp < 0) {
                                    compColor = Colors.red;
                                    compSign = '${(comp * 100).round()}% Kurang';
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: ThemeManager.cardBorderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ing.name,
                                                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Text(
                                              compSign,
                                              style: TextStyle(color: compColor, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ing.category,
                                          style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          ing.description,
                                          style: TextStyle(color: textMutedColor, fontSize: 11, height: 1.3),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Text('Risiko Iritasi: ', style: TextStyle(color: textMutedColor, fontSize: 10)),
                                                Row(
                                                  children: List.generate(5, (starIdx) {
                                                    return Icon(
                                                      Icons.warning_amber_rounded,
                                                      size: 11,
                                                      color: starIdx < ing.irritationScore
                                                          ? (ing.irritationScore >= 4 ? Colors.red : Colors.orange)
                                                          : textMutedColor.withOpacity(0.2),
                                                    );
                                                  }),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              'Skor: ${ing.irritationScore}/5',
                                              style: TextStyle(color: textMutedColor, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeManager.isDark;
    final textColor = ThemeManager.textColor;
    final textMutedColor = ThemeManager.textMutedColor;
    final primaryColor = ThemeManager.primaryColor;
    final cardBgColor = ThemeManager.cardBgColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFFFFDFD),
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: Text(
          'Skincare OCR Scanner',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Selector Tipe Kulit Horizontal
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _skinTypes.keys.length,
                  itemBuilder: (context, index) {
                    final key = _skinTypes.keys.elementAt(index);
                    final label = _skinTypes[key]!;
                    final isSelected = _selectedSkinType == key;

                    return GestureDetector(
                      onTap: () => _saveSkinType(key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : ThemeManager.cardBorderColor,
                          ),
                          boxShadow: isSelected ? ThemeManager.premiumGlowShadow : null,
                        ),
                        child: Text(
                          label,
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
              const SizedBox(height: 8),
              
              // 2. Viewfinder Kamera & View
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _isCameraInitialized && _cameraController != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_cameraController!),
                              
                              // Viewfinder Overlay Grid
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final double rectWidth = constraints.maxWidth * 0.8;
                                  final double rectHeight = constraints.maxHeight * 0.45;
                                  final double rectLeft = (constraints.maxWidth - rectWidth) / 2;
                                  final double rectTop = (constraints.maxHeight - rectHeight) / 2;

                                  return Stack(
                                    children: [
                                      // Darkened outer boundaries
                                      ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          Colors.black.withOpacity(0.6),
                                          BlendMode.srcOut,
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Container(
                                              color: Colors.black,
                                            ),
                                            Positioned(
                                              left: rectLeft,
                                              top: rectTop,
                                              width: rectWidth,
                                              height: rectHeight,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Frame border outline
                                      Positioned(
                                        left: rectLeft,
                                        top: rectTop,
                                        width: rectWidth,
                                        height: rectHeight,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: primaryColor, width: 2.5),
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                        ),
                                      ),
                                      // Animated laser lines
                                      AnimatedBuilder(
                                        animation: _laserAnimation,
                                        builder: (context, child) {
                                          final double currentTop = rectTop + (rectHeight * _laserAnimation.value);
                                          return Positioned(
                                            left: rectLeft + 6,
                                            top: currentTop,
                                            width: rectWidth - 12,
                                            height: 2.5,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    primaryColor.withOpacity(0.1),
                                                    primaryColor,
                                                    primaryColor.withOpacity(0.1),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Helper Text Overlay
                                      Positioned(
                                        bottom: 24,
                                        left: 16,
                                        right: 16,
                                        child: Text(
                                          'Posisikan teks kandungan bahan aktif skincare di dalam area pemindai',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          )
                        : Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: ThemeManager.cardBorderColor),
                            ),
                            child: _isCameraPermissionDenied
                                ? Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt_rounded, color: primaryColor, size: 44),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Izin Kamera Ditolak',
                                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Aplikasi memerlukan izin akses kamera belakang untuk memindai label teks kosmetik luring.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: textMutedColor, fontSize: 12, height: 1.4),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                          onPressed: _initializeCamera,
                                          child: const Text('Beri Akses Kamera', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(color: primaryColor),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Menginisialisasi Kamera...',
                                        style: TextStyle(color: textMutedColor, fontSize: 12),
                                      ),
                                    ],
                                  ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Actions Button Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Ambil dari Galeri
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: BorderSide(color: primaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isAnalyzing ? null : _pickAndScanFromGallery,
                        icon: Icon(Icons.photo_library_outlined, color: primaryColor, size: 20),
                        label: Text(
                          'Pilih Galeri',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Ambil Foto & Pindai
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          boxShadow: ThemeManager.premiumGlowShadow,
                          elevation: 0,
                        ),
                        onPressed: (_isCameraInitialized && !_isAnalyzing) ? _captureAndScan : null,
                        icon: const Icon(Icons.document_scanner_rounded, size: 20),
                        label: const Text(
                          'Ambil & Pindai',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),

          // 4. Loading overlay saat pemrosesan OCR berjalan
          if (_isAnalyzing)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 5,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Menganalisis kandungan produk...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mengekstrak teks & memvalidasi kecocokan secara luring',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
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
}
