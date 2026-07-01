/// Maps a physical paper width (mm) to the printable dot width used both for
/// on-screen preview and for the rasterized bytes sent to the printer.
///
/// Thermal heads are 8 dots/mm (203 dpi). The printable area is narrower than
/// the paper because of margins, so common sizes use their well-known dot
/// counts; custom widths fall back to a margin-adjusted estimate rounded to a
/// multiple of 8 (ESC/POS raster requires width in whole bytes).
class PaperMetrics {
  const PaperMetrics({required this.widthMm, required this.dots});

  final double widthMm;
  final int dots;

  double get widthInches => widthMm / 25.4;

  static PaperMetrics forWidth(double mm) {
    final dots = _printableDots(mm);
    return PaperMetrics(widthMm: mm, dots: dots);
  }

  static int _printableDots(double mm) {
    // Snap common presets to their standard printable widths.
    if ((mm - 44).abs() < 2) return 288; // 36mm printable
    if ((mm - 58).abs() < 2) return 384; // 48mm printable
    if ((mm - 72).abs() < 2) return 512; // 64mm printable
    if ((mm - 80).abs() < 2) return 576; // 72mm printable
    // Custom: assume ~5mm total margins, 8 dots/mm, snap to byte boundary.
    final printableMm = (mm - 5).clamp(20, 120);
    final raw = (printableMm * 8).round();
    return (raw ~/ 8) * 8;
  }
}

const double mmPerInch = 25.4;
double mmToInches(double mm) => mm / mmPerInch;
double inchesToMm(double inches) => inches * mmPerInch;
