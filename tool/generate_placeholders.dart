import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final samples = [
    {'name': 'sample_red_hatchback.jpg', 'r': 200, 'g': 50, 'b': 50},
    {'name': 'sample_blue_saloon.jpg', 'r': 40, 'g': 80, 'b': 180},
    {'name': 'sample_white_suv.jpg', 'r': 220, 'g': 220, 'b': 220},
    {'name': 'sample_black_estate.jpg', 'r': 40, 'g': 40, 'b': 40},
  ];

  for (final s in samples) {
    final r = s['r'] as int;
    final g = s['g'] as int;
    final b = s['b'] as int;

    final image = img.Image(width: 800, height: 600);
    img.fill(image, color: img.ColorRgb8(r, g, b));

    // Car body shape
    img.fillRect(image,
        x1: 150, y1: 200, x2: 650, y2: 450,
        color: img.ColorRgb8(
            (r * 0.8).toInt(), (g * 0.8).toInt(), (b * 0.8).toInt()));

    // Wheels
    img.fillCircle(image, x: 250, y: 440, radius: 40,
        color: img.ColorRgb8(30, 30, 30));
    img.fillCircle(image, x: 550, y: 440, radius: 40,
        color: img.ColorRgb8(30, 30, 30));

    // Windshield
    img.fillRect(image,
        x1: 380, y1: 220, x2: 600, y2: 320,
        color: img.ColorRgb8(150, 200, 230));

    final file = File('assets/sample_cars/${s['name']}');
    file.writeAsBytesSync(img.encodeJpg(image, quality: 85));
    print('Created ${s['name']}');
  }
}
