import '../../models/app_settings.dart';
import '../render/rasterizer.dart';

/// Turns a rendered [MonoBitmap] plus device settings into the raw byte stream
/// for a specific printer language. Transports are language-agnostic; builders
/// own all the ESC/POS / ZPL / CPCL specifics (raster command, cut, drawer).
abstract class CommandBuilder {
  List<int> build(MonoBitmap bitmap, AppSettings settings);
}

/// Utility: split a 16-bit value into low/high bytes (ESC/POS little-endian).
({int low, int high}) split16(int value) =>
    (low: value & 0xFF, high: (value >> 8) & 0xFF);

/// Uppercase hex encoding for ZPL/CPCL graphic fields.
String bytesToHex(List<int> bytes) {
  const digits = '0123456789ABCDEF';
  final sb = StringBuffer();
  for (final b in bytes) {
    sb
      ..write(digits[(b >> 4) & 0xF])
      ..write(digits[b & 0xF]);
  }
  return sb.toString();
}
