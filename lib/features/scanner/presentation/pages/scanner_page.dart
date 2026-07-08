import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
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
                  ? (context.read<ScannerBloc>().state as ScannerCameraReady).controller
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

              // 2. Overlay Panduan Wajah Premium
              IgnorePointer(
                child: CustomPaint(
                  painter: ScannerOverlayPainter(),
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

/// CustomPainter untuk menggambar overlay panduan scan wajah transparan
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = const Color(0xFF0F0F1A).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFE5A93B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final guideBoxPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Oval wajah di tengah
    final double width = size.width;
    final double height = size.height;
    final double ovalW = width * 0.70;
    final double ovalH = height * 0.45;
    final double ovalX = (width - ovalW) / 2;
    final double ovalY = (height - ovalH) / 2.3;

    final faceRect = Rect.fromLTWH(ovalX, ovalY, ovalW, ovalH);

    // Bikin lubang transparan di tengah background semi-transparan
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    canvas.drawOval(
      faceRect,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    // Gambar border oval emas untuk panduan wajah
    canvas.drawOval(faceRect, borderPaint);

    // Gambar indikator sampling: Dahi
    final foreheadRect = Rect.fromLTWH(
      ovalX + ovalW * 0.42,
      ovalY + ovalH * 0.20,
      ovalW * 0.16,
      ovalH * 0.12,
    );
    canvas.drawRect(foreheadRect, guideBoxPaint);
    _drawLabel(canvas, textPainter, 'Dahi', Offset(foreheadRect.left + 2, foreheadRect.top - 14));

    // Gambar indikator sampling: Pipi Kiri
    final cheekLeftRect = Rect.fromLTWH(
      ovalX + ovalW * 0.25,
      ovalY + ovalH * 0.55,
      ovalW * 0.15,
      ovalH * 0.15,
    );
    canvas.drawRect(cheekLeftRect, guideBoxPaint);
    _drawLabel(canvas, textPainter, 'Pipi Kiri', Offset(cheekLeftRect.left + 2, cheekLeftRect.top - 14));

    // Gambar indikator sampling: Pipi Kanan
    final cheekRightRect = Rect.fromLTWH(
      ovalX + ovalW * 0.60,
      ovalY + ovalH * 0.55,
      ovalW * 0.15,
      ovalH * 0.15,
    );
    canvas.drawRect(cheekRightRect, guideBoxPaint);
    _drawLabel(canvas, textPainter, 'Pipi Kanan', Offset(cheekRightRect.left + 2, cheekRightRect.top - 14));
  }

  void _drawLabel(Canvas canvas, TextPainter painter, String text, Offset offset) {
    painter.text = TextSpan(
      text: text,
      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
    );
    painter.layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
