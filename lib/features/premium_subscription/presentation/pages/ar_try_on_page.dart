import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:glowmatch/core/theme/theme_manager.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../data/models/app_settings.dart';
import '../widgets/lip_filter_painter.dart';
import '../../../../core/utils/widget_helper.dart';

class ArTryOnPage extends StatefulWidget {
  const ArTryOnPage({super.key});

  @override
  State<ArTryOnPage> createState() => _ArTryOnPageState();
}

class _ArTryOnPageState extends State<ArTryOnPage> with WidgetsBindingObserver {
  bool get isDark => ThemeManager.isDark;
  Color get textColor => ThemeManager.textColor;
  Color get textMutedColor => ThemeManager.textMutedColor;
  Color get cardBgColor => ThemeManager.cardBgColor;
  Color get cardBorderColor => ThemeManager.cardBorderColor;
  Color get primaryColor => ThemeManager.primaryColor;
  final Isar _isar = DatabaseService().isar;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isPremium = false;
  bool _showPaywall = true;

  // ML Kit Face Detector untuk penyejajaran bibir & pipi secara andal
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isProcessingFrame = false;
  Face? _detectedFace;
  int _imageWidth = 0;
  int _imageHeight = 0;

  // Active Category (0 = Lipstik, 1 = Blush-On)
  int _activeCategoryIndex = 0;

  // Filter Parameters - Lipstick (Bibir)
  Color _selectedLipstickColor = const Color(0xFFD81B60); // Cherry Red
  double _lipstickOpacity = 0.40; // Default 40%
  String _lipstickFinishing = 'matte'; // 'matte' atau 'glossy'

  // Filter Parameters - Blush-On (Pipi)
  Color _selectedBlushColor = const Color(0xFFFF8A80); // Soft Coral
  double _blushOpacity = 0.25; // Default 25%

  double _sliderX = 180.0; // Koordinat pembagi horizontal (default diatur di didChangeDependencies)
  bool _isSliderInitialized = false;
  bool _showControls = true;
  bool _isCameraDisposed = false;
  bool _canPop = false;

  // Demo Mode
  bool _isDemoActive = false;
  int _demoSecondsLeft = 60;
  Timer? _demoTimer;

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
    _initializeCamera();
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
      // Pilih kamera depan
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
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

