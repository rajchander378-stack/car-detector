// Generates AutoSpotter app icon assets using the `image` package.
// Run: dart run tool/generate_icon.dart

import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  const bgColor = 0xFF1565C0; // App seed color (blue)
  const fgColor = 0xFFFFFFFF; // White

  // --- Generate adaptive icon background (solid blue) ---
  final bg = img.Image(width: size, height: size);
  img.fill(bg, color: img.ColorRgba8(
    (bgColor >> 16) & 0xFF, (bgColor >> 8) & 0xFF, bgColor & 0xFF, 0xFF));

  // --- Generate adaptive icon foreground (white car on transparent) ---
  final fg = img.Image(width: size, height: size);
  // Keep transparent background

  _drawCar(fg, size, fgColor);

  // --- Generate combined icon (for iOS, web, etc.) ---
  final combined = img.Image(width: size, height: size);
  img.fill(combined, color: img.ColorRgba8(
    (bgColor >> 16) & 0xFF, (bgColor >> 8) & 0xFF, bgColor & 0xFF, 0xFF));
  _drawCar(combined, size, fgColor);

  // Ensure assets/icon directory exists
  Directory('assets/icon').createSync(recursive: true);

  // Save files
  File('assets/icon/icon_background.png').writeAsBytesSync(img.encodePng(bg));
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(combined));

  print('Icon assets generated in assets/icon/');
}

/// Draws a stylised side-view car silhouette centred on the image.
/// The car is drawn within the safe zone for adaptive icons (centre 66%).
void _drawCar(img.Image image, int size, int color) {
  final c = img.ColorRgba8(
    (color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF, 0xFF);

  // Safe zone for adaptive icons: centre 66% (masking can crop up to 17% each side)
  // So we draw within roughly 20%-80% of the image
  final double s = size.toDouble();

  // Car body proportions (relative to size)
  final bodyLeft = (s * 0.18).round();
  final bodyRight = (s * 0.82).round();
  final bodyTop = (s * 0.48).round();
  final bodyBottom = (s * 0.65).round();
  final bodyHeight = bodyBottom - bodyTop;

  // Draw main body (rounded rectangle)
  _fillRoundedRect(image, bodyLeft, bodyTop, bodyRight, bodyBottom,
    (bodyHeight * 0.25).round(), c);

  // Cabin / roof (trapezoid-ish shape using a narrower rounded rect)
  final cabinLeft = (s * 0.35).round();
  final cabinRight = (s * 0.72).round();
  final cabinTop = (s * 0.34).round();
  final cabinBottom = bodyTop + 2;
  _fillRoundedRect(image, cabinLeft, cabinTop, cabinRight, cabinBottom,
    (s * 0.04).round(), c);

  // Windshield angle — fill a triangle to connect cabin to hood
  _fillTriangle(image,
    cabinLeft, cabinBottom - 1,  // bottom-left of cabin
    cabinLeft, cabinTop + (s * 0.04).round(),  // top-left of cabin (with radius offset)
    bodyLeft + (s * 0.05).round(), cabinBottom - 1,  // hood connection point
    c);

  // Rear window angle
  _fillTriangle(image,
    cabinRight, cabinBottom - 1,
    cabinRight, cabinTop + (s * 0.04).round(),
    bodyRight - (s * 0.04).round(), cabinBottom - 1,
    c);

  // Wheels
  final wheelRadius = (s * 0.07).round();
  final wheelY = bodyBottom;
  final wheel1X = (s * 0.32).round();
  final wheel2X = (s * 0.70).round();

  // Wheel wells (cut into body) — draw dark circles, then white wheel circles
  // Actually, just draw white filled circles for the wheels
  _fillCircle(image, wheel1X, wheelY, wheelRadius, c);
  _fillCircle(image, wheel2X, wheelY, wheelRadius, c);

  // Inner wheel circles (hub) — draw slightly smaller transparent circles
  // to give a "tire + rim" look
  final hubRadius = (wheelRadius * 0.55).round();
  final hubColor = img.ColorRgba8(0, 0, 0, 0); // transparent for foreground
  // For combined icon, we want the blue to show through
  // Since this function is generic, let's just draw a smaller accent circle
  _fillCircle(image, wheel1X, wheelY, hubRadius, img.ColorRgba8(
    (0xFF1565C0 >> 16) & 0xFF, (0xFF1565C0 >> 8) & 0xFF, 0xFF1565C0 & 0xFF, 0xFF));
  _fillCircle(image, wheel2X, wheelY, hubRadius, img.ColorRgba8(
    (0xFF1565C0 >> 16) & 0xFF, (0xFF1565C0 >> 8) & 0xFF, 0xFF1565C0 & 0xFF, 0xFF));

  // Small hub dot (white)
  final dotRadius = (wheelRadius * 0.2).round();
  _fillCircle(image, wheel1X, wheelY, dotRadius, c);
  _fillCircle(image, wheel2X, wheelY, dotRadius, c);

  // Headlight
  final hlLeft = bodyRight - (s * 0.06).round();
  final hlTop = bodyTop + (bodyHeight * 0.2).round();
  final hlRight = bodyRight - (s * 0.01).round();
  final hlBottom = bodyTop + (bodyHeight * 0.5).round();
  _fillRoundedRect(image, hlLeft, hlTop, hlRight, hlBottom,
    (s * 0.015).round(), img.ColorRgba8(255, 235, 59, 255)); // yellow headlight

  // Taillight
  final tlLeft = bodyLeft + (s * 0.01).round();
  final tlTop = bodyTop + (bodyHeight * 0.2).round();
  final tlRight = bodyLeft + (s * 0.05).round();
  final tlBottom = bodyTop + (bodyHeight * 0.5).round();
  _fillRoundedRect(image, tlLeft, tlTop, tlRight, tlBottom,
    (s * 0.015).round(), img.ColorRgba8(244, 67, 54, 255)); // red taillight

  // Window glass (darker blue tint) on the cabin
  final winLeft = cabinLeft + (s * 0.03).round();
  final winRight = cabinRight - (s * 0.03).round();
  final winTop = cabinTop + (s * 0.03).round();
  final winBottom = cabinBottom - (s * 0.03).round();
  final winMid = ((winLeft + winRight) / 2).round();
  // Draw two window panes
  _fillRoundedRect(image, winLeft + (s * 0.02).round(), winTop, winMid - (s * 0.01).round(), winBottom,
    (s * 0.015).round(), img.ColorRgba8(100, 181, 246, 255)); // light blue
  _fillRoundedRect(image, winMid + (s * 0.01).round(), winTop, winRight - (s * 0.01).round(), winBottom,
    (s * 0.015).round(), img.ColorRgba8(100, 181, 246, 255));

  // Add "crosshair" / spotter element — a subtle targeting reticle around the car
  final reticleColor = img.ColorRgba8(255, 255, 255, 180);
  final cx = (s * 0.50).round();
  final cy = (s * 0.50).round();
  final rOuter = (s * 0.38).round();
  final rInner = (s * 0.35).round();
  // Draw corner brackets of a targeting reticle
  final bracketLen = (s * 0.08).round();
  final thick = (s * 0.008).round().clamp(2, 10);

  // Top-left bracket
  _fillRect(image, cx - rOuter, cy - rOuter, cx - rOuter + bracketLen, cy - rOuter + thick, c);
  _fillRect(image, cx - rOuter, cy - rOuter, cx - rOuter + thick, cy - rOuter + bracketLen, c);
  // Top-right bracket
  _fillRect(image, cx + rOuter - bracketLen, cy - rOuter, cx + rOuter, cy - rOuter + thick, c);
  _fillRect(image, cx + rOuter - thick, cy - rOuter, cx + rOuter, cy - rOuter + bracketLen, c);
  // Bottom-left bracket
  _fillRect(image, cx - rOuter, cy + rOuter - thick, cx - rOuter + bracketLen, cy + rOuter, c);
  _fillRect(image, cx - rOuter, cy + rOuter - bracketLen, cx - rOuter + thick, cy + rOuter, c);
  // Bottom-right bracket
  _fillRect(image, cx + rOuter - bracketLen, cy + rOuter - thick, cx + rOuter, cy + rOuter, c);
  _fillRect(image, cx + rOuter - thick, cy + rOuter - bracketLen, cx + rOuter, cy + rOuter, c);
}

void _fillRect(img.Image image, int x1, int y1, int x2, int y2, img.Color color) {
  for (var y = y1; y < y2; y++) {
    for (var x = x1; x < x2; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        image.setPixel(x, y, color);
      }
    }
  }
}

