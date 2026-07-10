import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../data/models/app_settings.dart';
import '../widgets/photo_makeup_painter.dart';
import '../../../../core/utils/widget_helper.dart';

class PhotoTryOnPage extends StatefulWidget {
  final String? initialFilePath;

  const PhotoTryOnPage({super.key, this.initialFilePath});

  @override
  State<PhotoTryOnPage> createState() => _PhotoTryOnPageState();
}

class _PhotoTryOnPageState extends State<PhotoTryOnPage> with WidgetsBindingObserver {
  final Isar _isar = DatabaseService().isar;
  bool _isPremium = false;
  bool _showPaywall = true;

  // ML Kit Face Detector
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // States gambar & analisis
  String? _imagePath;
  bool _isLoadingImage = false;
  Face? _detectedFace;
  int _originalWidth = 0;
  int _originalHeight = 0;

  // Active Category (0 = Dasaran/Base, 1 = Lipstik, 2 = Blush-On)
  int _activeCategoryIndex = 0;

  // Filter Parameters - Base Makeup (Foundation)
  Color _selectedFoundationColor = const Color(0xFFF3D3C4); // Fair Nude
  double _foundationOpacity = 0.0; // Default 0% (tidak aktif)

  // Filter Parameters - Lipstick (Bibir)
  Color _selectedLipstickColor = const Color(0xFFD81B60); // Cherry Red
  double _lipstickOpacity = 0.0; // Default 0% (tidak aktif)
  String _lipstickFinishing = 'matte'; // 'matte' atau 'glossy'

  // Filter Parameters - Blush-On (Pipi)
  Color _selectedBlushColor = const Color(0xFFFF8A80); // Soft Coral
  double _blushOpacity = 0.0; // Default 0% (tidak aktif)

  double _sliderX = 180.0; // Koordinat pembagi horizontal (default diatur di didChangeDependencies)
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPremiumStatus();