      // Mulai streaming frame kamera untuk Face Mesh Detector
      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessingFrame) return;
        _isProcessingFrame = true;
        _processFrame(image);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memuat kamera depan.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    // Jika paywall sedang tampil (bukan premium dan tidak sedang demo), skip pemrosesan ML
    if (_showPaywall) {
      _isProcessingFrame = false;
      return;
    }

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        debugPrint("DEBUG_AR: inputImage conversion failed");
        _isProcessingFrame = false;
        return;
      }

      final List<Face> faces = await _faceDetector.processImage(inputImage);
      debugPrint("DEBUG_AR: Face detected: ${faces.length} (Image Size: ${image.width}x${image.height}, Rotation: ${inputImage.metadata?.rotation.rawValue})");

      // Diagnosa Rotasi jika 0 wajah terdeteksi
      if (faces.isEmpty) {
        final format = InputImageFormatValue.fromRawValue(image.format.raw);
        if (format != null && image.planes.isNotEmpty) {
          final bytes = image.planes.length > 1 ? _combineYuvPlanes(image) : image.planes.first.bytes;
          for (final rot in [InputImageRotation.rotation0deg, InputImageRotation.rotation90deg, InputImageRotation.rotation180deg]) {
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
              debugPrint("DEBUG_AR: SUCCESS! Face detected with rotation ${rot.rawValue}: ${testFaces.length}");
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          if (faces.isNotEmpty) {
            _detectedFace = faces.first;
            _imageWidth = image.width;
            _imageHeight = image.height;
          } else {
            _detectedFace = null;
          }
        });
      }
    } catch (e) {
      debugPrint("DEBUG_AR: Exception in processImage: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
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

    final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: image.planes.length > 1 ? InputImageFormat.nv21 : format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _combineYuvPlanes(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = (width * height / 2).round();

    final Uint8List nv21 = Uint8List(ySize + uvSize);

    // Copy Y plane
    final Uint8List yPlane = image.planes[0].bytes;
    nv21.setRange(0, ySize, yPlane);

    // Interleave VU planes
    final Uint8List uPlane = image.planes[1].bytes;
    final Uint8List vPlane = image.planes[2].bytes;

    final int uRowStride = image.planes[1].bytesPerRow;
    final int vRowStride = image.planes[2].bytesPerRow;
    final int uPixelStride = image.planes[1].bytesPerPixel ?? 1;
    final int vPixelStride = image.planes[2].bytesPerPixel ?? 1;

    int nvIndex = ySize;

    for (int y = 0; y < (height / 2).round(); y++) {
      for (int x = 0; x < (width / 2).round(); x++) {
        final int uIndex = y * uRowStride + x * uPixelStride;
        final int vIndex = y * vRowStride + x * vPixelStride;

        if (vIndex < vPlane.length) {
          nv21[nvIndex++] = vPlane[vIndex];
        }
        if (uIndex < uPlane.length) {
          nv21[nvIndex++] = uPlane[uIndex];
        }
      }
    }

    return nv21;
  }

  @override
  void dispose() {
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
                      final double painterSliderX = ( _sliderX - cameraAreaWidth / 2 ) / scaleFactor + previewWidth / 2;

                      return Stack(
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
                                              face: _detectedFace,
                                              imageWidth: _imageWidth,
                                              imageHeight: _imageHeight,
                                              lensDirection: _cameraController!.description.lensDirection,
                                              lipstickColor: _selectedLipstickColor,
                                              lipstickOpacity: _lipstickOpacity,
                                              lipstickFinishing: _lipstickFinishing,
                                              blushColor: _selectedBlushColor,
                                              blushOpacity: _blushOpacity,
                                              sliderX: painterSliderX,
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
              bottom: _showControls ? 230 : 24,
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
                    // 1. Selector Tab Kategori (Lipstik vs Blush-On)
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
                              onTap: () {
                                setState(() {
                                    _activeCategoryIndex = 0;
                                });
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeCategoryIndex == 0
                                      ? primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'BIBIR (LIPSTICK)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _activeCategoryIndex == 0
                                        ? Colors.white
                                        : textMutedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _activeCategoryIndex = 1;
                                });
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeCategoryIndex == 1
                                      ? primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'PIPI (BLUSH-ON)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _activeCategoryIndex == 1
                                        ? Colors.white
                                        : textMutedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 1b. Finishing Lipstick Selector (Hanya jika kategori Bibir aktif)
                    if (_activeCategoryIndex == 0) ...[
                      Row(
                        children: [
                           Icon(Icons.brush_rounded, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                           Text('Tipe Finishing', style: TextStyle(color: textColor, fontSize: 11)),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showPaywall ? null : () => setState(() => _lipstickFinishing = 'matte'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _lipstickFinishing == 'matte' ? primaryColor : cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: _lipstickFinishing == 'matte' ? null : Border.all(color: cardBorderColor),
                              ),
                              child: Text(
                                'Matte',
                                style: TextStyle(
                                  color: _lipstickFinishing == 'matte' ? Colors.white : textMutedColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showPaywall ? null : () => setState(() => _lipstickFinishing = 'glossy'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _lipstickFinishing == 'glossy' ? primaryColor : cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: _lipstickFinishing == 'glossy' ? null : Border.all(color: cardBorderColor),
                              ),
                              child: Text(
                                'Glossy (Satin)',
                                style: TextStyle(
                                  color: _lipstickFinishing == 'glossy' ? Colors.white : textMutedColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 2. Slider Opacity/Ketebalan Kategori yang Aktif
                    Row(
                      children: [
                         Icon(Icons.opacity_rounded, color: primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _activeCategoryIndex == 0 ? 'Transparansi Lipstik' : 'Transparansi Blush',
                          style:  TextStyle(color: textColor, fontSize: 11),
                        ),
                        Expanded(
                          child: Slider(
                            activeColor: primaryColor,
                            inactiveColor: cardBorderColor,
                            value: _activeCategoryIndex == 0 ? _lipstickOpacity : _blushOpacity,
                            min: 0.0,
                            max: 0.8,
                            onChanged: _showPaywall
                                ? null
                                : (val) {
                                    setState(() {
                                      if (_activeCategoryIndex == 0) {
                                        _lipstickOpacity = val;
                                      } else {
                                        _blushOpacity = val;
                                      }
                                    });
                                  },
                          ),
                        ),
                        Text(
                          '${((_activeCategoryIndex == 0 ? _lipstickOpacity : _blushOpacity) * 100).round()}%',
                          style:  TextStyle(color: textMutedColor, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Palet Pemilihan Warna Kategori yang Aktif
                    Text(
                      _activeCategoryIndex == 0 ? 'WARNA LIPSTIK:' : 'WARNA BLUSH-ON:',
                      style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _activeCategoryIndex == 0 ? _lipstickColors.length : _blushColors.length,
                        itemBuilder: (context, index) {
                          final item = _activeCategoryIndex == 0
                              ? _lipstickColors[index]
                              : _blushColors[index];
                          final colorVal = item['color'] as Color;
                          final isSelected = _activeCategoryIndex == 0
                              ? _selectedLipstickColor == colorVal
                              : _selectedBlushColor == colorVal;

                          return GestureDetector(
                            onTap: _showPaywall
                                ? null
                                : () {
                                    setState(() {
                                      if (_activeCategoryIndex == 0) {
                                        _selectedLipstickColor = colorVal;
                                      } else {
                                        _selectedBlushColor = colorVal;
                                      }
                                    });
                                  },
                            child: Container(
                              margin: const EdgeInsets.only(right: 14),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorVal,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? primaryColor : cardBorderColor,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
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
