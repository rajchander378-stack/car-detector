import 'dart:ui';

class VehicleDetection {
  final Rect boundingBox;
  final String vehicleType;
  final double confidence;
  final bool isCar;

  VehicleDetection({
    required this.boundingBox,
    required this.vehicleType,
    required this.confidence,
    required this.isCar,
  });

  String get typeDisplayName {
    switch (vehicleType) {
      case 'car':
        return 'Car';
      case 'van':
        return 'Van (coming soon)';
      case 'truck':
        return 'Truck (coming soon)';
      case 'motorcycle':
        return 'Motorcycle (coming soon)';
      case 'bus':
        return 'Bus (not supported)';
      default:
        return 'Unknown vehicle';
    }
  }
}