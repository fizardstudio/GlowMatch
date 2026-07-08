import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart' show Size;
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

  bool _isDetecting = false;

  ScannerBloc({
    required ShadeMatcherRepository shadeMatcherRepository,
  })  : _shadeMatcherRepository = shadeMatcherRepository,
        super(ScannerInitial()) {
    on<InitializeCamera>(_onInitializeCamera);
    on<StartScanning>(_onStartScanning);
    on<FaceDetected>(_onFaceDetected);
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
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      emit(ScannerCameraReady(controller: _cameraController!));
    } catch (e) {
      emit(ScannerFailure('Gagal menginisialisasi kamera: ${e.toString()}'));
    }
  }

  Future<void> _onStartScanning(
    StartScanning event,
    Emitter<ScannerState> emit,
  ) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      await _cameraController!.startImageStream((CameraImage image) {
        if (_isDetecting) return;
        _isDetecting = true;

        _processCameraImage(image).then((faces) {
          if (faces != null && !isClosed) {
            add(FaceDetected(
              faces: faces,
              imageWidth: image.width,
              imageHeight: image.height,
            ));
          }
          _isDetecting = false;
        }).catchError((_) {
          _isDetecting = false;
        });
      });
    } catch (_) {}
  }

  void _onFaceDetected(
    FaceDetected event,
    Emitter<ScannerState> emit,
  ) {
    if (state is ScannerCameraReady) {
      emit((state as ScannerCameraReady).copyWith(
        detectedFaces: event.faces,
        imageWidth: event.imageWidth,
        imageHeight: event.imageHeight,
      ));
    }
  }

  Future<void> _onCaptureImage(
    CaptureImage event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is! ScannerCameraReady || _cameraController == null) return;
    
    // Stop the stream so the camera pipeline has full resources for capturing high-res photo!
    try {
      await _cameraController!.stopImageStream();
    } catch (_) {}

    emit(ScannerProcessing(controller: _cameraController!));

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

        // Ambil posisi landmark jika terdeteksi, jika tidak gunakan fallback persentase
        final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
        final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;
        final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
        final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

        final double boxW = (rect.width * 0.14);
        final double boxH = (rect.height * 0.12);

        int cheekLeftX = (leftCheek != null) ? (leftCheek.x - boxW / 2).round() : (rect.left + rect.width * 0.25).round();
        int cheekLeftY = (leftCheek != null) ? (leftCheek.y - boxW / 2).round() : (rect.top + rect.height * 0.55).round();

        int cheekRightX = (rightCheek != null) ? (rightCheek.x - boxW / 2).round() : (rect.left + rect.width * 0.60).round();
        int cheekRightY = (rightCheek != null) ? (rightCheek.y - boxW / 2).round() : (rect.top + rect.height * 0.55).round();

        int foreheadX = (rect.left + rect.width * 0.42).round();
        int foreheadY = (rect.top + rect.height * 0.20).round();

        if (leftEye != null && rightEye != null) {
          final midpointX = (leftEye.x + rightEye.x) / 2;
          final midpointY = (leftEye.y + rightEye.y) / 2;
          final double eyeDistance = (leftEye.x - rightEye.x).abs().toDouble();
          foreheadX = (midpointX - boxW / 2).round();
          foreheadY = (midpointY - eyeDistance * 0.85 - boxH / 2).round();
        }

        final regions = [
          // Pipi Kiri
          {
            'x': cheekLeftX,
            'y': cheekLeftY,
            'w': boxW.round(),
            'h': boxW.round(),
          },
          // Pipi Kanan
          {
            'x': cheekRightX,
            'y': cheekRightY,
            'w': boxW.round(),
            'h': boxW.round(),
          },
          // Dahi
          {
            'x': foreheadX,
            'y': foreheadY,
            'w': boxW.round(),
            'h': boxH.round(),
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

  Future<List<Face>?> _processCameraImage(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return null;
      return await _faceDetector.processImage(inputImage);
    } catch (_) {
      return null;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

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
  Future<void> close() {
    _cameraController?.dispose();
    _faceDetector.close();
    return super.close();
  }
}
