import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// A 1-bit monochrome image: row-major, 8 pixels per byte, MSB first, a set bit
/// meaning a black dot. Width is padded to a whole byte. This is the common
/// currency handed to every [CommandBuilder].
class MonoBitmap {
  MonoBitmap({
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.bits,
  });

  final int width;
  final int height;
  final int bytesPerRow;
  final Uint8List bits;
}

/// Captures a live [RenderRepaintBoundary] (from the preview screen) at exactly
/// 1 device pixel per printer dot, so the printed output matches the preview.
Future<MonoBitmap> captureBoundary(
  RenderRepaintBoundary boundary, {
  int threshold = 160,
}) async {
  final image = await boundary.toImage(pixelRatio: 1.0);
  try {
    return await imageToMono(image, threshold: threshold);
  } finally {
    image.dispose();
  }
}

/// Thresholds an [ui.Image] into a [MonoBitmap]. Pixels darker than [threshold]
/// (or transparent-over-white) become black dots.
Future<MonoBitmap> imageToMono(ui.Image image, {int threshold = 160}) async {
  final width = image.width;
  final height = image.height;
  final byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    throw StateError('Could not read image bytes for rasterization');
  }
  final rgba = byteData.buffer.asUint8List();
  final bytesPerRow = (width + 7) ~/ 8;
  final bits = Uint8List(bytesPerRow * height);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final a = rgba[i + 3];
      // Composite over white, then compute luminance.
      final alpha = a / 255.0;
      final lr = r * alpha + 255 * (1 - alpha);
      final lg = g * alpha + 255 * (1 - alpha);
      final lb = b * alpha + 255 * (1 - alpha);
      final lum = 0.299 * lr + 0.587 * lg + 0.114 * lb;
      if (lum < threshold) {
        bits[y * bytesPerRow + (x >> 3)] |= (0x80 >> (x & 7));
      }
    }
  }
  return MonoBitmap(
    width: width,
    height: height,
    bytesPerRow: bytesPerRow,
    bits: bits,
  );
}
