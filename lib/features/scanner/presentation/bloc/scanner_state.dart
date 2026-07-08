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

  const ScannerCameraReady({
    required this.controller,
    this.detectedFaces = const [],
    this.imageWidth,
    this.imageHeight,
  });

  ScannerCameraReady copyWith({
    CameraController? controller,
    List<Face>? detectedFaces,
    int? imageWidth,
    int? imageHeight,
  }) {
    return ScannerCameraReady(
      controller: controller ?? this.controller,
      detectedFaces: detectedFaces ?? this.detectedFaces,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }

  @override
  List<Object?> get props => [controller, detectedFaces, imageWidth, imageHeight];
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

  const ScannerSuccess({
    required this.extractedRgb,
    required this.matchedStandard,
    required this.commercialMatches,
  });

  @override
  List<Object?> get props => [extractedRgb, matchedStandard, commercialMatches];
}

class ScannerFailure extends ScannerState {
  final String errorMessage;

  const ScannerFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
