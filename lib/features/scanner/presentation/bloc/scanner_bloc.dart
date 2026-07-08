import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../../../core/utils/image_processor.dart';
import '../../../catalog/domain/repositories/shade_matcher_repository.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final ShadeMatcherRepository _shadeMatcherRepository;
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  ScannerBloc({
    required ShadeMatcherRepository shadeMatcherRepository,
  })  : _shadeMatcherRepository = shadeMatcherRepository,
        super(ScannerInitial()) {
    on<InitializeCamera>(_onInitializeCamera);
    on<CaptureImage>(_onCaptureImage);
    on<ResetScanner>(_onResetScanner);
  }

  Future<void> _onInitializeCamera(
    InitializeCamera event,
    Emitter<ScannerState> emit,
  ) async {
    emit(ScannerCameraLoading());
    try {
      final cameras = await availableCameras();
      
      // Gunakan kamera depan untuk pemindaian mandiri (selfie)
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      emit(ScannerCameraReady(controller: _cameraController!));
    } catch (e) {
      emit(ScannerFailure('Gagal menginisialisasi kamera: ${e.toString()}'));
    }
  }

  Future<void> _onCaptureImage(
    CaptureImage event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is! ScannerCameraReady || _cameraController == null) return;
    emit(ScannerProcessing());

    try {
      // 1. Ambil foto menggunakan CameraController
      final XFile photoFile = await _cameraController!.takePicture();
      
      // 2. Deteksi wajah pada foto hasil tangkapan menggunakan ML Kit
      final inputImage = InputImage.fromFilePath(photoFile.path);
      final List<Face> detectedFaces = await _faceDetector.processImage(inputImage);

      // 3. Muat gambar ke memori untuk pemrosesan piksel
      final decodedImage = await ImageProcessor.loadAndDecodeImage(photoFile.path);
      if (decodedImage == null) {
        emit(const ScannerFailure('Gagal memproses gambar hasil kamera.'));
        return;
      }

      List<int> finalRgb = [0, 0, 0];

      if (detectedFaces.isNotEmpty) {
        final face = detectedFaces.first;
        final rect = face.boundingBox;

        // Ambil area koordinat pipi kiri, pipi kanan, dan dahi relatif terhadap bounding box wajah
        // Bounding box: rect.left, rect.top, rect.width, rect.height
        final regions = [
          // Pipi Kiri
          {
            'x': (rect.left + rect.width * 0.25).round(),
            'y': (rect.top + rect.height * 0.55).round(),
            'w': (rect.width * 0.15).round(),
            'h': (rect.height * 0.15).round(),
          },
          // Pipi Kanan
          {
            'x': (rect.left + rect.width * 0.60).round(),
            'y': (rect.top + rect.height * 0.55).round(),
            'w': (rect.width * 0.15).round(),
            'h': (rect.height * 0.15).round(),
          },
          // Dahi
          {
            'x': (rect.left + rect.width * 0.42).round(),
            'y': (rect.top + rect.height * 0.20).round(),
            'w': (rect.width * 0.16).round(),
            'h': (rect.height * 0.12).round(),
          }
        ];

        finalRgb = ImageProcessor.extractSkinColor(decodedImage, regions);
      } else {
        // Fallback jika tidak ada wajah terdeteksi: Ambil sampel area tengah gambar
        final int w = (decodedImage.width * 0.20).round();
        final int h = (decodedImage.height * 0.20).round();
        final int x = (decodedImage.width * 0.40).round();
        final int y = (decodedImage.height * 0.40).round();

        finalRgb = ImageProcessor.calculateAverageRgb(
          decodedImage,
          startX: x,
          startY: y,
          width: w,
          height: h,
        );
      }

      // Hapus file foto sementara secara asinkron agar tidak membebani memori
      try {
        await File(photoFile.path).delete();
      } catch (_) {}

      if (finalRgb[0] == 0 && finalRgb[1] == 0 && finalRgb[2] == 0) {
        emit(const ScannerFailure('Gagal mendeteksi warna kulit. Pastikan cahaya cukup.'));
        return;
      }

      // 4. Konversi RGB rata-rata ke LabColor
      final targetLab = ColorCalculator.rgbToLab(finalRgb[0], finalRgb[1], finalRgb[2]);

      // 5. Cari kecocokan dengan warna teoretis standar & brand komersial
      final matchedStandard = await _shadeMatcherRepository.matchStandardShade(targetLab);
      final commercialMatches = await _shadeMatcherRepository.matchCommercialProducts(targetLab);

      if (matchedStandard == null) {
        emit(const ScannerFailure('Gagal mencocokkan profil warna standar kulit.'));
        return;
      }

      emit(ScannerSuccess(
        extractedRgb: finalRgb,
        matchedStandard: matchedStandard,
        commercialMatches: commercialMatches,
      ));
    } catch (e) {
      emit(ScannerFailure('Gagal memproses gambar: ${e.toString()}'));
    }
  }

  Future<void> _onResetScanner(
    ResetScanner event,
    Emitter<ScannerState> emit,
  ) async {
    if (_cameraController != null) {
      emit(ScannerCameraReady(controller: _cameraController!));
    } else {
      add(InitializeCamera());
    }
  }

  @override
  Future<void> close() {
    _cameraController?.dispose();
    _faceDetector.close();
    return super.close();
  }
}
