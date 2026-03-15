import 'dart:io';
import 'package:image/image.dart' as img;
import '../models/vehicle_detection.dart';

class ImageProcessor {

  Future<File> cropToVehicle(
    File imageFile,
    VehicleDetection detection,
    {double marginPercent = 0.1}
  ) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes)!;
    final box = detection.boundingBox;

    final marginX = (box.width * marginPercent).toInt();
    final marginY = (box.height * marginPercent).toInt();

    final x = (box.left - marginX)
        .clamp(0, image.width).toInt();
    final y = (box.top - marginY)
        .clamp(0, image.height).toInt();
    final w = (box.width + marginX * 2)
        .clamp(1, image.width - x).toInt();
    final h = (box.height + marginY * 2)
        .clamp(1, image.height - y).toInt();

    final cropped = img.copyCrop(
      image, x: x, y: y, width: w, height: h
    );

    final tempDir = Directory.systemTemp;
    final croppedFile = File(
      '${tempDir.path}/cropped_car.jpg'
    );
    await croppedFile.writeAsBytes(
      img.encodeJpg(cropped, quality: 85)
    );
    return croppedFile;
  }

  ImageQuality assessQuality(img.Image image) {
    final issues = <String>[];

    if (image.width < 200 || image.height < 200) {
      issues.add('Image too small - get closer');
    }

    double totalBrightness = 0;
    int sampleCount = 0;
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        totalBrightness +=
            (pixel.r + pixel.g + pixel.b) / 3;
        sampleCount++;
      }
    }
    final avgBrightness = totalBrightness / sampleCount;

    if (avgBrightness < 40) {
      issues.add('Image too dark');
    }
    if (avgBrightness > 240) {
      issues.add('Image too bright');
    }

    return ImageQuality(
      isAcceptable: issues.isEmpty,
      issues: issues,
    );
  }

  Future<OptimiseResult> optimise(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes)!;

    // 1. Bake EXIF orientation so the image is right-side up
    image = img.bakeOrientation(image);

    // 2. Resize
    if (image.width > 1024) {
      image = img.copyResize(image, width: 1024);
    }

    // 3. Auto brightness correction
    double totalBrightness = 0;
    int sampleCount = 0;
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        totalBrightness += (pixel.r + pixel.g + pixel.b) / 3;
        sampleCount++;
      }
    }
    final avgBrightness = totalBrightness / sampleCount;

    if (avgBrightness < 40) {
      // Too dark — brighten
      image = img.adjustColor(image, brightness: 1.3);
    } else if (avgBrightness > 240) {
      // Too bright — darken
      image = img.adjustColor(image, brightness: 0.7);
    }

    // Mild contrast boost for flat-light conditions
    image = img.contrast(image, contrast: 110);

    // 4. Light sharpen for plate legibility
    image = img.convolution(
      image,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
      amount: 0.3,
    );

    // 5. Assess quality
    final quality = assessQuality(image);

    final tempDir = Directory.systemTemp;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final optimised = File(
      '${tempDir.path}/optimised_car_$stamp.jpg'
    );
    await optimised.writeAsBytes(
      img.encodeJpg(image, quality: 85)
    );
    return OptimiseResult(file: optimised, quality: quality);
  }
}

class OptimiseResult {
  final File file;
  final ImageQuality quality;

  OptimiseResult({required this.file, required this.quality});
}

class ImageQuality {
  final bool isAcceptable;
  final List<String> issues;

  ImageQuality({
    required this.isAcceptable,
    required this.issues,
  });
}