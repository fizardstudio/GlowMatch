import '../../../../core/utils/face_geometry_helper.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint, WriteBuffer;
import 'package:flutter/material.dart' show Size;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../../../core/utils/image_processor.dart';
import '../../../catalog/domain/repositories/shade_matcher_repository.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';
import '../../../../core/data/models/standard_shade.dart';
import '../../../../core/data/models/product_shade.dart';

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
  InputImageRotation? _activeRotation;
  int _lastFrameTimeMs = 0;

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
    on<DisposeCamera>(_onDisposeCamera);
    on<ProcessGalleryImage>(_onProcessGalleryImage);
  }

  Future<void> _onInitializeCamera(
    InitializeCamera event,
    Emitter<ScannerState> emit,
  ) async {
    emit(ScannerCameraLoading());
    try {
      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isStreamingImages) {
            await _cameraController!.stopImageStream();
          }
        } catch (_) {}
        try {
          await _cameraController!.dispose();
        } catch (_) {}
        _cameraController = null;
      }

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
    } on CameraException catch (e) {
      if (e.code == 'CameraAccessDenied') {
        emit(const ScannerFailure('Izin akses kamera ditolak. Silakan berikan izin kamera di pengaturan HP Anda, lalu ketuk Coba Lagi.'));
      } else {
        emit(ScannerFailure('Gagal menginisialisasi kamera: ${e.description ?? e.code}'));
      }
    } catch (e) {
      emit(ScannerFailure('Gagal menginisialisasi kamera: ${e.toString()}'));
    }
  }

  Future<void> _onDisposeCamera(
    DisposeCamera event,
    Emitter<ScannerState> emit,
  ) async {
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
      } catch (_) {}
      try {
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }
    emit(ScannerInitial());
  }

  Future<void> _onStartScanning(
    StartScanning event,
    Emitter<ScannerState> emit,
  ) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      await _cameraController!.startImageStream((CameraImage image) {
        if (_isDetecting) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastFrameTimeMs < 65) return;
        _lastFrameTimeMs = now;
        _isDetecting = true;

        final lightingResult = _analyzeLighting(image);
        final lightingStatus = lightingResult['status'] ?? 'Optimal';
        final lightingTemp = lightingResult['temp'] ?? 'Neutral';

        _processCameraImage(image).then((faces) {
          if (faces != null && !isClosed) {
            add(FaceDetected(
              faces: faces,
              imageWidth: image.width,
              imageHeight: image.height,
              lightingStatus: lightingStatus,
              lightingTemp: lightingTemp,
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
        lightingTemp: event.lightingTemp,
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

    _activeRotation = null; // Reset kalibrasi rotasi agar dikalibrasi ulang untuk kamera baru!
    _currentLensDirection = _currentLensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    add(InitializeCamera());
  }

  Map<String, String> _analyzeLighting(CameraImage image) {
    if (image.planes.isEmpty) return {'status': 'Optimal', 'temp': 'Neutral'};

    try {
      final isBgra = image.format.group == ImageFormatGroup.bgra8888;
      final bytes = image.planes[0].bytes;
      if (bytes.isEmpty) return {'status': 'Optimal', 'temp': 'Neutral'};

      double avgY = 127;
      double colorBias = 0;
      String temp = 'Neutral';

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

          // Deteksi suhu warna dari RGB
          if (avgR > avgB + 12) {
            temp = 'Warm (Kuning/Hangat)';
          } else if (avgB > avgR + 12) {
            temp = 'Cool (Biru/Dingin)';
          } else {
            temp = 'Neutral';
          }
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
          final int ySize = (bytes.length / 1.5).round();
          if (bytes.length > ySize) {
            int uSum = 0;
            int vSum = 0;
            int uvSampleCount = 0;
            final int uvStep = ((bytes.length - ySize) / 300).round().clamp(2, 50);
            final int alignedUvStep = uvStep - (uvStep % 2);
            
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

        // Deteksi suhu warna dari YUV (V = red/warm bias, U = blue/cool bias)
        if (avgV > avgU + 6) {
          temp = 'Warm (Kuning/Hangat)';
        } else if (avgU > avgV + 6) {
          temp = 'Cool (Biru/Dingin)';
        } else {
          temp = 'Neutral';
        }
      }

      String status = 'Optimal';
      if (avgY < 65) {
        status = 'Cahaya Terlalu Redup';
      } else if (avgY > 200) {
        status = 'Cahaya Terlalu Terang';
      } else if (isBgra && colorBias > 70) {
        status = 'Cahaya Tidak Netral (Gunakan Cahaya Alami)';
      } else if (!isBgra && colorBias > 48) {
        status = 'Cahaya Tidak Netral (Gunakan Cahaya Alami)';
      }

      return {'status': status, 'temp': temp};
    } catch (e, stack) {
      debugPrint('Error in _analyzeLighting: $e\n$stack');
    }

    return {'status': 'Optimal', 'temp': 'Neutral'};
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
      List<int>? coupleRgb;

      if (event.isCoupleMode) {
        if (detectedFaces.length < 2) {
          emit(const ScannerFailure('Mode Couple memerlukan 2 wajah terdeteksi di kamera.'));
          return;
        }
        finalRgb = _extractSkinColorForFace(decodedImage, detectedFaces[0]);
        coupleRgb = _extractSkinColorForFace(decodedImage, detectedFaces[1]);
      } else {
        if (detectedFaces.isNotEmpty) {
          finalRgb = _extractSkinColorForFace(decodedImage, detectedFaces.first);
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
      }

      // Simpan file foto agar bisa ditampilkan di GlowCard hasil pemindaian

      if (finalRgb[0] == 0 && finalRgb[1] == 0 && finalRgb[2] == 0) {
        emit(const ScannerFailure('Gagal mendeteksi warna kulit wajah pertama.'));
        return;
      }

      if (event.isCoupleMode && coupleRgb != null && (coupleRgb[0] == 0 && coupleRgb[1] == 0 && coupleRgb[2] == 0)) {
        emit(const ScannerFailure('Gagal mendeteksi warna kulit wajah kedua.'));
        return;
      }

      // 4. Konversi RGB rata-rata ke LabColor
      final targetLab = ColorCalculator.rgbToLab(finalRgb[0], finalRgb[1], finalRgb[2]);
      final matchedStandard = await _shadeMatcherRepository.matchStandardShade(targetLab);
      final commercialMatches = await _shadeMatcherRepository.matchCommercialProducts(targetLab);

      if (matchedStandard == null) {
        emit(const ScannerFailure('Gagal mencocokkan profil warna standar kulit wajah pertama.'));
        return;
      }

      StandardShade? coupleMatchedStandard;
      if (event.isCoupleMode && coupleRgb != null) {
        final coupleLab = ColorCalculator.rgbToLab(coupleRgb[0], coupleRgb[1], coupleRgb[2]);
        coupleMatchedStandard = await _shadeMatcherRepository.matchStandardShade(coupleLab);
        if (coupleMatchedStandard == null) {
          emit(const ScannerFailure('Gagal mencocokkan profil warna standar kulit wajah kedua.'));
          return;
        }
      }

      // Fetch all product shades to filter matched lipsticks
      final allProducts = await _shadeMatcherRepository.getAllProductShades();
      final matchedLipsticks = _filterLipsticks(allProducts, matchedStandard.undertone);
      List<ProductShade>? coupleMatchedLipsticks;
      if (event.isCoupleMode && coupleMatchedStandard != null) {
        coupleMatchedLipsticks = _filterLipsticks(allProducts, coupleMatchedStandard.undertone);
      }

      String? faceShape;
      String? coupleFaceShape;
      double faceContrast = 35.0;
      double? coupleFaceContrast;
      if (detectedFaces.isNotEmpty) {
        faceShape = FaceGeometryHelper.classifyFaceShape(detectedFaces.first);
        faceContrast = _calculateFaceContrast(decodedImage, detectedFaces.first, finalRgb);
        if (event.isCoupleMode && detectedFaces.length >= 2 && coupleRgb != null) {
          coupleFaceShape = FaceGeometryHelper.classifyFaceShape(detectedFaces[1]);
          coupleFaceContrast = _calculateFaceContrast(decodedImage, detectedFaces[1], coupleRgb);
        }
      }

      emit(ScannerSuccess(
        extractedRgb: finalRgb,
        matchedStandard: matchedStandard,
        commercialMatches: commercialMatches,
        matchedLipsticks: matchedLipsticks,
        faceShape: faceShape,
        faceContrast: faceContrast,
        coupleExtractedRgb: coupleRgb,
        coupleMatchedStandard: coupleMatchedStandard,
        coupleMatchedLipsticks: coupleMatchedLipsticks,
        coupleFaceShape: coupleFaceShape,
        coupleFaceContrast: coupleFaceContrast,
        galleryFilePath: photoFile.path,
      ));
    } catch (e) {
      emit(ScannerFailure('Gagal memproses gambar: ${e.toString()}'));
    }
  }

  List<int> _extractSkinColorForFace(dynamic decodedImage, Face face) {
    final rect = face.boundingBox;

    // Ambil posisi landmark jika terdeteksi, jika tidak gunakan fallback persentase
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

    final double boxW = (rect.width * 0.14);
    final double boxH = (rect.height * 0.12);

    int cheekLeftX, cheekLeftY;
    int cheekRightX, cheekRightY;
    int foreheadX, foreheadY;

    if (leftCheek != null && rightCheek != null) {
      cheekLeftX = (leftCheek.x - boxW / 2).round();
      cheekLeftY = (leftCheek.y - boxW / 2).round();
      cheekRightX = (rightCheek.x - boxW / 2).round();
      cheekRightY = (rightCheek.y - boxW / 2).round();

      if (leftEye != null && rightEye != null) {
        final Point<double> leftEyePt = Point(leftEye.x.toDouble(), leftEye.y.toDouble());
        final Point<double> rightEyePt = Point(rightEye.x.toDouble(), rightEye.y.toDouble());
        final vectors = FaceGeometryHelper.getFaceUnitVectors(face, leftEyePt, rightEyePt);
        final unitY = vectors['unitY']!;
        final double eyeDistance = vectors['distance']!.x;
        
        final double midX = (leftEyePt.x + rightEyePt.x) / 2.0;
        final double midY = (leftEyePt.y + rightEyePt.y) / 2.0;
        
        foreheadX = (midX - unitY.x * (eyeDistance * 0.55) - boxW / 2).round();
        foreheadY = (midY - unitY.y * (eyeDistance * 0.55) - boxH / 2).round();
      } else {
        foreheadX = (rect.left + rect.width * 0.42).round();
        foreheadY = (rect.top + rect.height * 0.20).round();
      }
    } else if (leftEye != null && rightEye != null) {
      final Point<double> leftEyePt = Point(leftEye.x.toDouble(), leftEye.y.toDouble());
      final Point<double> rightEyePt = Point(rightEye.x.toDouble(), rightEye.y.toDouble());
      final vectors = FaceGeometryHelper.getFaceUnitVectors(face, leftEyePt, rightEyePt);
      final unitX = vectors['unitX']!;
      final unitY = vectors['unitY']!;
      final double eyeDistance = vectors['distance']!.x;
      
      final double midX = (leftEyePt.x + rightEyePt.x) / 2.0;
      final double midY = (leftEyePt.y + rightEyePt.y) / 2.0;
      
      // Rotated forehead calculation using face axes
      foreheadX = (midX - unitY.x * (eyeDistance * 0.55) - boxW / 2).round();
      foreheadY = (midY - unitY.y * (eyeDistance * 0.55) - boxH / 2).round();
      
      // Rotated left cheek calculation using face axes
      cheekLeftX = (leftEyePt.x + unitY.x * (eyeDistance * 0.45) - unitX.x * (eyeDistance * 0.15) - boxW / 2).round();
      cheekLeftY = (leftEyePt.y + unitY.y * (eyeDistance * 0.45) - unitX.y * (eyeDistance * 0.15) - boxW / 2).round();
      
      // Rotated right cheek calculation using face axes
      cheekRightX = (rightEyePt.x + unitY.x * (eyeDistance * 0.45) + unitX.x * (eyeDistance * 0.15) - boxW / 2).round();
      cheekRightY = (rightEyePt.y + unitY.y * (eyeDistance * 0.45) + unitX.y * (eyeDistance * 0.15) - boxW / 2).round();
    } else {
      cheekLeftX = (rect.left + rect.width * 0.25).round();
      cheekLeftY = (rect.top + rect.height * 0.55).round();
      cheekRightX = (rect.left + rect.width * 0.60).round();
      cheekRightY = (rect.top + rect.height * 0.55).round();
      foreheadX = (rect.left + rect.width * 0.42).round();
      foreheadY = (rect.top + rect.height * 0.20).round();
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

    try {
      return ImageProcessor.extractSkinColor(decodedImage, regions);
    } catch (_) {
      return [0, 0, 0];
    }
  }

  double _calculateFaceContrast(dynamic decodedImage, Face face, List<int> skinRgb) {
    final rect = face.boundingBox;
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

    final double boxW = (rect.width * 0.12);
    final double boxH = (rect.height * 0.10);

    int eyeLeftX, eyeLeftY;
    int eyeRightX, eyeRightY;

    if (leftEye != null && rightEye != null) {
      eyeLeftX = (leftEye.x - boxW / 2).round();
      eyeLeftY = (leftEye.y - boxH * 1.2).round();
      eyeRightX = (rightEye.x - boxW / 2).round();
      eyeRightY = (rightEye.y - boxH * 1.2).round();
    } else {
      eyeLeftX = (rect.left + rect.width * 0.28 - boxW / 2).round();
      eyeLeftY = (rect.top + rect.height * 0.38 - boxH * 1.2).round();
      eyeRightX = (rect.left + rect.width * 0.58 - boxW / 2).round();
      eyeRightY = (rect.top + rect.height * 0.38 - boxH * 1.2).round();
    }

    final featureRegions = [
      {
        'x': eyeLeftX,
        'y': eyeLeftY,
        'w': boxW.round(),
        'h': (boxH * 1.8).round(),
      },
      {
        'x': eyeRightX,
        'y': eyeRightY,
        'w': boxW.round(),
        'h': (boxH * 1.8).round(),
      }
    ];

    try {
      final List<int> featureRgb = ImageProcessor.extractSkinColor(decodedImage, featureRegions);
      
      final double skinLuminance = 0.299 * skinRgb[0] + 0.587 * skinRgb[1] + 0.114 * skinRgb[2];
      final double featureLuminance = 0.299 * featureRgb[0] + 0.587 * featureRgb[1] + 0.114 * featureRgb[2];
      
      final double contrast = (skinLuminance - featureLuminance).clamp(0.0, 255.0);
      return contrast;
    } catch (_) {
      return 35.0;
    }
  }

  List<ProductShade> _filterLipsticks(List<ProductShade> allProducts, String undertone) {
    final lowerUnder = undertone.toLowerCase();
    return allProducts.where((p) {
      if (p.category != 'Lip Color') return false;
      final double a = p.a;
      final double b = p.b;
      final double ratio = a != 0.0 ? b / a : 0.0;
      if (lowerUnder == 'cool') {
        return ratio < 0.45;
      } else if (lowerUnder == 'warm') {
        return ratio >= 0.45;
      } else {
        return true;
      }
    }).toList();
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
      final camera = _cameraController?.description;
      if (camera == null) return null;

      // Kalibrasi otomatis sekali saja untuk menemukan rotasi sensor yang benar untuk wajah tegak
      if (_activeRotation == null) {
        final format = InputImageFormatValue.fromRawValue(image.format.raw);
        if (format != null && image.planes.isNotEmpty) {
          final bytes = image.planes.length > 1 ? _combineYuvPlanes(image) : image.planes.first.bytes;
          final rotationsToTry = [
            InputImageRotation.rotation270deg,
            InputImageRotation.rotation90deg,
            InputImageRotation.rotation0deg,
            InputImageRotation.rotation180deg,
          ];
          
          for (final rot in rotationsToTry) {
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
              debugPrint("DEBUG_SCANNER: Auto-calibration SUCCESS! Face detected at rotation: ${rot.rawValue}");
              _activeRotation = rot; // Kunci rotasi ini!
              break;
            }
          }
        }
      }

      final currentRotation = _activeRotation ?? _getRotationFromSensor(camera.sensorOrientation);

      final inputImage = _inputImageFromCameraImage(image, currentRotation);
      if (inputImage == null) return null;
      return await _faceDetector.processImage(inputImage);
    } catch (_) {
      return null;
    }
  }

  InputImageRotation _getRotationFromSensor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation270deg;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, InputImageRotation rotation) {
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

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: image.planes.length > 1 ? InputImageFormat.nv21 : format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _combineYuvPlanes(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Future<void> _onProcessGalleryImage(
    ProcessGalleryImage event,
    Emitter<ScannerState> emit,
  ) async {
    emit(ScannerGalleryProcessing());

    try {
      // 1. Deteksi wajah pada foto dari galeri
      final inputImage = InputImage.fromFilePath(event.filePath);
      final List<Face> detectedFaces = await _faceDetector.processImage(inputImage);

      if (detectedFaces.isEmpty) {
        emit(const ScannerFailure('Wajah tidak terdeteksi di foto galeri. Silakan pilih foto selfie dengan wajah menghadap lurus ke depan dengan cahaya cukup.'));
        return;
      }

      // 2. Muat gambar ke memori untuk pemrosesan piksel
      final decodedImage = await ImageProcessor.loadAndDecodeImage(event.filePath);
      if (decodedImage == null) {
        emit(const ScannerFailure('Gagal membaca gambar dari galeri.'));
        return;
      }

      // 3. Ekstrak warna kulit wajah pertama yang terdeteksi
      final finalRgb = _extractSkinColorForFace(decodedImage, detectedFaces.first);

      if (finalRgb[0] == 0 && finalRgb[1] == 0 && finalRgb[2] == 0) {
        emit(const ScannerFailure('Gagal mendeteksi rona warna kulit pada wajah.'));
        return;
      }

      // 4. Konversi RGB rata-rata ke LabColor dan cari pencocokan
      final targetLab = ColorCalculator.rgbToLab(finalRgb[0], finalRgb[1], finalRgb[2]);
      final matchedStandard = await _shadeMatcherRepository.matchStandardShade(targetLab);
      final commercialMatches = await _shadeMatcherRepository.matchCommercialProducts(targetLab);

      if (matchedStandard == null) {
        emit(const ScannerFailure('Gagal mencocokkan profil warna standar kulit wajah.'));
        return;
      }

      // Fetch all product shades to filter matched lipsticks
      final allProducts = await _shadeMatcherRepository.getAllProductShades();
      final matchedLipsticks = _filterLipsticks(allProducts, matchedStandard.undertone);

      String? faceShape;
      double faceContrast = 35.0;
      if (detectedFaces.isNotEmpty) {
        faceShape = FaceGeometryHelper.classifyFaceShape(detectedFaces.first);
        faceContrast = _calculateFaceContrast(decodedImage, detectedFaces.first, finalRgb);
      }

      emit(ScannerSuccess(
        extractedRgb: finalRgb,
        matchedStandard: matchedStandard,
        commercialMatches: commercialMatches,
        matchedLipsticks: matchedLipsticks,
        faceShape: faceShape,
        faceContrast: faceContrast,
        galleryFilePath: event.filePath,
      ));
    } catch (e) {
      emit(ScannerFailure('Gagal memproses gambar galeri: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() async {
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
      } catch (e) {
        debugPrint("Error stopping image stream in ScannerBloc.close(): $e");
      }
      try {
        await _cameraController!.dispose();
      } catch (e) {
        debugPrint("Error disposing CameraController in ScannerBloc.close(): $e");
      }
    }
    await _faceDetector.close();
    return super.close();
  }
}
