import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'results_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  @override
  void initState() {
    super.initState();
    // Inisialisasi kamera saat halaman dimuat
    context.read<ScannerBloc>().add(InitializeCamera());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // Dark elegant background
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
            // Arahkan ke halaman hasil saat sukses
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResultsPage(
                  extractedRgb: state.extractedRgb,
                  matchedStandard: state.matchedStandard,
                  commercialMatches: state.commercialMatches,
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

          if (controller == null || !controller.value.isInitialized) {
            return const Center(
              child: Text(
                'Kamera tidak siap.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Preview Kamera
              CameraPreview(controller),

              // Live Face Tracking Bounding Box Overlay
              if (state is ScannerCameraReady && state.detectedFaces.isNotEmpty)
                IgnorePointer(
                  child: CustomPaint(
                    painter: FaceTrackerPainter(
                      faces: state.detectedFaces,
                      imageWidth: state.imageWidth ?? 0,
                      imageHeight: state.imageHeight ?? 0,
                    ),
                  ),
                ),



              // 3. UI Keterangan Atas
              Positioned(
                top: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16162A).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5A93B).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFE5A93B)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Posisikan wajah Anda di dalam lingkaran panduan di bawah cahaya terang yang merata.',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Tombol Ambil Gambar di Bawah
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: state is ScannerProcessing
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16162A).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFE5A93B)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5A93B)),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Menganalisis Warna Kulit...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: () {
                            context.read<ScannerBloc>().add(CaptureImage());
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
                                  colors: [Color(0xFFE5A93B), Color(0xFFC78F26)],
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
          );
        },
      ),
    );
  }
}



/// CustomPainter untuk menggambar kotak pelacakan wajah dinamis
class FaceTrackerPainter extends CustomPainter {
  final List<Face> faces;
  final int imageWidth;
  final int imageHeight;

  FaceTrackerPainter({
    required this.faces,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty || imageWidth == 0 || imageHeight == 0) return;

    // Hitung faktor skala (gambar kamera biasanya diputar 90/270 derajat,
    // jadi lebar dan tinggi gambar ditukar untuk penyesuaian rasio layar)
    final double scaleX = size.width / imageHeight;
    final double scaleY = size.height / imageWidth;

    final paint = Paint()
      ..color = const Color(0xFFE5A93B) // Gold border
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0xFFE5A93B).withOpacity(0.25)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final guideBoxPaint = Paint()
      ..color = const Color(0xFFE5A93B).withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final Face face in faces) {
      final rect = face.boundingBox;

      // Cerminkan koordinat X karena pemindaian menggunakan kamera depan (selfie)
      final double left = size.width - (rect.right * scaleX);
      final double right = size.width - (rect.left * scaleX);
      final double top = rect.top * scaleY;
      final double bottom = rect.bottom * scaleY;

      final mappedRect = Rect.fromLTRB(left, top, right, bottom);
      final rrect = RRect.fromRectAndRadius(mappedRect, const Radius.circular(20));

      // Gambar efek glow
      canvas.drawRRect(rrect, glowPaint);

      // Gambar garis utama kotak pelacak
      canvas.drawRRect(rrect, paint);

      // Gambar siku bidik (corner brackets) putih di ujung sudut
      _drawCornerBrackets(canvas, mappedRect);

      // Dapatkan landmark dinamis dari wajah
      final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
      final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;
      final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
      final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

      final double width = mappedRect.width;
      final double height = mappedRect.height;
      final double boxW = width * 0.14;
      final double boxH = height * 0.12;

      // Helper untuk memetakan koordinat landmark dari resolusi kamera ke ukuran layar
      Offset mapLandmark(Point<int> point) {
        final double mappedX = size.width - (point.x * scaleX);
        final double mappedY = point.y * scaleY;
        return Offset(mappedX, mappedY);
      }

      // 1. Kotak Pipi Kiri (Secara visual berada di sebelah kanan layar karena cermin)
      Rect cheekLeftRect;
      if (leftCheek != null) {
        final pos = mapLandmark(leftCheek);
        cheekLeftRect = Rect.fromLTWH(pos.dx - boxW / 2, pos.dy - boxW / 2, boxW, boxW);
      } else {
        cheekLeftRect = Rect.fromLTWH(mappedRect.left + width * 0.22, mappedRect.top + height * 0.55, boxW, boxW);
      }
      canvas.drawRect(cheekLeftRect, guideBoxPaint);
      _drawLabel(canvas, textPainter, 'Pipi Kiri', Offset(cheekLeftRect.left + 2, cheekLeftRect.top - 12));

      // 2. Kotak Pipi Kanan (Secara visual berada di sebelah kiri layar karena cermin)
      Rect cheekRightRect;
      if (rightCheek != null) {
        final pos = mapLandmark(rightCheek);
        cheekRightRect = Rect.fromLTWH(pos.dx - boxW / 2, pos.dy - boxW / 2, boxW, boxW);
      } else {
        cheekRightRect = Rect.fromLTWH(mappedRect.left + width * 0.62, mappedRect.top + height * 0.55, boxW, boxW);
      }
      canvas.drawRect(cheekRightRect, guideBoxPaint);
      _drawLabel(canvas, textPainter, 'Pipi Kanan', Offset(cheekRightRect.left + 2, cheekRightRect.top - 12));

      // 3. Kotak Dahi
      Rect foreheadRect;
      if (leftEye != null && rightEye != null) {
        final posLeftEye = mapLandmark(leftEye);
        final posRightEye = mapLandmark(rightEye);
        final midpoint = Offset(
          (posLeftEye.dx + posRightEye.dx) / 2,
          (posLeftEye.dy + posRightEye.dy) / 2,
        );
        final double eyeDistance = (posLeftEye.dx - posRightEye.dx).abs();
        foreheadRect = Rect.fromLTWH(
          midpoint.dx - boxW / 2,
          midpoint.dy - eyeDistance * 0.85 - boxH / 2,
          boxW,
          boxH,
        );
      } else {
        foreheadRect = Rect.fromLTWH(mappedRect.left + width * 0.42, mappedRect.top + height * 0.20, boxW, boxH);
      }
      canvas.drawRect(foreheadRect, guideBoxPaint);
      _drawLabel(canvas, textPainter, 'Dahi', Offset(foreheadRect.left + 2, foreheadRect.top - 12));
    }
  }

  void _drawLabel(Canvas canvas, TextPainter painter, String text, Offset offset) {
    painter.text = TextSpan(
      text: text,
      style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
    );
    painter.layout();
    painter.paint(canvas, offset);
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect) {
    final bracketPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final double length = 16.0;

    // Atas Kiri
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + length, rect.top)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.left, rect.top + length),
      bracketPaint,
    );

    // Atas Kanan
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - length, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + length),
      bracketPaint,
    );

    // Bawah Kiri
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + length, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.bottom - length),
      bracketPaint,
    );

    // Bawah Kanan
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - length, rect.bottom)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right, rect.bottom - length),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant FaceTrackerPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