void _fillRoundedRect(img.Image image, int x1, int y1, int x2, int y2, int radius, img.Color color) {
  final int r = radius.clamp(0, min((x2 - x1) ~/ 2, (y2 - y1) ~/ 2)).toInt();
  for (var y = y1; y < y2; y++) {
    for (var x = x1; x < x2; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        // Check if in rounded corner region
        bool inside = true;
        if (x < x1 + r && y < y1 + r) {
          inside = _dist(x, y, (x1 + r).toInt(), (y1 + r).toInt()) <= r;
        } else if (x >= x2 - r && y < y1 + r) {
          inside = _dist(x, y, (x2 - r - 1).toInt(), (y1 + r).toInt()) <= r;
        } else if (x < x1 + r && y >= y2 - r) {
          inside = _dist(x, y, (x1 + r).toInt(), (y2 - r - 1).toInt()) <= r;
        } else if (x >= x2 - r && y >= y2 - r) {
          inside = _dist(x, y, (x2 - r - 1).toInt(), (y2 - r - 1).toInt()) <= r;
        }
        if (inside) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

double _dist(int x1, int y1, int x2, int y2) {
  return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

void _fillCircle(img.Image image, int cx, int cy, int radius, img.Color color) {
  for (var y = cy - radius; y <= cy + radius; y++) {
    for (var x = cx - radius; x <= cx + radius; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        if (_dist(x, y, cx, cy) <= radius) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

void _fillTriangle(img.Image image, int x1, int y1, int x2, int y2, int x3, int y3, img.Color color) {
  final minX = [x1, x2, x3].reduce(min);
  final maxX = [x1, x2, x3].reduce(max);
  final minY = [y1, y2, y3].reduce(min);
  final maxY = [y1, y2, y3].reduce(max);

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        if (_pointInTriangle(x, y, x1, y1, x2, y2, x3, y3)) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

bool _pointInTriangle(int px, int py, int x1, int y1, int x2, int y2, int x3, int y3) {
  final d1 = _sign(px, py, x1, y1, x2, y2);
  final d2 = _sign(px, py, x2, y2, x3, y3);
  final d3 = _sign(px, py, x3, y3, x1, y1);
  final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
  final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
  return !(hasNeg && hasPos);
}

double _sign(int x1, int y1, int x2, int y2, int x3, int y3) {
  return (x1 - x3) * (y2 - y3) - (x2 - x3) * (y1 - y3) + 0.0;
}
