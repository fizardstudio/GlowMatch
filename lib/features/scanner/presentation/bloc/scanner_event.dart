import 'package:equatable/equatable.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

class InitializeCamera extends ScannerEvent {}

class StartScanning extends ScannerEvent {}

class FaceDetected extends ScannerEvent {
  final List<Face> faces;
  final int imageWidth;
  final int imageHeight;
  final String lightingStatus;
  final String lightingTemp;

  const FaceDetected({
    required this.faces,
    required this.imageWidth,
    required this.imageHeight,
    required this.lightingStatus,
    required this.lightingTemp,
  });

  @override
  List<Object?> get props => [faces, imageWidth, imageHeight, lightingStatus, lightingTemp];
}

class SwitchCamera extends ScannerEvent {}

class CaptureImage extends ScannerEvent {
  final bool isCoupleMode;
  const CaptureImage({this.isCoupleMode = false});

  @override
  List<Object?> get props => [isCoupleMode];
}

class ResetScanner extends ScannerEvent {}

class DisposeCamera extends ScannerEvent {}

class ProcessGalleryImage extends ScannerEvent {
  final String filePath;
  const ProcessGalleryImage(this.filePath);

  @override
  List<Object?> get props => [filePath];
}
