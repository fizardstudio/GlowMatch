import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../../core/data/models/standard_shade.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerCameraLoading extends ScannerState {}

class ScannerCameraReady extends ScannerState {
  final CameraController controller;
  final List<Face> detectedFaces;
  final int? imageWidth;
  final int? imageHeight;
  final String lightingStatus;
  final String lightingTemp;
  final CameraLensDirection lensDirection;

  const ScannerCameraReady({
    required this.controller,
    this.detectedFaces = const [],
    this.imageWidth,
    this.imageHeight,
    this.lightingStatus = 'Optimal',
    this.lightingTemp = 'Neutral',
    this.lensDirection = CameraLensDirection.front,
  });

  ScannerCameraReady copyWith({
    CameraController? controller,
    List<Face>? detectedFaces,
    int? imageWidth,
    int? imageHeight,
    String? lightingStatus,
    String? lightingTemp,
    CameraLensDirection? lensDirection,
  }) {
    return ScannerCameraReady(
      controller: controller ?? this.controller,
      detectedFaces: detectedFaces ?? this.detectedFaces,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      lightingStatus: lightingStatus ?? this.lightingStatus,
      lightingTemp: lightingTemp ?? this.lightingTemp,
      lensDirection: lensDirection ?? this.lensDirection,
    );
  }

  @override
  List<Object?> get props => [
        controller,
        detectedFaces,
        imageWidth,
        imageHeight,
        lightingStatus,
        lightingTemp,
        lensDirection,
      ];
}

class ScannerProcessing extends ScannerState {
  final CameraController controller;

  const ScannerProcessing({required this.controller});

  @override
  List<Object?> get props => [controller];
}

class ScannerSuccess extends ScannerState {
  final List<int> extractedRgb;
  final StandardShade matchedStandard;
  final List<Map<String, dynamic>> commercialMatches;
  final String? galleryFilePath;

  // Fields for Face 2 (Couple Mode)
  final List<int>? coupleExtractedRgb;
  final StandardShade? coupleMatchedStandard;

  const ScannerSuccess({
    required this.extractedRgb,
    required this.matchedStandard,
    required this.commercialMatches,
    this.galleryFilePath,
    this.coupleExtractedRgb,
    this.coupleMatchedStandard,
  });

  bool get isCoupleMode => coupleMatchedStandard != null;

  @override
  List<Object?> get props => [
        extractedRgb,
        matchedStandard,
        commercialMatches,
        galleryFilePath,
        coupleExtractedRgb,
        coupleMatchedStandard,
      ];
}

class ScannerFailure extends ScannerState {
  final String errorMessage;

  const ScannerFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class ScannerGalleryProcessing extends ScannerState {}
