import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
  CameraLensDirection _currentLensDirection = CameraLensDirection.front;

  ScannerBloc({
    required ShadeMatcherRepository shadeMatcherRepository,
  })  : _shadeMatcherRepository = shadeMatcherRepository,
        super(ScannerInitial()) {
    on<InitializeCamera>(_onInitializeCamera);
    on<StartScanning>(_onStartScanning);
    on<FaceDetected>(_onFaceDetected);
    on<SwitchCamera>(_onSwitchCamera);
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
      
      final targetCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == _currentLensDirection,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      emit(ScannerCameraReady(
        controller: _cameraController!,
        lensDirection: _currentLensDirection,
      ));
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

        final lightingStatus = _analyzeLighting(image);

        _processCameraImage(image).then((faces) {
          if (faces != null && !isClosed) {
            add(FaceDetected(
              faces: faces,
              imageWidth: image.width,
              imageHeight: image.height,
              lightingStatus: lightingStatus,
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
        lightingStatus: event.lightingStatus,
      ));
    }
  }

  Future<void> _onSwitchCamera(
    SwitchCamera event,
    Emitter<ScannerState> emit,
  ) async {
    if (_cameraController == null) return;

    // Pancarkan loading terlebih dahulu agar UI melepaskan widget CameraPreview
    // dan menghindari kedipan layar merah (red error blink)
    emit(ScannerCameraLoading());

    try {
      await _cameraController!.stopImageStream();
    } catch (_) {}

    try {
      await _cameraController!.dispose();
    } catch (_) {}
    _cameraController = null;

    _currentLensDirection = _currentLensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    add(InitializeCamera());
  }

  String _analyzeLighting(CameraImage image) {
    if (image.planes.isEmpty) return 'Optimal';

    try {
      final isBgra = image.format.group == ImageFormatGroup.bgra8888;
      final bytes = image.planes[0].bytes;
      if (bytes.isEmpty) return 'Optimal';

      double avgY = 127;
      double colorBias = 0;

      if (isBgra) {
        // Format BGRA (biasanya di iOS atau emulator/fallback Android)
        int bSum = 0;
        int gSum = 0;
        int rSum = 0;
        int sampleCount = 0;
        
        // Sampling kelipatan 4 bytes (Blue, Green, Red, Alpha)
        final int step = (bytes.length / 1000).round().clamp(4, 400);
        final int alignedStep = step - (step % 4);

        for (int i = 0; i < bytes.length - 4; i += alignedStep > 0 ? alignedStep : 4) {
          bSum += bytes[i];
          gSum += bytes[i + 1];
          rSum += bytes[i + 2];
          sampleCount++;
        }

        if (sampleCount > 0) {
          final double avgB = bSum / sampleCount;
          final double avgG = gSum / sampleCount;
          final double avgR = rSum / sampleCount;
          
          // Hitung Luminance Y standard
          avgY = 0.299 * avgR + 0.587 * avgG + 0.114 * avgB;

          // Hitung bias warna (selisih R, G, B ekstrim)
          final double maxVal = [avgR, avgG, avgB].reduce((curr, next) => curr > next ? curr : next);
          final double minVal = [avgR, avgG, avgB].reduce((curr, next) => curr < next ? curr : next);
          colorBias = maxVal - minVal;
        }
      } else {
        // Format YUV / NV21
        // Bagian awal buffer (2/3 dari total panjang) adalah plane Y (Luminance)
        final int yLength = (bytes.length * 2 / 3).round();
        if (yLength > 0) {
          int ySum = 0;
          final int step = (yLength / 500).round().clamp(1, 100);
          int sampleCount = 0;
          for (int i = 0; i < yLength; i += step) {
            ySum += bytes[i];
            sampleCount++;
          }
          avgY = ySum / sampleCount;
        }

        double avgU = 128;
        double avgV = 128;

        // Ambil data U & V (Chrominance)
        if (image.planes.length >= 3) {
          final uBytes = image.planes[1].bytes;
          final vBytes = image.planes[2].bytes;

          if (uBytes.isNotEmpty && vBytes.isNotEmpty) {
            int uSum = 0;
            int vSum = 0;
            int uvSampleCount = 0;
            final int uvStep = (uBytes.length / 300).round().clamp(1, 50);
            for (int j = 0; j < uBytes.length; j += uvStep) {
              if (j < uBytes.length && j < vBytes.length) {
                uSum += uBytes[j];
                vSum += vBytes[j];
                uvSampleCount++;
              }
            }
            if (uvSampleCount > 0) {
              avgU = uSum / uvSampleCount;
              avgV = vSum / uvSampleCount;
            }
          }
          colorBias = ((avgU - 128).abs() + (avgV - 128).abs());
        } else if (image.planes.length == 1) {
          // Format Semi-Planar NV21 (Y dan VU digabung dalam satu plane)
          // Saluran VU dimulai setelah data Y. Gunakan pembagian rasio 1.5 untuk Y size
          final int ySize = (bytes.length / 1.5).round();
          if (bytes.length > ySize) {
            int uSum = 0;
            int vSum = 0;
            int uvSampleCount = 0;
            final int uvStep = ((bytes.length - ySize) / 300).round().clamp(2, 50);
            final int alignedUvStep = uvStep - (uvStep % 2);
            
            // Loop data VU yang saling selang-seling (V, U, V, U)
            for (int k = ySize; k < bytes.length - 1; k += alignedUvStep > 0 ? alignedUvStep : 2) {
              vSum += bytes[k];
              uSum += bytes[k + 1];
              uvSampleCount++;
            }
            if (uvSampleCount > 0) {
              avgU = uSum / uvSampleCount;
              avgV = vSum / uvSampleCount;
            }
          }
          colorBias = ((avgU - 128).abs() + (avgV - 128).abs());
        }
      }

      // Cetak log untuk analisis manual tingkat kecerahan saat pengembangan
      // debugPrint('LIGHTING LOG - avgY: $avgY, colorBias: $colorBias');

      // Ambang batas yang lebih peka terhadap Auto Exposure:
      // Y < 65: Terlalu redup
      // Y > 200: Terlalu terang
      // Bias warna: YUV colorBias > 48, RGB colorBias > 70
      if (avgY < 65) {
        return 'Cahaya Terlalu Redup';
      } else if (avgY > 200) {
        return 'Cahaya Terlalu Terang';
      } else if (isBgra && colorBias > 70) {
        return 'Cahaya Tidak Netral (Gunakan Cahaya Alami)';
      } else if (!isBgra && colorBias > 48) {
        return 'Cahaya Tidak Netral (Gunakan Cahaya Alami)';
      }
    } catch (e, stack) {
      debugPrint('Error in _analyzeLighting: $e\n$stack');
    }

    return 'Optimal';
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
