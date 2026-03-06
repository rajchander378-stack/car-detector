import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

class ImageProcessor {
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
        totalBrightness += (pixel.r + pixel.g + pixel.b) / 3;
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

  Future<OptimiseResult> optimise(File imageFile, {String? suffix}) async {
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) {
      throw ImageProcessingException('Failed to decode image');
    }

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
      image = img.adjustColor(image, brightness: 1.3);
    } else if (avgBrightness > 240) {
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

    // Use unique suffix to avoid temp file collisions under concurrency
    final uniqueSuffix = suffix ?? '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final tempDir = Directory.systemTemp;
    final optimised = File('${tempDir.path}/optimised_car_$uniqueSuffix.jpg');
    await optimised.writeAsBytes(img.encodeJpg(image, quality: 85));

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

  Map<String, dynamic> toJson() => {
        'is_acceptable': isAcceptable,
        'issues': issues,
      };
}

class ImageProcessingException implements Exception {
  final String message;
  ImageProcessingException(this.message);
  @override
  String toString() => message;
}
