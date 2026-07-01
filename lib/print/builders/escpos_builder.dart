import '../../core/enums.dart';
import '../../models/app_settings.dart';
import '../render/rasterizer.dart';
import 'command_builder.dart';

/// ESC/POS builder. Supports the three raster "print command" methods exposed
/// in settings plus cut, feed, cash-drawer and beep control codes.
class EscPosBuilder implements CommandBuilder {
  const EscPosBuilder();

  static const _esc = 0x1B;
  static const _gs = 0x1D;

  @override
  List<int> build(MonoBitmap bmp, AppSettings s) {
    final out = <int>[];

    // Initialize.
    out.addAll([_esc, 0x40]); // ESC @

    // Print density / darkness (GS ( K would be model-specific; use a safe
    // no-op-ish default). Center alignment for the receipt block.
    out.addAll([_esc, 0x61, 0x01]); // ESC a 1 -> center

    final method = s.printMethod == PrintMethod.auto
        ? PrintMethod.gsv0
        : s.printMethod;
    switch (method) {
      case PrintMethod.gsv0:
      case PrintMethod.auto:
        out.addAll(_rasterGsv0(bmp));
        break;
      case PrintMethod.esc33:
        out.addAll(_rasterEsc33(bmp));
        break;
      case PrintMethod.star:
        out.addAll(_rasterStar(bmp));
        break;
    }

    out.addAll([_esc, 0x61, 0x00]); // back to left

    // Feed before cut.
    final feed = (s.cutSpacing + s.feedAfterPrint).clamp(0, 20);
    if (feed > 0) out.addAll([_esc, 0x64, feed]); // ESC d n

    // Cut.
    switch (s.cutMode) {
      case CutMode.full:
        out.addAll([_gs, 0x56, 0x00]);
        break;
      case CutMode.partial:
        out.addAll([_gs, 0x56, 0x01]);
        break;
      case CutMode.none:
        break;
    }

    // Cash drawer pulse: ESC p m t1 t2.
    if (s.openCashDrawer) {
      final pin = s.drawerPin == 1 ? 0x01 : 0x00;
      out.addAll([_esc, 0x70, pin, 0x19, 0xFA]);
    }

    // Beep (common buzzer: ESC B n t).
    if (s.beep) {
      out.addAll([_esc, 0x42, 0x03, 0x02]);
    }

    return out;
  }

  /// GS v 0 — raster bit image (the modern, widely supported command).
  List<int> _rasterGsv0(MonoBitmap bmp) {
    final xL = bmp.bytesPerRow & 0xFF;
    final xH = (bmp.bytesPerRow >> 8) & 0xFF;
    final yL = bmp.height & 0xFF;
    final yH = (bmp.height >> 8) & 0xFF;
    return [
      _gs, 0x76, 0x30, 0x00, // GS v 0, mode 0
      xL, xH, yL, yH,
      ...bmp.bits,
    ];
  }

  /// ESC * 33 — 24-dot double-density bit image, printed band by band. This is
  /// the classic Epson method for older firmware.
  List<int> _rasterEsc33(MonoBitmap bmp) {
    final out = <int>[];
    out.addAll([_esc, 0x33, 0x18]); // ESC 3 24 -> line spacing 24 dots
    for (var yBand = 0; yBand < bmp.height; yBand += 24) {
      final nL = bmp.width & 0xFF;
      final nH = (bmp.width >> 8) & 0xFF;
      out.addAll([_esc, 0x2A, 33, nL, nH]); // ESC * 33 nL nH
      for (var x = 0; x < bmp.width; x++) {
        for (var k = 0; k < 3; k++) {
          var b = 0;
          for (var bit = 0; bit < 8; bit++) {
            final y = yBand + k * 8 + bit;
            if (y < bmp.height && _dot(bmp, x, y)) {
              b |= (0x80 >> bit);
            }
          }
          out.add(b);
        }
      }
      out.addAll([0x0A]); // line feed
    }
    out.addAll([_esc, 0x32]); // ESC 2 -> reset line spacing
    return out;
  }

  /// Star Micronics raster mode (ESC * r A ... ESC * r B). Approximated with the
  /// Star line-graphics command set.
  List<int> _rasterStar(MonoBitmap bmp) {
    final out = <int>[];
    out.addAll([_esc, 0x2A, 0x72, 0x41]); // ESC * r A  (enter raster)
    out.addAll([_esc, 0x2A, 0x72, 0x50, 0x30, 0x00]); // set page 0
    // 'b' data command: ESC * r Y width-lo width-hi data per row.
    for (var y = 0; y < bmp.height; y++) {
      out.addAll([0x62, bmp.bytesPerRow & 0xFF, (bmp.bytesPerRow >> 8) & 0xFF]);
      final start = y * bmp.bytesPerRow;
      out.addAll(bmp.bits.sublist(start, start + bmp.bytesPerRow));
    }
    out.addAll([_esc, 0x2A, 0x72, 0x42]); // ESC * r B  (exit raster)
    return out;
  }

  bool _dot(MonoBitmap bmp, int x, int y) {
    final byte = bmp.bits[y * bmp.bytesPerRow + (x >> 3)];
    return (byte & (0x80 >> (x & 7))) != 0;
  }
}
