import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'results_page.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../../../core/network/database_service.dart';
import '../../../premium_subscription/data/models/app_settings.dart';
import '../../../../core/utils/widget_helper.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _isCameraDisposed = false;
  bool _canPop = false;
  bool _isCoupleMode = false;
  bool _isPremium = false;
  bool _hasUsedCoupleTrial = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi kamera saat halaman dimuat
    context.read<ScannerBloc>().add(InitializeCamera());
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final isar = DatabaseService().isar;
    final settings = await isar.appSettings.get(0);
    if (settings != null) {
      setState(() {
        _isPremium = settings.isPremium;
        _hasUsedCoupleTrial = settings.hasUsedCoupleTrial;
      });
    }
  }

  Color _getLightingColor(String status) {
    switch (status) {
      case 'Optimal':
        return const Color(0xFF4CAF50); // Hijau
      case 'Cahaya Terlalu Redup':
      case 'Cahaya Terlalu Terang':
        return const Color(0xFFFF9800); // Amber/Oranye
      case 'Cahaya Tidak Netral (Gunakan Cahaya Alami)':
      default:
        return const Color(0xFFE53935); // Merah
    }
  }

  Color _getTempColor(String temp) {
    if (temp.contains('Warm')) {
      return const Color(0xFFFFD600); // Kuning/Oranye hangat
    } else if (temp.contains('Cool')) {
      return const Color(0xFF29B6F6); // Biru dingin
    } else {
      return const Color(0xFF00E676); // Hijau netral
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        setState(() {
          _isCameraDisposed = true;
        });
        
        final bloc = context.read<ScannerBloc>();
        final state = bloc.state;
        final controller = (state is ScannerCameraReady)
            ? state.controller
            : (state is ScannerProcessing)
                ? state.controller
                : null;
                
        if (controller != null) {
          try {
            if (controller.value.isStreamingImages) {
              await controller.stopImageStream();
            }
            await controller.dispose();
          } catch (e) {
            debugPrint("Error stopping camera in ScannerPage.PopScope: $e");
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
      backgroundColor: const Color(0xFF0F0F1A), // Dark elegant background
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          'GlowMatch Scanner',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: (context, state) {
          if (state is ScannerSuccess) {
            // Jika dalam mode Couple dan pengguna bukan premium, tandai trial telah digunakan
            if (state.isCoupleMode && !_isPremium) {
              final isar = DatabaseService().isar;
              isar.appSettings.get(0).then((settingsObj) async {
                final settings = settingsObj ?? (AppSettings()..id = 0..isPremium = false);
                settings.hasUsedCoupleTrial = true;
                await isar.writeTxn(() async {
                  await isar.appSettings.put(settings);
                });
                setState(() {
                  _hasUsedCoupleTrial = true;
                });
              });
            }

            // Arahkan ke halaman hasil saat sukses
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResultsPage(
                  extractedRgb: state.extractedRgb,
                  matchedStandard: state.matchedStandard,
                  commercialMatches: state.commercialMatches,
                  coupleExtractedRgb: state.coupleExtractedRgb,
                  coupleMatchedStandard: state.coupleMatchedStandard,
                ),
              ),
            ).then((_) {
              // Reset scanner ketika kembali dari halaman hasil
              context.read<ScannerBloc>().add(ResetScanner());
            });
          }
          if (state is ScannerCameraReady) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.read<ScannerBloc>().state is ScannerCameraReady) {
                context.read<ScannerBloc>().add(StartScanning());
              }
            });
          }
          if (state is ScannerFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ScannerCameraLoading || state is ScannerInitial) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5A93B)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Menyalakan Kamera...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          if (state is ScannerFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A93B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        context.read<ScannerBloc>().add(InitializeCamera());
                      },
                      child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          final controller = (state is ScannerCameraReady)
              ? state.controller
              : (state is ScannerProcessing)
                  ? state.controller
                  : null;

          if (controller == null || !controller.value.isInitialized || _isCameraDisposed) {
            return const Center(
              child: Text(
                'Kamera tidak siap.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final double cameraAreaWidth = constraints.maxWidth;
              final double cameraAreaHeight = constraints.maxHeight;

              final double rawAspectRatio = controller.value.aspectRatio; // landscape (e.g. 1.333)
              final double previewWidth = cameraAreaWidth;
              final double previewHeight = cameraAreaWidth * rawAspectRatio;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Preview Kamera (FittedBox cover)
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
                              CameraPreview(controller),

                              // Live Face Tracking Bounding Box Overlay
                              if (state is ScannerCameraReady && state.detectedFaces.isNotEmpty)
                                IgnorePointer(
                                  child: CustomPaint(
                                    painter: FaceTrackerPainter(
                                      faces: state.detectedFaces,
                                      imageWidth: state.imageWidth ?? 0,
                                      imageHeight: state.imageHeight ?? 0,
                                      lensDirection: state.lensDirection,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. UI Keterangan Atas & Real-time Lighting Indicator
                  Positioned(
                    top: 24,
                    left: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16162A).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5C185).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFE5C185)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  state is ScannerCameraReady && state.detectedFaces.isEmpty
                                      ? 'Arahkan kamera ke wajah Anda'
                                      : 'Posisikan wajah Anda secara tegak di bawah cahaya terang yang merata. Sensor akan melacak dahi dan pipi Anda secara otomatis.',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Lencana status pencahayaan dinamis
                        if (state is ScannerCameraReady)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              // 1. Status Intensitas Cahaya
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getLightingColor(state.lightingStatus).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _getLightingColor(state.lightingStatus).withOpacity(0.7),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _getLightingColor(state.lightingStatus),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cahaya: ${state.lightingStatus}',
                                      style: TextStyle(
                                        color: _getLightingColor(state.lightingStatus),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 2. Status Suhu Cahaya
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getTempColor(state.lightingTemp).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _getTempColor(state.lightingTemp).withOpacity(0.7),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _getTempColor(state.lightingTemp),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Suhu: ${state.lightingTemp}',
                                      style: TextStyle(
                                        color: _getTempColor(state.lightingTemp),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // 4. Tombol Ambil Foto / Capture di Bagian Bawah Tengah (Glassmorphism)
                  if (state is ScannerCameraReady) ...[
                    // A. Mode Selector Toggle (di atas tombol jepret)
                    Positioned(
                      bottom: 136,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16162A).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isCoupleMode = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: !_isCoupleMode
                                        ? const Color(0xFFE5A93B)
                                        : Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 16,
                                        color: !_isCoupleMode ? Colors.black : Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Personal 👤',
                                        style: TextStyle(
                                          color: !_isCoupleMode ? Colors.black : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () async {
                                  await _checkPremiumStatus();
                                  if (!_isPremium && _hasUsedCoupleTrial) {
                                    _showCouplePremiumUnlockDialog();
                                  } else {
                                    setState(() {
                                      _isCoupleMode = true;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: _isCoupleMode
                                        ? const Color(0xFFE5A93B)
                                        : Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people_outline_rounded,
                                        size: 16,
                                        color: _isCoupleMode ? Colors.black : Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Couple 👥',
                                            style: TextStyle(
                                              color: _isCoupleMode ? Colors.black : Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (!_isPremium) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: _hasUsedCoupleTrial ? const Color(0xFFE5A93B) : Colors.greenAccent,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _hasUsedCoupleTrial ? 'PRO' : 'TRIAL',
                                                style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ]
                                        ],
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

                    // B. Banner Wajah kurang dari 2 di Couple Mode
                    if (_isCoupleMode && state.detectedFaces.length < 2)
                      Positioned(
                        bottom: 200,
                        left: 24,
                        right: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(color: Colors.black38, blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sejajarkan 2 wajah bersama dalam frame!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // C. Tombol Jepret
                    Positioned(
                      bottom: 36,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: (state is ScannerProcessing)
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16162A).withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFE5C185), width: 2),
                                ),
                                child: const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5C185)),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () {
                                  if (_isCoupleMode && state.detectedFaces.length < 2) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Harap posisikan 2 wajah dalam kamera untuk memindai berdua!'),
                                        backgroundColor: Colors.orangeAccent,
                                      ),
                                    );
                                    return;
                                  }
                                  context.read<ScannerBloc>().add(CaptureImage(isCoupleMode: _isCoupleMode));
                                },
                                child: Container(
                                  height: 84,
                                  width: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFE5C185), Color(0xFFC78F26)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.black,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],

                  // 5. Tombol Switch Camera di Pojok Kanan Bawah
                  if (state is ScannerCameraReady && state is! ScannerProcessing)
                    Positioned(
                      bottom: 56,
                      right: 36,
                      child: FloatingActionButton(
                        heroTag: 'switch_camera_fab',
                        onPressed: () {
                          context.read<ScannerBloc>().add(SwitchCamera());
                        },
                        backgroundColor: const Color(0xFF16162A).withOpacity(0.85),
                        mini: true,
                        shape: CircleBorder(
                          side: BorderSide(
                            color: const Color(0xFFE5C185).withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}

  void _showCouplePremiumUnlockDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5A93B).withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A93B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFFE5A93B), size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Buka Couple Matcher 👥',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Uji coba gratis Anda telah habis. Berlangganan Premium untuk memindai undertone berdua dengan pacar atau sahabat sepuasnya!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A93B),
                  foregroundColor: const Color(0xFF0F0F1A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _activatePremium();
                },
                child: const Text('Aktifkan Premium Permanen', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti Saja', style: TextStyle(color: Colors.white30)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _activatePremium() async {
    final isar = DatabaseService().isar;
    final settings = AppSettings()
      ..id = 0
      ..isPremium = true;

    await isar.writeTxn(() async {
      await isar.appSettings.put(settings);
    });

    setState(() {
      _isPremium = true;
    });

    // Update native widget data
    WidgetHelper.updateExpiryWidget();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selamat! Fitur Premium Berhasil Diaktifkan.'),
          backgroundColor: Color(0xFFE5C185),
        ),
      );
    }
  }
}



/// CustomPainter untuk menggambar kotak pelacakan wajah dinamis premium
class FaceTrackerPainter extends CustomPainter {
  final List<Face> faces;
  final int imageWidth;
  final int imageHeight;
  final CameraLensDirection lensDirection;

  FaceTrackerPainter({
    required this.faces,
    required this.imageWidth,
    required this.imageHeight,
    required this.lensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty || imageWidth == 0 || imageHeight == 0) return;

    // Hitung faktor skala (gambar kamera biasanya diputar 90/270 derajat,
    // jadi lebar dan tinggi gambar ditukar untuk penyesuaian rasio layar)
    final double scaleX = size.width / imageHeight;
    final double scaleY = size.height / imageWidth;

    final guideBoxPaint = Paint()
      ..color = const Color(0xFFE5C185).withOpacity(0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFFE5C185).withOpacity(0.04)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final Face face in faces) {
      final rect = face.boundingBox;

      // Cerminkan koordinat X jika kamera depan (selfie), jangan jika kamera belakang
      final double left = lensDirection == CameraLensDirection.front
          ? size.width - (rect.right * scaleX)
          : rect.left * scaleX;
      final double right = lensDirection == CameraLensDirection.front
          ? size.width - (rect.left * scaleX)
          : rect.right * scaleX;
      final double top = rect.top * scaleY;
      final double bottom = rect.bottom * scaleY;

      final mappedRect = Rect.fromLTRB(left, top, right, bottom);

      // Dapatkan landmark dinamis dari wajah
      final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
      final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;
      final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
      final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

      final double width = mappedRect.width;
      final double height = mappedRect.height;
      final double radius = width * 0.07; // Jari-jari lingkaran bidik dinamis yang presisi

      // Helper untuk memetakan koordinat landmark dari resolusi kamera ke ukuran layar
      Offset mapLandmark(Point<int> point) {
        final double mappedX = lensDirection == CameraLensDirection.front
            ? size.width - (point.x * scaleX)
            : point.x * scaleX;
        final double mappedY = point.y * scaleY;
        return Offset(mappedX, mappedY);
      }

      // 1. Lingkaran Bidik Pipi Kiri
      Offset centerLeft;
      if (leftCheek != null) {
        centerLeft = mapLandmark(leftCheek);
      } else {
        centerLeft = Offset(mappedRect.left + width * 0.30, mappedRect.top + height * 0.62);
      }
      _drawReticle(canvas, centerLeft, radius, guideBoxPaint, fillPaint, textPainter, 'Pipi Kiri');

      // 2. Lingkaran Bidik Pipi Kanan
      Offset centerRight;
      if (rightCheek != null) {
        centerRight = mapLandmark(rightCheek);
      } else {
        centerRight = Offset(mappedRect.left + width * 0.70, mappedRect.top + height * 0.62);
      }
      _drawReticle(canvas, centerRight, radius, guideBoxPaint, fillPaint, textPainter, 'Pipi Kanan');

      // 3. Lingkaran Bidik Dahi
      Offset centerForehead;
      if (leftEye != null && rightEye != null) {
        final posLeftEye = mapLandmark(leftEye);
        final posRightEye = mapLandmark(rightEye);
        final midpoint = Offset(
          (posLeftEye.dx + posRightEye.dx) / 2,
          (posLeftEye.dy + posRightEye.dy) / 2,
        );
        final double eyeDistance = (posLeftEye.dx - posRightEye.dx).abs();
        centerForehead = Offset(midpoint.dx, midpoint.dy - eyeDistance * 0.85);
      } else {
        centerForehead = Offset(mappedRect.left + width * 0.50, mappedRect.top + height * 0.26);
      }
      _drawReticle(canvas, centerForehead, radius, guideBoxPaint, fillPaint, textPainter, 'Dahi');
    }
  }

  void _drawReticle(Canvas canvas, Offset center, double radius, Paint linePaint, Paint fillPaint, TextPainter textPainter, String label) {
    // Gambar latar belakang transparan bulat (glassmorphic)
    canvas.drawCircle(center, radius, fillPaint);
    
    // Gambar lingkaran bidik tipis
    canvas.drawCircle(center, radius, linePaint);
    
    // Gambar tanda plus (+) kecil di pusat bidikan
    final plusPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    const double size = 3.0;
    canvas.drawLine(Offset(center.dx - size, center.dy), Offset(center.dx + size, center.dy), plusPaint);
    canvas.drawLine(Offset(center.dx, center.dy - size), Offset(center.dx, center.dy + size), plusPaint);
    
    // Gambar label kecil dengan peluru
    final offset = Offset(center.dx - 22, center.dy - radius - 12);
    _drawLabel(canvas, textPainter, '• $label', offset);
  }

  void _drawLabel(Canvas canvas, TextPainter painter, String text, Offset offset) {
    painter.text = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 8.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
    painter.layout();
    painter.paint(canvas, offset);
  }



  @override
  bool shouldRepaint(covariant FaceTrackerPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
