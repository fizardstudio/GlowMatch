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

  const FaceDetected({
    required this.faces,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  List<Object?> get props => [faces, imageWidth, imageHeight];
}

class CaptureImage extends ScannerEvent {}

class ResetScanner extends ScannerEvent {}
