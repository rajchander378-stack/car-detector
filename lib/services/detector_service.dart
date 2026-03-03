import 'dart:io';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import '../models/vehicle_detection.dart';

class DetectorService {
  late ObjectDetector _detector;

  DetectorService() {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _detector = ObjectDetector(options: options);
  }

  Future<VehicleDetection?> detectVehicle(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final objects = await _detector.processImage(inputImage);

    DetectedObject? bestVehicle;
    double bestConfidence = 0.0;
    String detectedType = 'unknown';

    for (final object in objects) {
      for (final label in object.labels) {
        final name = label.text.toLowerCase();
        final confidence = label.confidence;

        if (_isVehicle(name) && confidence > bestConfidence) {
          bestVehicle = object;
          bestConfidence = confidence;
          detectedType = _classifyVehicleType(name);
        }
      }
    }

    if (bestVehicle == null) return null;

    return VehicleDetection(
      boundingBox: bestVehicle.boundingBox,
      vehicleType: detectedType,
      confidence: bestConfidence,
      isCar: detectedType == 'car',
    );
  }

  bool _isVehicle(String label) {
    const vehicleLabels = [
      'car', 'vehicle', 'automobile', 'truck',
      'van', 'bus', 'motorcycle', 'suv',
    ];
    return vehicleLabels.any((v) => label.contains(v));
  }

  String _classifyVehicleType(String label) {
    if (label.contains('motorcycle') ||
        label.contains('bike')) {
      return 'motorcycle';
    }
    if (label.contains('truck')) return 'truck';
    if (label.contains('van')) return 'van';
    if (label.contains('bus')) return 'bus';
    return 'car';
  }

  void dispose() {
    _detector.close();
  }
}