    // Muat foto awal jika dilewatkan lewat argumen navigasi
    if (widget.initialFilePath != null) {
      _processImageFile(widget.initialFilePath!);
    }
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
    if (settings != null && settings.isPremium) {
      setState(() {
        _isPremium = true;
        _showPaywall = false;
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
      final XFile? selectedFile = await picker.pickImage(source: source);
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

  // Fungsi untuk mensimulasikan penyimpanan kombinasi riasan premium
  void _saveCurrentMakeupLook() {
    if (!_isPremium && !_isDemoActive) {
      setState(() {
        _showPaywall = true;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kombinasi riasan Anda sukses disimpan ke Isar Database! 💖'),
        backgroundColor: Color(0xFFE5A99E),
      ),
    );
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
      backgroundColor: const Color(0xFFFCF9F6),
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Uji Riasan 2D Foto',
              style: TextStyle(
                color: Color(0xFF3E3635),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            _isPremium
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A99E),
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
                      color: const Color(0xFF8E807E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(color: Color(0xFF8E807E), fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
        backgroundColor: const Color(0xFFFCF9F6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E3635)),
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
                              color: const Color(0xFFE5A99E).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_photo_alternate_rounded, size: 72, color: Color(0xFFE5A99E)),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Belum Ada Foto Terpilih',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3E3635)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ambil foto selfie baru menggunakan kamera ponsel atau unggah foto dari galeri untuk memulai simulasi riasan statis.',
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
                                label: const Text('Galeri 🖼️', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5A99E))),
                            SizedBox(height: 16),
                            Text('Menganalisis Face Mesh Foto...', style: TextStyle(color: Color(0xFF3E3635), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final double areaWidth = constraints.maxWidth;
                          final double areaHeight = constraints.maxHeight - (_showControls ? 230 : 0);

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

                          return Center(
                            child: SizedBox(
                              width: fittedSize.width,
                              height: fittedSize.height,
                              child: Stack(
                                children: [
                                  // Foto Asli
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
                                          foundationColor: _selectedFoundationColor,
                                          foundationOpacity: _foundationOpacity,
                                          lipstickColor: _selectedLipstickColor,
                                          lipstickOpacity: _lipstickOpacity,
                                          lipstickFinishing: _lipstickFinishing,
                                          blushColor: _selectedBlushColor,
                                          blushOpacity: _blushOpacity,
                                          sliderX: _sliderX,
                                        ),
                                      ),
                                    ),

                                  // Slider Garis Pembagi
                                  if (!_showPaywall)
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
                                                color: const Color(0xFFE5A99E),
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

                                  // Floating Actions Ganti/Ambil Foto di Pojok Kiri Atas
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: Row(
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.9),
                                            foregroundColor: const Color(0xFF3E3635),
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
                                            backgroundColor: Colors.white.withOpacity(0.9),
                                            foregroundColor: const Color(0xFF3E3635),
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

          // 3. Toggle Panel Kontrol
          if (_imagePath != null && !_showPaywall)
            Positioned(
              bottom: _showControls ? 230 : 24,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'photo_toggle_controls_fab',
                onPressed: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                backgroundColor: Colors.white.withOpacity(0.92),
                mini: true,
                shape: CircleBorder(
                  side: BorderSide(
                    color: const Color(0xFFE5A99E).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _showControls ? Icons.keyboard_arrow_down_rounded : Icons.tune_rounded,
                  color: const Color(0xFF3E3635),
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
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border.all(color: const Color(0xFFF2ECE7), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tab Selector Kategori
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCF9F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton('Dasaran Base', 0),
                          _buildTabButton('Lipstik', 1),
                          _buildTabButton('Blush-On', 2),
                        ],
                      ),
                    ),

                    // Sliders & Toggles khusus Tab Aktif
                    if (_activeCategoryIndex == 0) ...[
                      // Opacity Foundation
                      _buildSliderRow('Opasitas Base', _foundationOpacity, (val) {
                        setState(() {
                          _foundationOpacity = val;
                        });
                      }),
                      const SizedBox(height: 8),
                      // Palet Warna Foundation
                      SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _foundationColors.length,
                          itemBuilder: (context, index) {
                            final fColor = _foundationColors[index];
                            final isSel = _selectedFoundationColor == fColor['color'];
                            return _buildColorCircle(fColor['color'], fColor['name'], isSel, () {
                              setState(() {
                                _selectedFoundationColor = fColor['color'];
                                if (_foundationOpacity == 0.0) _foundationOpacity = 0.35; // Aktifkan jika masih 0%
                              });
                            });
                          },
                        ),
                      ),
                    ] else if (_activeCategoryIndex == 1) ...[
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
                              color: const Color(0xFFFCF9F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF2ECE7)),
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
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _lipstickColors.length,
                          itemBuilder: (context, index) {
                            final lColor = _lipstickColors[index];
                            final isSel = _selectedLipstickColor == lColor['color'];
                            return _buildColorCircle(lColor['color'], lColor['name'], isSel, () {
                              setState(() {
                                _selectedLipstickColor = lColor['color'];
                                if (_lipstickOpacity == 0.0) _lipstickOpacity = 0.40;
                              });
                            });
                          },
                        ),
                      ),
                    ] else ...[
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
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _blushColors.length,
                          itemBuilder: (context, index) {
                            final bColor = _blushColors[index];
                            final isSel = _selectedBlushColor == bColor['color'];
                            return _buildColorCircle(bColor['color'], bColor['name'], isSel, () {
                              setState(() {
                                _selectedBlushColor = bColor['color'];
                                if (_blushOpacity == 0.0) _blushOpacity = 0.25;
                              });
                            });
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // Action Buttons (Simpan Kombinasi)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A99E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.favorite_rounded, size: 18),
                      label: const Text('Simpan Kombinasi Riasan 💖', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _saveCurrentMakeupLook,
                    ),
                  ],
                ),
              ),
            ),

          // 5. Paywall Dialog Screen Overlay (Glassmorphism)
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
                              Icons.face_retouching_natural_rounded,
                              color: Color(0xFFE5A99E),
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Uji Riasan 2D Statis',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE5A99E),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Eksperimen shade dasar makeup, lipstick, dan blush-on interaktif langsung pada foto selfie Anda!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E807E),
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
                              backgroundColor: const Color(0xFFE5A99E),
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
                              foregroundColor: const Color(0xFF3E3635),
                              side: const BorderSide(color: Color(0xFFF2ECE7)),
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
                            child: const Text(
                              'Kembali',
                              style: TextStyle(color: Color(0xFF8E807E), fontSize: 12),
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
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeCategoryIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isAct ? const Color(0xFFE5A99E) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isAct ? FontWeight.bold : FontWeight.normal,
              color: isAct ? Colors.white : const Color(0xFF8E807E),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishingButton(String label, bool isSel) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _lipstickFinishing = label.toLowerCase();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFE5A99E) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSel ? Colors.white : const Color(0xFF3E3635),
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
            style: const TextStyle(color: Color(0xFF3E3635), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFE5A99E),
              inactiveTrackColor: const Color(0xFFF2ECE7),
              thumbColor: const Color(0xFFE5A99E),
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
            style: const TextStyle(color: Color(0xFF8E807E), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildColorCircle(Color color, String name, bool isSel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSel ? const Color(0xFF3E3635) : Colors.transparent,
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
      ),
    );
  }

  Widget _buildPaywallFeature(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFFE5A99E), size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF8E807E), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
